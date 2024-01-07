execute 'source' expand('<script>:p:h') .. '/p5loop.vim'

let s:seed = srand()
" return random number from min to max-1
function s:rand(m1, m2 = 1) abort
  if a:m1 < 0 || a:m2 < 1
    throw 'args must be positive'
  endif
  let [min, max] = a:m2 == 1 ? [a:m2, a:m1] : [a:m1, a:m2]
  return (rand(s:seed) % (max - min)) + min
endfunction

let s:p5 = p5loop#new()

function snake#score() abort
  return s:p5.framecount
endfunction

function s:under_cursor() abort
  let save_reg = getreginfo('z')
  normal! "zyl
  let c = @z
  call setreg('z', save_reg)
  return c
endfunction

function s:draw_wall() abort
  let sidewall = repeat(' ', s:top_x-2) .. '❎' .. repeat('⬜', s:width-2) .. '❎'
  let topwall = substitute(sidewall, '⬜', '❎', 'g')
  let lines = repeat([""], s:top_y) + [topwall]
        \ + repeat([sidewall], s:height-2) + [topwall]
  call setline(1, lines)
endfunction

function s:setcharpos(pos) abort
  call setcharpos('.', [0, s:top_y + a:pos[1], s:top_x - 2 + a:pos[0], 0])
endfunction

let s:body_pos_list = []

" let s:head_parts = ['⬆ ', '➡ ', '⬇ ', '⬅ ']
" let s:body_parts = '🟥🟧🟨🟩🟦🟪'->split('\zs')
" function s:draw_snake() abort
"   let i = 0
"   for pos in s:body_pos_list
"   endfor
" endfunction

function s:put_food() abort
  while 1
    let s:food_pos = [s:rand(2, s:width-1), s:rand(2, s:height-1)]
    if indexof(s:body_pos_list, {_, v-> v == s:food_pos}) < 0
      return
    endif
  endwhile
endfunction

let s:direction = 'l'
function s:setdir(dir) abort
  let dd = s:direction .. a:dir
  if s:direction == a:dir
        \ || (dd =~ 'h' && dd =~ 'l')
        \ || (dd =~ 'j' && dd =~ 'k')
    return
  endif
  let s:direction = a:dir
endfunction

function s:p5.setup() abort
  let self.interval = 300
  let s:width = min([self.width, 10])
  let s:height = min([self.height, 10])
  let s:top_x = (self.width - s:width) / 2
  let s:top_y = (self.height - s:height) / 2
  let s:body_pos_list = [[s:width / 3, s:height / 2], [s:width / 3 - 1, s:height / 2]]
  let s:head_idx = 0
  let s:tail_idx = 1
  let s:food_pos = [2 * s:width / 3, s:height / 2]

  nnoremap <buffer><nowait> h <cmd>call <sid>setdir('h')<cr>
  nnoremap <buffer><nowait> j <cmd>call <sid>setdir('j')<cr>
  nnoremap <buffer><nowait> k <cmd>call <sid>setdir('k')<cr>
  nnoremap <buffer><nowait> l <cmd>call <sid>setdir('l')<cr>
  nnoremap <buffer><nowait> i <nop>
  nnoremap <buffer><nowait> a <nop>
  nnoremap <buffer><nowait> o <nop>
  nnoremap <buffer><nowait> O <nop>
  call s:draw_wall()

  call s:setcharpos(s:food_pos)
  normal! r🍎

  call s:setcharpos(s:body_pos_list[s:tail_idx])
  normal! r🟩
  call s:setcharpos(s:body_pos_list[s:head_idx])
  normal! r🟩
endfunction

function s:p5.draw() abort

  " if s:body_pos_list[s:head_idx] == s:food_pos
  "   call add(s:body_pos_list, s:body_pos_list[s:head_idx]->copy())
  "   echomsg s:body_pos_list s:head_idx s:tail_idx
  "   call s:put_food()
  "   call s:setcharpos(s:food_pos)
  "   normal! r🍎
  "   call self.stop()
  " else
  " call s:setcharpos(s:body_pos_list[s:tail_idx])
  " normal! r⬜
  " endif

  let old_tail_idx = s:tail_idx
  let old_tail_pos = s:body_pos_list[s:tail_idx]->copy()
  let s:body_pos_list[s:tail_idx] = s:body_pos_list[s:head_idx]->copy()
  let s:head_idx = s:tail_idx
  let s:tail_idx += 1
  if s:tail_idx > len(s:body_pos_list)-1
    let s:tail_idx = 0
  endif

  if s:direction == 'h'
    let s:body_pos_list[s:head_idx][0] -= 1
  elseif s:direction == 'j'
    let s:body_pos_list[s:head_idx][1] += 1
  elseif s:direction == 'k'
    let s:body_pos_list[s:head_idx][1] -= 1
  elseif s:direction == 'l'
    let s:body_pos_list[s:head_idx][0] += 1
  endif

  if s:body_pos_list[s:head_idx] == s:food_pos
    call add(s:body_pos_list, old_tail_pos)
    let s:tail_idx = len(s:body_pos_list)-1
    call s:put_food()
    call s:setcharpos(s:food_pos)
    normal! r🍎
  else
    call s:setcharpos(old_tail_pos)
    normal! r⬜
  endif
  " echomsg s:body_pos_list s:head_idx s:tail_idx

  call s:setcharpos(s:body_pos_list[s:head_idx])
  if index(['⬜', '🍎'], s:under_cursor()) >= 0
    normal! r🟩
  else
    normal! r❌
    call self.stop()
  endif

  " if self.framecount > 30
  "   call self.stop()
  " endif
endfunction

function s:run()
  call s:p5.run()
endfunction
nnoremap # <cmd>call <sid>run()<cr>
