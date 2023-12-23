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

function s:listitemscmp(list1, list2) abort
  return a:list1->copy()->sort() == a:list2->copy()->sort()
endfunction

let g:chord_wait = 50

" タイマー名と設定の対応テーブル
let s:chord_specs = {}

" キーとタイマー名の対応テーブル
" このキーが押されたらどのタイマーを起動するのか？の紐付けに使う
let s:chord_keys = {}

function Chord_def(mode, keys, timer_name, func, args = []) abort
  let s:chord_specs[a:timer_name] = {'keys': a:keys, 'func': a:func, 'args': a:args}
  for k in a:keys
    let s:chord_keys[k] = get(s:chord_keys, k, []) + [a:timer_name]
    execute $'{a:mode}noremap {k} <cmd>call Chord_run("{k}")<cr>'
  endfor
endfunction

let s:delayed_feed = {}
function s:delayed_feed.eject(key) abort dict
  if self.stop(a:key)
    call feedkeys(a:key, 'ni')
  endif
endfunction
function s:delayed_feed.reserve(key) abort dict
  call self.eject(a:key)
  let self[a:key] = timer_start(g:chord_wait, {->self.eject(a:key)})
endfunction
function s:delayed_feed.stop(key) abort dict
  if has_key(self, a:key)
    call timer_stop(self[a:key])
    unlet self[a:key]
    return v:true
  endif
  return v:false
endfunction

function Chord_run(key) abort
  let stop_keys = []
  for timer_name in s:chord_keys[a:key]
    let stop_keys += Chord(a:key, timer_name)
  endfor

  if empty(stop_keys)
    call s:delayed_feed.reserve(a:key)
  else
    for k in stop_keys
      call s:delayed_feed.stop(k)
    endfor
  endif
endfunction

call Chord_def('n', ['j', 'k', 'l'], 'my_super', 'execute', ["echo 'my_super!'", ''])
call Chord_def('n', ['j', ';'], 'my_awesome', 'execute', ["echo 'my_awesome!'", ''])
call Chord_def('i', ['j', 'k'], 'esc_jk', 'feedkeys', ["\<esc>", 'ni'])

let s:chord_timers = {}
function Chord(key, timer_name) abort
  let key = a:key
  let timer_name = a:timer_name
  let spec = s:chord_specs[timer_name]

  if has_key(s:chord_timers, timer_name)
    let current_timers = s:chord_timers[timer_name]
    if has_key(current_timers, key)
      call timer_stop(current_timers[key])
    else
      let current_keys = current_timers->keys()->add(key)
      if s:listitemscmp(current_keys, spec.keys)
        for timer in current_timers->values()
          call timer_stop(timer)
        endfor
        unlet s:chord_timers[timer_name]
        call call(spec.func, spec.args)
        return current_keys
      endif
    endif
  else
    let s:chord_timers[timer_name] = {}
  endif

  let s:chord_timers[timer_name][key] = timer_start(g:chord_wait, {->
        \ execute($"unlet s:chord_timers['{timer_name}']['{key}']", '')
        \ })
  return []
endfunction

" nnoremap j <cmd>call Chord('j', 50, 'jkl')<cr>
" nnoremap k <cmd>call Chord('k', 50, 'jkl')<cr>
" nnoremap l <cmd>call Chord('l', 50, 'jkl')<cr>
