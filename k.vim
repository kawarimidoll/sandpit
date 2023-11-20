function! s:capital(char) abort
  return substitute(a:char, '.', '\U\0', '')
endfunction
function! s:is_capital(char) abort
  return '[A-Z]' =~# a:char
endfunction

let s:kana_start_pos = [0, 0]

let s:is_enable = v:false
let s:keys_to_remaps = []
let s:keys_to_unmaps = []

function! k#is_enable() abort
  return s:is_enable
endfunction

function! k#enable() abort
  if s:is_enable
    return ''
  endif

  let s:keys_to_remaps = []
  let s:keys_to_unmaps = []

  for k in extendnew(s:start_keys, s:end_keys)->keys()
    let current_map = maparg(k, 'i', 0, 1)
    if empty(current_map)
      call add(s:keys_to_unmaps, k)
    else
      call add(s:keys_to_remaps, current_map)
    endif
    execute $"inoremap <expr> {k} k#ins('{k}')"
    if k =~ '\l'
      execute $"inoremap <expr> {s:capital(k)} k#ins('{k}',1)"
    endif
  endfor

  inoremap <expr> <space> k#henkan(" ")
  call add(s:keys_to_unmaps, "<space>")
  inoremap <expr> <cr> k#kakutei("\n")
  call add(s:keys_to_unmaps, "<cr>")

  let s:is_enable = v:true
  return ''
endfunction

function! k#disable() abort
  if !s:is_enable
    return ''
  endif

  for m in s:keys_to_remaps
    call mapset('i', 0, m)
  endfor
  for k in s:keys_to_unmaps
    execute 'iunmap' k
  endfor

  let s:keys_to_remaps = []
  let s:keys_to_unmaps = []

  let s:is_enable = v:false
  return ''
endfunction

function! k#toggle() abort
  return k#is_enable() ? k#disable() : k#enable()
endfunction

function! k#initialize() abort
  let raw = json_decode(join(readfile('./kana_table.json'), "\n"))

  let s:start_keys = {}
  let s:end_keys = {}

  for [key, val] in items(raw)
    let preceding_keys = slice(key, 0, -1)
    let start_key = slice(key, 0, 1)
    let end_key = slice(key, -1)

    let s:start_keys[start_key] = 1
    if !has_key(s:end_keys, end_key)
      let s:end_keys[end_key] = {}
    endif
    let s:end_keys[end_key][preceding_keys] = val
  endfor
endfunction

let s:henkan_start_pos = [0, 0]

function! k#ins(key, henkan = v:false) abort
  let current_pos = getcharpos('.')[1:2]
  if s:kana_start_pos[0] != current_pos[0] || s:kana_start_pos[1] > current_pos[1]
    let s:kana_start_pos = current_pos
  endif

  let kana_dict = get(s:end_keys, a:key, {})
  if a:henkan
    if s:henkan_start_pos[0] != current_pos[0] || s:henkan_start_pos[1] > current_pos[1]
      let s:henkan_start_pos = current_pos
    else
      let preceding_str = getline('.')->slice(s:henkan_start_pos[1]-1, charcol('.')-1)
      echomsg preceding_str .. a:key

      let converted = s:to_kanji(preceding_str .. a:key)
      if converted ==# ''
        return get(kana_dict, '', a:key)
      endif

      let s:henkan_start_pos = [0, 0]
      return repeat("\<bs>", strcharlen(preceding_str)) .. converted .. get(kana_dict, '', a:key)
    endif
  endif

  if !empty(kana_dict)
    let preceding_str = getline('.')->slice(s:kana_start_pos[1]-1, charcol('.')-1)

    let i = len(preceding_str)
    while i > 0
      let tail_str = slice(preceding_str, -i)
      if has_key(kana_dict, tail_str)
        return repeat("\<bs>", i) .. kana_dict[tail_str]
      endif
      let i -= 1
    endwhile
  endif

  return get(kana_dict, '', a:key)
endfunction

let s:jisyo = {
      \ 'path': expand('~/.cache/vim/SKK-JISYO.L'),
      \ 'encoding': 'euc-jp'
      \ }

function! s:to_kanji(str) abort
  let cmd = $"rg --no-filename --no-line-number --encoding {s:jisyo.encoding} '^{a:str} ' {s:jisyo.path}"
  let results = systemlist(cmd)

  if len(results) == 0
    echomsg 'No Kanji'
    return ''
  endif

  let kanji_list = []
  for r in results
    let tmp = split(r, '/')
    call extend(kanji_list, tmp[1:])
  endfor

  " TODO: create UI to select one
  let selected = kanji_list[0]

  return substitute(selected, ';.*', '', '')
endfunction

" echomsg s:to_kanji('にほんご')
" " -> 日本語
" echomsg s:to_kanji('かk')
" " -> 書chomsg s:to_kanji('かk')

function! k#henkan(fallback_key) abort
  let current_pos = getcharpos('.')[1:2]
  if s:henkan_start_pos[0] != current_pos[0] || s:henkan_start_pos[1] > current_pos[1]
    return a:fallback_key
  endif

  let preceding_str = getline('.')->slice(s:henkan_start_pos[1]-1, charcol('.')-1)
  echomsg preceding_str

  let converted = s:to_kanji(preceding_str)
  if converted ==# ''
    return ''
  endif

  let s:henkan_start_pos = [0, 0]
  return repeat("\<bs>", strcharlen(preceding_str)) .. converted
endfunction

function! k#kakutei(fallback_key) abort
  let current_pos = getcharpos('.')[1:2]
  if s:henkan_start_pos[0] != current_pos[0] || s:henkan_start_pos[1] > current_pos[1]
    return a:fallback_key
  endif

  let s:henkan_start_pos = [0, 0]
  return ''
endfunction

augroup k_augroup
  autocmd!
  autocmd InsertLeave * call k#disable()
augroup END

call k#initialize()
inoremap <expr> <c-j> k#toggle()
