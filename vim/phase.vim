let s:state = { 'machi': 0, 'okuri': 0, 'kouho': 0 }

function phase#enable(target) abort
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

  let opt_states = opts#get('phase_dict')[a:target]
  let text = opt_states.marker
  let hl = opt_states.hl

  let [lnum, col] = getpos('.')[1:2]
  if a:target ==# 'kouho'
    let [lnum, col] = phase#getpos('machi')
    call inline_mark#clear('machi')
  endif

  call inline_mark#put(lnum, col, {'name': a:target, 'text': text, 'hl': hl})
endfunction

function phase#move(target, pos) abort
  if !has_key(s:state, a:target)
    echoerr 'invalid target'
  endif
  let [lnum, col] = a:pos
  let text = { 'machi': '▽', 'okuri': '*', 'kouho': '▼' }[a:target]
  call inline_mark#put(lnum, col, {'name': a:target, 'text': text})
endfunction

function phase#disable(target) abort
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

function phase#clear() abort
  " machiがoffになったらkouhoとokuriもoffなのでこれでよし
  call phase#disable('machi')
endfunction

function phase#is_enabled(target) abort
  if !has_key(s:state, a:target)
    echoerr 'invalid target'
  endif
  return s:state[a:target]
endfunction

function phase#is_disabled(target) abort
  return !phase#is_enabled(a:target)
endfunction

function phase#getpos(target) abort
  return phase#is_enabled(a:target) ? inline_mark#get(a:target) : []
endfunction

" v2 ----

let s:phase = { 'current': '', 'previous': '', 'reason': '' }
" function phase#full_get() abort
"   return s:phase
" endfunction
" function phase#get() abort
"   return s:phase.current
" endfunction
function phase#is(name) abort
  return s:phase.current ==# a:name
endfunction
function phase#was(name) abort
  return s:phase.previous ==# a:name
endfunction
function phase#set(name, reason = '') abort
  let s:phase.previous = s:phase.current
  let s:phase.current = a:name
  let s:phase.reason = a:reason
endfunction
function phase#forget() abort
  let s:phase.previous = ''
  let s:phase.reason = ''
endfunction
