execute 'source' expand('<script>:p:h') .. '/p5loop.vim'

" highlight SnakeBody ctermfg=Green ctermbg=Green guibg=#00a440 guifg=#00a440
" highlight SnakeWall ctermfg=DarkRed ctermbg=DarkRed guibg=#a43f00 guifg=#a43f00
" 🍎
" 🟥🟧🟨🟩🟦🟪◀▲▼▶ ❎❌
" ⬜
" ═║╔╗╚╝

let s:seed = srand()
" return random number from 0 to max-1
function s:rand(max) abort
  return rand(s:seed) % a:max
endfunction

let s:p5 = p5loop#new()

function snake#score() abort
  return s:p5.framecount
endfunction

function s:draw_wall() abort
  let sidewall = repeat(' ', s:top_x-2) .. '❎' .. repeat('⬜', s:width-2) .. '❎'
  let topwall = substitute(sidewall, '⬜', '❎', 'g')
  let lines = repeat([""], s:top_y) + [topwall]
        \ + repeat([sidewall], s:height-2) + [topwall]
  call setline(1, lines)
endfunction

let s:body_pos_list = []
let s:head_parts = ['⬆ ', '➡ ', '⬇ ', '⬅ ']
let s:body_parts = '🟥🟧🟨🟩🟦🟪'->split('\zs')
" let s:body_parts = '🟥🟧🟨🟩🟦🟪🟫'->split('\zs')
function s:draw_snake() abort
  let i = 0
  for pos in s:body_pos_list
  endfor
endfunction

let direction = 'l'

function s:draw_food() abort
  let s:food_pos = [s:rand(s:width), s:rand(s:height)]
  call setline(s:top_y+s:height, topwall)
endfunction

function s:p5.setup() abort
  let s:width = min([self.width, 10])
  let s:height = min([self.height, 10])
  let s:top_x = (self.width - s:width) / 2
  let s:top_y = (self.height - s:height) / 2
endfunction

function s:p5.draw() abort
call s:draw_wall()
  call self.stop()
endfunction

function s:p5.after_stop() abort
endfunction

call s:p5.run()
