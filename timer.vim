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

function Chord_def(mode, keys, wait, timer_name, func, args = []) abort
  let s:chord_specs[a:timer_name] = {'keys': a:keys, 'wait': a:wait, 'func': a:func, 'args': a:args}
  for k in a:keys
    let s:chord_keys[k] = get(s:chord_keys, k, []) + [a:timer_name]
    execute $'{a:mode}noremap {k} <cmd>call Chord_run("{k}")<cr>'
  endfor
endfunction

let s:delayed_feed = {}
function s:delayed_feed.exec(key) abort dict
  if self.stop(a:key)
    call feedkeys(a:key, 'ni')
  endif
endfunction
function s:delayed_feed.set(key) abort dict
  let key = a:key
    call self.exec(a:key)
  let self[a:key] = timer_start(g:chord_wait, {->self.exec(a:key)})
  " if self.stop(key)
  "   call feedkeys(key, 'ni')
  " endif
  " let s:delayed_feed[key] = timer_start(g:chord_wait, {->[
  "       \ feedkeys(key, 'ni'),
  "       \ execute($"unlet s:delayed_feed['{key}']", ''),
  "       \ ] })
endfunction
function s:delayed_feed.stop(key) abort dict
  if has_key(self, a:key)
    call timer_stop(self[a:key])
    unlet self[a:key]
    return v:true
  endif
  return v:false
endfunction

let s:feed_timers = {}
function Chord_run(key) abort
  let key = a:key
  let result = []
  for timer_name in s:chord_keys[key]
    let result += Chord(key, timer_name)
  endfor

  if empty(result)
    call s:delayed_feed.set(key)
  else
    for k in result
      call s:delayed_feed.stop(k)
    endfor
  endif
endfunction

call Chord_def('n', ['j', 'k', 'l'], 50, 'my_super', 'execute', ["echo 'my_super!'", ''])
call Chord_def('n', ['j', ';'], 50, 'my_awesome', 'execute', ["echo 'my_awesome!'", ''])
call Chord_def('i', ['j', 'k'], 50, 'esc_jk', 'feedkeys', ["\<esc>", 'ni'])

let s:chord_timers = {}
function Chord(key, timer_name) abort
  let key = a:key
  let timer_name = a:timer_name
  let spec = s:chord_specs[timer_name]

  if has_key(s:chord_timers, timer_name)
    if has_key(s:chord_timers[timer_name], key)
      call timer_stop(s:chord_timers[timer_name][key])
    else
      let current_keys = s:chord_timers[timer_name]->keys()->add(key)
      if s:listitemscmp(current_keys, spec.keys)
        for timer in s:chord_timers[timer_name]->values()
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

  let wait = spec.wait

  let s:chord_timers[timer_name][key] = timer_start(wait, {->
        \ execute($"unlet s:chord_timers['{timer_name}']['{key}']", '')
        \ })
  return []
endfunction

" nnoremap j <cmd>call Chord('j', 50, 'jkl')<cr>
" nnoremap k <cmd>call Chord('k', 50, 'jkl')<cr>
" nnoremap l <cmd>call Chord('l', 50, 'jkl')<cr>
