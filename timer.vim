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

let s:chord_timers = {}
function Chord(key, wait, timer_name) abort
  let key = a:key
  let timer_name = a:timer_name
  if has_key(s:chord_timers, timer_name)
    if has_key(s:chord_timers[timer_name], key)
      call timer_stop(s:chord_timers[timer_name][key])
      call feedkeys(key, 'ni')
    else
      let current_keys = s:chord_timers[timer_name]->keys()->join('') .. key
      if s:strcharscmp(current_keys, timer_name)
        for timer in s:chord_timers[timer_name]->values()
          call timer_stop(timer)
        endfor
        unlet s:chord_timers[timer_name]
        echo 'super!'
        return
      endif
    endif
  else
    let s:chord_timers[timer_name] = {}
  endif

  let s:chord_timers[timer_name][key] = timer_start(a:wait, {->[
        \ feedkeys(key, 'ni'),
        \ execute($"unlet s:chord_timers['{timer_name}']['{key}']", ''),
        \ ]})
  echo s:chord_timers
endfunction

nnoremap j <cmd>call Chord('j', 50, 'jkl')<cr>
nnoremap k <cmd>call Chord('k', 50, 'jkl')<cr>
nnoremap l <cmd>call Chord('l', 50, 'jkl')<cr>
