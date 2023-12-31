let s:store = { 'hanpa': '', 'choku': '', 'machi': '', 'okuri': '', 'kouho': '' }
let s:show_choku_namespace = 'show_choku_namespace'

function store#display_odd_char() abort
  if store#is_blank('choku')
    call inline_mark#clear(s:show_choku_namespace)
    return
  endif
  let [lnum, col] = getpos('.')[1:2]
  let syn_offset = (col > 1 && col == col('$')) ? 1 : 0
  let hlname = synID(lnum, col-syn_offset, 1)->synIDattr('name')
  call inline_mark#put(lnum, col, {
        \ 'name': s:show_choku_namespace,
        \ 'text': store#get('choku'),
        \ 'hl': hlname })
endfunction

function store#set(target, str) abort
  let s:store[a:target] = a:str
endfunction

function store#get(target) abort
  return s:store[a:target]
endfunction

function store#clear(target = '') abort
  if a:target !=# ''
    call store#set(a:target, '')
    return
  endif
  for t in keys(s:store)
    call store#set(t, '')
  endfor
endfunction

function store#push(target, str) abort
  call store#set(a:target, store#get(a:target) .. a:str)
endfunction

function store#pop(target) abort
  let char = store#get(a:target)->utils#lastchar()
  call store#set(a:target, store#get(a:target)->substitute('.$', '', ''))
  return char
endfunction

function store#unshift(target, str) abort
  call store#set(a:target, a:str .. store#get(a:target))
endfunction

function store#shift(target) abort
  let char = store#get(a:target)->utils#firstchar()
  call store#set(a:target, store#get(a:target)->substitute('^.', '', ''))
  return char
endfunction

function store#is_blank(target) abort
  return store#get(a:target) ==# ''
endfunction

function store#is_present(target) abort
  return !store#is_blank(a:target)
endfunction
