" run last one call in wait time
let s:debounce_timers = {}
function! Debounce(fn, wait, args = [], timer_name = '') abort
  let timer_name = a:timer_name !=# '' ? a:timer_name
        \ : type(a:fn) == v:t_string ? a:fn
        \ : string(a:fn)
  call get(s:debounce_timers, timer_name, 0)->timer_stop()
  let args = a:args
  let s:debounce_timers[timer_name] = timer_start(a:wait, {-> call(a:fn, args) })
endfunction

" run first one call in wait time
let s:throttle_timers = {}
function! Throttle(fn, wait, args = [], timer_name = '') abort
  let timer_name = a:timer_name !=# '' ? a:timer_name
        \ : type(a:fn) == v:t_string ? a:fn
        \ : string(a:fn)
  if get(s:throttle_timers, timer_name, 0)
    return
  endif
  call call(a:fn, a:args)
  let s:throttle_timers[timer_name] = timer_start(a:wait, {->
        \ execute($"unlet s:throttle_timers['{timer_name}']", '')
        \ })
  " \ execute('unlet! s:throttle_timers[timer_name]', 'silent!')
endfunction

function! Echoline(...) abort
  echo line('.')
endfunction

" nnoremap j j<cmd>call Echoline()<cr>
" nnoremap k k<cmd>call Echoline()<cr>

" nnoremap j j<cmd>call Debounce('Echoline', 1000)<cr>
" nnoremap k k<cmd>call Debounce('Echoline', 1000)<cr>

" nnoremap j j<cmd>call Throttle('Echoline', 1000)<cr>
" nnoremap k k<cmd>call Throttle('Echoline', 1000)<cr>

" nnoremap j j<cmd>call Throttle({->Echoline()}, 1000)<cr>
" nnoremap k k<cmd>call Throttle({->Echoline()}, 1000)<cr>
" nnoremap j j<cmd>call Throttle({->Echoline()}, 1000, [], 'el')<cr>
" nnoremap k k<cmd>call Throttle({->Echoline()}, 1000, [], 'el')<cr>

function s:strcharscmp(str1, str2) abort
  return a:str1->split('\zs')->sort()
        \ == a:str2->split('\zs')->sort()
endfunction

" echo s:strcharscmp('str', 'st')
" echo s:strcharscmp('str', 'stu')
" echo s:strcharscmp('str', 'str')

" run last one call in wait time
let s:chord_keys = {}
let s:chord_timers = {}
function! Chord(key, wait, timer_name) abort
  let key = a:key
  let timer_name = a:timer_name
  if has_key(s:chord_keys, timer_name)
    if stridx(s:chord_keys[timer_name], key) < 0
      let s:chord_keys[timer_name] ..= key
      if s:strcharscmp(s:chord_keys[timer_name], timer_name)
        call timer_stop(s:chord_timers[timer_name])
        unlet s:chord_keys[timer_name]
        unlet s:chord_timers[timer_name]
        echo 'super!'
        return
      endif
    else
      call timer_stop(s:chord_timers[timer_name])
      call feedkeys(key, 'ni')
    endif
  else
    let s:chord_keys[timer_name] = key
  endif

  let s:chord_timers[timer_name] = timer_start(a:wait, {->[
        \ feedkeys(key, 'ni'),
        \ execute($"unlet s:chord_keys['{timer_name}']", ''),
        \ execute($"unlet s:chord_timers['{timer_name}']", ''),
        \ ]})
  echo s:chord_timers s:chord_keys
endfunction

nnoremap j <cmd>call Chord('j', 500, 'jk')<cr>
nnoremap k <cmd>call Chord('k', 500, 'jk')<cr>
