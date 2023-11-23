source ./inline_mark.vim

function! s:capital(char) abort
  return substitute(a:char, '.', '\U\0', '')
endfunction
function! s:is_capital(char) abort
  return '[A-Z]' =~# a:char
endfunction

let s:is_enable = v:false
let s:keys_to_remaps = []
let s:keys_to_unmaps = []

let s:henkan_marker = "▽"
let s:select_marker = "▼"

let s:user_jisyo_path = expand('~/.cache/vim/SKK-JISYO.user')

let s:jisyo_list = [
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.L'), 'encoding': 'euc-jp' },
      \   { 'path': s:user_jisyo_path, 'encoding': 'utf-8' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.geo'), 'encoding': 'euc-jp' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.emoji'), 'encoding': 'utf-8' },
      \ ]

function! k#is_enable() abort
  return s:is_enable
endfunction

function! k#enable() abort
  if s:is_enable
    return
  endif

  let s:keys_to_remaps = []
  let s:keys_to_unmaps = []

  for key in extendnew(s:start_keys, s:end_keys)->keys()
    let k = keytrans(key)
    let k_lt = substitute(k, '<', '<lt>', 'g')
    let current_map = maparg(k, 'i', 0, 1)
    if empty(current_map)
      call add(s:keys_to_unmaps, k)
    else
      call add(s:keys_to_remaps, current_map)
    endif
    execute $"inoremap {k} <cmd>call k#ins('{k_lt}')<cr>"

    if key =~ '^\l$'
      let ck = s:capital(k)
      let current_map = maparg(ck, 'i', 0, 1)
      if empty(current_map)
        call add(s:keys_to_unmaps, ck)
      else
        call add(s:keys_to_remaps, current_map)
      endif
      execute $"inoremap {ck} <cmd>call k#ins('{k}',1)<cr>"
    endif
  endfor

  call s:set_inner_mode('hira')
  let s:is_enable = v:true
endfunction

function! k#disable() abort
  call inline_mark#clear()
  if !s:is_enable
    return
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
endfunction

function! k#toggle() abort
  return k#is_enable() ? k#disable() : k#enable()
endfunction

" e.g. <space> -> \<space>
function! s:trans_special_key(str) abort
  return substitute(a:str, '<[^>]*>', {m -> eval($'"\{m[0]}"')}, 'g')
endfunction

function! k#initialize() abort
  let raw = json_decode(join(readfile('./kana_table.json'), "\n"))

  if glob(s:user_jisyo_path)->empty()
    call fnamemodify(s:user_jisyo_path, ':p:h')
          \ ->iconv(&encoding, &termencoding)
          \ ->mkdir('p')
    let user_jisyo_lines = [
          \ ';; フォーマット',
          \ ';; yomi /(henkan(;setsumei)?/)+',
          \ ';;',
          \ ';; okuri-ari entries.',
          \ ';; okuri-nasi entries.',
          \ ]
    call writefile(user_jisyo_lines, s:user_jisyo_path)
  endif

  let s:start_keys = {}
  let s:end_keys = {}

  for [k, val] in items(raw)
    let key = s:trans_special_key(k)
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

" hira / zen_kata / han_kata / abbrev
let s:inner_mode = 'hira'

function! s:set_inner_mode(mode) abort
  let s:inner_mode = a:mode
endfunction
function! s:toggle_inner_mode(mode) abort
  call s:set_inner_mode(s:inner_mode == a:mode ? 'hira' : a:mode)
endfunction

" 変数名を文字列連結で作ってしまうと後からgrepしづらくなるので
" 行数が嵩むが直接記述する
function! s:is_same_line_right_col(target) abort
  if a:target !=# 'kana' && a:target !=# 'henkan'
    throw 'wrong target name'
  endif
  let target_name = a:target ==# 'kana' ? 'kana_start_pos' : 'henkan_start_pos'

  let target = get(w:, target_name, [0, 0])
  let current_pos = getcharpos('.')[1:2]

  return target[0] ==# current_pos[0] && target[1] < current_pos[1]
endfunction

function! s:get_preceding_str(target, trim_trail_n = v:true) abort
  if a:target !=# 'kana' && a:target !=# 'henkan'
    throw 'wrong target name'
  endif
  let target_name = a:target ==# 'kana' ? 'kana_start_pos' : 'henkan_start_pos'

  let start_col = get(w:, target_name, [0, 0])[1]

  let preceding_str = getline('.')->slice(start_col-1, charcol('.')-1)
  return a:trim_trail_n ? preceding_str->substitute("n$", "ん", "") : preceding_str
endfunction

function! k#zen_kata(...) abort
  if !s:is_same_line_right_col('henkan')
    call s:toggle_inner_mode('zen_kata')
    return ''
  endif

  let preceding_str = s:get_preceding_str('henkan')
  call s:clear_henkan_start_pos()
  return repeat("\<bs>", strcharlen(preceding_str)) .. s:hira_to_kata(preceding_str)
endfunction

