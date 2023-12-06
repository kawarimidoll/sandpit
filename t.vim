source ./converters.vim
source ./google_cgi.vim
source ./job.vim
source ./utils.vim
source ./opts.vim
source ./henkan_list.vim
source ./states.vim
source ./func.vim

function! s:is_completed() abort
  return get(complete_info(), 'selected', -1) >= 0
endfunction

function! t#is_enable() abort
  return get(s:, 'is_enable', v:false)
endfunction

function! t#enable() abort
  if !exists('s:is_enable')
    call utils#echoerr('[t#enable] not initialized')
    call utils#echoerr('[t#enable] abort')
    return
  endif
  if s:is_enable
    return
  endif

  if opts#get('textwidth_zero')
    let s:save_textwidth = &textwidth
    set textwidth=0
  endif

  augroup t#augroup
    autocmd!
    autocmd InsertLeave * call t#disable()
    autocmd TextChangedI *
          \   if states#in('kouho')
          \ |   call states#off('kouho')
          \ | endif
    autocmd CompleteDonePre *
          \ call states#off('kouho')
  augroup END

  let s:keys_to_remaps = []
  for [key, map_cmd] in opts#get('map_cmds')
    let current_map = maparg(key, 'i', 0, 1)
    call add(s:keys_to_remaps, empty(current_map) ? key : current_map)
    execute map_cmd
  endfor

  call states#clear()

  let s:is_enable = v:true
endfunction

function! t#disable() abort
  if !exists('s:is_enable')
    call utils#echoerr('[t#enable] not initialized')
    call utils#echoerr('[t#enable] abort')
    return
  endif
  call states#clear()
  if !s:is_enable
    return
  endif

  if has_key(s:, 'save_textwidth')
    let &textwidth = s:save_textwidth
    unlet! s:save_textwidth
  endif

  for k in s:keys_to_remaps
    if type(k) == v:t_string
      execute 'iunmap' k
    else
      call mapset('i', 0, k)
    endif
  endfor

  autocmd! t#augroup
  let s:is_enable = v:false
endfunction

function! t#toggle() abort
  return t#is_enable() ? t#disable() : t#enable()
endfunction

function! t#default_kana_table() abort
  return json_decode(join(readfile('./kana_table.json'), "\n"))
endfunction

function! t#initialize(opts = {}) abort
  try
    call opts#parse(a:opts)
  catch
    call utils#echoerr($'[t#initialize] {v:exception}')
    call utils#echoerr('[t#initialize] abort')
    return
  endtry

  let s:is_enable = v:false
endfunction

let s:hira_mode = {
      \ 'name': 'hira',
      \ 'conv': {c->c}
      \ }
let s:mode = s:hira_mode
function! t#ins(key, henkan = v:false) abort
  " feedkeys直後はバッファに文字が反映されていないので
  " bs_countを使って文字を一部取り出すテクニックが必要
  let key = utils#trans_special_key(a:key)
  let [bs_count, spec] = s:get_insert_spec(key)
  call feedkeys(repeat("\<bs>", bs_count), 'n')

  if type(spec) == v:t_dict
    if has_key(spec, 'func')
      let feed = call($'func#{spec.func}', [key])
      call feedkeys(feed, 'n')
      return
    elseif has_key(spec, 'conv')
      let conv_name = {
            \ 'zen_kata': 'converters#hira_to_kata',
            \ 'han_kata': 'converters#hira_to_han_kata'
            \ }[spec.conv]
      if states#in('machi')
        let machistr =  states#getstr('machi')[0 : -bs_count-1]
        let feed = repeat("\<bs>", strcharlen(machistr)) .. call(conv_name, [machistr])
        call feedkeys(feed, 'n')
        call states#off('machi')
        return
      endif
      let s:mode = s:mode.name ==# spec.conv ? s:hira_mode : {
            \ 'name': spec.conv,
            \ 'conv': funcref(conv_name)
            \ }
      echomsg $'{s:mode.name} mode'
    endif
    return
  endif

  " type(spec) == v:t_string

  if pumvisible() && s:is_completed()
    call states#off('machi')
    call states#off('choku')
  endif
  if spec == ''
    return
  endif
  if a:henkan
    call states#on('machi')
  endif
  call states#on('choku')

  call feedkeys(call(s:mode.conv, [spec]), 'n')

  if states#in('okuri') && slice(spec, -1) !~ '\a$'
    " [machistr, okuristr] は以下のようになる
    " ;oku;ri -> [おく, り]
    " ;modo;tte -> [もど, って]
    let from_col = states#get('machi')[1]-1
    let to_col = states#get('okuri')[1]-2
    let machistr = getline('.')[from_col : to_col]
    let okuristr = states#getstr('okuri')[0 : -bs_count-1] .. spec

    call henkan_list#update_manual(machistr, okuristr)

    " この時点ではまだ「おくr」の状態で、specが入力されていない
    " 下のfeedkeysを実行することで上のも実行されるようだ
    call feedkeys($"\<c-r>=t#completefunc()\<cr>", 'n')
    call states#off('okuri')
  endif
endfunction

function! s:get_insert_spec(key) abort
  let kana_dict = get(opts#get('keymap_dict'), a:key, {})
  if empty(kana_dict)
    return [0, a:key]
  endif

  let preceding_str = states#getstr('choku')

  let i = strcharlen(preceding_str)
  while i > 0
    let tail_str = slice(preceding_str, -i)
    if has_key(kana_dict, tail_str)
      return [i, kana_dict[tail_str]]
    endif
    let i -= 1
  endwhile

  return [0, get(kana_dict, '', a:key)]
endfunction

function! t#completefunc()
  call states#on('kouho')

  let preceding_str = states#getstr('machi')
  let comp_list = copy(henkan_list#get())

  let list_len = len(comp_list)

  call complete(states#get('machi')[1], comp_list)

  echo $'{preceding_str}: {complete_info(["items"])->len()}件'
  return list_len > 0 ? "\<c-n>" : ''
endfunction

" cnoremap <c-j> <cmd>call t#cmd_buf()<cr>
inoremap <c-j> <cmd>call t#toggle()<cr>
inoremap <c-k> <cmd>imap<cr>

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call t#initialize({
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
      \ 'textwidth_zero': v:true,
      \ })
