source ./converters.vim
source ./google_cgi.vim
source ./job.vim
source ./utils.vim
source ./opts.vim
source ./henkan_list.vim
source ./states.vim
source ./func.vim

function s:is_completed() abort
  return get(complete_info(), 'selected', -1) >= 0
endfunction

function t#is_enable() abort
  return get(s:, 'is_enable', v:false)
endfunction

function t#enable() abort
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

  call states#clear()
  let s:mode = s:hira_mode

  let s:is_enable = v:true
endfunction

function t#disable() abort
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

function t#toggle() abort
  return t#is_enable() ? t#disable() : t#enable()
endfunction

function t#default_kana_table() abort
  return json_decode(join(readfile('./kana_table.json'), "\n"))
endfunction

function t#initialize(opts = {}) abort
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
function t#ins(key, henkan = v:false) abort
  " feedkeys直後はバッファに文字が反映されていないので
  " bs_countを使って文字を一部取り出すテクニックが必要
  let key = utils#trans_special_key(a:key)
  let [bs_count, spec] = s:get_insert_spec(key)

  if s:mode.name !=# 'zen_alnum' && s:mode.name !=# 'abbrev'
    call feedkeys(repeat("\<bs>", bs_count), 'n')
  endif

  if type(spec) == v:t_dict
    if has_key(spec, 'func')
      let feed = call($'func#{spec.func}', [key])
      call feedkeys(feed, 'n')
      if spec.func ==# 'kakutei' && s:mode.name ==# 'abbrev'
        let s:mode = s:hira_mode
      endif
      return
    elseif has_key(spec, 'mode')
      let conv_name = {
            \ 'zen_kata': 'converters#hira_to_kata',
            \ 'han_kata': 'converters#hira_to_han_kata',
            \ 'zen_alnum': 'converters#alnum_to_zen_alnum',
            \ 'abbrev': 's:hira_mode.conv',
            \ }[spec.mode]
      if states#in('machi')
        let machistr =  states#getstr('machi')[0 : -bs_count-1]
        let feed = repeat("\<bs>", strcharlen(machistr)) .. call(conv_name, [machistr])
        call feedkeys(feed, 'n')
        call states#off('machi')
        return
      endif
      let s:mode = s:mode.name ==# spec.mode ? s:hira_mode : {
            \ 'name': spec.mode,
            \ 'conv': funcref(conv_name)
            \ }
      echomsg $'{s:mode.name} mode'
      if s:mode.name ==# 'abbrev'
        call states#on('machi')
      endif
    endif
    return
  endif

  " type(spec) == v:t_string

  if pumvisible() && s:is_completed()
    call states#off('machi')
    " call states#off('choku')

    if s:mode.name ==# 'abbrev'
      let s:mode = s:hira_mode
    endif
  endif
  if spec == ''
    return
  endif
  if s:mode.name ==# 'zen_alnum' || s:mode.name ==# 'abbrev'
    call feedkeys(call(s:mode.conv, [key]), 'n')
    return
  endif
  if a:henkan
    " echomsg 'henkan' key
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
    " echomsg machistr okuristr states#getstr('machi')
    " この時点ではまだ「おくr」の状態で、specが入力されていない
    " 下のfeedkeysを実行することで上のも実行されるようだ
    call feedkeys($"\<c-r>=t#completefunc()\<cr>", 'n')
    call states#off('okuri')
  endif
endfunction

function s:get_insert_spec(key) abort
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

function t#completefunc()
  call states#on('kouho')

  let preceding_str = states#getstr('machi')
  let comp_list = copy(henkan_list#get())

  let list_len = len(comp_list)
  if empty(comp_list)
    call add(comp_list, {'word': preceding_str, 'abbr': 'none'})
  endif

  call complete(states#get('machi')[1], comp_list)

  echo $'{preceding_str}: {list_len}件'
  return list_len > 0 ? "\<c-n>" : ''
endfunction

let s:latest_auto_complete_str = ''
function s:auto_complete() abort
  let preceding_str = states#getstr('machi')->substitute('\a*$', '', '')

  let min_length = 3
  " let min_length = opts#get('min_auto_complete_length')
  let str_len = strcharlen(preceding_str)
  if str_len ==# ''
    return
  endif
  " if str_len < min_length
  "   return
  " endif

  " 3文字目までは完全一致で検索
  let exact_match = str_len <= min_length

  " 4文字目が異なった場合はhenkan_listを更新
  let need_update = strcharpart(preceding_str, min_length, 1) !=# strcharpart(s:latest_auto_complete_str, min_length, 1)

  let s:latest_auto_complete_str = preceding_str

  if exact_match || need_update
    call henkan_list#update_async(preceding_str, exact_match)
  else
    call t#autocompletefunc()
  endif
endfunction

function t#autocompletefunc()
  if mode() !=# 'i' || !states#in('machi') || states#in('okuri') || states#in('kouho')
    echomsg 'exit autocomplete'
    return
  endif
  let start_col = states#get('machi')[1]
  if start_col < 1
    return
  endif

  " yomiの前方一致で絞り込む
  let comp_list = copy(henkan_list#get(1))
        \ ->filter($"v:val.user_data.yomi =~# '^{s:latest_auto_complete_str}'")

  echomsg $'auto comp from {start_col} {s:latest_auto_complete_str}'
  echo $'{s:latest_auto_complete_str}: {len(comp_list)}件'
  if empty(comp_list)
    return
  endif
  call complete(start_col, comp_list)

  return
endfunction

" cnoremap <c-j> <cmd>call t#cmd_buf()<cr>
inoremap <c-j> <cmd>call t#toggle()<cr>
inoremap <c-k> <cmd>imap<cr>
inoremap <c-l> <cmd>call states#show()<cr>

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
      \ 'abbrev_ignore_case': v:true,
      \ })
if has('nvim')
  autocmd InsertEnter * ++once lua require('cmp').setup.buffer({ enabled = false })
endif


inoremap <c-f> <C-R>=ListMonths()<CR>

func ListMonths()
  " call complete(col('.'), ['January', 'February', 'March',
  call complete(1, ['January', 'February', 'March',
        \ 'April', 'May', 'June', 'July', 'August', 'September',
        \ 'October', 'November', 'December'])
  return ''
endfunc
