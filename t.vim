source ./inline_mark.vim
source ./converters.vim
source ./google_cgi.vim
source ./job.vim
source ./utils.vim
source ./opts.vim
source ./henkan_list.vim
source ./states.vim

function! t#is_enable() abort
  return get(s:, 'is_enable', v:false)
endfunction

function! t#enable() abort
  if !exists('s:is_enable')
    call utils#echoerr('[t#enable] not initialized')
    call utils#echoerr('[t#enable] abort')
    return
  endif
  if s:is_enable
    return
  endif

  if opts#get('textwidth_zero')
    let s:save_textwidth = &textwidth
    set textwidth=0
  endif

  augroup t#augroup
    autocmd!
    autocmd InsertLeave * call t#disable()
    autocmd CompleteDonePre * call states#off('machi')
  augroup END

  let s:keys_to_remaps = []
  for [key, map_cmd] in opts#get('map_cmds')
    let current_map = maparg(key, 'i', 0, 1)
    call add(s:keys_to_remaps, empty(current_map) ? key : current_map)
    execute map_cmd
  endfor

  call states#clear()

  let s:is_enable = v:true
endfunction

function! t#disable() abort
  if !exists('s:is_enable')
    call utils#echoerr('[t#enable] not initialized')
    call utils#echoerr('[t#enable] abort')
    return
  endif
  call inline_mark#clear()
  if !s:is_enable
    return
  endif

  if has_key(s:, 'save_textwidth')
    let &textwidth = s:save_textwidth
    unlet! s:save_textwidth
  endif

  autocmd! t#augroup

  for k in s:keys_to_remaps
    if type(k) == v:t_string
      execute 'iunmap' k
    else
      call mapset('i', 0, k)
    endif
  endfor

  let s:is_enable = v:false
endfunction

function! t#toggle() abort
  return t#is_enable() ? t#disable() : t#enable()
endfunction

function! t#default_kana_table() abort
  return json_decode(join(readfile('./kana_table.json'), "\n"))
endfunction

function! t#initialize(opts = {}) abort
  try
    call opts#parse(a:opts)
  catch
    call utils#echoerr($'[t#initialize] {v:exception}')
    call utils#echoerr('[t#initialize] abort')
    return
  endtry

  let s:is_enable = v:false
endfunction

function! t#ins(key, henkan = v:false) abort
  let key = utils#trans_special_key(a:key)
  call states#on('choku')
  let [bs_count, spec] = s:get_insert_spec(key, a:henkan)
  call feedkeys(repeat("\<bs>", bs_count), 'n')

  if type(spec) == v:t_string
    call feedkeys(spec, 'n')
    return
  endif
  echomsg spec
  call states#off('choku')
  let feed = call($'t#{spec.func}', [key])
  call feedkeys(feed, 'n')
endfunction

function! s:get_insert_spec(key, henkan = v:false) abort
  let kana_dict = get(opts#get('keymap_dict'), a:key, {})
  if empty(kana_dict)
    return [0, a:key]
  endif

  if a:henkan
    call states#on('machi')
  endif

  let preceding_str = states#getstr('choku')

  let i = strcharlen(preceding_str)
  while i > 0
    let tail_str = slice(preceding_str, -i)
    if has_key(kana_dict, tail_str)
      return [i, kana_dict[tail_str]]
    endif
    let i -= 1
  endwhile

  return [0, get(kana_dict, '', a:key)]
endfunction

function! t#sticky(...) abort
  call states#on('machi')
  return ''
endfunction

function! t#henkan(fallback_key) abort
  if states#in('kouho')
    return "\<c-n>"
  endif

  if !states#in('machi')
    return a:fallback_key
  endif

  let preceding_str = states#getstr('machi')

  call henkan_list#update_manual(preceding_str)

  " return "\<c-r>=t#completefunc()\<cr>"
  return ''
endfunction

function! t#kakutei(fallback_key) abort
  if !states#in('machi')
    return a:fallback_key
  endif

  call states#off('machi')
  return pumvisible() ? "\<c-y>" : ''
endfunction

function! t#backspace(...) abort
  let pos = getpos('.')[1:2]
  let canceled = v:false
  for target in ['machi', 'okuri', 'kouho']
    if states#in(target) && utils#compare_pos(states#get(target), pos) == 0
      call states#off(target)
      let canceled = v:true
    endif
  endfor
  return canceled ? '' : "\<bs>"
endfunction

" cnoremap <c-j> <cmd>call t#cmd_buf()<cr>
inoremap <c-j> <cmd>call t#toggle()<cr>
inoremap <c-k> <cmd>imap<cr>

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call t#initialize({
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
      \ })
