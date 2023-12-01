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
" xnoremap <script> sp <cmd>echo <sid>get_string(<sid>getcharpos("v"), <sid>getcharpos("."), v:true)<cr>

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

" e.g. <space> -> \<space>
function! utils#trans_special_key(str) abort
  return substitute(a:str, '<[^>]*>', {m -> eval($'"\{m[0]}"')}, 'g')
endfunction

function! utils#uniq_add(list, item) abort
  if index(a:list, a:item) < 0
    call add(a:list, a:item)
  endif
endfunction

function! utils#echoerr(str) abort
  echohl ErrorMsg
  echomsg a:str
  echohl NONE
endfunction

function! utils#debug_log(contents) abort
  let contents = type(a:contents) == v:t_list ? mapnew(a:contents, 'json_encode(v:val)')
        \ : type(a:contents) == v:t_dict ? json_encode(a:contents)
        \ : [a:contents]
  call writefile(contents, './debug.log', 'a')
endfunction
