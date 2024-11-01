" let sixel = systemlist('img2sixel -h 60px /Users/kawarimidoll/Downloads/lying.jpeg')[0]
" call echoraw("\x1b[8;8H" .. sixel)
" let sixel = system('img2sixel -h 18px /Users/kawarimidoll/Downloads/nyan.png')
let s:img_cache = {}


function s:put_img(path, pos, height) abort
  let height = a:height
  " let height = a:height->substitute('px$', '', '')
  let sixel = ''
  if has_key(s:img_cache, a:path)
    let sixel = s:img_cache[a:path]
  else
    let sixel = system($"img2sixel -h {height}px {a:path}")
    if sixel =~ 'usage'
      echomsg 'error'
      return
    endif
    let s:img_cache[a:path] = sixel
  endif
  let [x, y] = a:pos
  if has('nvim')
    call chansend(v:stderr, $"\x1b[{x+1};{y+2}H" .. sixel)
  else
    call echoraw($"\x1b[{x};{y}H" .. sixel)
  endif
endfunction

function s:clear_img() abort
  execute "normal! \<c-l>"
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
" function s:loop_img(paths, pos, height, wait) abort
"   call s:loop_inner(a:paths, a:pos, a:height, a:wait, 0)
" endfunction

" call s:put_img('/Users/kawarimidoll/Downloads/nyan.png', [20, 5], 100)

" let imgs = [
"       \ '/Users/kawarimidoll/Downloads/kawarimi1.png',
"       \ '/Users/kawarimidoll/Downloads/kawarimi2.png',
"       \ '/Users/kawarimidoll/Downloads/kawarimi3.png',
"       \ '/Users/kawarimidoll/Downloads/kawarimi4.png',
"       \ ]
let imgs = [
      \ '/Users/kawarimidoll/Downloads/kawarimi_r1.png',
      \ '/Users/kawarimidoll/Downloads/kawarimi_r2.png',
      \ '/Users/kawarimidoll/Downloads/kawarimi_r3.png',
      \ '/Users/kawarimidoll/Downloads/kawarimi_r4.png',
      \ ]

call s:loop_img(imgs, [20, 5], 18, 200)


