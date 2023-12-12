function! insert#map() abort
  let s:keys_to_remaps = []
  let sid = "\<sid>"
  for [key, val] in items(opts#get('map_keys_dict'))
    if index(['|', ''''], key) >= 0
      continue
    endif
    let current_map = maparg(key, 'i', 0, 1)
    let k = keytrans(key)
    call add(s:keys_to_remaps, empty(current_map) ? k : current_map)
    execute $"inoremap {k} <cmd>call {sid}i1('{keytrans(k)}', {val})<cr><cmd>call {sid}i2()<cr>"
  endfor

  " 以下の2つはループでの処理が困難なので個別対応
  " single quote
  let current_map = maparg("'", 'i', 0, 1)
  call add(s:keys_to_remaps, empty(current_map) ? "'" : current_map)
  inoremap ' <cmd>call s:i1("'")<cr><cmd>call s:i2()<cr>
  " bar
  let current_map = maparg('<bar>', 'i', 0, 1)
  call add(s:keys_to_remaps, empty(current_map) ? '<bar>' : current_map)
  inoremap <bar> <cmd>call s:i1("<bar>")<cr><cmd>call s:i2()<cr>

  let s:reserved_spec = []
  let s:comp_offset = 0
endfunction

function! insert#unmap() abort
  for k in s:keys_to_remaps
    try
      if type(k) == v:t_string
        execute 'iunmap' k
      else
        call mapset('i', 0, k)
      endif
    catch
      echomsg k v:exception
    endtry
  endfor

  let s:reserved_spec = []
  let s:comp_offset = 0
endfunction

" function! insert#henkan_count(list_size) abort
"   ここをCompleteChangedでよび出せば良いかと思ったが<c-n>で
"   候補を選択したタイミングでも毎回呼び出されてしまうのでクリアされてしまって困る
"   let result = a:list_size - s:comp_offset
"   let s:comp_offset = 0
"   return result
" endfunction

function! s:get_spec(key) abort
  let current = store#get('choku') .. a:key
  " echomsg $'spec choku {store#get("choku")}'

  if has_key(opts#get('kana_table'), current)
    " s:store.chokuの残存文字と合わせて完成した場合
    if type(opts#get('kana_table')[current]) == v:t_dict
      call store#clear('choku')
      return opts#get('kana_table')[current]
    endif
    let [kana, roma; _rest] = opts#get('kana_table')[current]->split('\A*\zs') + ['']
    call store#set('choku', roma)
    return kana
  elseif has_key(opts#get('preceding_keys_dict'), current)
    " 完成はしていないが、先行入力の可能性がある場合
    call store#set('choku', current)
    " echomsg $'choku {store#get("choku")}'
    return ''
  endif

  " echomsg $'oh choku {store#get("choku")} key {a:key} has_key {has_key(opts#get('kana_table'), a:key)}'
  if has_key(opts#get('kana_table'), a:key)
    let spec = opts#get('kana_table')[a:key]

    " 半端な文字はバッファに載せる
    " ただしspecが文字列でdel_odd_charがtrueなら消す(残さない)
    if !opts#get('del_odd_char') || type(spec) == v:t_dict
      call feedkeys(store#get('choku'), 'ni')
      if phase#is_enabled('okuri')
        call store#push('okuri', store#get('choku'))
      elseif phase#is_enabled('machi')
        call store#push('machi', store#get('choku'))
      endif
    endif

    call store#clear('choku')
    return spec
  endif

  if has_key(opts#get('preceding_keys_dict'), a:key)
    call store#set('choku', a:key)
    return ''
  endif

  call store#clear('choku')
  return a:key
endfunction

function! s:i1(key, with_sticky = v:false) abort
  let key = a:key
  if a:with_sticky
    call func#v_sticky('')
    let key = a:key->tolower()
  endif

  let spec = a:key =~ '^[!-~]$' && mode#is_direct() ? a:key
        \ : s:get_spec(key)

  if type(spec) == v:t_dict
    " echomsg spec
    if has_key(spec, 'expr')
      let spec = call(spec.expr[0], spec.expr[1:])
    else
      let s:reserved_spec = [spec, key]
      return
    endif
  endif

  if type(spec) != v:t_string
    call utils#echoerr('input must be string')
    return
  endif

  if spec ==# ''
    return
  endif

  call feedkeys(mode#convert(spec), 'ni')
  if phase#is_enabled('okuri')
    call store#push('okuri', spec)
  elseif phase#is_enabled('machi')
    call store#push('machi', spec)
  endif
endfunction

function! s:i2() abort
  let spec_result = ''
  if !empty(s:reserved_spec)
    " funcのfeedkeysはフラグにiを使わない
    let [spec, key] = s:reserved_spec
    if has_key(spec, 'func')
      if index(['backspace', 'kakutei', 'henkan', 'sticky'], spec.func) >= 0
        let spec_result = call($'func#v_{spec.func}', [key])
      endif
    elseif has_key(spec, 'mode')
      call mode#set(spec.mode)
      if mode#is_start_sticky()
        call func#v_sticky('')
      endif
    endif
    let s:reserved_spec = []
  endif

  call store#display_odd_char()
  if (type(spec_result) == v:t_string && spec_result ==# '_henkan_start_') ||
        \ (store#get('choku') ==# ''
        \ && phase#is_enabled('okuri')
        \ && utils#compare_pos(phase#getpos('okuri'), getpos('.')[1:2]) > 0)
    call s:henkan_start()
    unlet! s:save_okuri_pos
  endif

  if exists('s:save_okuri_pos')
    " echomsg 'get s:save_okuri_pos' s:save_okuri_pos
    call phase#move('okuri', s:save_okuri_pos)
  elseif !exists('s:save_okuri_pos') && phase#is_enabled('okuri')
    let s:save_okuri_pos = phase#getpos('okuri')
    " echomsg 'set s:save_okuri_pos' s:save_okuri_pos
  endif
endfunction

" yomiは必須
function! s:make_special_henkan_item(opts) abort
  let yomi = a:opts.yomi
  let word = get(a:opts, 'word', yomi)
  let abbr = get(a:opts, 'abbr', word)
  let info = get(a:opts, 'word', yomi)

  let user_data = { 'yomi': yomi }
  if has_key(a:opts, 'virt_poc_process')
    let user_data.virt_poc_process = a:opts.virt_poc_process
    let user_data.context = {
          \   'start_col': phase#getpos('machi')[1],
          \   'pos': getpos('.')[1:2],
          \   'machi': store#get('machi'),
          \   'okuri': store#get('okuri'),
          \   'is_trailing': col('.') == col('$')
          \ }
  endif

  return {
        \ 'word': word, 'abbr': abbr, 'menu': info, 'info': info, 'dup': v:true,
        \ 'user_data': user_data
        \ }
endfunction

function! s:henkan_start() abort
  " echomsg $'henkan_start machi {store#get("machi")} okuri {store#get("okuri")}'
  call henkan_list#update_manual(store#get("machi"), store#get("okuri"))
  let comp_list = copy(henkan_list#get())
  let list_len = len(comp_list)
  let yomi = store#get('machi') .. store#get('okuri')

  if opts#get('use_google_cgi')
    call add(comp_list, s:make_special_henkan_item({
          \ 'abbr': '[Google変換]',
          \ 'yomi': yomi,
          \ 'virt_poc_process': 'google'
          \ }))
    let s:comp_offset += 1
  endif

  call add(comp_list, s:make_special_henkan_item({
        \ 'abbr': '[辞書登録]',
        \ 'yomi': yomi,
        \ 'virt_poc_process': 'new_word'
        \ }))
  let s:comp_offset += 1

  call complete(phase#getpos('machi')[1], comp_list)
  call phase#disable('okuri')
  call phase#enable('kouho')
  if list_len != 0
    call feedkeys("\<c-n>", 'n')
  endif
endfunction
