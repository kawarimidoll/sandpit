" let list = [
"       \ '-0,0 +1,2',
"       \ '-11,0 +12,2',
"       \ '-14,0 +15,2',
"       \ '-1 +1,2',
"       \ '-1,2 +0,0',
"       \ '-0,0 +1',
"       \ '-1,0 +3',
"       \ ]
" let s:parse_hunk = {pair -> split($'{pair},1', '[ ,+-]')[:1]->map('str2nr(v:val)')}

" for l in list
"   " echo l l->split(' ')->map('s:parse_hunk(v:val)')
"   " echo l l->substitute('\v[+-](\d+)%( |$)', '\1,1,', 'g')
"   "       \ ->substitute(' ', ',', 'g')
"   "       \ ->substitute('[+-]', '', 'g')
"   echo l l->substitute('\v%( |$)', ',1,', 'g')
"         \ ->matchlist('\v(\d+),(\d+).{-}(\d+),(\d+)')[1:4]
"         \ ->map('str2nr(v:val)')
" endfor

highlight HunkSignAdd ctermfg=red guifg=red
highlight HunkSignDel ctermfg=green guifg=green
highlight HunkSignUpd ctermfg=yellow guifg=yellow

function s:put_signs(hunk_info) abort
  let [old_lines, new_start, new_lines] = split(a:hunk_info, ',')[1:]
  " echomsg a:list
  let bn = bufnr()
  let list = []
  if old_lines == 0
    let name = 'HunkSignAdd'
    let new_end = new_start + new_lines - 1
    for lnum in range(new_start, new_end)
      call add(list, {'buffer': bn, 'lnum': lnum, 'name': name})
    endfor
  elseif new_lines == 0
    let name = 'HunkSignDel'
    call add(list, {'buffer': bn, 'lnum': new_start, 'name': name})
  else
    let name = 'HunkSignUpd'
    let new_end = new_start + min([old_lines, new_lines]) - 1
    for lnum in range(new_start, new_end)
      call add(list, {'buffer': bn, 'lnum': lnum, 'name': name})
    endfor
    if old_lines > new_lines
      let name = 'HunkSignDel'
      call add(list, {'buffer': bn, 'lnum': new_start, 'name': name})
    elseif old_lines < new_lines
      let name = 'HunkSignAdd'
      let line_dif = new_lines - old_lines
      for lnum in range(new_end + 1, new_end + line_dif)
        call add(list, {'buffer': bn, 'lnum': lnum, 'name': name})
      endfor
    endif
  endif
  call sign_placelist(list)
endfunction
function SignDef() abort
  call sign_define([{
        \ 'name' : 'HunkSignAdd',
        \ 'texthl' : 'HunkSignAdd',
        \ 'text' : '+',
        \ }, {
        \ 'name' : 'HunkSignDel',
        \ 'texthl' : 'HunkSignDel',
        \ 'text' : '-',
        \ }, {
        \ 'name' : 'HunkSignUpd',
        \ 'texthl' : 'HunkSignUpd',
        \ 'text' : '~',
        \ }])
  let s:sign_def = 1
endfunction

function GetHunk() abort
  let cmd = $'git --no-pager diff -U0 --no-color --no-ext-diff {@%}'
        \ .. ' | grep ''^@@'' '
        \ .. ' | sed -r ''s/[-+]([0-9]+) /\1,1,/g'' '
        \ .. ' | sed -r ''s/^[-@ ]*([0-9]+,[0-9]+)[ ,+]+([0-9]+,[0-9]+)[, ].*/\1,\2/'' '
  return systemlist(cmd)
endfunction

let s:sign_def = 0
let s:sign_id = 0
function ShowHunk() abort
  if !s:sign_def
    call SignDef()
    set signcolumn=auto
  endif

  let output = GetHunk()

  let bn = bufnr()
  for line in output
    call s:put_signs(line)
  endfor
endfunction
