let s:store = { 'choku': '', 'machi': '', 'okuri': '' }

function! store#set(target, str) abort
  let s:store[a:target] = a:str
endfunction

function! store#get(target) abort
  return s:store[a:target]
endfunction

function! store#clear(target = '') abort
  if a:target ==# ''
    let s:store = { 'choku': '', 'machi': '', 'okuri': '' }
  else
    let s:store[a:target] = ''
  endif
endfunction
