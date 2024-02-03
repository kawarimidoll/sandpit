" TODO
" diffで--no-indexも使う？
" let cmd = 'git status --porcelain | grep "^ "'
" call mi#job#start(['sh', '-c', cmd], { 'exit': {data->execute('let g:git_status = data')} })

highlight HunkSignAdd ctermfg=red guifg=red
highlight HunkSignDelete ctermfg=green guifg=green
highlight HunkSignTopDelete ctermfg=green guifg=green
highlight HunkSignChange ctermfg=yellow guifg=yellow
highlight HunkSignChangeDelete ctermfg=yellow guifg=yellow

let s:sign_obj = {name, text -> {'name': name, 'texthl': name, 'text': text}}
call sign_define([
      \ s:sign_obj('HunkSignAdd', '+'),
      \ s:sign_obj('HunkSignDelete', '_'),
      \ s:sign_obj('HunkSignChange', '~'),
      \ s:sign_obj('HunkSignTopDelete', '‾'),
      \ s:sign_obj('HunkSignChangeDelete', '≃'),
      \ ])

let s:group = 'GitHunk'
function s:put_signs(hunk_info) abort
  let [old_lines, new_start, new_lines] = a:hunk_info[1:]
  " echomsg [a:hunk_info, old_lines, new_start, new_lines]
  let bn = bufnr()
  let list = []
  if old_lines == 0
    let name = 'HunkSignAdd'
    let new_end = new_start + new_lines - 1
    for lnum in range(new_start, new_end)
      call add(list, {'buffer': bn, 'group': s:group, 'lnum': lnum, 'name': name})
    endfor
  elseif new_lines == 0
    let name = 'HunkSignDelete'
    call add(list, {'buffer': bn, 'group': s:group, 'lnum': new_start, 'name': name})
  else
    let name = 'HunkSignChange'
    let new_end = new_start + min([old_lines, new_lines]) - 1
    for lnum in range(new_start, new_end)
      call add(list, {'buffer': bn, 'group': s:group, 'lnum': lnum, 'name': name})
    endfor
    if old_lines > new_lines
      let name = 'HunkSignChangeDelete'
      call add(list, {'buffer': bn, 'group': s:group, 'lnum': new_end, 'name': name})
    elseif old_lines < new_lines
      let name = 'HunkSignAdd'
      let line_dif = new_lines - old_lines
      " echomsg new_end line_dif
      for lnum in range(new_end + 1, new_end + line_dif)
        call add(list, {'buffer': bn, 'group': s:group, 'lnum': lnum, 'name': name})
      endfor
    endif
  endif
  call sign_placelist(list)
endfunction

let s:hunk_cache = {}
function Gethunk() abort
  let bufnr = bufnr()
  if get(s:hunk_cache, bufnr, {})->get('changedtick', 0) == b:changedtick
    return s:hunk_cache[bufnr].hunks
  endif
  echo $'bufnr {bufnr} re-hunk'
  let cmd = $'git --no-pager diff -U0 --no-color --no-ext-diff {@%}'
        \ .. '| grep ^@@'
        \ .. '| sed -r ''s/[-+]([0-9]+) /\1,1,/g'''
        \ .. '| sed -r ''s/^[-@ ]*([0-9]+,[0-9]+)[ ,+]+([0-9]+,[0-9]+)[, ].*/\1,\2/'''
  let s:hunk_cache[bufnr] = {
        \ 'hunks': systemlist(cmd)->map({_,v->eval($'[{v}]')}),
        \ 'changedtick': b:changedtick
        \ }
  return s:hunk_cache[bufnr].hunks
endfunction

" function Gethunk() abort
"   let cmd = $'git --no-pager diff -U0 --no-color --no-ext-diff {@%}'
"         \ .. ' | grep ''^@@'' '
"         \ .. ' | sed -r ''s/[-+]([0-9]+) /\1,1,/g'' '
"         \ .. ' | sed -r ''s/^[-@ ]*([0-9]+,[0-9]+)[ ,+]+([0-9]+,[0-9]+)[, ].*/\1,\2/'' '
"   return systemlist(cmd)
" endfunction

function Hidehunk() abort
  let bn = bufnr()
  call sign_unplace(s:group, {'buffer': bn})
endfunction

function Showhunk() abort
  set signcolumn=auto
  call Hidehunk()

  let output = Gethunk()
  " echomsg output

  for line in output
    call s:put_signs(line)
  endfor
endfunction

function s:between(num, min, max) abort
  return a:min <= a:num && a:num <= a:max
endfunction

function Onhunk() abort
  let lnum = line('.')
  for hunk_info in Gethunk()
    let [new_start, new_lines] = hunk_info[2:]
    if new_lines == 0
      " delete
      if new_start == line
        return v:true
      endif
    else
      " modify
      if s:between(lnum, new_start, new_start + new_lines - 1)
        return v:true
      endif
    endif
    return v:false
  endfor
endfunction
