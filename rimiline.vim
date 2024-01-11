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

let s:img_cache = {}
let s:img_width = 3

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
  let s:image_num += 1
  if s:image_num > 4
    let s:image_num = 1
  endif
  call s:show_img()
endfunction

function s:cursor_percent() abort
  return 100 * line('.') / line('$')
endfunction

let s:last_offset = []
function s:show_img() abort
  let lead = s:img_cache['space']
  let main = s:img_cache[$'{s:image_base}{s:image_num}']
  let trail = s:img_cache[s:trail]
  let lnum = &lines-&cmdheight

  let left = s:is_number(s:left_offset) ? s:left_offset : call(s:left_offset, [])
  let right = s:is_number(s:right_offset) ? s:right_offset : call(s:right_offset, [])
  let length = &columns - left - right

  let offset = [left, right]
  if s:last_offset != offset
    let s:last_offset = offset
    execute "normal! \<c-l>"
  endif

  " subtract image width from length so as not to jump out of the area
  let img_pos = (length - s:img_width) * line('.') / line('$')

  " save cursor pos
  call s:echoraw("\x1b[s")

  " display sixels
  if img_pos > 0
    let cnt = s:image_num
    " for i in range(img_pos - 1)
    "   call s:display_sixel(trail, lnum, left + i)
    " endfor
    let i = 0
    " TODO: use flag
    while i < img_pos
      call s:display_sixel(s:img_cache[$'rainbow_w{cnt}'], lnum, left + i)
      if cnt > 4
        let cnt = 1
      endif
      let i += 2
    endwhile
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

  let interval = get(a:opts, 'interval', 0)
  let use_animation = interval > 0

  " 'straight', 'wave', ''
  let rainbow = get(a:opts, 'rainbow', '')

  let img_names = ['space']
  let s:trail = rainbow == 'straight' ? 'rainbow'
        \ : rainbow == 'wave' ? 'rainbow_w1'
        \ : 'space'
  call add(img_names, s:trail)

  let s:image_base = rainbow == '' ? 'kawarimi' : 'kawarimi_r'
  let s:image_num = 1
  let numbers = use_animation ? [1,2,3,4] : [1]
  for i in numbers
    call add(img_names, $'{s:image_base}{i}')
  endfor

  for name in img_names
    call s:load_img(name, size)
  endfor

  " TODO: use flag
  call s:load_img('rainbow_w2', size)
  call s:load_img('rainbow_w3', size)
  call s:load_img('rainbow_w4', size)

  augroup rimiline_inner
    autocmd VimResized * call s:show_img()
  augroup END

  if use_animation
    let s:timer_id = timer_start(interval, {->s:show_animation()}, {'repeat': -1})
  else
    call s:show_img()
  endif
endfunction

call rimiline#start({
      \ 'size': 22,
      \ 'left_offset': {->strcharlen(bufname()) + 20},
      \ 'right_offset': 20,
      \ 'rainbow': 'wave',
      \ 'interval': 250
      \ })