function! k#han_kata(...) abort
  if !s:is_same_line_right_col('henkan')
    call s:toggle_inner_mode('han_kata')
    return ''
  endif

  let preceding_str = s:get_preceding_str('henkan')
  call s:clear_henkan_start_pos()
  return repeat("\<bs>", strcharlen(preceding_str)) .. s:zen_kata_to_han_kata(s:hira_to_kata(preceding_str))
endfunction

function! k#dakuten(...) abort
  if !s:is_same_line_right_col('henkan')
    call s:toggle_inner_mode('dakuten')
    return ''
  endif

  let preceding_str = s:get_preceding_str('henkan')
  call s:clear_henkan_start_pos()
  return repeat("\<bs>", strcharlen(preceding_str)) .. s:hira_to_dakuten(preceding_str)
endfunction

function! k#ins(key, henkan = v:false) abort
  let key = s:trans_special_key(a:key)
  let spec = s:get_insert_spec(key, a:henkan)

  let result = type(spec) == v:t_dict ? get(spec, 'prefix', '') .. call($'k#{spec.func}', [key])
        \ : s:inner_mode == 'zen_kata' ? s:hira_to_kata(spec)
        \ : s:inner_mode == 'han_kata' ? s:zen_kata_to_han_kata(s:hira_to_kata(spec))
        \ : s:inner_mode == 'dakuten' ? s:hira_to_dakuten(spec)
        \ : spec
  " implement other modes, maybe

  call feedkeys(result, 'n')
endfunction

function! s:get_insert_spec(key, henkan = v:false) abort
  let current_pos = getcharpos('.')[1:2]
  if !s:is_same_line_right_col('kana')
    let w:kana_start_pos = current_pos
  endif

  let kana_dict = get(s:end_keys, a:key, {})
  if a:henkan
    if !s:is_same_line_right_col('henkan')
      call s:set_henkan_start_pos(current_pos)
    else
      let preceding_str = s:get_preceding_str('henkan', v:false)
      echomsg 'okuri-ari:' preceding_str .. a:key

      let s:latest_henkan_list = k#get_henkan_list(preceding_str .. a:key)

      return $"\<c-r>=k#completefunc('{get(kana_dict,'',a:key)}')\<cr>\<c-n>"
    endif
  endif

  if !empty(kana_dict)
    let preceding_str = s:get_preceding_str('kana', v:false)

    let i = len(preceding_str)
    while i > 0
      let tail_str = slice(preceding_str, -i)
      if has_key(kana_dict, tail_str)
        if type(kana_dict[tail_str]) == v:t_dict
          let result = { 'prefix': repeat("\<bs>", i) }
          call extend(result, kana_dict[tail_str])
          return result
        else
          return repeat("\<bs>", i) .. kana_dict[tail_str]
        endif
      endif
      let i -= 1
    endwhile
  endif

  return get(kana_dict, '', a:key)
endfunction

function! k#get_henkan_list(str) abort
  let henkan_list = []
  for jisyo in s:jisyo_list
    let cmd = $"rg --no-filename --no-line-number --encoding {jisyo.encoding} '^{a:str} ' {jisyo.path}"
    let results = systemlist(cmd)
    for r in results
      let tmp = split(r, '/')
      call extend(henkan_list, tmp[1:]->map({_,v->{ 'henkan':v, 'yomi': a:str }}))
    endfor
  endfor

  return henkan_list
endfunction

function! k#completefunc(suffix_key = '')
  call s:set_henkan_select_mark()
  " 補完の始点のcol
  let [lnum, char_col] = w:henkan_start_pos
  let start_col = s:char_col_to_byte_col(lnum, char_col)
  let preceding_str = s:get_preceding_str('henkan') .. a:suffix_key

  let comp_list = []
  for k in s:latest_henkan_list
    " ;があってもなくても良いよう_restを使う
    let [word, info; _rest] = split(k.henkan, ';') + ['']
    " :h complete-items
    call add(comp_list, {
          \ 'word': word .. a:suffix_key,
          \ 'menu': info,
          \ 'info': info,
          \ 'user_data': { 'yomi': k.yomi }
          \ })
  endfor
  call add(comp_list, {
        \ 'word': preceding_str,
        \ 'abbr': '[辞書登録]',
        \ 'menu': preceding_str,
        \ 'info': preceding_str,
        \ 'user_data': { 'yomi': preceding_str, 'func': 'jisyo_touroku' }
        \ })

  call complete(start_col, comp_list)

  return ''
endfunction

function! s:kata_to_hira(str) abort
  return a:str->substitute('[ァ-ヶ]', {m->nr2char(char2nr(m[0], v:true) - 96, v:true)}, 'g')
endfunction

function! s:hira_to_kata(str) abort
  return a:str->substitute('[ぁ-ゖ]', {m->nr2char(char2nr(m[0], v:true) + 96, v:true)}, 'g')
endfunction

function! s:hira_to_dakuten(str) abort
  return a:str->substitute('[^[:alnum:][:graph:][:space:]]', {m->m[0] .. '゛'}, 'g')
endfunction

