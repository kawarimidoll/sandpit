source ./utils.vim

if !exists('*keytrans') || exists(':defer') != 2
  call utils#echoerr('このバージョンの' .. v:progname .. 'はサポートしていません')
  finish
endif

source ./inline_mark.vim
source ./converters.vim
source ./opts.vim
source ./store.vim
source ./henkan_list.vim
source ./mode.vim
source ./cmd_buf.vim

let s:phase = { 'current': '', 'previous': '', 'reason': '' }
" function s:phase_full_get() abort
"   return s:phase
" endfunction
" function s:phase_get() abort
"   return s:phase.current
" endfunction
function s:phase_is(name) abort
  return s:phase.current ==# a:name
endfunction
function s:phase_was(name) abort
  return s:phase.previous ==# a:name
endfunction
function s:phase_set(name, reason = '') abort
  let s:phase.previous = s:phase.current
  let s:phase.current = a:name
  let s:phase.reason = a:reason
endfunction
function s:phase_forget() abort
  let s:phase.previous = ''
  let s:phase.reason = ''
endfunction

function s:mark_put(target, hlname) abort
  call inline_mark#put_text(a:target, store#get(a:target), a:hlname)
endfunction
function s:mark_clear(target = '') abort
  call inline_mark#clear(a:target)
endfunction

function s:feed(str) abort
  call feedkeys(a:str, 'ni')
endfunction

function s:is_complete_selected() abort
  return complete_info(['selected']).selected >= 0
endfunction

