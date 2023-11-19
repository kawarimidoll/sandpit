" left = [lnum, col]
" right = [lnum, col]
" left < right -> 1
" left = right -> 0
" left > right -> -1
function! s:compare_pos(left, right) abort
  return a:left[0] < a:right[0] ? 1
        \ : a:left[0] > a:right[0] ? -1
        \ : a:left[1] == a:right[1] ? 0
        \ : a:left[1] < a:right[1] ? 1
        \ : -1
endfunction

function! s:getcharpos(pos = '.') abort
  return getcharpos(a:pos)[1:2]
endfunction

function! s:get_string(from, to, auto_swap = v:false) abort
  let compared = s:compare_pos(a:from, a:to)
  if compared == 0 || (compared < 0 && !a:auto_swap)
    return ''
  endif

  let [from, to] = compared > 0 ? [a:from, a:to] : [a:to, a:from]

  let lines = getline(from[0], to[0])
  let lines[-1] = slice(lines[-1], 0, to[1]-1)
  let lines[0] = slice(lines[0], from[1]-1)
  return join(lines, "\n")
endfunction

xnoremap <script> sp <cmd>echo <sid>get_string(<sid>getcharpos("v"), <sid>getcharpos("."), v:true)<cr>

" export
let utils#export = {}
let utils#export.compare_pos = function('s:compare_pos')
let utils#export.getcharpos = function('s:getcharpos')
let utils#export.get_string = function('s:get_string')
