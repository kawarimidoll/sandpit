source ./inline_mark.vim
source ./converters.vim
source ./google_cgi.vim
source ./job.vim
source ./utils.vim
source ./opts.vim

function! s:is_completed() abort
  return get(complete_info(), 'selected', -1) >= 0
endfunction

function! k#is_enable() abort
  return get(s:, 'is_enable', v:false)
endfunction

function! k#enable() abort
  if !exists('s:is_enable')
    call utils#echoerr('[k#enable] not initialized')
    call utils#echoerr('[k#enable] abort')
    return
  endif
  if s:is_enable
    return
  endif

  augroup k_augroup
    autocmd!
    autocmd InsertLeave * call inline_mark#clear()
    " TODO 自動disableはユーザーに任せるべき
    autocmd InsertLeave * call k#disable()
    autocmd CompleteDonePre *
          \   if s:is_completed()
          \ |   call s:complete_done_pre(complete_info(), v:completed_item)
          \ | endif

    if opts#get('min_auto_complete_length') > 0
      autocmd TextChangedI,TextChangedP *
            \   if !s:is_completed()
            \ |   call s:auto_complete()
            \ | endif
    endif
  augroup END

  let s:keys_to_remaps = []
  for [key, map_cmd] in opts#get('map_cmds')
    let current_map = maparg(key, 'i', 0, 1)
    call add(s:keys_to_remaps, empty(current_map) ? key : current_map)
    execute map_cmd
  endfor

  call s:set_inner_mode('hira')

  call s:clear_henkan_start_pos()
  let b:kana_start_pos = [0, 0]

  let s:is_enable = v:true
endfunction

function! k#disable() abort
  if !exists('s:is_enable')
    call utils#echoerr('[k#enable] not initialized')
    call utils#echoerr('[k#enable] abort')
    return
  endif
  call inline_mark#clear()
  if !s:is_enable
    return
  endif

  autocmd! k_augroup

  for k in s:keys_to_remaps
    if type(k) == v:t_string
      execute 'iunmap' k
    else
      call mapset('i', 0, k)
    endif
  endfor

  let s:is_enable = v:false
endfunction

function! k#toggle() abort
  return k#is_enable() ? k#disable() : k#enable()
endfunction

function! k#default_kana_table() abort
  return json_decode(join(readfile('./kana_table.json'), "\n"))
endfunction

function! k#initialize(opts = {}) abort
  try
    call opts#parse(a:opts)
  catch
    call utils#echoerr($'[k#initialize] {v:exception}')
    call utils#echoerr('[k#initialize] abort')
    return
  endtry

  let s:is_enable = v:false
endfunction

" hira / zen_kata / han_kata / abbrev
let s:inner_mode = 'hira'

function! s:set_inner_mode(mode) abort
  let s:inner_mode = a:mode
endfunction
function! s:toggle_inner_mode(mode) abort
  call s:set_inner_mode(s:inner_mode == a:mode ? 'hira' : a:mode)
endfunction

function! s:is_same_line_right_col(target) abort
  let [pos_l, pos_c] = get(b:, $'{a:target}_start_pos', [0, 0])
  let [cur_l, cur_c] = getcharpos('.')[1:2]
  return pos_l ==# cur_l && pos_c <= cur_c
endfunction

function! s:get_preceding_str(target, trim_trail_n = v:true) abort
  if a:target !=# 'kana' && a:target !=# 'henkan'
    throw 'wrong target name'
  endif
  let target_name = a:target ==# 'kana' ? 'kana_start_pos' : 'henkan_start_pos'

  let start_col = get(b:, target_name, [0, 0])[1]

  let str = getline('.')->slice(start_col-1, charcol('.')-1)
  let str = opts#get('merge_tsu') ? substitute(str, 'っ\+', 'っ', 'g') : str
  return a:trim_trail_n ? str->substitute("n$", "ん", "") : str
endfunction

