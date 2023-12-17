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

function! utils#echoerr(...) abort
  echohl ErrorMsg
  for str in a:000
    echomsg '[sandpit]' str
  endfor
  echohl NONE
endfunction

function! utils#debug_log(contents) abort
  let contents = type(a:contents) == v:t_list ? mapnew(a:contents, 'json_encode(v:val)')
        \ : type(a:contents) == v:t_dict ? json_encode(a:contents)
        \ : [a:contents]
  call writefile(contents, './debug.log', 'a')
endfunction

let consonant_list = [
      \ 'aあ', 'iい', 'uう', 'eえ', 'oお',
      \ 'kかきくけこ', 'gがぎぐげご',
      \ 'sさしすせそ', 'zざじずぜぞ',
      \ 'tたちつてとっ', 'dだぢづでど',
      \ 'nなにぬねのん',
      \ 'hはひふへほ', 'bばびぶべぼ', 'pぱぴぷぺぽ',
      \ 'mまみむめも',
      \ 'yやゆよ',
      \ 'rらりるれろ',
      \ 'wわを',
      \ ]
let s:consonant_dict = {}
for c in consonant_list
  let [a; japanese] = split(c, '\zs')
  for j in japanese
    let s:consonant_dict[j] = a
  endfor
endfor

function! utils#consonant(char) abort
  return s:consonant_dict[a:char]
endfunction

function! utils#strsplit(str) abort
  " 普通にsplitすると<bs>など<80>k?のコードを持つ文字を正しく切り取れないので対応
  let chars = split(a:str, '\zs')
  let prefix = split("\<bs>", '\zs')
  let result = []
  let i = 0
  while i < len(chars)
    if chars[i] == prefix[0] && chars[i+1] == prefix[1]
      call add(result, chars[i : i+2]->join(''))
      let i += 2
    else
      call add(result, chars[i])
    endif
    let i += 1
  endwhile
  return result
endfunction

" run last one call in wait time
" https://github.com/lambdalisue/gin.vim/blob/937cc4dd3b5b1fbc90a21a8b8318b1c9d2d7c2cd/autoload/gin/internal/util.vim
let s:debounce_timers = {}
function! utils#debounce(fn, wait, args = [], timer_name = '') abort
  let timer_name = a:timer_name !=# '' ? a:timer_name
        \ : type(a:fn) == v:t_string ? a:fn
        \ : string(a:fn)
  call get(s:debounce_timers, timer_name, 0)->timer_stop()
  let s:debounce_timers[timer_name] = timer_start(a:wait, {-> call(a:fn, a:args) })
endfunction
