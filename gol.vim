execute 'source' expand('<script>:p:h') .. '/p5loop.vim'

let s:seed = srand()

highlight GolZero ctermfg=Black ctermbg=Black guibg=#101010 guifg=#101010
highlight GolOne ctermfg=White ctermbg=White guibg=#f0f0f0 guifg=#f0f0f0

let s:p5 = p5loop#new()

function gol#generation() abort
  return s:p5.framecount
endfunction

function s:toggle() abort
  call s:p5.toggle()
endfunction

function s:p5.setup() abort
  nnoremap <buffer><nowait> <space> <cmd>call <sid>toggle()<cr>
  nnoremap <buffer><nowait> <cr> <cmd>call <sid>flip()<cr>

  let self.setoptions = #{
        \ laststatus: 0,
        \ ruler: 1,
        \ rulerformat: 'gen:%{gol#generation()}',
        \ }

  let s:cells = []
  for i in range(self.height)
    call add(s:cells, [])
    for j in range(self.width)
      call add(s:cells[i], {'current': rand(s:seed) % 2})
    endfor
  endfor

  let s:winid = win_getid()
  let s:match_ids = [matchadd('GolZero', '0'),  matchadd('GolOne', '1')]

  echo '<space> to pause_or_start, <cr> to flip'
endfunction

function s:p5.draw() abort
  for i in range(self.height)
    let iprev = i - 1
    let inext = i == self.height-1 ? 0 : i + 1
    for j in range(self.width)
      let jprev = j - 1
      let jnext = j == self.width-1 ? 0 : j + 1

      let living_neighbors =
            \   s:cells[iprev][jprev].current
            \ + s:cells[iprev][  j  ].current
            \ + s:cells[iprev][jnext].current
            \ + s:cells[  i  ][jprev].current
            \ + s:cells[  i  ][jnext].current
            \ + s:cells[inext][jprev].current
            \ + s:cells[inext][  j  ].current
            \ + s:cells[inext][jnext].current

      " rule:
      "   current=dead, neighbors=3 -> live (reproduction)
      "   current=live, neighbors<2 -> dead (underpopulation)
      "   current=live, neighbors>3 -> dead (overpopulation)
      "   current=live, neighbors=2,3 -> live (continue)
      " in short:
      "   if neighbors = 3, always live
      "   if neighbors = 2, continue current
      "   otherwise dead
      let s:cells[i][j].next = living_neighbors == 3
            \ || (living_neighbors == 2 && s:cells[i][j].current)
    endfor
  endfor

  for i in range(self.height)
    let current_line = ''
    for j in range(self.width)
      let s:cells[i][j].current = s:cells[i][j].next
      let current_line ..= s:cells[i][j].current
    endfor
    call setline(i+1, current_line)
  endfor
endfunction

function s:p5.after_stop() abort
  if !exists('s:winid')
    return
  endif
  call matchdelete(s:match_ids[0], s:winid)
  call matchdelete(s:match_ids[1], s:winid)
  unlet s:winid
endfunction

call s:p5.run()

function s:flip() abort
  let [l,c] = getpos('.')[1:2]->map('v:val-1')
  let s:cells[l][c].current = !s:cells[l][c].current
  if !s:p5.is_looping
    call setline(l+1, s:cells[l]->copy()->map('v:val.current')->join(''))
  endif
endfunction
