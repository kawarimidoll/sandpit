let s:kana_start_pos = [0, 0]

let s:is_enable = v:false
let s:keys_to_remaps = []
let s:keys_to_unmaps = []

function! k#is_enable() abort
  return s:is_enable
endfunction

function! k#enable() abort
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
  endfor

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

function! k#ins(key) abort
  let current_pos = getcharpos('.')[1:2]
  if s:kana_start_pos[0] != current_pos[0] || s:kana_start_pos[1] > current_pos[1]
    let s:kana_start_pos = current_pos
  endif

  let kana_dict = get(s:end_keys, a:key, {})
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

augroup k_augroup
  autocmd!
  autocmd InsertLeave * call k#disable()
augroup END

call k#initialize()
inoremap <expr> <c-j> k#toggle()