" たまにsplit文字列の描画がおかしくなるので注意
let s:hankana_list = ('ｧｱｨｲｩｳｪｴｫｵｶｶﾞｷｷﾞｸｸﾞｹｹﾞｺｺﾞ'
      \ .. 'ｻｻﾞｼｼﾞｽｽﾞｾｾﾞｿｿﾞﾀﾀﾞﾁﾁﾞｯﾂﾂﾞﾃﾃﾞﾄﾄﾞ'
      \ .. 'ﾅﾆﾇﾈﾉﾊﾊﾞﾊﾟﾋﾋﾞﾋﾟﾌﾌﾞﾌﾟﾍﾍﾞﾍﾟﾎﾎﾞﾎﾟ'
      \ .. 'ﾏﾐﾑﾒﾓｬﾔｭﾕｮﾖﾗﾘﾙﾚﾛﾜﾜｲｴｦﾝｳﾞｰｶｹ')
      \ ->split('.[ﾞﾟ]\?\zs')
let s:zen_kata_origin = char2nr('ァ', v:true)
let s:griph_map = { 'ー': '-', '〜': '~', '、': '､', '。': '｡', '「': '｢', '」': '｣', '・': '･' }

function! s:zen_kata_to_han_kata(str) abort
  return a:str->substitute('.', {m->get(s:griph_map,m[0],m[0])}, 'g')
        \ ->substitute('[ァ-ヶ]', {m->get(s:hankana_list, char2nr(m[0], v:true) - s:zen_kata_origin, m[0])}, 'g')
        \ ->substitute('[！-～]', {m->nr2char(char2nr(m[0], v:true) - 65248, v:true)}, 'g')
endfunction

function! s:char_col_to_byte_col(lnum, char_col) abort
  return getline(a:lnum)->slice(0, a:char_col-1)->strlen()+1
endfunction

function! s:set_henkan_start_pos(pos) abort
  let w:henkan_start_pos = a:pos

  let [lnum, char_col] = w:henkan_start_pos
  let byte_col = s:char_col_to_byte_col(lnum, char_col)
  call inline_mark#display(lnum, byte_col, s:henkan_marker)
endfunction

function! s:set_henkan_select_mark() abort
  call inline_mark#clear()
  let [lnum, char_col] = w:henkan_start_pos
  let byte_col = s:char_col_to_byte_col(lnum, char_col)
  call inline_mark#display(lnum, byte_col, s:select_marker)
endfunction

function! s:clear_henkan_start_pos() abort
  let w:henkan_start_pos = [0, 0]
  call inline_mark#clear()
endfunction

function! k#henkan(fallback_key) abort
  if pumvisible()
    return "\<c-n>"
  endif

  if !s:is_same_line_right_col('henkan')
    return a:fallback_key
  endif

  let preceding_str = s:get_preceding_str('henkan')
  echomsg preceding_str

  let s:latest_henkan_list = k#get_henkan_list(preceding_str)

  return "\<c-r>=k#completefunc()\<cr>\<c-n>"
endfunction

function! k#kakutei(fallback_key) abort
  if !s:is_same_line_right_col('henkan')
    return a:fallback_key
  endif

  call s:clear_henkan_start_pos()
  return pumvisible() ? "\<c-y>" : ''
endfunction

augroup k_augroup
  autocmd!
  autocmd InsertLeave * call k#disable()
  autocmd CompleteDonePre * if get(complete_info(), 'selected', -1) >= 0
        \ |   call s:clear_henkan_start_pos()
        \ | endif
  " TODO: add register feature
  autocmd CompleteDonePre * echomsg 'completed' v:completed_item
augroup END

function! k#cmd_buf() abort
  let cmdtype = getcmdtype()
  if ':/?' !~# cmdtype
    return
  endif

  let s:cb_ctx = {
        \ 'type': cmdtype,
        \ 'text': getcmdline(),
        \ 'col': getcmdpos(),
        \ 'view': winsaveview(),
        \ 'winid': win_getid(),
        \ }

  botright 1new
  setlocal buftype=nowrite bufhidden=wipe noswapfile

  call feedkeys("\<c-c>", 'n')

  call setline(1, s:cb_ctx.text)
  call cursor(1, s:cb_ctx.col)

  if strlen(s:cb_ctx.text) < s:cb_ctx.col
    startinsert!
  else
    startinsert
  endif
  call k#enable()

  augroup k_cmd_buf
    autocmd!
    autocmd InsertEnter <buffer> ++once
          \ autocmd TextChanged,TextChangedI,TextChangedP,InsertLeave <buffer> ++nested
          \   if line('$') > 1 || mode() !=# 'i'
          \ |   stopinsert
          \ |   let s:cb_ctx.line = s:cb_ctx.type .. getline(1, '$')->join('')
          \ |   quit!
          \ |   call win_gotoid(s:cb_ctx.winid)
          \ |   call winrestview(s:cb_ctx.view)
          \ |   call timer_start(1, {->feedkeys(s:cb_ctx.line, 'nt')})
          \ | endif
  augroup END
endfunction

cnoremap <c-j> <cmd>call k#cmd_buf()<cr>
inoremap <c-j> <cmd>call k#toggle()<cr>
call k#initialize()
