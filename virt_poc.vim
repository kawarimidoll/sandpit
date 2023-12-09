source ./utils.vim

if !exists('?keytrans') || exists(':defer') != 2
  call utils#echoerr('このバージョンの' .. v:progname .. 'はサポートしていません')
  finish
endif

source ./google_cgi.vim
source ./inline_mark.vim
source ./converters.vim
source ./henkan_list.vim
source ./opts.vim
source ./phase.vim
source ./store.vim
source ./func.vim
source ./mode.vim

function! s:is_completed() abort
  return get(complete_info(), 'selected', -1) >= 0
endfunction

function! s:doautocmd(event_name) abort
  if exists($'#User#{a:event_name}')
    execute $'doautocmd User {a:event_name}'
  endif
endfunction

function! virt_poc#enable() abort
  if s:is_enable
    return
  endif
  call s:doautocmd('virt_poc_enable_pre')
  defer s:doautocmd('virt_poc_enable_post')

  if opts#get('textwidth_zero')
    let s:save_textwidth = &textwidth
    set textwidth=0
  endif

  let s:keys_to_remaps = []
  let sid = "\<sid>"
  for [key, val] in items(opts#get('map_keys_dict'))
    if index(['|', ''''], key) >= 0
      continue
    endif
    let current_map = maparg(key, 'i', 0, 1)
    let k = keytrans(key)
    call add(s:keys_to_remaps, empty(current_map) ? k : current_map)
    execute $"inoremap {k} <cmd>call {sid}ins('{keytrans(k)}', {val})<cr><cmd>call {sid}after_ins()<cr>"
  endfor

  " 以下の2つはループでの処理が困難なので個別対応
  " single quote
  let current_map = maparg("'", 'i', 0, 1)
  call add(s:keys_to_remaps, empty(current_map) ? "'" : current_map)
  inoremap ' <cmd>call s:ins("'")<cr><cmd>call s:after_ins()<cr>
  " bar
  let current_map = maparg('<bar>', 'i', 0, 1)
  call add(s:keys_to_remaps, empty(current_map) ? '<bar>' : current_map)
  inoremap <bar> <cmd>call s:ins("<bar>")<cr><cmd>call s:after_ins()<cr>

  augroup virt_poc#augroup
    autocmd!
    autocmd InsertLeave * call virt_poc#disable()
    autocmd CompleteChanged *
          \   echo $'{v:event.size - s:comp_offset}件'
          \ | let s:comp_offset = 0
          \ | if s:is_completed() && phase#is_enabled('machi') && store#get('choku') !=# ''
          \ |   call store#clear('choku')
          \ |   call store#display_odd_char()
          \ | endif
    autocmd TextChangedI * call s:auto_complete()
    autocmd CompleteDonePre * call timer_start(1, {->call("\<sid>complete_done_pre", [])})
  augroup END

  call phase#clear()
  call store#clear()
  call mode#clear()
  let s:reserved_spec = []
  let s:comp_offset = 0
  let s:is_enable = v:true
endfunction

function! virt_poc#disable() abort
  if !s:is_enable
    return
  endif
  call s:doautocmd('virt_poc_disable_pre')
  defer s:doautocmd('virt_poc_disable_post')

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

  if has_key(s:, 'save_textwidth')
    let &textwidth = s:save_textwidth
    unlet! s:save_textwidth
  endif

  autocmd! virt_poc#augroup

  call phase#clear()
  call store#clear()
  let s:reserved_spec = []
  let s:is_enable = v:false
endfunction

function! virt_poc#toggle() abort
  return s:is_enable ? virt_poc#disable() : virt_poc#enable()
endfunction

function! virt_poc#init(opts = {}) abort
  call s:doautocmd('virt_poc_initialize_pre')
  defer s:doautocmd('virt_poc_initialize_post')
  try
    call opts#parse(a:opts)
  catch
    call utils#echoerr($'[virt_poc#init] {v:exception}')
    call utils#echoerr('[virt_poc#init] abort')
    return
  endtry

  let s:is_enable = v:false
endfunction

function! s:ins(key, with_sticky = v:false) abort
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

function! s:henkan_start() abort
  " echomsg $'henkan_start machi {store#get("machi")} okuri {store#get("okuri")}'
  call henkan_list#update_manual(store#get("machi"), store#get("okuri"))
  let comp_list = copy(henkan_list#get())
  let list_len = len(comp_list)

  let yomi = store#get('machi') .. store#get('okuri')
  let context = {
        \   'start_col': phase#getpos('machi')[1],
        \   'pos': getpos('.')[1:2],
        \   'machi': store#get('machi'),
        \   'okuri': store#get('okuri'),
        \   'is_trailing': col('.') == col('$')
        \ }
  if opts#get('use_google_cgi')
    call add(comp_list, {
          \ 'word': yomi,
          \ 'abbr': '[Google変換]',
          \ 'menu': yomi,
          \ 'info': yomi,
          \ 'dup': 1,
          \ 'user_data': { 'yomi': yomi, 'context': context, 'virt_poc_process': 'google' }
          \ })
    let s:comp_offset += 1
  endif

  call add(comp_list, {
        \ 'word': yomi,
        \ 'abbr': '[辞書登録]',
        \ 'menu': yomi,
        \ 'info': yomi,
        \ 'dup': 1,
        \ 'user_data': { 'yomi': yomi, 'context': context, 'virt_poc_process': 'new_word' }
        \ })
  let s:comp_offset += 1

  call complete(phase#getpos('machi')[1], comp_list)
  call phase#disable('okuri')
  call phase#enable('kouho')
  if list_len != 0
    call feedkeys("\<c-n>", 'n')
  endif
endfunction

let s:latest_auto_complete_str = ''
function! s:auto_complete() abort
  let min_length = 5
  if phase#is_enabled('kouho') || phase#is_enabled('okuri') || phase#is_disabled('machi') || store#get('machi') ==# ''
    return
  endif

  " auto complete
  let need_update = strcharpart(store#get('machi'), 0, min_length + 1) !=# strcharpart(s:latest_auto_complete_str, 0, min_length + 1)
  let s:latest_auto_complete_str = store#get('machi')
  let exact_match = s:latest_auto_complete_str->strcharlen() < min_length

  if need_update || exact_match
    call henkan_list#update_fuzzy(s:latest_auto_complete_str, exact_match)
    " call utils#debug_log('henkan_list#get_fuzzy')
    " call utils#debug_log(henkan_list#get_fuzzy())
  endif
  " echomsg s:latest_auto_complete_str store#get('machi')

  " yomiの前方一致で絞り込む
  let comp_list = copy(henkan_list#get_fuzzy())
        \ ->filter($"v:val.user_data.yomi =~# '^{s:latest_auto_complete_str}'")

  if len(comp_list) > 0
    call complete(phase#getpos('machi')[1], comp_list)
  endif
endfunction

function! s:after_ins() abort
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

function! s:complete_done_pre() abort
  if pumvisible() && phase#is_enabled('kouho')
    return
  endif
  call phase#disable('kouho')
  " ここでは既にCompleteDoneが発行されているのでcomplete_info()は使用できない
  if !empty(v:completed_item)
    call phase#disable('machi')
    call store#clear('machi')
    call store#clear('okuri')
  endif

  let user_data = get(v:completed_item, 'user_data', {})
  if type(user_data) != v:t_dict || !has_key(user_data, 'virt_poc_process')
    return
  endif

  if user_data.virt_poc_process ==# 'google'
    let google_result = google_cgi#henkan(user_data.yomi)
    if google_result ==# ''
      echomsg 'Google変換で結果が得られませんでした。'
      return
    endif

    let comp_list = [{
          \ 'word': google_result,
          \ 'menu': '[Google]',
          \ 'info': '[Google]',
          \ 'user_data': { 'yomi': user_data.yomi, 'context': user_data.context, 'virt_poc_process': 'set_to_user_jisyo' }
          \ }]
    call complete(user_data.context.start_col, comp_list)
    call phase#enable('kouho')
    return
  endif

  if user_data.virt_poc_process ==# 'set_to_user_jisyo'
    let line = $'{user_data.yomi} /{v:completed_item.word}/'
    call writefile([line], opts#get('user_jisyo_path'), "a")
    return
  endif

  if user_data.virt_poc_process ==# 'new_word'
    autocmd BufEnter <buffer> ++once call s:buf_enter_try_user_henkan()

    let context = user_data.context
    let yomi = context.machi
    let b:virt_poc_context = context

    let jump_line = '/okuri-nasi'
    if context.okuri !=# ''
      let jump_line = '/okuri-ari'
      let consonant = utils#consonant(strcharpart(context.okuri, 0, 1))
      let yomi ..= consonant
    endif

    let user_jisyo_winnr = bufwinnr(bufnr(opts#get('user_jisyo_path')))
    if user_jisyo_winnr > 0
      " ユーザー辞書がすでに開いている場合は
      " okuri-ari/okuri-nasiの行へジャンプする
      execute user_jisyo_winnr .. 'wincmd w'
      normal! gg
      execute jump_line
    else
      call virt_poc#open_user_jisyo($'+{jump_line}')
    endif

    call feedkeys($"\<c-o>o{yomi} //\<c-g>U\<left>\<cmd>call virt_poc#enable()\<cr>", 'n')
  endif
endfunction

function! virt_poc#open_user_jisyo(args = '') abort
  execute 'botright 5new' a:args opts#get("user_jisyo_path")
endfunction

function! s:buf_enter_try_user_henkan() abort
  call cursor(b:virt_poc_context.pos)
  if b:virt_poc_context.is_trailing
    startinsert!
  else
    startinsert
  endif

  call virt_poc#enable()

  call henkan_list#update_manual(b:virt_poc_context.machi, b:virt_poc_context.okuri)
  if empty(henkan_list#get())
    return
  endif

  call phase#enable('kouho')
  " ここで直接実行するとインサートモードに入れておらずエラーになるので
  " タイマーで遅延する必要がある
  call timer_start(1, {->call('complete', [b:virt_poc_context.start_col, henkan_list#get()])})
endfunction

function! virt_poc#cmd_buf() abort
  let cmdtype = getcmdtype()
  if ':/?' !~# cmdtype
    return
  endif

  let s:cmd_buf_context = {
        \ 'type': cmdtype,
        \ 'text': getcmdline(),
        \ 'col': getcmdpos(),
        \ 'view': winsaveview(),
        \ 'winid': win_getid(),
        \ }

  botright 1new
  setlocal buftype=nowrite bufhidden=wipe noswapfile

  call feedkeys("\<c-c>", 'n')

  call setline(1, s:cmd_buf_context.text)
  call cursor(1, s:cmd_buf_context.col)

  if strlen(s:cmd_buf_context.text) < s:cmd_buf_context.col
    startinsert!
  else
    startinsert
  endif
  call virt_poc#enable()

  augroup virt_poc_cmd_buf
    autocmd!
    " 直接記述すると即座に発火してしまうのでInsertEnterでラップする
    " 入力を終了したり改行したりしたタイミングでコマンドラインに戻って反映する
    autocmd InsertEnter <buffer> ++once
          \ autocmd TextChanged,TextChangedI,TextChangedP,InsertLeave,BufLeave,WinLeave <buffer> ++nested
          \   if line('$') > 1 || mode() !=# 'i'
          \ |   stopinsert
          \ |   let s:cmd_buf_context.line = s:cmd_buf_context.type .. getline(1, '$')->join('')
          \ |   quit!
          \ |   call win_gotoid(s:cmd_buf_context.winid)
          \ |   call winrestview(s:cmd_buf_context.view)
          \ |   call timer_start(1, {->feedkeys(s:cmd_buf_context.line, 'ni')})
          \ | endif
  augroup END
endfunction

cnoremap <c-j> <cmd>call virt_poc#cmd_buf()<cr>

inoremap <c-j> <cmd>call virt_poc#toggle()<cr>
inoremap <c-k> <cmd>imap<cr>
" inoremap <c-d> <cmd>echomsg $'choku {store#get("choku")} machi {store#get("machi")} okuri {store#get("okuri")}'<cr>

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call virt_poc#init({
      \ 'user_jisyo_path': uj,
      \ 'jisyo_list':  [
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.L'), 'encoding': 'euc-jp', 'mark': '[L]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.geo'), 'encoding': 'euc-jp', 'mark': '[G]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.station'), 'encoding': 'euc-jp', 'mark': '[S]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.jawiki'), 'encoding': 'utf-8', 'mark': '[W]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.emoji'), 'encoding': 'utf-8' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.nicoime'), 'encoding': 'utf-8', 'mark': '[N]' },
      \ ],
      \ 'min_auto_complete_length': 3,
      \ 'sort_auto_complete_by_length': v:true,
      \ 'use_google_cgi': v:true,
      \ 'merge_tsu': v:true,
      \ 'trailing_n': v:true,
      \ 'textwidth_zero': v:true,
      \ 'abbrev_ignore_case': v:true,
      \ 'del_odd_char': v:true,
      \ })
