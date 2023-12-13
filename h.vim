source ./inline_mark.vim
source ./utils.vim
source ./opts.vim

let s:store = { 'choku': '', 'machi': '', 'okuri': '' }
function! s:store_get(target) abort
  return s:store[a:target]
endfunction
function! s:store_set(target, str) abort
  let s:store[a:target] = a:str
endfunction
function! s:store_clear(target = '') abort
  if a:target ==# ''
    let s:store = { 'choku': '', 'machi': '', 'okuri': '' }
  else
    call s:store_set(a:target, '')
  endif
endfunction

function! h#enable() abort
  if s:is_enable
    return
  endif

  augroup h#augroup
    autocmd!
    autocmd InsertLeave * call h#disable()
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

  call s:store_clear()

  let s:is_enable = v:true
endfunction

function! h#disable() abort
  if !s:is_enable
    return
  endif

  autocmd! h#augroup

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

  let s:is_enable = v:false
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
  let current = s:store_get('choku') .. a:key
  if has_key(opts#get('kana_table'), current)
    let spec.message = 'full found'
    " s:store.chokuの残存文字と合わせて完成した場合
    if type(opts#get('kana_table')[current]) == v:t_dict
      call extend(spec, opts#get('kana_table')[current])
      return spec
    endif
    let [kana, roma; _rest] = opts#get('kana_table')[current]->split('\A*\zs') + ['']
    " call s:store_set('choku', roma)
    let spec.string = kana
    let spec.store = roma
    return spec
  elseif has_key(opts#get('preceding_keys_dict'), current)
    let spec.message = 'full candidate'
    " 完成はしていないが、先行入力の可能性がある場合
    " call s:store_set('choku', current)
    let spec.store = current
    return spec
  endif

  if has_key(opts#get('kana_table'), a:key)
    let spec.message = 'alone found'
    " 先行入力を無視して単体で完成した場合
    if type(opts#get('kana_table')[a:key]) == v:t_dict
      call extend(spec, opts#get('kana_table')[a:key])
    else
      " specが文字列でdel_odd_charがfalseの場合、
      " storeに残っていた半端な文字をバッファに載せずに消す
      let prefix = opts#get('del_odd_char') ? '' : s:store_get('choku')
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
  let prefix = opts#get('del_odd_char') ? '' : s:store_get('choku')
  let spec.string = prefix .. a:key
  let spec.store = ''
  return spec
endfunction

function! s:i1(key, with_sticky = v:false) abort
  let key = a:key
  if a:with_sticky
    let key = a:key->tolower()
  endif
  let spec = s:get_spec(key)
  let spec.key = key
  return spec
endfunction

let s:show_choku_namespace = 'SHOW_CHOKU_NAMESPACE'
function! s:i2(args) abort
  echomsg a:args

  let hlname = ''
  if s:store_get('choku') ==# ''
    let [lnum, col] = getpos('.')[1:2]
    let syn_offset = (col > 1 && col == col('$')) ? 1 : 0
    let hlname = synID(lnum, col-syn_offset, 1)->synIDattr('name')
  endif

  call s:store_set('choku', a:args.store)

  if s:store_get('choku') ==# ''
    call inline_mark#clear(s:show_choku_namespace)
  else
    call inline_mark#put_text(s:show_choku_namespace, s:store_get('choku'), hlname)
  endif

  if has_key(a:args, 'func')
    " TODO: handle func
    call feedkeys(utils#trans_special_key(a:args.key), 'n')
  elseif has_key(a:args, 'mode')
    " TODO: handle mode
    call feedkeys(utils#trans_special_key(a:args.key), 'n')
  elseif has_key(a:args, 'expr')
    " TODO: handle expr
    call feedkeys(utils#trans_special_key(a:args.key), 'n')
  else
    call feedkeys(utils#trans_special_key(a:args.string), 'n')
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