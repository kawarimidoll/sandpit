function! simple_skk#toggle_iminsert() abort
  if &iminsert == 0
    set iminsert=1
  else
    set iminsert=0
  endif
  return "\<c-^>"
endfunction

function! simple_skk#initialize(opts = {}) abort
  let raw = json_decode(join(readfile(a:opts.json_path), "\n"))
  let s:kana_table = {}
  let map_targets = []
  for [key, val] in items(raw)
    let key_except_last = slice(key, 0, -1)
    let key_last = slice(key, -1)
    if !has_key(s:kana_table, key_last)
      let s:kana_table[key_last] = {}
    endif
    let s:kana_table[key_last][key_except_last] = val
    call add(map_targets, key_last)
  endfor

  for key in map_targets
    execute printf("lnoremap <buffer><script><expr> %s <sid>lang_map('%s')", key, key)
  endfor
endfunction

function! s:key_max_length(table) abort
  return max(map(keys(a:table), 'strlen(v:val)'))
endfunction

function! s:lang_map(char) abort
  let idx = charcol('.') - 2
  let chars = split(getline('.'), '\zs')
  let table = get(s:kana_table, a:char, {})

  if idx < 0 || len(chars) == 0
    return get(table, '', a:char)
  endif

  let result = ''
  let keylen = 0
  for i in reverse(range(0, s:key_max_length(table) - 1))
    if idx-i < 0
      continue
    endif
    let tail_str = join(chars[idx-i : idx], '')
    let result = get(table, tail_str, '')
    if result !=# ''
      let keylen = i+1
      break
    endif
  endfor

  if result ==# ''
    return get(table, '', a:char)
  endif
  return repeat("\<bs>", keylen) .. result
endfunction

call simple_skk#initialize({'json_path': expand('~/dotfiles/kana_table.json')})
inoremap <expr> <c-j> simple_skk#toggle_iminsert()

function! s:kata_to_hira(str) abort
  let chars = split(a:str, '\zs')
  let result = ''
  for c in chars
    let code = char2nr(c, v:true)
    let result ..= (0x30A1 <= code && code <= 0x30F6) ? nr2char(code - 0x60, v:true) : c
  endfor
  return result
endfunction

function! s:hira_to_kata(str) abort
  let chars = split(a:str, '\zs')
  let result = ''
  for c in chars
    let code = char2nr(c, v:true)
    let result ..= (0x3041 <= code && code <= 0x3096) ? nr2char(code + 0x60, v:true) : c
  endfor
  return result
endfunction

function! s:hira_to_kanji(str) abort
  let dict_opts = {
        \ 'path': '/Users/kawarimidoll/.local/share/nvim/plugged/skk-dict/SKK-JISYO.L',
        \ 'encode': 'euc-jp'
        \ }

  let cmd = printf("rg --encoding %s '^%s ' %s", dict_opts.encode, a:str, dict_opts.path)
  let results = systemlist(cmd)

  if len(results) == 0
    echomsg 'No Kanji'
    return a:str
  endif

  let kanji_list = []
  for r in results
    let tmp = split(r, '/')
    call extend(kanji_list, tmp[1:])
  endfor

  if len(kanji_list) == 1
    return substitute(kanji_list[0], ';.*', '', '')
  endif

  let textlist = ['Select Kanji: ']
        \ + map(copy(kanji_list), {idx, val -> (idx+1) .. '. ' .. val})

  let selected = inputlist(textlist)

  if selected == 0
    echomsg 'Canceled'
    return a:str
  endif

  return substitute(kanji_list[selected-1], ';.*', '', '')
endfunction

function! s:kanji_to_hira(str) abort
  let dict_opts = {
        \ 'path': '/Users/kawarimidoll/.local/share/nvim/plugged/skk-dict/SKK-JISYO.L',
        \ 'encode': 'euc-jp'
        \ }

  let cmd = printf("rg --encoding %s '^[^a-zA-Z]+ .*/%s/' %s", dict_opts.encode, a:str, dict_opts.path)
  let kana_list = map(copy(systemlist(cmd)), "substitute(v:val, ' .*', '', '')")

  if len(kana_list) == 0
    return a:str
  endif

  if len(kana_list) == 1
    return kana_list[0]
  endif

  let textlist = ['Select Kana: ']
        \ + map(copy(kana_list), {idx, val -> (idx+1) .. '. ' .. val})

  let selected = inputlist(textlist)

  if selected == 0
    echomsg 'Canceled'
    return a:str
  endif

  return kana_list[selected-1]
endfunction

function! simple_skk#operator_to_hira(type = '') abort
  if a:type == ''
    set operatorfunc=function('simple_skk#operator_to_hira')
    return 'g@'
  endif
  let save_reg = getreginfo('z')
  noautocmd normal! `[v`]"zy
  let tmp = s:kata_to_hira(getreg('z'))
  call setreg('z', s:kanji_to_hira(tmp))
  noautocmd normal! `[v`]"zP
  call setreg('z', save_reg)
endfunction

function! simple_skk#operator_to_kata(type = '') abort
  if a:type == ''
    set operatorfunc=function('simple_skk#operator_to_kata')
    return 'g@'
  endif
  let save_reg = getreginfo('z')
  noautocmd normal! `[v`]"zy
  call setreg('z', s:hira_to_kata(getreg('z')))
  noautocmd normal! `[v`]"zP
  call setreg('z', save_reg)
endfunction

function! simple_skk#operator_to_kanji(type = '') abort
  if a:type == ''
    set operatorfunc=function('simple_skk#operator_to_kanji')
    return 'g@'
  endif
  let save_reg = getreginfo('z')
  noautocmd normal! `[v`]"zy
  call setreg('z', s:hira_to_kanji(getreg('z')))
  noautocmd normal! `[v`]"zP
  call setreg('z', save_reg)
endfunction

nnoremap <expr> skh simple_skk#operator_to_hira()
xnoremap <expr> skh simple_skk#operator_to_hira()
nnoremap <expr> skk simple_skk#operator_to_kata()
xnoremap <expr> skk simple_skk#operator_to_kata()
nnoremap <expr> skj simple_skk#operator_to_kanji()
xnoremap <expr> skj simple_skk#operator_to_kanji()
