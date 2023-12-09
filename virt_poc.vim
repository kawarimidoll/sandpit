source ./utils.vim

if !exists('?keytrans') || exists(':defer') != 2
  call utils#echoerr('このバージョンの' .. v:progname .. 'はサポートしていません')
  finish
endif

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
  for [key, val] in items(opts#get('map_keys_dict'))
    if index(['|', ''''], key) >= 0
      continue
    endif
    let current_map = maparg(key, 'i', 0, 1)
    let k = keytrans(key)
    call add(s:keys_to_remaps, empty(current_map) ? k : current_map)
    execute $"inoremap {k} <cmd>call virt_poc#ins('{keytrans(k)}', {val})<cr><cmd>call virt_poc#after_ins()<cr>"
  endfor

  " 以下の2つはループでの処理が困難なので個別対応
  " single quote
  let current_map = maparg("'", 'i', 0, 1)
  call add(s:keys_to_remaps, empty(current_map) ? "'" : current_map)
  inoremap ' <cmd>call virt_poc#ins("'")<cr><cmd>call virt_poc#after_ins()<cr>
  " bar
  let current_map = maparg('<bar>', 'i', 0, 1)
  call add(s:keys_to_remaps, empty(current_map) ? '<bar>' : current_map)
  inoremap <bar> <cmd>call virt_poc#ins("<bar>")<cr><cmd>call virt_poc#after_ins()<cr>

  augroup virt_poc#augroup
    autocmd!
    autocmd InsertLeave * call virt_poc#disable()
    autocmd CompleteChanged *
          \   echo $'{v:event.size}件'
          \ | if s:is_completed() && phase#is_enabled('machi') && store#get('choku') !=# ''
          \ |   call store#clear('choku')
          \ |   call store#display_odd_char()
          \ | endif
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
  call mode#clear()
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

function! virt_poc#ins(key, with_sticky = v:false) abort
  let key = a:key
  if a:with_sticky
    call func#v_sticky('')
    let key = a:key->tolower()
  endif

  let spec = a:key =~ '^[!-~]$' && mode#is_direct() ? a:key
        \ : s:get_spec(key)

  if type(spec) == v:t_string
    " ここは不要？
    " if phase#is_enabled('kouho') && pumvisible()
    "   call feedkeys("\<c-y>", 'n')
    " endif
    if spec !=# ''
      call feedkeys(mode#convert(spec), 'ni')
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
      call call($'func#v_{spec.func}', [key])
    endif
  elseif has_key(spec, 'mode')
    call mode#set(spec.mode)
    if mode#is_start_sticky()
      call func#v_sticky('')
    endif
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

function! virt_poc#henkan_start() abort
  " echomsg $'henkan_start machi {store#get("machi")} okuri {store#get("okuri")}'
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
    " call utils#debug_log('henkan_list#get_fuzzy')
    " call utils#debug_log(henkan_list#get_fuzzy())
  endif
  " echomsg s:latest_auto_complete_str store#get('machi')

  " yomiの前方一致で絞り込む
  let comp_list = copy(henkan_list#get_fuzzy())
        \ ->filter($"v:val.user_data.yomi =~# '^{s:latest_auto_complete_str}'")

  let s:comp_list = comp_list

  if len(comp_list) > 0
    call complete(phase#getpos('machi')[1], comp_list)
  endif
endfunction

let s:henkan_reserve = 0
function! virt_poc#henkan_reserve() abort
  let s:henkan_reserve = 1
endfunction

function! virt_poc#after_ins() abort
  " echomsg $'after choku {store#get("choku")}'
  call store#display_odd_char()
  if store#get('choku') ==# ''
        \ && phase#is_enabled('okuri')
        \ && utils#compare_pos(phase#getpos('okuri'), getpos('.')[1:2]) > 0
    call virt_poc#henkan_start()
    unlet! s:save_okuri_pos
  endif

  if s:henkan_reserve
    let s:henkan_reserve = 0
    call virt_poc#henkan_start()
  endif

  if exists('s:save_okuri_pos')
    " echomsg 'get s:save_okuri_pos' s:save_okuri_pos
    call phase#move('okuri', s:save_okuri_pos)
  elseif !exists('s:save_okuri_pos') && phase#is_enabled('okuri')
    let s:save_okuri_pos = phase#getpos('okuri')
    " echomsg 'set s:save_okuri_pos' s:save_okuri_pos
  endif
endfunction

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
