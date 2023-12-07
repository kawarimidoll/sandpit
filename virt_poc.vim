source ./inline_mark.vim
source ./utils.vim

function! virt_poc#sample() abort
  let s:kana_table = json_decode(join(readfile('./kana_table.json'), "\n"))

  let s:preceding_keys_dict = {}
  for key in keys(s:kana_table)
    let kx = utils#trans_special_key(key)
    if strcharlen(kx) > 1
      let s:preceding_keys_dict[slice(kx, 0, -1)] = 1
    endif
  endfor

  let sss = 'hiraganawoisppainyuuryoku'->split('\zs')
  let put_mis_char = 1
  let i_buf = ''
  let o_buf = ''
  for s1 in sss
    let i_buf ..= s1
    if has_key(s:kana_table, i_buf)
      let [kana, roma; _rest] = s:kana_table[i_buf]->split('\A*\zs') + ['']
      let o_buf ..= kana
      let i_buf = roma
    elseif !has_key(s:preceding_keys_dict, i_buf)
      if put_mis_char
        let o_buf ..= i_buf->substitute('.$', '', '')
      endif
      let i_buf = i_buf->substitute('^.*\(.\)', '\1', '')
    endif
  endfor
  echo o_buf
endfunction

function! virt_poc#enable() abort
  if s:is_enable
    return
  endif

  let s:keys_to_remaps = []
  for key in keys(s:map_keys_dict)
    let current_map = maparg(key, 'i', 0, 1)
    call add(s:keys_to_remaps, empty(current_map) ? key : current_map)
    let k = keytrans(key)
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
  let s:kana_table = json_decode(join(readfile('./kana_table.json'), "\n"))
  " echo s:kana_table

  let s:preceding_keys_dict = {}
  let s:map_keys_dict = {}
  for k in keys(s:kana_table)
    if k =~ '<bs>' || k =~ '<Space>'
      continue
    endif

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

let s:put_mis_char = 1
let s:kana_input_namespace = 'kana_input_namespace'

function! virt_poc#ins(key) abort
  let spec = get(s:kana_table, a:key->tolower(), '')
  if type(spec) == v:t_dict
    if has_key(spec, 'func')
      if spec.func ==# 'backspace'
        if s:i_buf ==# ''
          call feedkeys("\<bs>", 'n')
        else
          let s:i_buf = s:i_buf->substitute('.$', '', '')
        endif
      elseif spec.func ==# 'kakutei'
        let s:i_buf = ''
        call feedkeys("\<cr>", 'n')
      endif
    endif
    return
  endif

  let current = s:i_buf .. a:key

  let result = ''
  if has_key(s:kana_table, current)
    let [kana, roma; _rest] = s:kana_table[current]->split('\A*\zs') + ['']
    let result = kana
    let s:i_buf = roma
  elseif has_key(s:preceding_keys_dict, current)
    let s:i_buf = current
  else
    if s:put_mis_char
      let result = current->substitute('.$', '', '')
    endif
    let s:i_buf = current->substitute('^.*\(.\)', '\1', '')
  endif

  if result !=# ''
    call feedkeys(result, 'ni')
  endif
endfunction
function! virt_poc#show_i_buf() abort
  return s:i_buf
endfunction
function! virt_poc#after_ins() abort
  call inline_mark#clear(s:kana_input_namespace)

  if s:i_buf !=# ''
    call inline_mark#put(line('.'), col('.'), {
          \ 'name': s:kana_input_namespace,
          \ 'text': s:i_buf})
  endif
endfunction

inoremap <c-j> <cmd>call virt_poc#enable()<cr>
inoremap <c-k> <cmd>imap<cr>
inoremap <c-p> <cmd>echo inline_mark#get('kana_input_namespace')<cr>
inoremap <c-e> <cmd>echo virt_poc#show_i_buf()<cr>
