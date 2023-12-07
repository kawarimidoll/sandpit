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

let s:put_mis_char = 1
let s:kana_input_namespace = 'kana_input_namespace'

function! virt_poc#ins(key) abort
  let spec = get(s:kana_table, a:key, '')

  if type(spec) == v:t_dict
    echomsg spec
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
