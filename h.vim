source ./inline_mark.vim
source ./utils.vim
source ./opts.vim
source ./store.vim
source ./henkan_list.vim

function! h#feed(str) abort
  call feedkeys(a:str, 'ni')
endfunction

function! h#enable() abort
  if s:is_enable
    return
  endif

  augroup h#augroup
    autocmd!
    autocmd CompleteChanged * call s:on_complete_changed(v:event)
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
    execute $"inoremap {k} <cmd>call {sid}i1('{keytrans(k)}', {val})->{sid}i2()<cr>"
  endfor

  call store#clear()
  let s:current_store_name = 'choku'

  let s:phase = { 'choku': '', 'machi': '', 'okuri': '' }

  let s:is_enable = v:true
endfunction

function! h#disable(escape = v:false) abort
  if !s:is_enable
    return
  endif

  autocmd! h#augroup

  call inline_mark#clear(s:show_okuri_namespace)
  call inline_mark#clear(s:show_machi_namespace)
  call inline_mark#clear(s:show_choku_namespace)
  " call h#feed(store#get('machi') .. store#get('okuri') .. store#get('choku'))
  let after_feed = store#get('machi') .. store#get('okuri') .. store#get('choku')

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
  let s:current_store_name = 'choku'

  let s:is_enable = v:false
  if a:escape
    let after_feed ..= "\<esc>"
    " call timer_start(1, {->call('h#feed', ["\<esc>"])})
  endif
  call h#feed(after_feed)
endfunction

function! h#toggle() abort
  return s:is_enable ? h#disable() : h#enable()
endfunction

function! h#init(opts = {}) abort
  try
    call opts#parse(a:opts)
  catch
    call utils#echoerr($'[h#init] {v:exception}', 'abort')
    return
  endtry

  let s:is_enable = v:false
endfunction

function! s:on_complete_changed(event) abort
  if a:event.completed_item->empty()
    call store#set('machi', s:henkan_context.query)
  else
    call store#set('machi', a:event.completed_item.abbr)
  endif
  call inline_mark#put_text(s:show_machi_namespace, store#get('machi'), 'IncSearch')
  if store#is_present('okuri')
    call inline_mark#put_text(s:show_okuri_namespace, store#get('okuri'),  'Error')
  endif
endfunction