function h#enable() abort
  if s:is_enable
    return
  endif
  call utils#do_user('h_autocmd_enable_pre')
  defer utils#do_user('h_autocmd_enable_post')

  augroup h_inner_augroup
    autocmd!
    autocmd CompleteChanged * call s:on_complete_changed(v:event)
    " InsertLeaveだと<c-c>を使用した際に発火しないため
    " ModeChangedを使用する
    autocmd ModeChanged i:*
          \   if mode(1) !~ '^n\?i'
          \ |   call h#disable()
          \ | endif
  augroup END

  let s:keys_to_remaps = []
  let sid = "\<sid>"
  for [key, val] in items(opts#get('map_keys_dict'))
    if index(['|', ''''], key) >= 0
      continue
    endif
    let current_map = maparg(key, 'i', 0, 1)
    let k = keytrans(key)
    call add(s:keys_to_remaps, empty(current_map) ? k : current_map)
    execute $"inoremap {k} <cmd>call {sid}ins('{keytrans(k)}', {val})<cr>"
  endfor

  call store#clear()
  call mode#clear()
  call s:phase_set('hanpa')

  let s:is_enable = v:true
endfunction

function h#disable(escape = v:false) abort
  if !s:is_enable
    return
  endif
  call utils#do_user('h_autocmd_disable_pre')
  defer utils#do_user('h_autocmd_disable_post')

  autocmd! h_inner_augroup

  call s:mark_clear()
  let after_feed = (store#is_present('kouho') ? store#get('kouho') : store#get('machi'))
        \ .. store#get('okuri') .. store#get('hanpa')

  for k in s:keys_to_remaps
    try
      if type(k) == v:t_string
        execute 'iunmap' k
      else
        call mapset('i', 0, k)
      endif
    catch
      echomsg k v:exception
    endtry
  endfor

  call store#clear()
  call mode#clear()
  call s:phase_set('hanpa')

  let s:is_enable = v:false
  if mode() !=# 'i'
    return
  endif
  if a:escape
    let after_feed ..= "\<esc>"
  endif
  call s:feed(after_feed)
endfunction

function h#toggle() abort
  return s:is_enable ? h#disable() : h#enable()
endfunction

function h#init(opts = {}) abort
  call utils#do_user('h_autocmd_initialize_pre')
  defer utils#do_user('h_autocmd_initialize_post')
  try
    call opts#parse(a:opts)
  catch
    call utils#echoerr($'[init] {v:exception}', 'abort')
    return
  endtry

  let s:is_enable = v:false
endfunction

function s:on_complete_changed(event) abort
  call store#set('kouho', get(a:event.completed_item, 'abbr', ''))
  call s:display_marks()
endfunction

function s:get_spec(key) abort
  " 先行入力と合わせて
  "   完成した
  "     辞書
  "     文字列
  "       半端がある
  "       半端がない→半端が空文字として判断できる
  "   完成していないが次なる先行入力の可能性がある
  " 先行入力を無視して単体で
  "   完成した→直前の先行入力を消すか分岐する必要がある
  "     辞書
  "     文字列
  "       半端がある
  "       半端がない→半端が空文字として判断できる
  "   完成していないが次なる先行入力の可能性がある
  " 完成していないし先行入力にもならない

  " string: バッファに書き出す文字列
  " store: ローマ字入力バッファの文字列（上書き）
  " その他：関数など func / mode / expr
  let spec = { 'string': '', 'store': '', 'key': a:key }

  let current = store#get('hanpa') .. a:key
  if has_key(opts#get('kana_table'), current)
    let spec.reason = 'combined:found'
    " s:store.hanpaの残存文字と合わせて完成した場合
    if type(opts#get('kana_table')[current]) == v:t_dict
      call extend(spec, opts#get('kana_table')[current])
      return spec
    endif
    let [kana, roma; _rest] = opts#get('kana_table')[current]->split('\A*\zs') + ['']
    let spec.string = kana
    let spec.store = roma
    return spec
  elseif has_key(opts#get('preceding_keys_dict'), current)
    let spec.reason = 'combined:probably'
    " 完成はしていないが、先行入力の可能性がある場合
    let spec.store = current
    return spec
  endif

  " ここまでで値がヒットせず、put_hanpaがfalseなら、
  " storeに残っていた半端な文字をバッファに載せずに消す
  let spec.string = opts#get('put_hanpa') ? store#get('hanpa') : ''

  if has_key(opts#get('kana_table'), a:key)
    let spec.reason = 'alone:found'
    " 先行入力を無視して単体で完成した場合
    if type(opts#get('kana_table')[a:key]) == v:t_dict
      call extend(spec, opts#get('kana_table')[a:key])
      " 値が辞書ならput_hanpaに関らずstringは削除
      " storeに値を保存する
      let spec.string = ''
      let spec.store = store#get('hanpa')
    else
      let [kana, roma; _rest] = opts#get('kana_table')[a:key]->split('\A*\zs') + ['']
      let spec.string ..= kana
      let spec.store = roma
    endif

    return spec
  elseif has_key(opts#get('preceding_keys_dict'), a:key)
    let spec.reason = 'alone:probably'
    " 完成はしていないが、単体で先行入力の可能性がある場合
    let spec.store = a:key
    return spec
  endif

  let spec.reason = 'unfound'
  " ここまで完成しない（かなテーブルに定義が何もない）場合
  let spec.string ..= a:key
  let spec.store = ''
  return spec
endfunction

function s:henkan_fuzzy() abort
  " echowindow 'henkan' a:machistr a:okuristr
  let exact_match = store#get('machi')->strcharlen() < opts#get('suggest_prefix_match_minimum')
  call henkan_list#update_fuzzy_v2(store#get('machi'), exact_match)
  let comp_list = copy(henkan_list#get_fuzzy())
  if mode() !=# 'i'
    " タイマー実行しており、さらに変換リストの構築に時間がかかるため、
    " この時点で挿入モードから抜けてしまっている可能性がある
    return
  elseif s:phase_kouho
    " 手動変換が開始していたら何もしない
    return
  elseif empty(comp_list) && pumvisible()
    call s:feed("\<c-e>")
    return
  endif
  let machi_pos = inline_mark#get('machi')
  let col = machi_pos->empty() ? col('.') : machi_pos[1]
  call complete(col, comp_list)
endfunction

function s:henkan_start() abort
  " echowindow 'henkan' a:machistr a:okuristr
  call henkan_list#update_manual_v2(store#get('machi'), store#get('okuri'))
  let comp_list = copy(henkan_list#get())
  if !empty(comp_list)
    call complete(col('.'), comp_list)
    return "\<c-n>"
  endif
  return ''
endfunction

function s:sticky() abort
  if store#is_present('hanpa')
    " ひらがなになりきれていない文字が残っている場合はスキップ
    return ''
  endif

  if s:phase_is('machi')
    if store#is_present('machi')
      call s:phase_set('okuri', 'sticky: start okuri')
    endif
  elseif s:phase_is('okuri')
  " nop
  else
    call s:phase_set('machi', 'sticky: start machi')
  endif
  return ''
endfunction

function s:backspace() abort
  let feed = ''
  if store#is_present('hanpa')
    call store#pop('hanpa')
  elseif store#is_present('okuri')
    call store#pop('okuri')
    if store#is_blank('okuri')
      call s:phase_set('machi', 'backspace: blank okuri')
    endif
  elseif store#is_present('machi')
    call store#pop('machi')
    if store#is_blank('machi')
      call s:phase_set('hanpa', 'backspace: blank machi')
      if mode#is_start_sticky()
        call mode#set_anyway('hira')
      endif
    endif
  else
    let feed = "\<bs>"
  endif
  return feed
endfunction

function s:kakutei(fallback_key) abort
  call s:phase_set('hanpa', 'kakutei')
  let feed = (store#is_present('kouho') ? store#get('kouho') : store#get('machi')) .. store#get('okuri')
  call store#clear('kouho')
  call store#clear('machi')
  call store#clear('okuri')
  if mode#is_start_sticky()
    call mode#set_anyway('hira')
  endif
  return feed ==# '' ? utils#trans_special_key(a:fallback_key) : feed
endfunction

function s:henkan(fallback_key) abort
  let feed = ''
  if store#is_present('okuri')
    return "\<c-n>"
  elseif store#is_present('machi')
    if s:phase_kouho
      return "\<c-n>"
    endif
    if opts#get('trailing_n') && store#get('hanpa') ==# 'n' && store#get('machi')->slice(-1) != 'ん'
      call store#push('machi', 'ん')
    endif
    let feed = s:henkan_start()
  else
    let feed = store#get('hanpa') .. utils#trans_special_key(a:fallback_key)
  endif
  call store#clear('hanpa')
  return feed
endfunction

function s:ins(key, with_sticky = v:false) abort
  call s:phase_forget()
  if a:with_sticky && !mode#is_direct_v2(a:key)
  " TODO direct modeの変換候補を選択した状態で大文字を入力した場合の対処
    let feed = s:handle_spec({ 'string': '', 'store': '', 'func': 'sticky' })

    let key = a:key->tolower()
    call s:feed(utils#trans_special_key(feed) .. $"\<cmd>call {expand('<SID>')}ins('{key}')\<cr>")
    return
  endif

  let spec = s:get_spec(a:key)

  let feed = s:handle_spec(spec)

  if feed ==# ''
    call s:display_marks()
    if s:phase_is('machi')
      if opts#get('suggest_wait_ms') >= 0
        call utils#debounce(funcref('s:henkan_fuzzy'), opts#get('suggest_wait_ms'))
      endif
    elseif s:phase_was('machi') && s:phase_is('hanpa')
      call s:feed("\<c-e>")
    endif
  else
    call s:feed(utils#trans_special_key(feed) .. $"\<cmd>call {expand('<SID>')}display_marks()\<cr>")
  endif
endfunction

" kouho状態の判定は他のphaseとは独立して判定する
let s:phase_kouho = v:false
function s:handle_spec(args) abort
  let spec = a:args

  if !s:is_complete_selected() && mode#is_direct_v2(get(spec, 'key', ''))
    let spec = { 'string': spec.key, 'store': '', 'key': spec.key }
  endif

  call store#set('hanpa', spec.store)

  " kouho状態に入る(継続する)かのフラグ
  let next_kouho = v:false

  " 多重コンバートを防止
  let allow_convert = v:true

  " 末尾でstickyを実行するかどうかのフラグ
  " 変換候補選択中にstickyを実行した場合、いちど確定してからstickyを実行するため、
  " このフラグを見て実行を後回しにする必要がある
  let after_sticky = v:false

  let feed = ''
  if has_key(spec, 'func')
    " handle func
    if spec.func ==# 'sticky'
      if s:is_complete_selected()
        let feed = s:kakutei('')
        let after_sticky = v:true
      else
        let feed = s:sticky()
      endif

    elseif spec.func ==# 'backspace'
      let feed = s:backspace()
    elseif spec.func ==# 'kakutei'
      let feed = s:kakutei(spec.key) .. store#get('hanpa')
      call store#clear()
    elseif spec.func ==# 'henkan'
      let feed = s:henkan(spec.key)
      let next_kouho = v:true
    endif
  elseif has_key(spec, 'mode')
    if store#is_present('okuri')
    " nop
    elseif store#is_present('machi')
      if s:phase_kouho
      " nop
      else
        let feed ..= mode#convert_alt(spec.mode, s:kakutei(''))
        let allow_convert = v:false
      endif
    else
      call mode#set_alt(spec.mode)
      if mode#is_start_sticky()
        let after_sticky = v:true
      endif
    endif
  elseif has_key(spec, 'expr')
    let feed = call(spec.expr[0], spec.expr[1:])
  elseif has_key(spec, 'call')
    call call(spec.call[0], spec.call[1:])
  else
    if s:is_complete_selected()
      let feed = s:kakutei('')
    endif
    let feed ..= spec.string
  endif

  let s:phase_kouho = next_kouho

  if allow_convert
    " TODO カタカナモードでも変換できるようにする
    let feed = mode#convert(feed)
  endif

  if after_sticky
    let feed ..= $"\<cmd>call {expand('<SID>')}sticky()\<cr>"
  endif

  if s:phase_is('hanpa') || feed !~ '\p'
    return feed
  elseif s:phase_is('machi')
    call store#push('machi', feed)
  elseif s:phase_is('okuri')
    call store#push('okuri', feed)

    if store#is_blank('hanpa')
      return s:henkan_start()
    endif
  endif
  return ''
endfunction

function s:display_marks(...) abort
  let hlname = opts#get('highlight_hanpa')
  if hlname == ''
    let [lnum, col] = getpos('.')[1:2]
    let syn_offset = (col > 1 && col == col('$')) ? 1 : 0
    let hlname = synID(lnum, col-syn_offset, 1)->synIDattr('name')
  endif

  if s:phase_is('machi')
    let hlname = opts#get('highlight_machi')
  endif
  if store#is_present('kouho')
    call s:mark_clear('machi')
    let hlname = opts#get('highlight_kouho')
    call s:mark_put('kouho', hlname)
  elseif store#is_present('machi')
    call s:mark_clear('kouho')
    let hlname = opts#get('highlight_machi')
    call s:mark_put('machi', hlname)
  else
    call s:mark_clear('kouho')
    call s:mark_clear('machi')
  endif
  if s:phase_is('okuri')
    let hlname = opts#get('highlight_okuri')
  endif
  if store#is_present('okuri')
    call s:mark_put('okuri', hlname)
  else
    call s:mark_clear('okuri')
  endif
  if store#is_present('hanpa')
    call s:mark_put('hanpa', hlname)
  else
    call s:mark_clear('hanpa')
  endif
endfunction

inoremap <c-j> <cmd>call h#toggle()<cr>
cnoremap <c-j> <cmd>call cmd_buf#run('h#enable')<cr>

inoremap <c-k> <cmd>imap<cr>

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call h#init({
      \ 'user_jisyo_path': uj,
      \ 'jisyo_list':  [
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.L'), 'encoding': 'euc-jp', 'mark': '[L]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.geo'), 'encoding': 'euc-jp', 'mark': '[G]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.station'), 'encoding': 'euc-jp', 'mark': '[S]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.jawiki'), 'encoding': 'utf-8', 'mark': '[W]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.emoji'), 'encoding': 'utf-8' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.nicoime'), 'encoding': 'utf-8', 'mark': '[N]' },
      \ ],
      \ 'henkan_sort_by': 'jisyo',
      \ 'suggest_wait_ms': 200,
      \ 'suggest_prefix_match_minimum': 5,
      \ 'suggest_sort_by': 'length',
      \ 'debug_log': '',
      \ 'use_google_cgi': v:true,
      \ 'merge_tsu': v:true,
      \ 'trailing_n': v:true,
      \ 'abbrev_ignore_case': v:true,
      \ 'put_hanpa': v:true,
      \ })
