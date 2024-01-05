let s:seed = srand()

highlight GolZero ctermfg=Black ctermbg=Black guibg=#101010 guifg=#101010
highlight GolOne ctermfg=White ctermbg=White guibg=#f0f0f0 guifg=#f0f0f0

function s:update() abort
  for i in range(s:HEIGHT)
    let iprev = i - 1
    let inext = i == s:HEIGHT-1 ? 0 : i + 1
    for j in range(s:WIDTH)
      let jprev = j - 1
      let jnext = j == s:WIDTH-1 ? 0 : j + 1

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

  for i in range(s:HEIGHT)
    let current_line = ''
    for j in range(s:WIDTH)
      let s:cells[i][j].current = s:cells[i][j].next
      let current_line ..= s:cells[i][j].current
    endfor
    call setline(i+1, current_line)
  endfor
endfunction

function s:update_wrapper(...) abort
  try
    let s:generation += 1
    call s:update()
  catch
    echomsg v:throwpoint v:exception
    call gol#stop()
  endtry
endfunction

function gol#generation() abort
  return s:generation
endfunction

function gol#stop() abort
  if exists('s:timer_id')
    call timer_stop(s:timer_id)
    unlet s:timer_id
  endif
  if !exists('s:winid')
    return
  endif
  call matchdelete(s:match_ids[0], s:winid)
  call matchdelete(s:match_ids[1], s:winid)
  unlet s:winid
  let &laststatus = s:laststatus
  let &ruler = s:ruler
  let &rulerformat = s:rulerformat
endfunction

function s:flip() abort
  let [l,c] = getpos('.')[1:2]->map('v:val-1')
  let s:cells[l][c].current = !s:cells[l][c].current
  if !exists('s:timer_id')
    call setline(l+1, s:cells[l]->copy()->map('v:val.current')->join(''))
  endif
endfunction

function s:pause_or_start() abort
  if exists('s:timer_id')
    call timer_stop(s:timer_id)
    unlet s:timer_id
  else
    let s:timer_id = timer_start(30, 's:update_wrapper', {'repeat': -1})
  endif
endfunction

function gol#start() abort
  call gol#stop()

  silent only!
  enew

  setlocal buftype=nowrite bufhidden=wipe noswapfile
  autocmd BufLeave <buffer> call gol#stop()
  nnoremap <buffer><nowait> <space> <cmd>call <sid>pause_or_start()<cr>
  nnoremap <buffer><nowait> <cr> <cmd>call <sid>flip()<cr>

  let s:laststatus = &laststatus
  let s:ruler = &ruler
  let s:rulerformat = &rulerformat
  set laststatus=0 ruler rulerformat=gen:%{gol#generation()}

  let s:WIDTH = winwidth(0)
  let s:HEIGHT = winheight(0)
  let s:cells = []
  for i in range(s:HEIGHT)
    call add(s:cells, [])
    for j in range(s:WIDTH)
      call add(s:cells[i], {'current': rand(s:seed) % 2})
    endfor
  endfor

  let s:winid = win_getid()
  let s:match_ids = [matchadd('GolZero', '0'),  matchadd('GolOne', '1')]

  echo '<space> to pause_or_start, <cr> to flip'

  let s:generation = 0
  let s:timer_id = timer_start(30, 's:update_wrapper', {'repeat': -1})
endfunction