function! s:get_spec(key) abort
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
  let spec = { 'string': '', 'store': '' }

  let current = store#get('choku') .. a:key
  if has_key(opts#get('kana_table'), current)
    let spec.message = 'full found'
    " s:store.chokuの残存文字と合わせて完成した場合
    if type(opts#get('kana_table')[current]) == v:t_dict
      call extend(spec, opts#get('kana_table')[current])
      return spec
    endif
    let [kana, roma; _rest] = opts#get('kana_table')[current]->split('\A*\zs') + ['']
    " call store#set('choku', roma)
    let spec.string = kana
    let spec.store = roma
    return spec
  elseif has_key(opts#get('preceding_keys_dict'), current)
    let spec.message = 'full candidate'
    " 完成はしていないが、先行入力の可能性がある場合
    " call store#set('choku', current)
    let spec.store = current
    return spec
  endif

  if has_key(opts#get('kana_table'), a:key)
    let spec.message = 'alone found'
    " 先行入力を無視して単体で完成した場合
    if type(opts#get('kana_table')[a:key]) == v:t_dict
      call extend(spec, opts#get('kana_table')[a:key])
      let spec.store = store#get('choku')
    else
      " specが文字列でdel_odd_charがfalseの場合、
      " storeに残っていた半端な文字をバッファに載せずに消す
      let prefix = opts#get('del_odd_char') ? '' : store#get('choku')
      let [kana, roma; _rest] = opts#get('kana_table')[a:key]->split('\A*\zs') + ['']
      let spec.string = prefix .. kana
      let spec.store = roma
    endif

    return spec
  elseif has_key(opts#get('preceding_keys_dict'), a:key)
    let spec.message = 'alone candidate'
    " 完成はしていないが、単体で先行入力の可能性がある場合
    let spec.store = a:key
    return spec
  endif

  let spec.message = 'not found'
  " ここまで完成しない（かなテーブルに定義が何もない）場合
  " specが文字列でdel_odd_charがfalseの場合、
  " storeに残っていた半端な文字をバッファに載せずに消す
  let prefix = opts#get('del_odd_char') ? '' : store#get('choku')
  let spec.string = prefix .. a:key
  let spec.store = ''
  return spec
endfunction

function! s:henkan_start(machistr, okuristr = '') abort
  echowindow 'henkan' a:machistr a:okuristr
  call henkan_list#update_manual_v2(a:machistr, a:okuristr)
  let comp_list = copy(henkan_list#get())
  let feed = ''
  if !empty(comp_list)
    call complete(col('.'), comp_list)
    let feed = "\<c-n>"
  endif
  return feed
endfunction

function! s:henkan() abort
  let feed = ''
  if store#is_present('okuri')
    return ''
  elseif store#is_present('machi')
    if s:phase_kouho
      let feed = "\<c-n>"
      return feed
    endif

    let feed = s:henkan_start(store#get('machi') .. store#get('choku'))

  else
    let feed = store#get('choku') .. a:args.key
    call store#clear('choku')
  endif
  return feed
endfunction

function! s:i1(key, with_sticky = v:false) abort
  let key = a:key
  if a:with_sticky
    let key = a:key->tolower()
  endif
  let spec = s:get_spec(key)
  let spec.original_key = a:key
  let spec.key = key
  return spec
endfunction

let s:show_choku_namespace = 'SHOW_CHOKU_NAMESPACE'
let s:show_machi_namespace = 'SHOW_MACHI_NAMESPACE'
let s:show_okuri_namespace = 'SHOW_OKURI_NAMESPACE'
let s:current_store_name = 'choku'
let s:phase_kouho = v:false
function! s:i2(args) abort
  echomsg a:args

  let hlname = ''
  if store#is_blank('choku')
    let [lnum, col] = getpos('.')[1:2]
    let syn_offset = (col > 1 && col == col('$')) ? 1 : 0
    let hlname = synID(lnum, col-syn_offset, 1)->synIDattr('name')
  endif

  call store#set('choku', a:args.store)

  let next_kouho = v:false

  let feed = ''
  if has_key(a:args, 'func')
    " handle func
    if a:args.func ==# 'sticky'
      if s:current_store_name == 'machi'
        let s:current_store_name = 'okuri'
      elseif s:current_store_name == 'okuri'
      " ここで確定？
      else
        let s:current_store_name = 'machi'
      endif
    elseif a:args.func ==# 'backspace'
      if store#is_present('choku')
        call store#pop('choku')
      elseif store#is_present('okuri')
        call store#pop('okuri')
        if store#is_blank('okuri')
          let s:current_store_name = 'machi'
        endif
      elseif store#is_present('machi')
        call store#pop('machi')
        if store#is_blank('machi')
          let s:current_store_name = 'choku'
        endif
      else
        let feed = '<bs>'
      endif
    elseif a:args.func ==# 'kakutei'
      let s:current_store_name = 'choku'
      let feed = store#get('machi') .. store#get('okuri') .. store#get('choku')
      call store#clear()
      if feed ==# ''
        let feed = a:args.key
      endif
    elseif a:args.func ==# 'henkan'
      let feed = s:henkan()
      let next_kouho = v:true
    endif
  elseif has_key(a:args, 'mode')
  " handle mode
  elseif has_key(a:args, 'expr')
    let feed = call(a:args.expr[0], a:args.expr[1:])
  elseif has_key(a:args, 'call')
    call call(a:args.call[0], a:args.call[1:])
  else
    let feed = a:args.string
  endif

  let s:phase_kouho = next_kouho

  if s:current_store_name == 'choku' || feed !~ '\p'
    call h#feed(utils#trans_special_key(feed))
  elseif s:current_store_name == 'machi'
    call store#push('machi', feed)
  " call inline_mark#put_text(s:show_machi_namespace, store#get('machi'), 'IncSearch')
  elseif s:current_store_name == 'okuri'
    call store#push('okuri', feed)

    if store#is_blank('choku')
      let feed = s:henkan_start(store#get('machi'), store#get('okuri'))
      call h#feed(utils#trans_special_key(feed))
    endif
  endif

  if store#is_blank('machi')
    call inline_mark#clear(s:show_machi_namespace)
  else
    call inline_mark#put_text(s:show_machi_namespace, store#get('machi'),  'IncSearch')
  endif
  if store#is_blank('okuri')
    call inline_mark#clear(s:show_okuri_namespace)
  else
    call inline_mark#put_text(s:show_okuri_namespace, store#get('okuri'),  'Error')
  endif
  if store#is_blank('choku')
    call inline_mark#clear(s:show_choku_namespace)
  else
    call inline_mark#put_text(s:show_choku_namespace, store#get('choku'), hlname)
  endif
endfunction

inoremap <c-j> <cmd>call h#toggle()<cr>

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
      \ 'min_auto_complete_length': 3,
      \ 'sort_auto_complete_by_length': v:true,
      \ 'use_google_cgi': v:true,
      \ 'merge_tsu': v:true,
      \ 'trailing_n': v:true,
      \ 'textwidth_zero': v:true,
      \ 'abbrev_ignore_case': v:true,
      \ 'del_odd_char': v:true,
      \ })
