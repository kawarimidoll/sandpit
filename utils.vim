" left = [lnum, col]
" right = [lnum, col]
" left < right -> 1
" left = right -> 0
" left > right -> -1
function! utils#compare_pos(left, right) abort
  return a:left[0] < a:right[0] ? 1
        \ : a:left[0] > a:right[0] ? -1
        \ : a:left[1] == a:right[1] ? 0
        \ : a:left[1] < a:right[1] ? 1
        \ : -1
endfunction

function! utils#getcharpos(pos = '.') abort
  return getcharpos(a:pos)[1:2]
endfunction

function! utils#get_string(from, to, auto_swap = v:false) abort
  let compared = utils#compare_pos(a:from, a:to)
  if compared == 0 || (compared < 0 && !a:auto_swap)
    return ''
  endif

  let [from, to] = compared > 0 ? [a:from, a:to] : [a:to, a:from]

  let lines = getline(from[0], to[0])
  let lines[-1] = slice(lines[-1], 0, to[1]-1)
  let lines[0] = slice(lines[0], from[1]-1)
  return join(lines, "\n")
endfunction

" xnoremap sp <cmd>echo utils#get_string(utils#getcharpos("v"), utils#getcharpos("."), v:true)<cr>
