source ./inline_mark.vim
source ./utils.vim
source ./opts.vim

function! h#enable() abort
  if s:is_enable
    return
  endif

  augroup h#augroup
    autocmd!
    autocmd InsertLeave * call h#disable()
  augroup END

  let s:keys_to_remaps = []
  let sid = "\<sid>"
  for [key, val] in items(opts#get('map_keys_dict'))
    if index(['|', ''''], key) >= 0
      continue
    endif
    let current_map = maparg(key, 'i', 0, 1)
    let k = keytrans(key)
    call add(s:keys_to_remaps, empty(current_map) ? k : current_map)
    execute $"inoremap {k} <cmd>call {sid}i1('{keytrans(k)}', {val})->{sid}i2()<cr>"
  endfor

  let s:is_enable = v:true
endfunction

function! h#disable() abort
  if !s:is_enable
    return
  endif

  autocmd! h#augroup

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

  let s:is_enable = v:false
endfunction

function! h#toggle() abort
  return s:is_enable ? h#disable() : h#enable()
endfunction

function! h#init(opts = {}) abort
  try
    call opts#parse(a:opts)
  catch
    call utils#echoerr($'[h#init] {v:exception}', 'abort')
    return
  endtry

  let s:is_enable = v:false
endfunction

function! s:get_spec(key) abort
  return a:key
endfunction

function! s:i1(key, with_sticky = v:false) abort
  let key = a:key
  if a:with_sticky
    let key = a:key->tolower()
  endif
  let spec = s:get_spec(key)
  return spec
endfunction

function! s:i2(args) abort
  echomsg a:args

  call feedkeys(utils#trans_special_key(a:args), 'n')
endfunction

inoremap <c-j> <cmd>call h#toggle()<cr>

inoremap <c-k> <cmd>imap<cr>

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call h#init({
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
