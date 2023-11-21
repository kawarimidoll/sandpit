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
      let ck = s:capital(k)
      let current_map = maparg(ck, 'i', 0, 1)
      if empty(current_map)
        call add(s:keys_to_unmaps, ck)
      else
        call add(s:keys_to_remaps, current_map)
      endif
      execute $"inoremap <expr> {ck} k#ins('{k}',1)"
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
      echomsg 'okuri-ari:' preceding_str .. a:key

      let s:latest_kanji_list = k#get_henkan_list(preceding_str .. a:key)
      if empty(s:latest_kanji_list)
        echomsg 'okuri-ari: No Kanji'
        return get(kana_dict, '', a:key)
      endif

      return $"\<c-r>=k#completefunc('{get(kana_dict,'',a:key)}')\<cr>\<c-n>"
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

function! k#get_henkan_list(str) abort
  let cmd = $"rg --no-filename --no-line-number --encoding {s:jisyo.encoding} '^{a:str} ' {s:jisyo.path}"
  let results = systemlist(cmd)

  let kanji_list = []
  for r in results
    let tmp = split(r, '/')
    call extend(kanji_list, tmp[1:])
  endfor

  return kanji_list
endfunction

function! k#completefunc(suffix_key = '')
  " 補完の始点のcol
  let preceding_str = getline('.')->slice(0, s:henkan_start_pos[1]-1)
  echomsg 'completefunc preceding_str' preceding_str
  let start_col = strlen(preceding_str)+1

  let comp_list = []
  " for k in k#get_henkan_list(a:base)
  for k in s:latest_kanji_list
    " ;があってもなくても良いよう_restを使う
    let [word, info; _rest] = split(k, ';') + ['']
    " :h complete-items
    call add(comp_list, {
          \ 'word': word .. a:suffix_key,
          \ 'menu': info,
          \ 'info': info
          \ })
  endfor

  call complete(start_col, comp_list)

  return ''
endfunction

function! k#henkan(fallback_key) abort
  if pumvisible()
    return "\<c-n>"
  endif

  let current_pos = getcharpos('.')[1:2]
  if s:henkan_start_pos[0] != current_pos[0] || s:henkan_start_pos[1] > current_pos[1]
    return a:fallback_key
  endif

  let preceding_str = getline('.')->slice(s:henkan_start_pos[1]-1, charcol('.')-1)
        \->substitute("n$", "ん", "")
  echomsg preceding_str

  let s:latest_kanji_list = k#get_henkan_list(preceding_str)
  if empty(s:latest_kanji_list)
    echomsg 'No Kanji'
    return ''
  endif

  return "\<c-r>=k#completefunc()\<cr>\<c-n>"
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
  autocmd CompleteDonePre * if get(complete_info(), 'selected', -1) >= 0
        \ |   let s:henkan_start_pos = [0, 0]
        \ | endif
augroup END

call k#initialize()
inoremap <expr> <c-j> k#toggle()
