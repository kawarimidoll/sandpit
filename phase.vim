let s:state = { 'machi': 0, 'okuri': 0, 'kouho': 0 }

function! phase#enable(target) abort
  if !has_key(s:state, a:target)
    echoerr 'invalid target'
  endif
  if a:target ==# 'machi'
    if phase#is_enabled('okuri') || phase#is_enabled('kouho')
      return
    elseif phase#is_enabled('machi')
      call phase#enable('okuri')
      return
    endif
  else
    " 'okuri' or  'kouho'
    if !phase#is_enabled('machi') || phase#is_enabled(a:target)
      return
    endif
  endif
  let s:state[a:target] = v:true

  let text = { 'machi': '▽', 'okuri': '*', 'kouho': '▼' }[a:target]

  let [lnum, col] = getpos('.')[1:2]
  if a:target ==# 'kouho'
    let [lnum, col] = phase#getpos('machi')
    call inline_mark#clear('machi')
  endif

  call inline_mark#put(lnum, col, {'name': a:target, 'text': text})
endfunction

function! phase#disable(target) abort
  if !has_key(s:state, a:target)
    echoerr 'invalid target'
  endif
  if !s:state[a:target]
    return
  endif

  if a:target ==# 'kouho' && phase#is_enabled('machi')
    let [lnum, col] = inline_mark#get('kouho')
    call inline_mark#put(lnum, col, {'name': 'machi', 'text': '▽'})
  endif
  let s:state[a:target] = v:false
  call inline_mark#clear(a:target)
  if a:target ==# 'machi'
    call phase#disable('okuri')
  endif
  if a:target ==# 'okuri'
    call phase#disable('kouho')
  endif
endfunction

function! phase#clear() abort
  " machiがoffになったらkouhoとokuriもoffなのでこれでよし
  call phase#disable('machi')
endfunction

function! phase#is_enabled(target) abort
  if !has_key(s:state, a:target)
    echoerr 'invalid target'
  endif
  return s:state[a:target]
endfunction

function! phase#is_disabled(target) abort
  return !phase#is_enabled(a:target)
endfunction

function! phase#getpos(target) abort
  return phase#is_enabled(a:target) ? inline_mark#get(a:target) : []
endfunction
