source ./utils.vim

if !exists('*keytrans') || exists(':defer') != 2
  call utils#echoerr('このバージョンの' .. v:progname .. 'はサポートしていません')
  finish
endif

source ./google_cgi.vim
source ./inline_mark.vim
source ./converters.vim
source ./henkan_list.vim
source ./opts.vim
source ./phase.vim
source ./store.vim
source ./func.vim
source ./mode.vim
source ./insert.vim

function s:is_completed() abort
  return get(complete_info(), 'selected', -1) >= 0
endfunction

function s:doautocmd(event_name) abort
  if exists($'#User#{a:event_name}')
    execute $'doautocmd User {a:event_name}'
  endif
endfunction

function virt_poc#enable() abort
  if s:is_enable
    return
  endif
  call s:doautocmd('virt_poc_enable_pre')
  defer s:doautocmd('virt_poc_enable_post')

  if opts#get('textwidth_zero')
    let s:save_textwidth = &textwidth
    set textwidth=0
  endif

  augroup virt_poc#augroup
    autocmd!
    autocmd InsertLeave * call virt_poc#disable()
    autocmd CompleteChanged *
          \   echo $'{v:event.size}件'
          \ | if s:is_completed() && phase#is_enabled('machi') && store#get('choku') !=# ''
          \ |   call store#clear('choku')
          \ |   call store#display_odd_char()
          \ | endif
    " autocmd TextChangedI * call s:auto_complete()
    autocmd CompleteDonePre * call timer_start(1, {->call("\<sid>complete_done_pre", [])})
  augroup END

  call insert#map()
  call phase#clear()
  call store#clear()
  call mode#clear()
  let s:is_enable = v:true
endfunction

function virt_poc#disable() abort
  if !s:is_enable
    return
  endif
  call s:doautocmd('virt_poc_disable_pre')
  defer s:doautocmd('virt_poc_disable_post')

  if has_key(s:, 'save_textwidth')
    let &textwidth = s:save_textwidth
    unlet! s:save_textwidth
  endif

  autocmd! virt_poc#augroup

  call insert#unmap()
  call phase#clear()
  call store#clear()
  let s:is_enable = v:false
endfunction

function virt_poc#toggle() abort
  return s:is_enable ? virt_poc#disable() : virt_poc#enable()
endfunction

function virt_poc#init(opts = {}) abort
  call s:doautocmd('virt_poc_initialize_pre')
  defer s:doautocmd('virt_poc_initialize_post')
  try
    call opts#parse(a:opts)
  catch
    call utils#echoerr($'[virt_poc#init] {v:exception}')
    call utils#echoerr('[virt_poc#init] abort')
    return
  endtry

  let s:is_enable = v:false
endfunction

