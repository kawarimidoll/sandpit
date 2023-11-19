source ./utils.vim
let s:utils = utils#export

function! skk#is_enable() abort
  return &iminsert != 0
endfunction

function! skk#enable() abort
  if exists('#User#SkkEnablePre')
    doautocmd User SkkEnablePre
  endif
  set iminsert=1
  call s:set_start_point()
  if exists('#User#SkkEnablePost')
    doautocmd User SkkEnablePost
  endif
  return "\<c-^>"
endfunction
function! skk#disable() abort
  if exists('#User#SkkDisablePre')
    doautocmd User SkkDisablePre
  endif
  set iminsert=0
  if exists('#User#SkkDisablePost')
    doautocmd User SkkDisablePost
  endif
  return "\<c-^>"
endfunction

function! skk#toggle() abort
  return skk#is_enable() ? skk#disable() : skk#enable()
endfunction

function! skk#initialize(opts = {}) abort
  if exists('#User#SkkInitializePre')
    doautocmd User SkkInitializePre
  endif
  let kana_table_path = get(a:opts, 'kana_table_path', './kana_table.json')
  let jisyo_path_list = get(a:opts, 'jisyo_path_list', [['/usr/share/skk/SKK-JISYO.L', 'euc-jp']])

  " currently, only one jisyo is allowed
  let s:jisyo_first = {
        \ 'path': jisyo_path_list[0][0],
        \ 'encoding': get(jisyo_path_list[0], 1, 'auto')
        \ }

  let raw = json_decode(join(readfile(kana_table_path), "\n"))

  " use dictionary to unique keys
  let s:start_keys = {}
  let s:end_keys = {}

  for [key, val] in items(raw)

    " ex.1. 'gya': 'ぎゃ'
    "   preceding_keys: gy
    "   start_key: g
    "   end_key: a
    " g -> start_keysに入れる 入力開始位置になる可能性がある
    " G -> 漢字変換スタートを行う
    " a -> end_keysに入れる 直前の文字列(gy)を見て仮名変換を行う
    " A -> *このペアにおいては*なにもしなくてよい
    "
    " start_keys = {
    "   g: 1,
    " },
    " end_keys = {
    "   a: {
    "     gy: 'ぎゃ',
    "   },
    " }
    "
    " ex.2. 'a': 'あ',
    "   preceding_keys: ''
    "   start_key: a
    "   end_key: a
    " start_keys = {
    "   g: 1,
    "   a: 1
    " },
    " end_keys = {
    "   a: {
    "     gy: 'ぎゃ',
    "     '': 'あ',
    "   }
    " }

    let preceding_keys = slice(key, 0, -1)
    let start_key = slice(key, 0, 1)
    let end_key = slice(key, -1)

    let s:start_keys[start_key] = 1
    if !has_key(s:end_keys, end_key)
      let s:end_keys[end_key] = {}
    endif
    let s:end_keys[end_key][preceding_keys] = val
  endfor

  for key in keys(s:start_keys)
    execute printf("lnoremap <buffer><script><expr> %s <sid>set_start_point('%s')", key, key)
    execute printf("lnoremap <buffer><script><expr> %s <sid>set_henkan_start_point('%s')", substitute(key, '.', '\U\0', ''), key)
  endfor
  for key in keys(s:end_keys)
    let capital_key = substitute(key, '.', '\U\0', '')
    if has_key(s:start_keys, key)
      execute printf("lnoremap <buffer><script><expr> %s <sid>set_start_point(<sid>lang_map('%s'))", key, key)
      execute printf("lnoremap <buffer><script><expr> %s <sid>set_henkan_start_point(<sid>set_start_point(<sid>lang_map('%s')))", capital_key, key)
    else
      execute printf("lnoremap <buffer><script><expr> %s <sid>lang_map('%s')", key, key)
      execute printf("lnoremap <buffer><script><expr> %s <sid>set_henkan_start_point(<sid>lang_map('%s'))", capital_key, key)
    endif
  endfor
  lnoremap <buffer><script><expr> <space> <sid>henkan(' ')
  lnoremap <buffer><script><expr> <cr> <sid>kakutei("\<cr>")
  if exists('#User#SkkInitializePost')
    doautocmd User SkkInitializePost
  endif
endfunction

function! s:key_max_length(table) abort
  return max(map(keys(a:table), 'strlen(v:val)'))
endfunction

function! s:lang_map(char) abort
  let idx = charcol('.') - 2
  let chars = split(getline('.'), '\zs')
  let table = get(s:end_keys, a:char, {})

  if idx < 0 || len(chars) == 0 || !s:is_before_start_point()
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

