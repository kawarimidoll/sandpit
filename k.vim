source ./inline_mark.vim

function! s:capital(char) abort
  return substitute(a:char, '.', '\U\0', '')
endfunction

function! s:url_encode(str)
  return range(0, strlen(a:str)-1)
        \ ->map({i -> a:str[i] =~ '[-.~]\|\w' ? a:str[i] : printf("%%%02x", char2nr(a:str[i]))})
        \ ->join('')
endfunction

let s:is_enable = v:false
let s:keys_to_remaps = []
let s:keys_to_unmaps = []

let s:henkan_marker = "▽"
let s:select_marker = "▼"

let s:user_jisyo_path = expand('~/.cache/vim/SKK-JISYO.user')

let s:jisyo_list = [
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.L'), 'encoding': 'euc-jp', 'mark': 'L' },
      \   { 'path': s:user_jisyo_path, 'encoding': 'utf-8', 'mark': 'U' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.geo'), 'encoding': 'euc-jp', 'mark': 'G' },
      \   { 'path': expand('~/.local/share/nvim/plugged/skk-wiki-dict/SKK-JISYO.jawiki'), 'encoding': 'utf-8', 'mark': 'W' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.emoji'), 'encoding': 'utf-8' },
      \ ]

function! k#is_enable() abort
  return s:is_enable
endfunction

function! k#enable() abort
  if s:is_enable
    return
  endif

  augroup k_augroup
    autocmd!
    autocmd InsertLeave * call k#disable()
    autocmd CompleteDonePre * call s:complete_done_pre(complete_info(), v:completed_item)
    autocmd TextChangedI * call s:auto_complete()
  augroup END

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

  call s:clear_henkan_start_pos()
  let b:kana_start_pos = [0, 0]

  let s:is_enable = v:true
endfunction

function! k#disable() abort
  call inline_mark#clear()
  if !s:is_enable
    return
  endif

  autocmd! k_augroup

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
          \ ';; フォーマットは以下',
          \ ';; yomi /(henkan(;setsumei)?/)+',
          \ ';; コメント行は変更しないでください',
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

  let target = get(b:, target_name, [0, 0])
  let current_pos = getcharpos('.')[1:2]

  return target[0] ==# current_pos[0] && target[1] < current_pos[1]
endfunction

function! s:get_preceding_str(target, trim_trail_n = v:true) abort
  if a:target !=# 'kana' && a:target !=# 'henkan'
    throw 'wrong target name'
  endif
  let target_name = a:target ==# 'kana' ? 'kana_start_pos' : 'henkan_start_pos'

  let start_col = get(b:, target_name, [0, 0])[1]

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
    let b:kana_start_pos = current_pos
  endif

  let kana_dict = get(s:end_keys, a:key, {})
  let next_okuri = get(s:, 'next_okuri', v:false)
  if a:henkan || next_okuri
    " echomsg 'get_insert_spec henkan'
    if !next_okuri && (!s:is_same_line_right_col('henkan') || pumvisible())
      call s:set_henkan_start_pos(current_pos)
    else
      let preceding_str = s:get_preceding_str('henkan', v:false)
      " echomsg 'okuri-ari:' preceding_str .. a:key

      call k#update_henkan_list(preceding_str .. a:key)

      let s:next_okuri = v:false

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

function! k#update_henkan_list(str, exact_match = v:true) abort
  let str = a:exact_match ? $'{a:str} ' : $'^{a:str}[^ -~]* '
  let henkan_list = []
  for jisyo in s:jisyo_list
    let mark = get(jisyo, 'mark', '') ==# '' ? '' : $'[{jisyo.mark}]'
    let cmd = $"rg --no-filename --no-line-number --encoding {jisyo.encoding} '^{str}' {jisyo.path} 2>/dev/null"
    let results = systemlist(cmd)
    for r in results
      let tmp = split(r, '/')
      call extend(henkan_list, tmp[1:]->map({_,v->{
            \ 'henkan': v,
            \ 'yomi': tmp[0]->substitute(' *$', '', ''),
            \ 'mark': mark
            \ }}))
    endfor
  endfor

  let s:latest_henkan_list = henkan_list
endfunction

let s:latest_auto_complete_str = ''
let s:min_auto_complete_length = 2
function! s:auto_complete() abort
  let preceding_str = s:get_preceding_str('henkan', v:false)
        \ ->substitute('\a*$', '', '')

  if strcharlen(preceding_str) < s:min_auto_complete_length
    return
  endif

  " echomsg 'auto_complete' preceding_str

  " 冒頭のmin_lengthぶんの文字が異なった場合はhenkan_listを更新
  if slice(preceding_str, 0, s:min_auto_complete_length) !=# slice(s:latest_auto_complete_str, 0, s:min_auto_complete_length)
    call k#update_henkan_list(preceding_str, 0)
  endif

  let s:latest_auto_complete_str = preceding_str

  call feedkeys("\<c-r>=k#autocompletefunc()\<cr>", 'n')
endfunction

function! k#autocompletefunc()
  let [lnum, char_col] = b:henkan_start_pos
  let start_col = s:char_col_to_byte_col(lnum, char_col)

  let comp_list = []
  for k in s:latest_henkan_list
    " 前方一致で絞り込む
    if k.yomi !~# $'^{s:latest_auto_complete_str}'
      continue
    endif
    " ;があってもなくても良いよう_restを使う
    let [word, info; _rest] = split(k.henkan, ';') + ['']
    " :h complete-items
    call add(comp_list, {
          \ 'word': word,
          \ 'menu': info .. k.mark,
          \ 'info': info .. k.mark,
          \ 'user_data': { 'yomi': k.yomi }
          \ })
  endfor

  call complete(start_col, comp_list)

  return ''
endfunction

function! k#completefunc(suffix_key = '')
  call s:set_henkan_select_mark()
  " 補完の始点のcol
  let [lnum, char_col] = b:henkan_start_pos
  let start_col = s:char_col_to_byte_col(lnum, char_col)
  let preceding_str = s:get_preceding_str('henkan') .. a:suffix_key

  let google_exists = v:false
  let comp_list = []
  for k in s:latest_henkan_list
    " ;があってもなくても良いよう_restを使う
    let [word, info; _rest] = split(k.henkan, ';') + ['']
    " :h complete-items
    call add(comp_list, {
          \ 'word': word .. a:suffix_key,
          \ 'menu': info .. k.mark,
          \ 'info': info .. k.mark,
          \ 'user_data': { 'yomi': k.yomi }
          \ })

    let google_exists = google_exists || has_key(k, 'by_google')
  endfor

  let current_pos = getcharpos('.')[1:2]
  let is_trailing = getline('.')->strcharlen() < current_pos[1]
  let context = {
        \   'yomi': preceding_str,
        \   'start_pos': b:henkan_start_pos,
        \   'cursor_pos': getcharpos('.')[1:2],
        \   'is_trailing': is_trailing,
        \   'suffix_key': a:suffix_key,
        \ }

  if !google_exists
    call add(comp_list, {
          \ 'word': preceding_str,
          \ 'abbr': '[Google変換]',
          \ 'dup': 1,
          \ 'user_data': { 'yomi': preceding_str, 'google_trans': context }
          \ })
  endif
  call add(comp_list, {
        \ 'word': preceding_str,
        \ 'abbr': '[辞書登録]',
        \ 'menu': preceding_str,
        \ 'info': preceding_str,
        \ 'dup': 1,
        \ 'user_data': { 'yomi': preceding_str, 'jisyo_touroku': context }
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
  let b:henkan_start_pos = a:pos

  let [lnum, char_col] = b:henkan_start_pos
  let byte_col = s:char_col_to_byte_col(lnum, char_col)
  call inline_mark#display(lnum, byte_col, s:henkan_marker)
endfunction

function! s:set_henkan_select_mark() abort
  call inline_mark#clear()
  let [lnum, char_col] = b:henkan_start_pos
  let byte_col = s:char_col_to_byte_col(lnum, char_col)
  call inline_mark#display(lnum, byte_col, s:select_marker)
  let b:select_start_pos = getcharpos('.')[1:2]
endfunction

function! s:clear_henkan_start_pos() abort
  let b:henkan_start_pos = [0, 0]
  let b:select_start_pos = [0, 0]
  call inline_mark#clear()
endfunction

" 変換中→送りあり変換を予約
" それ以外→現在位置に変換ポイントを設定
function! k#sticky(...) abort
  if s:is_same_line_right_col('henkan')
    let s:next_okuri = v:true
    echomsg 'next okuri set'
  else
    let current_pos = getcharpos('.')[1:2]
    call s:set_henkan_start_pos(current_pos)
  endif
  return ''
endfunction

function! k#henkan(fallback_key) abort
  " echomsg 'henkan'
  if pumvisible()
    return "\<c-n>"
  endif

  if !s:is_same_line_right_col('henkan')
    return a:fallback_key
  endif

  let preceding_str = s:get_preceding_str('henkan')
  " echomsg preceding_str

  call k#update_henkan_list(preceding_str)

  return "\<c-r>=k#completefunc()\<cr>\<c-n>"
endfunction

function! k#kakutei(fallback_key) abort
  if !s:is_same_line_right_col('henkan')
    return a:fallback_key
  endif

  call s:clear_henkan_start_pos()
  return pumvisible() ? "\<c-y>" : ''
endfunction

function! k#google_henkan(str) abort
  let url_base = 'http://www.google.com/transliterate?langpair=ja-Hira|ja&text='
  let encoded = s:url_encode(a:str)
  " echomsg encoded
  let result = system($"curl -s '{url_base}{encoded}'")
  " echomsg result
  try
    return json_decode(result)->map({_,v->v[1][0]})->join('')
  catch
    echomsg v:exception
    return ''
  endtry
endfunction

function! s:complete_done_pre(complete_info, completed_item) abort
  " echomsg a:complete_info a:completed_item

  if get(a:complete_info, 'selected', -1) < 0
    " not selected
    return
  endif

  if s:is_same_line_right_col('henkan')
    " echomsg 'complete_done_pre clear_henkan_start_pos'
    call s:clear_henkan_start_pos()
  endif

  let user_data = get(a:completed_item, 'user_data', {})
  if type(user_data) != v:t_dict
    return
  endif

  " TODO google変換結果を自動でユーザー辞書へ追加する
  if has_key(user_data, 'google_trans')
    let gt = user_data.google_trans
    let henkan_result = k#google_henkan(gt.yomi)
    if henkan_result ==# ''
      " echomsg 'Google変換で結果が得られませんでした。'
      return
    endif
    call insert(s:latest_henkan_list, {
          \ 'henkan': henkan_result,
          \ 'mark': '[Google]',
          \ 'yomi': gt.yomi,
          \ 'by_google': v:true
          \ })

    let b:henkan_start_pos = gt.start_pos
    call feedkeys("\<c-r>=k#completefunc()\<cr>\<c-n>", 'n')
    return
  endif

  " TODO ユーザー辞書内で再度登録を呼び出したときの対処
  if has_key(user_data, 'jisyo_touroku')
    let jt = user_data.jisyo_touroku
    let b:jisyo_touroku_ctx = jt

    autocmd BufEnter <buffer> ++once call s:buf_enter_try_user_henkan()

    let okuri = '+/okuri-' .. (jt.suffix_key ==# '' ? 'nasi' : 'ari')
    execute 'botright 5new' okuri s:user_jisyo_path

    call feedkeys($"\<c-o>o{jt.yomi} //\<c-g>U\<left>\<cmd>call k#enable()\<cr>", 'n')
  endif
endfunction

function! s:buf_enter_try_user_henkan() abort
  call setcursorcharpos(b:jisyo_touroku_ctx.cursor_pos)
  if b:jisyo_touroku_ctx.is_trailing
    startinsert!
  else
    startinsert
  endif

  call k#enable()

  call k#update_henkan_list(b:jisyo_touroku_ctx.yomi)
  if empty(s:latest_henkan_list)
    return
  endif

  let henkan_result = substitute(s:latest_henkan_list[0].henkan, ';.*', '', '')
  call feedkeys(repeat("\<bs>", strcharlen(b:jisyo_touroku_ctx.yomi)) .. henkan_result, 'n')

  if b:jisyo_touroku_ctx.suffix_key !=# ''
    let tmp_pos = b:jisyo_touroku_ctx.start_pos
    let tmp_pos[1] += strcharlen(henkan_result)
    let b:kana_start_pos = tmp_pos
    call feedkeys(b:jisyo_touroku_ctx.suffix_key, 'n')
  endif
endfunction

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

  " cmdlineには文字単位で位置を取得する関数がないのでstrlenを使用する
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