function! k#zen_kata(...) abort
  if !s:is_same_line_right_col('henkan')
    call s:toggle_inner_mode('zen_kata')
    return ''
  endif

  let preceding_str = s:get_preceding_str('henkan')
  call s:clear_henkan_start_pos()
  return repeat("\<bs>", strcharlen(preceding_str)) .. converters#hira_to_kata(preceding_str)
endfunction

function! k#han_kata(...) abort
  if !s:is_same_line_right_col('henkan')
    call s:toggle_inner_mode('han_kata')
    return ''
  endif

  let preceding_str = s:get_preceding_str('henkan')
  call s:clear_henkan_start_pos()
  return repeat("\<bs>", strcharlen(preceding_str)) .. converters#hira_to_han_kata(preceding_str)
endfunction

function! k#ins(key, henkan = v:false) abort
  let key = utils#trans_special_key(a:key)
  call s:ensure_kana_start_pos()
  let spec = s:get_insert_spec(key, a:henkan)

  let result = type(spec) == v:t_dict ? get(spec, 'prefix', '') .. call($'k#{spec.func}', [key])
        \ : s:inner_mode == 'zen_kata' ? converters#hira_to_kata(spec)
        \ : s:inner_mode == 'han_kata' ? converters#hira_to_han_kata(spec)
        \ : spec
  " implement other modes, maybe

  call feedkeys(result, 'n')
endfunction

function! s:ensure_kana_start_pos() abort
  if !s:is_same_line_right_col('kana')
    let current_pos = getcharpos('.')[1:2]
    let b:kana_start_pos = current_pos
  endif
endfunction

function! s:get_insert_spec(key, henkan = v:false) abort
  let kana_dict = get(opts#get('keymap_dict'), a:key, {})
  let next_okuri = get(s:, 'next_okuri', v:false)
  if a:henkan || next_okuri
    " echomsg 'get_insert_spec henkan'
    if !next_okuri && (!s:is_same_line_right_col('henkan') || pumvisible())
      call s:set_henkan_start_pos()
    else
      let preceding_str = s:get_preceding_str('henkan', v:false)
      " echomsg 'okuri-ari:' preceding_str .. a:key

      call k#update_henkan_list(preceding_str .. a:key)

      let s:next_okuri = v:false

      return $"\<c-r>=k#completefunc('{get(kana_dict,'',a:key)}')\<cr>"
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

" 自動補完用なので前方一致のみ
function! k#async_update_henkan_list(str) abort
  let s:latest_henkan_list = []
  let s:latest_async_henkan_list = []
  let str = substitute(a:str, 'ゔ', '(ゔ|う゛)', 'g')
  for jisyo in opts#get('jisyo_list')
    call job#start(substitute(jisyo.grep_cmd, ':query:', $'{str}[^!-~]* /', 'g'), {
          \ 'exit': {data->s:populate_async_henkan_list(data)} })
  endfor
endfunction

