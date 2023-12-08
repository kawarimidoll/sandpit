source ./inline_mark.vim
source ./utils.vim
source ./henkan_list.vim
source ./opts.vim
source ./phase.vim
source ./store.vim
source ./func.vim

function! s:is_completed() abort
  return get(complete_info(), 'selected', -1) >= 0
endfunction

function! virt_poc#enable() abort
  if s:is_enable
    return
  endif

  if opts#get('textwidth_zero')
    let s:save_textwidth = &textwidth
    set textwidth=0
  endif

  let s:keys_to_remaps = []
  for key in keys(s:map_keys_dict)
    let current_map = maparg(key, 'i', 0, 1)
    let k = keytrans(key)
    call add(s:keys_to_remaps, empty(current_map) ? k : current_map)
    execute $"inoremap {k} <cmd>call virt_poc#ins('{keytrans(k)}')<cr><cmd>call virt_poc#after_ins()<cr>"
  endfor

  augroup virt_poc#augroup
    autocmd!
    autocmd InsertLeave * call virt_poc#disable()
    autocmd CompleteChanged * echo $'{v:event.size}件'
    autocmd TextChangedI * call s:auto_complete()
    autocmd CompleteDonePre *
          \   call phase#disable('kouho')
          \ | if s:is_completed()
          \ |   call phase#disable('machi')
          \ |   call store#clear('machi')
          \ |   call store#clear('okuri')
          \ | endif
  augroup END

  call phase#clear()
  call store#clear()
  let s:is_enable = v:true
endfunction

function! virt_poc#disable() abort
  if !s:is_enable
    return
  endif

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

  call phase#clear()
  call store#clear()
  let s:is_enable = v:false
endfunction

function! virt_poc#toggle() abort
  return s:is_enable ? virt_poc#disable() : virt_poc#enable()
endfunction

function! virt_poc#init(opts = {}) abort
  try
    call opts#parse(a:opts)
  catch
    call utils#echoerr($'[virt_poc#init] {v:exception}')
    call utils#echoerr('[virt_poc#init] abort')
    return
  endtry

  let raw_kana_table = json_decode(join(readfile('./kana_table.json'), "\n"))

  let s:preceding_keys_dict = {}
  let s:map_keys_dict = {}
  let s:kana_table = {}
  for [k, val] in items(raw_kana_table)
    let key = utils#trans_special_key(k)->keytrans()
    let s:kana_table[key] = val

    let chars = utils#trans_special_key(k)->utils#strsplit()

    if len(chars) > 1
      let s:preceding_keys_dict[slice(chars, 0, -1)->join('')] = 1
    endif
    for char in chars
      let s:map_keys_dict[char] = 1
    endfor
  endfor
  " echo s:preceding_keys_dict
  let s:is_enable = v:false
endfunction

let s:kana_input_namespace = 'kana_input_namespace'

function! virt_poc#ins(key) abort
  " echomsg $'key {a:key}'
  let spec = s:get_spec(a:key)

  if type(spec) == v:t_string
    if phase#is_enabled('kouho')
      call feedkeys("\<c-y>", 'ni')
    endif
    if spec !=# ''
      " echomsg 'feed' spec
      call feedkeys(spec, 'ni')
      if phase#is_enabled('okuri')
        call store#push('okuri', spec)
      elseif phase#is_enabled('machi')
        call store#push('machi', spec)
        " echomsg 'machi' store#get('machi')
      endif
    endif
    return
  endif

  " echomsg spec
  " funcのfeedkeysはフラグにiを使わない
  if has_key(spec, 'func')
    if index(['backspace', 'kakutei', 'henkan', 'sticky'], spec.func) >= 0
      call call($'func#v_{spec.func}', [a:key])
    endif
  endif
endfunction

function! s:get_spec(key) abort
  let current = store#get('choku') .. a:key
  " echomsg $'spec choku {store#get("choku")}'

  if has_key(s:kana_table, current)
    " s:store.chokuの残存文字と合わせて完成した場合
    if type(s:kana_table[current]) == v:t_dict
      return s:kana_table[current]
    endif
    let [kana, roma; _rest] = s:kana_table[current]->split('\A*\zs') + ['']
    call store#set('choku', roma)
    return kana
  elseif has_key(s:preceding_keys_dict, current)
    " 完成はしていないが、先行入力の可能性がある場合
    call store#set('choku', current)
    " echomsg $'choku {store#get("choku")}'
    return ''
  endif

  let spec = get(s:kana_table, a:key, '')

  " 半端な文字はバッファに載せる
  " ただしdel_odd_charがtrueなら消す
  if !opts#get('del_odd_char') || type(spec) == v:t_dict
    call feedkeys(store#get('choku'), 'ni')
  endif
  if type(spec) == v:t_string
    call store#set('choku', a:key)
  else
    call store#set('choku', '')
  endif

  return spec
endfunction

function! virt_poc#henkan_start() abort
  call henkan_list#update_manual(store#get("machi"), store#get("okuri"))
  let comp_list = copy(henkan_list#get())
  let list_len = len(comp_list)
  if list_len == 0
    call add(comp_list, {'word': store#get("machi") .. store#get("okuri"), 'abbr': 'none'})
  endif
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
    call utils#debug_log('henkan_list#get_fuzzy')
    call utils#debug_log(henkan_list#get_fuzzy())
  endif
  echomsg s:latest_auto_complete_str store#get('machi')

  " yomiの前方一致で絞り込む
  let comp_list = copy(henkan_list#get_fuzzy())
        \ ->filter($"v:val.user_data.yomi =~# '^{s:latest_auto_complete_str}'")

  let s:comp_list = comp_list

  if len(comp_list) > 0
    call complete(phase#getpos('machi')[1], comp_list)
  endif
endfunction

function! virt_poc#after_ins() abort
  " echomsg $'after choku {store#get("choku")}'
  if store#get('choku') ==# ''
    call inline_mark#clear(s:kana_input_namespace)
    if phase#is_enabled('okuri')
      if utils#compare_pos(phase#getpos('okuri'), getpos('.')[1:2]) > 0
        call virt_poc#henkan_start()
      endif
    else
    endif
  else
    let [lnum, col] = getpos('.')[1:2]
    let hlname = synID(lnum, col, 1)->synIDattr('name')
    call inline_mark#put(lnum, col, {
          \ 'name': s:kana_input_namespace,
          \ 'text': store#get('choku'),
          \ 'hl': hlname })
  endif
endfunction

inoremap <c-j> <cmd>call virt_poc#toggle()<cr>
inoremap <c-k> <cmd>imap<cr>
inoremap <c-p> <cmd>echo phase#getpos('kana_input_namespace')<cr>

call virt_poc#init()

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
      \ 'textwidth_zero': v:true,
      \ 'abbrev_ignore_case': v:true,
      \ 'del_odd_char': v:true,
      \ })
