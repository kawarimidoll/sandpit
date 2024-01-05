function s:p5_stop() abort dict
  if has_key(self, 'timer_id')
    call timer_stop(self.timer_id)
    unlet! self.timer_id
  endif
endfunction

function s:draw_wrapper(obj) abort
  call call(a:obj.draw, [])
endfunction

function s:p5_run() abort dict
  call call(self.setup, [])
  let self.timer_id = timer_start(self.interval, {->call(self.draw, [])}, {'repeat': -1})
endfunction

function p5loop#new() abort
  let p5obj = #{
        \ width: winwidth(0),
        \ height: winheight(0),
        \ interval: 100,
        \ run: function('s:p5_run'),
        \ stop: function('s:p5_stop'),
        \ }
  return p5obj
endfunction

" " how to use
" let MyP5 = p5loop#new()
" function MyP5.setup() abort
"   let self.interval = 1000
" endfunction
" let s:cnt = 0
" function MyP5.draw() abort
"   echowindow s:cnt
"   let s:cnt += 1
"   if s:cnt > 5
"     call self.stop()
"   endif
" endfunction
" call MyP5.run()