let s:latest_auto_complete_str = ''
function s:auto_complete() abort
  let min_length = 5
  if phase#is_enabled('kouho') || phase#is_enabled('okuri') || phase#is_disabled('machi') || store#get('machi') ==# ''
    return
  endif

  " auto complete
  let need_update = strcharpart(store#get('machi'), 0, min_length + 1) !=# strcharpart(s:latest_auto_complete_str, 0, min_length + 1)
  let s:latest_auto_complete_str = store#get('machi')
  let exact_match = s:latest_auto_complete_str->strcharlen() < min_length

  if need_update || exact_match
    call henkan_list#update_fuzzy(s:latest_auto_complete_str, exact_match)
    " call utils#debug_log('henkan_list#get_fuzzy')
    " call utils#debug_log(henkan_list#get_fuzzy())
  endif
  " echomsg s:latest_auto_complete_str store#get('machi')

  " yomiの前方一致で絞り込む
  let comp_list = copy(henkan_list#get_fuzzy())
        \ ->filter($"v:val.user_data.yomi =~# '^{s:latest_auto_complete_str}'")

  if len(comp_list) > 0
    call complete(phase#getpos('machi')[1], comp_list)
  endif
endfunction

function s:complete_done_pre() abort
  if pumvisible() && phase#is_enabled('kouho')
    return
  endif
  call phase#disable('kouho')
  " ここでは既にCompleteDoneが発行されているのでcomplete_info()は使用できない
  if !empty(v:completed_item)
    call phase#disable('machi')
    call store#clear('machi')
    call store#clear('okuri')
  endif

  let user_data = get(v:completed_item, 'user_data', {})
  if type(user_data) != v:t_dict || !has_key(user_data, 'virt_poc_process')
    return
  endif

  if user_data.virt_poc_process ==# 'google'
    let google_result = google_cgi#henkan(user_data.yomi)
    if google_result ==# ''
      echomsg 'Google変換で結果が得られませんでした。'
      return
    endif

    let comp_list = [{
          \ 'word': google_result,
          \ 'menu': '[Google]',
          \ 'info': '[Google]',
          \ 'user_data': { 'yomi': user_data.yomi, 'context': user_data.context, 'virt_poc_process': 'set_to_user_jisyo' }
          \ }]
    call complete(user_data.context.start_col, comp_list)
    call phase#enable('kouho')
    return
  endif

  if user_data.virt_poc_process ==# 'set_to_user_jisyo'
    let line = $'{user_data.yomi} /{v:completed_item.word}/'
    call writefile([line], opts#get('user_jisyo_path'), "a")
    return
  endif

  if user_data.virt_poc_process ==# 'new_word'
    autocmd BufEnter <buffer> ++once call s:buf_enter_try_user_henkan()

    let context = user_data.context
    let yomi = context.machi
    let b:virt_poc_context = context

    let jump_line = '/okuri-nasi'
    if context.okuri !=# ''
      let jump_line = '/okuri-ari'
      let consonant = utils#consonant(strcharpart(context.okuri, 0, 1))
      let yomi ..= consonant
    endif

    let user_jisyo_winnr = bufwinnr(bufnr(opts#get('user_jisyo_path')))
    if user_jisyo_winnr > 0
      " ユーザー辞書がすでに開いている場合は
      " okuri-ari/okuri-nasiの行へジャンプする
      execute user_jisyo_winnr .. 'wincmd w'
      normal! gg
      execute jump_line
    else
      call virt_poc#open_user_jisyo($'+{jump_line}')
    endif

    call feedkeys($"\<c-o>o{yomi} //\<c-g>U\<left>\<cmd>call virt_poc#enable()\<cr>", 'n')
  endif
endfunction

function virt_poc#open_user_jisyo(args = '') abort
  execute 'botright 5new' a:args opts#get("user_jisyo_path")
endfunction

function s:buf_enter_try_user_henkan() abort
  call cursor(b:virt_poc_context.pos)
  if b:virt_poc_context.is_trailing
    startinsert!
  else
    startinsert
  endif

  call virt_poc#enable()

  call henkan_list#update_manual(b:virt_poc_context.machi, b:virt_poc_context.okuri)
  if empty(henkan_list#get())
    return
  endif

  call phase#enable('kouho')
  " ここで直接実行するとインサートモードに入れておらずエラーになるので
  " タイマーで遅延する必要がある
  call timer_start(1, {->call('complete', [b:virt_poc_context.start_col, henkan_list#get()])})
endfunction

function virt_poc#cmd_buf() abort
  let cmdtype = getcmdtype()
  if ':/?' !~# cmdtype
    return
  endif

  let s:cmd_buf_context = {
        \ 'type': cmdtype,
        \ 'text': getcmdline(),
        \ 'col': getcmdpos(),
        \ 'view': winsaveview(),
        \ 'winid': win_getid(),
        \ }

  botright 1new
  setlocal buftype=nowrite bufhidden=wipe noswapfile

  call feedkeys("\<c-c>", 'n')

  call setline(1, s:cmd_buf_context.text)
  call cursor(1, s:cmd_buf_context.col)

  if strlen(s:cmd_buf_context.text) < s:cmd_buf_context.col
    startinsert!
  else
    startinsert
  endif
  call virt_poc#enable()

  augroup virt_poc_cmd_buf
    autocmd!
    " 直接記述すると即座に発火してしまうのでInsertEnterでラップする
    " 入力を終了したり改行したりしたタイミングでコマンドラインに戻って反映する
    autocmd InsertEnter <buffer> ++once
          \ autocmd TextChanged,TextChangedI,TextChangedP,InsertLeave,BufLeave,WinLeave <buffer> ++nested
          \   if line('$') > 1 || mode() !=# 'i'
          \ |   stopinsert
          \ |   let s:cmd_buf_context.line = s:cmd_buf_context.type .. getline(1, '$')->join('')
          \ |   quit!
          \ |   call win_gotoid(s:cmd_buf_context.winid)
          \ |   call winrestview(s:cmd_buf_context.view)
          \ |   call timer_start(1, {->feedkeys(s:cmd_buf_context.line, 'ni')})
          \ | endif
  augroup END
endfunction

cnoremap <c-j> <cmd>call virt_poc#cmd_buf()<cr>

inoremap <c-j> <cmd>call virt_poc#toggle()<cr>
inoremap <c-k> <cmd>imap<cr>
" inoremap <c-d> <cmd>echomsg $'choku {store#get("choku")} machi {store#get("machi")} okuri {store#get("okuri")}'<cr>

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call virt_poc#init({
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
