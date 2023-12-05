function! func#sticky(...) abort
  if states#getstr('choku') =~ '\a$'
    return ''
  endif
  call states#on('machi')
  return ''
endfunction

function! func#henkan(fallback_key) abort
  call states#off('choku')
  echomsg $'henkan {states#in("kouho")}'
  if states#in('kouho')
    return "\<c-n>"
  endif

  if !states#in('machi')
    return a:fallback_key
  endif

  let preceding_str = states#getstr('machi')

  call henkan_list#update_manual(preceding_str)

  return "\<c-r>=t#completefunc()\<cr>"
endfunction

function! func#kakutei(fallback_key) abort
  call states#off('choku')
  if !states#in('machi')
    return a:fallback_key
  endif

  call states#off('machi')
  return pumvisible() ? "\<c-y>" : ''
endfunction

function! func#backspace(...) abort
  let pos = getpos('.')[1:2]
  let canceled = v:false
  for target in ['machi', 'okuri', 'kouho']
    if states#in(target) && utils#compare_pos(states#get(target), pos) == 0
      call states#off(target)
      let canceled = v:true
    endif
  endfor
  return canceled ? '' : "\<bs>"
endfunction
