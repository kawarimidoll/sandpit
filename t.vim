source ./converters.vim
source ./google_cgi.vim
source ./job.vim
source ./utils.vim
source ./opts.vim
source ./henkan_list.vim
source ./states.vim
source ./func.vim

function! s:is_completed() abort
  return get(complete_info(), 'selected', -1) >= 0
endfunction

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
    autocmd TextChangedI *
          \   if states#in('kouho')
          \ |   call states#off('kouho')
          \ | endif
    autocmd CompleteDonePre *
          \ call states#off('kouho')
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
  call states#clear()
  if !s:is_enable
    return
  endif

  if has_key(s:, 'save_textwidth')
    let &textwidth = s:save_textwidth
    unlet! s:save_textwidth
  endif

  for k in s:keys_to_remaps
    if type(k) == v:t_string
      execute 'iunmap' k
    else
      call mapset('i', 0, k)
    endif
  endfor

  autocmd! t#augroup
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
  let [bs_count, spec] = s:get_insert_spec(key, a:henkan)
  if bs_count > 0
    call feedkeys(repeat("\<bs>", bs_count), 'n')
  endif

  if type(spec) == v:t_dict
    let feed = call($'func#{spec.func}', [key])
    if feed !=# ''
      call feedkeys(feed, 'n')
    endif
    return
  endif

  " type(spec) == v:t_string

  if pumvisible() && s:is_completed()
    call states#off('machi')
    call states#off('choku')
  endif
  if spec == ''
    return
  endif
  if a:henkan
    call states#on('machi')
  endif
  call states#on('choku')

  call feedkeys(spec, 'n')

  if states#in('okuri') && slice(spec, -1) !~ '\a$'
    " ;oku;ri
    " machistr = おく
    " okuristr = り
    " consonant = r
    " ;modo;tte
    " machistr = もど
    " okuristr = って
    " consonant = t
    let from_col = states#get('machi')[1]-1
    let to_col = states#get('okuri')[1]-2
    let machistr = getline('.')[from_col : to_col]
    let okuristr = states#getstr('okuri')[0 : -bs_count-1] .. spec
    let consonant = utils#consonant(strcharpart(okuristr, 0, 1))

    call henkan_list#update_manual(machistr .. consonant)
    let s:okuri_context = {
          \ 'machistr': machistr,
          \ 'okuristr': okuristr,
          \ 'consonant': consonant,
          \ }

    call feedkeys($"\<c-r>=t#completefunc()\<cr>", 'n')
    call states#off('okuri')
  endif
endfunction

function! s:get_insert_spec(key, henkan = v:false) abort
  let kana_dict = get(opts#get('keymap_dict'), a:key, {})
  if empty(kana_dict)
    return [0, a:key]
  endif

  " if a:henkan
  "   call states#on('machi')
  " endif

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

let s:okuri_context = {}
function! t#completefunc()
  call states#on('kouho')

  let preceding_str = states#getstr('machi')
  let comp_list = copy(henkan_list#get())

  if !empty(s:okuri_context)
    let preceding_str = s:okuri_context.machistr .. s:okuri_context.okuristr
    for comp_item in comp_list
      let comp_item.word ..= s:okuri_context.okuristr
    endfor
  endif

  let list_len = len(comp_list)

  let s:okuri_context = {}

  call complete(states#get('machi')[1], comp_list)

  echo $'{preceding_str}: {complete_info(["items"])->len()}件'
  return list_len > 0 ? "\<c-n>" : ''
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
