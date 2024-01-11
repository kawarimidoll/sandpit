function s:echoerr(...) abort
  echohl ErrorMsg
  for str in a:000
    echomsg '[rimiline]' str
  endfor
  echohl NONE
endfunction

if !executable('img2sixel')
  call s:echoerr('img2sixel (in libsixel) is required')
  finish
endif

let s:resources_dir = expand('<sfile>:h') .. '/resources'
let s:is_number = {item->type(item)==v:t_number}
let s:is_func = {item->type(item)==v:t_func}

" {{{ ring list
function s:make_ring_list(items) abort
  let obj = {'index': 0, 'items': a:items}
  let obj.tick = funcref('s:tick')
  let obj.current = funcref('s:current')
  let obj.push = funcref('s:push')
  return obj
endfunction
function s:tick() abort dict
  let self.index = (self.index >= len(self.items)-1) ? 0 : (self.index + 1)
endfunction
function s:current() abort dict
  return self.items[self.index]
endfunction
function s:push(item) abort dict
  call add(self.items, a:item)
endfunction
" }}}

let s:img_cache = {}
let s:MAIN_IMG_WIDTH = 3
let s:MAIN_IMG_BASE = 'kawarimi'
let s:TRAIL_IMG_BASE = 'rainbow'

let s:echoraw = has('nvim') ? {str->chansend(v:stderr, str)} : {str->echoraw(str)}

highlight link StatusLine NONE

function s:load_img(name, height) abort
  if has_key(s:img_cache, a:name)
    return
  endif
  let path = $'{s:resources_dir}/{a:name}.png'
  let sixel = system($"img2sixel -h {a:height}px {path}")
  if sixel =~ 'usage' || sixel =~ 'No such file or directory'
    call s:echoerr($"failed to load: {path}")
    return
  endif
  let s:img_cache[a:name] = sixel
endfunction

function s:display_sixel(sixel, lnum, cnum) abort
  let [sixel, lnum, cnum] = [a:sixel, a:lnum, a:cnum]
  let pos = has('nvim') ? $'{lnum+1};{cnum+2}' : $'{lnum};{cnum}'
  call s:echoraw($"\x1b[{pos}H" .. sixel)
endfunction

let s:loop_cnt = 0

function s:loop_img(paths, pos, height, wait, cnt = 0) abort
  let cnt = a:cnt + 1
  if cnt >= len(a:paths)-1
    let cnt = 0
  endif
  call timer_start(a:wait, {->[
        \ s:put_img(a:paths[cnt], a:pos, a:height),
        \ s:loop_img(a:paths, a:pos, a:height, a:wait, cnt),
        \ ]})
endfunction

function s:show_animation() abort
  call s:main_images.tick()
  call s:trail_images.tick()
  call s:show_img()
endfunction

let s:last_offset = []
function s:show_img() abort
  if mode() == 'c'
    return
  endif

  let lead = s:img_cache['space']
  let main = s:img_cache[s:main_images.current()]
  let trail = s:img_cache[s:trail_images.current()]

  let lnum = &lines-&cmdheight

  let left = s:is_number(s:left_offset) ? s:left_offset : call(s:left_offset, [])
  let right = s:is_number(s:right_offset) ? s:right_offset : call(s:right_offset, [])
  let length = &columns - left - right

  let offset = [left, right]
  if s:last_offset != offset
    if empty(s:last_offset)
      execute "normal! \<c-l>"
    endif
    let s:last_offset = offset
  endif

  " subtract image width from length so as not to jump out of the area
  let img_pos = (length - s:MAIN_IMG_WIDTH) * line('.') / line('$')

  " save cursor pos
  call s:echoraw("\x1b[s")

  " display sixels
  if img_pos > 0
    for i in range(0, img_pos - 1, 2)
      call s:display_sixel(trail, lnum, left + i)
    endfor
  endif
  for i in range(img_pos, length - 1)
    call s:display_sixel(lead, lnum, left + i)
  endfor
  call s:display_sixel(main, lnum, left + img_pos)

  " restore cursor pos
  call s:echoraw("\x1b[u")
endfunction

function rimiline#stop() abort
  silent! call timer_stop(s:timer_id)
  execute "normal! \<c-l>"
  let s:last_offset = []
  augroup rimiline_inner
    autocmd!
  augroup END
endfunction

let s:timer_id = 0

function rimiline#start(opts) abort
  call rimiline#stop()

  " required
  let size = a:opts.size
  let s:left_offset = a:opts.left_offset
  let s:right_offset = a:opts.right_offset

  if !s:is_number(size)
    call s:echoerr('invalid type: size should be number')
  elseif !s:is_number(s:left_offset) && !s:is_func(s:left_offset)
    call s:echoerr('invalid type: left_offset should be number or funcref')
  elseif !s:is_number(s:right_offset) && !s:is_func(s:right_offset)
    call s:echoerr('invalid type: right_offset should be number or funcref')
  endif

  let interval = get(a:opts, 'interval', 400)

  let animation = get(a:opts, 'animation', v:false)
  let wave = get(a:opts, 'wave', v:false)

  let img_names = ['space']

  let s:main_images = s:make_ring_list([])
  let s:trail_images = s:make_ring_list([])

  if animation
    for i in [1,2,3,4]
      call add(img_names, $'{s:MAIN_IMG_BASE}{i}')
      call s:main_images.push($'{s:MAIN_IMG_BASE}{i}')
      if wave
        call add(img_names, $'{s:TRAIL_IMG_BASE}{i}')
        call s:trail_images.push($'{s:TRAIL_IMG_BASE}{i}')
      endif
    endfor
    if !wave
      call add(img_names, $'{s:TRAIL_IMG_BASE}0')
      call s:trail_images.push($'{s:TRAIL_IMG_BASE}0')
    endif
  else
    call add(img_names, $'{s:MAIN_IMG_BASE}1')
    call s:main_images.push($'{s:MAIN_IMG_BASE}1')

    call add(img_names, $'{s:TRAIL_IMG_BASE}{wave ? 1 : 0}')
    call s:trail_images.push($'{s:TRAIL_IMG_BASE}{wave ? 1 : 0}')
  endif

  for name in img_names
    call s:load_img(name, size)
  endfor

  augroup rimiline_inner
    autocmd VimResized * call s:show_img()
  augroup END

  let s:timer_id = timer_start(interval,
        \ animation ? {->s:show_animation()} : {->s:show_img()},
        \ {'repeat': -1})
endfunction

func rimiline#debug()
  echo s:main_images.items s:trail_images.items
endfunction

call rimiline#start({
      \ 'size': 22,
      \ 'left_offset': {->strcharlen(bufname()) + 20},
      \ 'right_offset': 21,
      \ 'animation': v:true,
      \ 'wave': v:true,
      \ })
