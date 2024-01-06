function p5loop#play(obj = {}) abort
  let obj = a:obj ?? self
  let obj.is_looping = 1
endfunction
function p5loop#pause(obj = {}) abort
  let obj = a:obj ?? self
  let obj.is_looping = 0
endfunction
function p5loop#toggle(obj = {}) abort
  let obj = a:obj ?? self
  let obj.is_looping = !obj.is_looping
endfunction

function s:timer_start(obj) abort
  let a:obj.timer_id = timer_start(a:obj.interval, {->s:draw_wrapper(a:obj)}, {'repeat': -1})
endfunction
function s:timer_stop(obj) abort
  if p5loop#is_running(a:obj)
    call timer_stop(a:obj.timer_id)
    unlet! a:obj.timer_id
  endif
endfunction

function p5loop#is_running(obj = {}) abort
  let obj = a:obj ?? self
  return has_key(obj, 'timer_id')
endfunction

function p5loop#stop(obj = {}) abort
  let obj = a:obj ?? self
  call p5loop#pause(obj)
  call s:timer_stop(obj)

  for [name, value] in items(obj.saveopts)
    if type(value) == v:t_string
      let value = string(value)
    endif
    execute $'let &{name} = {value}'
  endfor
  unlet! obj.saveopts

  if has_key(obj, 'after_stop')
    call call(obj.after_stop, [])
  endif
endfunction

function s:draw_wrapper(obj) abort
  if a:obj.is_looping
    let a:obj.framecount += 1
    call call(a:obj.draw, [])
  endif
  try

    if has_key(a:obj, 'keypressed')
      let c = getchar(0)
      if c != 0
        call a:obj.keypressed(nr2char(c))
      endif
    endif
  catch
    call call(a:obj.stop, [])
    if has_key(a:obj, 'catch')
      call call(a:obj.catch, [v:throwpoint, v:exception])
    else
      echoerr v:throwpoint v:exception
    endif
  endtry
endfunction

function p5loop#run(obj = {}) abort
  let obj = a:obj ?? self

  call s:timer_stop(obj)
  silent enew

  setlocal buftype=nowrite bufhidden=wipe noswapfile
  execute 'autocmd BufLeave <buffer> ++once '
        \ .. $'if p5loop#is_running(s:p5objs[{obj.id}])'
        \ .. $' | call p5loop#stop(s:p5objs[{obj.id}])'
        \ .. ' | endif'

  try
    call call(obj.setup, [])
    let obj.saveopts = {}
    for [name, value] in items(obj.setoptions)
      let obj.saveopts[name] = eval($'&{name}')
      if type(value) == v:t_string
        let value = string(value)
      endif
      execute $'let &{name} = {value}'
    endfor
  catch
    call call(a:obj.stop, [])
    if has_key(a:obj, 'catch')
      call call(a:obj.catch, [v:throwpoint, v:exception])
    else
      echoerr v:throwpoint v:exception
    endif
  endtry

  call p5loop#play(obj)
  call s:timer_start(obj)
endfunction

let s:id = 0
let s:p5objs = {}
function p5loop#new() abort
  let s:id += 1
  let p5obj = #{
        \ id: s:id,
        \ width: winwidth(0),
        \ height: winheight(0),
        \ interval: 100,
        \ is_looping: 0,
        \ framecount: 0,
        \ setoptions: {},
        \ }
  let p5obj.run = {->p5loop#run(p5obj)}
  let p5obj.is_running = {->p5loop#is_running(p5obj)}
  let p5obj.stop = {->p5loop#stop(p5obj)}
  let p5obj.play = {->p5loop#play(p5obj)}
  let p5obj.pause = {->p5loop#pause(p5obj)}
  let p5obj.toggle = {->p5loop#toggle(p5obj)}
  let s:p5objs[s:id] = p5obj
  return p5obj
endfunction

" " how to use
" let MyP5 = p5loop#new()
" function MyP5.setup() abort
"   let self.interval = 1000
"   let self.setoptions = #{
"         \ laststatus: 0
"         \ }
" endfunction
" function MyP5.draw() abort
"   echowindow self.framecount
"   if self.framecount >= 3
"     call self.stop()
"   endif
" endfunction
" function MyP5.after_stop() abort
"   echomsg 'final frame:' self.framecount
" endfunction
" function MyP5.catch(throwpoint, exception) abort
"   echomsg 'catch' a:throwpoint a:exception
" endfunction
" function MyP5.keypressed(key) abort
"   if a:key == "g"
"     echomsg 'g is pressed!'
"   endif
" endfunction
" call MyP5.run()