function! s:populate_async_henkan_list(data) abort
  " 変換リストの蓄積が辞書リストの数に満たなければ早期脱出
  call add(s:latest_async_henkan_list, a:data)
  if len(s:latest_async_henkan_list) != len(opts#get('jisyo_list'))
    return
  endif

  " 蓄積リストを辞書リストの順に並び替える
  let henkan_list = []
  for jisyo in opts#get('jisyo_list')
    let result_of_current_dict_index = indexof(s:latest_async_henkan_list, {
          \ _,v -> !empty(v) && substitute(v[0], ':.*', '', '') ==# jisyo.path
          \ })
    if result_of_current_dict_index < 0
      continue
    endif
    call extend(henkan_list, s:latest_async_henkan_list[result_of_current_dict_index])
  endfor

  " TODO 送りあり変換をスタートしていたら自動補完はキャンセルする
  call s:save_henkan_list(henkan_list, "\<c-r>=k#autocompletefunc()\<cr>")
endfunction

function! k#update_henkan_list(str) abort
  let str = substitute(a:str, 'ゔ', '(ゔ|う゛)', 'g')
  let results = systemlist(substitute(opts#get('combined_grep_cmd'), ':query:', $'{str} ', 'g'))
  call s:save_henkan_list(results)
endfunction

function! s:save_henkan_list(source_list, after_feedkeys = '') abort
  let henkan_list = []
  for r in a:source_list
    try
      " /path/to/jisyo:よみ /変換1/変換2/.../
      " 変換部分にcolonが含まれる可能性があるためsplitは不適
      let colon_idx = stridx(r, ':')
      let path = strpart(r, 0, colon_idx)
      let content = strpart(r, colon_idx+1)
      let space_idx = stridx(content, ' /')
      let yomi = strpart(content, 0, space_idx)
      let henkan_str = strpart(content, space_idx+1)

      let mark = opts#get('jisyo_mark_pair')[path]

      for v in split(henkan_str, '/')
        " ;があってもなくても良いよう_restを使う
        let [word, info; _rest] = split(v, ';') + ['']
        " :h complete-items
        call add(henkan_list, {
              \ 'word': word,
              \ 'menu': mark .. info,
              \ 'info': mark .. info,
              \ 'user_data': { 'yomi': trim(yomi), 'path': path }
              \ })
      endfor
    catch
      echomsg v:exception r
    endtry
  endfor

  let s:latest_henkan_list = henkan_list
  if a:after_feedkeys != ''
    call feedkeys(a:after_feedkeys, 'n')
  endif
endfunction

let s:latest_auto_complete_str = ''
function! s:auto_complete() abort
  let preceding_str = s:get_preceding_str('henkan', v:false)
        \ ->substitute('\a*$', '', '')

  let min_length = opts#get('min_auto_complete_length')
  if strcharlen(preceding_str) < min_length
    return
  endif

  " echomsg 'auto_complete' preceding_str

  " 冒頭のmin_lengthぶんの文字が異なった場合はhenkan_listを更新
  let need_update = slice(preceding_str, 0, min_length) !=# slice(s:latest_auto_complete_str, 0, min_length)

  let s:latest_auto_complete_str = preceding_str

  if need_update
    call k#async_update_henkan_list(preceding_str)
  else
    call feedkeys("\<c-r>=k#autocompletefunc()\<cr>", 'n')
  endif
endfunction

function! k#autocompletefunc()
  let start_col = s:char_col_to_byte_col(b:henkan_start_pos)

  " yomiの前方一致で絞り込む
  let comp_list = copy(s:latest_henkan_list)
        \ ->filter($"v:val.user_data.yomi =~# '^{s:latest_auto_complete_str}'")

  call complete(start_col, comp_list)
  echo $'{s:latest_auto_complete_str}: {len(comp_list)}件'

  return ''
endfunction

function! k#completefunc(suffix_key = '')
  call s:set_henkan_select_mark()
  " 補完の始点のcol
  let start_col = s:char_col_to_byte_col(b:henkan_start_pos)
  let preceding_str = s:get_preceding_str('henkan') .. a:suffix_key

  let google_exists = v:false
  let comp_list = copy(s:latest_henkan_list)
  if a:suffix_key ==# ''
    for comp_item in comp_list
      if type(comp_item.user_data) == v:t_dict &&
            \ get(comp_item.user_data, 'by_google', 0)
        let google_exists = v:true
        break
      endif
    endfor
  else
    for comp_item in comp_list
      let comp_item.word ..= a:suffix_key
    endfor
  endif

  let list_len = len(comp_list)

  let current_pos = getcharpos('.')[1:2]
  let is_trailing = getline('.')->strcharlen() < current_pos[1]
  let context = {
        \   'yomi': preceding_str,
        \   'start_pos': b:henkan_start_pos,
        \   'cursor_pos': getcharpos('.')[1:2],
        \   'is_trailing': is_trailing,
        \   'suffix_key': a:suffix_key,
        \ }

  if opts#get('use_google_cgi') && !google_exists && a:suffix_key ==# ''
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

  echo $'{preceding_str}: {list_len}件'
  return list_len > 0 ? "\<c-n>" : ''
endfunction

function! s:char_col_to_byte_col(char_pos) abort
  return getline(a:char_pos[0])->slice(0, a:char_pos[1]-1)->strlen()+1
endfunction

function! s:set_henkan_start_pos() abort
  let b:henkan_start_pos = getcharpos('.')[1:2]
  let byte_col = s:char_col_to_byte_col(b:henkan_start_pos)
  call inline_mark#clear()
  call inline_mark#display(b:henkan_start_pos[0], byte_col, opts#get('henkan_marker'))
endfunction

function! s:set_henkan_select_mark() abort
  call inline_mark#clear()
  let byte_col = s:char_col_to_byte_col(b:henkan_start_pos)
  call inline_mark#display(b:henkan_start_pos[0], byte_col, opts#get('select_marker'))
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
    call s:set_henkan_start_pos()
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

  return "\<c-r>=k#completefunc()\<cr>"
endfunction

function! k#kakutei(fallback_key) abort
  if !s:is_same_line_right_col('henkan')
    return a:fallback_key
  endif

  call s:clear_henkan_start_pos()
  return pumvisible() ? "\<c-y>" : ''
endfunction

function! s:complete_done_pre(complete_info, completed_item) abort
  " echomsg a:complete_info a:completed_item

  if s:is_same_line_right_col('henkan')
    " echomsg 'complete_done_pre clear_henkan_start_pos'
    call s:clear_henkan_start_pos()
  endif

  let user_data = get(a:completed_item, 'user_data', {})
  if type(user_data) != v:t_dict
    return
  endif

  if has_key(user_data, 'google_trans')
    let gt = user_data.google_trans
    let henkan_result = google_cgi#henkan(gt.yomi)
    if henkan_result ==# ''
      echomsg 'Google変換で結果が得られませんでした。'
      return
    endif

    call insert(s:latest_henkan_list, {
          \ 'word': henkan_result,
          \ 'menu': '[Google]',
          \ 'info': '[Google]',
          \ 'user_data': { 'yomi': gt.yomi, 'by_google': v:true }
          \ })
    let b:henkan_start_pos = gt.start_pos
    call feedkeys("\<c-r>=k#completefunc()\<cr>", 'n')
    return
  endif

  if has_key(user_data, 'by_google')
    " Google変換確定時、自動でユーザー辞書末尾に登録
    let line = $'{user_data.yomi} /{a:completed_item.word}/'
    call writefile([line], opts#get('user_jisyo_path'), "a")
    return
  endif

  if has_key(user_data, 'jisyo_touroku')
    let jt = user_data.jisyo_touroku
    let b:jisyo_touroku_ctx = jt

    autocmd BufEnter <buffer> ++once call s:buf_enter_try_user_henkan()

    let okuri = jt.suffix_key ==# '' ? '/okuri-nasi' : '/okuri-ari'
    let user_jisyo_winnr = bufwinnr(bufnr(opts#get('user_jisyo_path')))
    if user_jisyo_winnr > 0
      " ユーザー辞書がすでに開いている場合は
      " okuri-ari/okuri-nasiの行へジャンプする
      execute user_jisyo_winnr .. 'wincmd w'
      normal! gg
      execute okuri
    else
      execute $'botright 5new +{okuri}' opts#get('user_jisyo_path')
    endif

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

  let henkan_result = s:latest_henkan_list[0].word
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

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call k#initialize({
      \ 'user_jisyo_path': uj,
      \ 'jisyo_list':  [
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.L'), 'encoding': 'euc-jp', 'mark': '[L]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.geo'), 'encoding': 'euc-jp', 'mark': '[G]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.station'), 'encoding': 'euc-jp', 'mark': '[S]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.jawiki'), 'encoding': 'utf-8', 'mark': '[W]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.emoji'), 'encoding': 'utf-8' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.nicoime'), 'encoding': 'utf-8', 'mark': '[N]' },
      \ ],
      \ 'min_auto_complete_length': 2,
      \ 'use_google_cgi': v:true,
      \ 'merge_tsu': v:true,
      \ })
