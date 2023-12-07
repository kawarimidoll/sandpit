source ./inline_mark.vim
source ./utils.vim


function! virt_poc#enable() abort
  if s:is_enable
    return
  endif

  let s:keys_to_remaps = []
  for key in keys(s:map_keys_dict)
    let current_map = maparg(key, 'i', 0, 1)
    let k = keytrans(key)
    call add(s:keys_to_remaps, empty(current_map) ? k : current_map)
    execute $"inoremap {k} <cmd>call virt_poc#ins('{keytrans(k)}')<cr><cmd>call virt_poc#after_ins()<cr>"
  endfor

  augroup virt_poc#augroup
    autocmd!
    autocmd InsertLeave * call virt_poc#disable()
  augroup END

  let s:i_buf = ''
  let s:is_enable = v:true
endfunction

function! virt_poc#disable() abort
  if !s:is_enable
    return
  endif
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

  let s:i_buf = ''
  call inline_mark#clear()
  let s:is_enable = v:false
endfunction

function! virt_poc#toggle() abort
  return s:is_enable ? virt_poc#disable() : virt_poc#enable()
endfunction

function! virt_poc#init() abort
  let raw_kana_table = json_decode(join(readfile('./kana_table.json'), "\n"))

  let s:preceding_keys_dict = {}
  let s:map_keys_dict = {}
  let s:kana_table = {}
  for [k, val] in items(raw_kana_table)
    let key = utils#trans_special_key(k)->keytrans()
    let s:kana_table[key] = val

    let chars = utils#trans_special_key(k)->utils#strsplit()

    if len(chars) > 1
      let s:preceding_keys_dict[slice(chars, 0, -1)->join('')] = 1
    endif
    for char in chars
      let s:map_keys_dict[char] = 1
    endfor
  endfor
  " echo s:preceding_keys_dict
  let s:is_enable = v:false
endfunction

let s:kana_input_namespace = 'kana_input_namespace'

function! virt_poc#ins(key) abort
  let spec = s:get_spec(a:key)

  if type(spec) == v:t_string
    if spec !=# ''
      call feedkeys(spec, 'ni')
    endif
    return
  endif

  echomsg spec
  if has_key(spec, 'func')
    if spec.func ==# 'backspace'
      if s:i_buf ==# ''
        call feedkeys("\<bs>", 'n')
      else
        let s:i_buf = s:i_buf->substitute('.$', '', '')
      endif
    elseif spec.func ==# 'kakutei'
      call feedkeys("\<cr>", 'n')
      let s:i_buf = ''
    endif
  endif
endfunction

function! s:get_spec(key) abort
  let current = s:i_buf .. a:key

  if has_key(s:kana_table, current)
    " s:i_bufの残存文字と合わせて完成した場合
    if type(s:kana_table[current]) == v:t_dict
      return s:kana_table[current]
    endif
    let [kana, roma; _rest] = s:kana_table[current]->split('\A*\zs') + ['']
    let s:i_buf = roma
    return kana
  elseif has_key(s:preceding_keys_dict, current)
    " 完成はしていないが、先行入力の可能性がある場合
    let s:i_buf = current
    return ''
  endif

  let spec = get(s:kana_table, a:key, '')

  " 半端な文字はバッファに載せる
  " ただしdel_mis_charがtrueなら消す
  if !s:del_mis_char || type(spec) == v:t_dict
    call feedkeys(s:i_buf, 'ni')
  endif
  if type(spec) == v:t_string
    let s:i_buf = a:key
  else
    let s:i_buf = ''
  endif

  return spec
endfunction

let s:del_mis_char = 1

function! virt_poc#after_ins() abort
  call inline_mark#clear(s:kana_input_namespace)

  if s:i_buf !=# ''
    call inline_mark#put(line('.'), col('.'), {
          \ 'name': s:kana_input_namespace,
          \ 'text': s:i_buf})
  endif
endfunction

inoremap <c-j> <cmd>call virt_poc#toggle()<cr>
inoremap <c-k> <cmd>imap<cr>
inoremap <c-p> <cmd>echo inline_mark#get('kana_input_namespace')<cr>

call virt_poc#init()