call skk#initialize({
      \ 'jisyo_path_list': [['/Users/kawarimidoll/.local/share/nvim/plugged/skk-dict/SKK-JISYO.L', 'euc-jp']]
      \ })

inoremap <expr> <c-j> skk#toggle()

function! s:kata_to_hira(str) abort
  return a:str->substitute('[ァ-ヶ]',
        \ '\=nr2char(char2nr(submatch(0), v:true) - 96, v:true)', 'g')
endfunction

function! s:hira_to_kata(str) abort
  return a:str->substitute('[ぁ-ゖ]',
        \ '\=nr2char(char2nr(submatch(0), v:true) + 96, v:true)', 'g')
endfunction

function! s:hira_to_kanji(str) abort
  let cmd = printf("rg --no-filename --no-line-number --encoding %s '^%s ' %s", s:jisyo_first.encoding, a:str, s:jisyo_first.path)
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
  let cmd = printf("rg --no-filename --no-line-number --encoding %s '^[^a-zA-Z]+ .*/%s/' %s", s:jisyo_first.encoding, a:str, s:jisyo_first.path)
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

function! skk#operator_to_hira(type = '') abort
  if a:type == ''
    set operatorfunc=function('skk#operator_to_hira')
    return 'g@'
  endif
  let save_reg = getreginfo('z')
  noautocmd normal! `[v`]"zy
  let tmp = s:kata_to_hira(getreg('z'))
  call setreg('z', s:kanji_to_hira(tmp))
  noautocmd normal! `[v`]"zP
  call setreg('z', save_reg)
endfunction

function! skk#operator_to_kata(type = '') abort
  if a:type == ''
    set operatorfunc=function('skk#operator_to_kata')
    return 'g@'
  endif
  let save_reg = getreginfo('z')
  noautocmd normal! `[v`]"zy
  call setreg('z', s:hira_to_kata(getreg('z')))
  noautocmd normal! `[v`]"zP
  call setreg('z', save_reg)
endfunction

function! skk#operator_to_kanji(type = '') abort
  if a:type == ''
    set operatorfunc=function('skk#operator_to_kanji')
    return 'g@'
  endif
  let save_reg = getreginfo('z')
  noautocmd normal! `[v`]"zy
  call setreg('z', s:hira_to_kanji(getreg('z')))
  noautocmd normal! `[v`]"zP
  call setreg('z', save_reg)
endfunction

let s:start_point = [0, 0]
function! s:set_start_point(char = '') abort
  let s:start_point = s:utils.getcharpos()
  return a:char
endfunction
function! s:is_before_start_point() abort
  return s:utils.compare_pos(s:start_point, s:utils.getcharpos()) > 0
endfunction

let s:henkan_point = []
function! s:set_henkan_start_point(char = '') abort
  let s:henkan_point = s:utils.getcharpos()
  echo s:start_point
  return a:char
endfunction

function! s:henkan(fallback) abort
  if len(s:henkan_point) == 0
    return a:fallback
  endif

  let current_point = s:utils.getcharpos()
  let line_chars = split(getline('.'), '\zs')
  let src_chars = line_chars[s:henkan_point[1]-1 : current_point[1]-1]
  let src_str = join(src_chars, '')

  let s:henkan_point = []
  let kanji = s:hira_to_kanji(src_str)

  return repeat("\<bs>", len(src_chars)) .. kanji
endfunction

function! s:kakutei(fallback) abort
  if len(s:henkan_point) == 0
    return a:fallback
  endif
  return ''
endfunction

" function! s:select_list(items, opts = {}) abort
"   let prompt = get(a:opts, 'prompt', 'Select one of:')
"   let items = map(a:items[:], {idx,item-> (idx + 1) .. ': ' .. item})
"   echo join(items, "\n")
"   echo prompt
"   let choice = getcharstr()
"   if choice > 0 && choice <= len(a:items)
"     return choice-1
"   else
"     return -1
"   endif
" endfunction

nnoremap <expr> skh skk#operator_to_hira()
xnoremap <expr> skh skk#operator_to_hira()
nnoremap <expr> skk skk#operator_to_kata()
xnoremap <expr> skk skk#operator_to_kata()
nnoremap <expr> skj skk#operator_to_kanji()
xnoremap <expr> skj skk#operator_to_kanji()

augroup skk
  autocmd!
  autocmd InsertEnter * if skk#is_enable() | call s:set_start_point() | endif
  autocmd InsertLeave,CmdlineLeave * set iminsert=0
augroup END
