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

function! func#v_sticky(...) abort
  if phase#is_enabled('kouho')
    " kakutei & restart machi
    " 普通に待ち状態に入ろうとすると失敗したので
    " timer_startを使って一瞬待機する
    call func#v_kakutei('')
    call timer_start(1, {->call('phase#enable', ['machi'])})
  elseif phase#is_enabled('okuri')
  " nop
  elseif phase#is_enabled('machi')
    if pumvisible() && get(complete_info(), 'selected', -1) >= 0
      " kakutei & restart machi
      call func#v_kakutei('')
      call timer_start(1, {->call('phase#enable', ['machi'])})
    elseif store#get("machi") !=# ''
      call phase#enable('okuri')
    endif
  else
    call phase#enable('machi')
  endif
endfunction

function! func#v_henkan(fallback_key) abort
  if phase#is_enabled('kouho')
    call feedkeys("\<c-n>", 'n')
  elseif phase#is_enabled('okuri')
  " nop
  elseif phase#is_enabled('machi')
    " echomsg $'machi {store#get("machi")} okuri {store#get("okuri")}'
    call virt_poc#henkan_start()
  else
    call feedkeys(utils#trans_special_key(a:fallback_key), 'n')
  endif
endfunction

function! func#v_kakutei(fallback_key) abort
  if phase#is_enabled('kouho')
    call phase#disable('machi')
    call feedkeys("\<c-y>", 'n')
  elseif phase#is_enabled('okuri')
  " nop
  elseif phase#is_enabled('machi')
    call phase#disable('machi')
    if pumvisible()
      call feedkeys("\<c-y>", 'n')
    endif
  else
    call feedkeys(utils#trans_special_key(a:fallback_key), 'n')
    call store#clear('choku')
  endif
endfunction

function! func#v_backspace(...) abort
  if phase#is_enabled('kouho')
    call phase#disable('kouho')
  elseif phase#is_enabled('okuri')
    if utils#compare_pos(getpos('.')[1:2], phase#getpos('okuri')) == 0
      call phase#disable('okuri')
      return
    endif
  elseif phase#is_enabled('machi')
    if utils#compare_pos(getpos('.')[1:2], phase#getpos('machi')) == 0
      call phase#disable('machi')
      return
    endif
  endif

  if store#get('choku') ==# ''
    if phase#is_enabled('okuri')
      call store#pop('okuri')
    elseif phase#is_enabled('machi')
      call store#pop('machi')
    endif
    call feedkeys("\<bs>", 'n')
  else
    call store#pop('choku')
  endif
endfunction
