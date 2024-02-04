highlight! link myDiffTitle Title
highlight! link myDiffAdded Added
highlight! link myDiffRemoved Removed

function! Showdiff() abort
  let filename = @%

  tabnew
  let t:my_diff_filename = filename
  setlocal filetype=mydiff
  botright new
  setlocal filetype=mydiff
  call s:refresh_diff_win()
endfunction

function! s:refresh_diff_win() abort
  1 wincmd w
  call s:init_diff_win(0)
  2 wincmd w
  call s:init_diff_win(1)
  1 wincmd w
endfunction

function! s:init_diff_win(staged) abort
  setlocal modifiable noreadonly
  silent %delete_
  if !a:staged && system('git status --porcelain ' .. t:my_diff_filename)->trim() =~# '?'
    " new file
    call append(0, repeat([''], 5))
    silent execute 'read! cat' t:my_diff_filename
    %substitute/^/+/
    call setline(6, $'@@ -0,0 +1,{line("$")-6} @@')
  else
    let cmd = 'read! git --no-pager diff --no-color --no-ext-diff'
    silent execute cmd a:staged ? "--staged" : "" t:my_diff_filename
  endif

  call matchadd('myDiffTitle', '^@@\v -\d+%(,\d+)? \+\d+%(,\d+)? \V@@')
  call matchadd('myDiffRemoved', '^-.*')
  call matchadd('myDiffAdded', '^+.*')
  normal! gg
  if line('$') == 1
    call setline(1, $'no {a:staged ? "" : "un"}staged changes')
  else
    silent 1,/^@@/-1delete_
  endif
  setlocal bufhidden=wipe buftype=nofile noswapfile readonly nomodifiable nomodified
  execute $'nnoremap <buffer> <Plug>(diff-stage-line) <cmd>call <sid>stage_line({a:staged})<cr>'
  execute $'xnoremap <buffer> <Plug>(diff-stage-line) <cmd>call <sid>stage_line({a:staged})<cr>'
  execute $'nnoremap <buffer> <Plug>(diff-stage-file) <cmd>call <sid>stage_file({a:staged})<cr>'
  execute 'nnoremap <buffer> <Plug>(diff-quit) <cmd>tabclose<cr>'
endfunction

function! s:lastindexof(object, expr) abort
  let rev_index = indexof(a:object->copy()->reverse(), a:expr)
  return rev_index == -1 ? -1 : len(a:object) - 1 - rev_index
endfunction

let s:hunk_info_line = {info->$'@@ -{info[0]},{info[1]} +{info[2]},{info[3]} @@'}

function! s:stage_line(staged) abort
  let [l_from, l_to] = [line('.'), line('v')]
  if l_from > l_to
    let [l_from, l_to] = [l_to, l_from]
  endif

  setlocal modifiable noreadonly

  let lines = getline(l_from, l_to)
  let first_mark_idx = indexof(lines, {_,l -> l =~# '^[-+]'})
  if first_mark_idx == -1
    NotifyShow 'no changes'
    setlocal nomodifiable readonly
    return
  endif
  let last_mark_idx = s:lastindexof(lines, {_,l -> l =~# '^[-+]'})

  let first_mark_lnum = l_from + first_mark_idx
  let last_mark_lnum = l_from + last_mark_idx

  let hunk_info_pat = '^@@\v -(\d+)%(,(\d+))? \+(\d+)%(,(\d+))? \V@@'
  NotifyShow $'first_mark_lnum {first_mark_lnum} last_mark_lnum {last_mark_lnum}'

  call cursor(last_mark_lnum, 1)
  let next_hunk_info_lnum = search(hunk_info_pat, 'cnW')
  if next_hunk_info_lnum > 0
    silent execute $'{next_hunk_info_lnum},$global/^/delete_'
  endif
  normal! G
  if l_to < line('$')
    let last_hunk_info_lnum = search(hunk_info_pat, 'bcnW')
    let last_hunk_info = getline(last_hunk_info_lnum)
          \ ->matchlist(hunk_info_pat)[1:4]->map('str2nr(v:val??"1")')
    for l in getline(l_to+1, '$')
      if l[0] == '+'
        let last_hunk_info[3] -= 1
      elseif l[0] == '-'
        let last_hunk_info[3] += 1
      endif
    endfor
    call setline(last_hunk_info_lnum, s:hunk_info_line(last_hunk_info))
    silent execute $'{l_to+1},$substitute /^-/ /e'
    silent execute $'{l_to+1},$global /^+/delete_'
  endif

  call cursor(first_mark_lnum, 1)
  let first_hunk_info_lnum = search(hunk_info_pat, 'bcnW')
  if first_hunk_info_lnum < first_mark_lnum - 1
    let first_hunk_info = getline(first_hunk_info_lnum)
          \ ->matchlist(hunk_info_pat)[1:4]->map('str2nr(v:val??"1")')

    for l in getline(first_hunk_info_lnum, first_mark_lnum - 1)
      if l[0] == '+'
        let first_hunk_info[3] -= 1
      elseif l[0] == '-'
        let first_hunk_info[3] += 1
      endif
    endfor
    call setline(first_hunk_info_lnum, s:hunk_info_line(first_hunk_info))

    silent execute $'{first_hunk_info_lnum},{first_mark_lnum-1}substitute /^-/ /e'
    silent execute $'{first_hunk_info_lnum},{first_mark_lnum-1}global /^+/delete_'
  endif

  if first_hunk_info_lnum > 1
    silent execute $'1,{first_hunk_info_lnum-1}global/^/delete_'
  endif

  call append(0, [$'--- a/{t:my_diff_filename}', $'+++ b/{t:my_diff_filename}'])
endfunction

function! s:stage_file(staged) abort
  if line('$') == 1
    return
  endif
  call system($'git {a:staged ? "un" : ""}stage {t:my_diff_filename}')
  call s:refresh_diff_win()
endfunction

function! s:my_diff_map() abort
  nmap <buffer><silent><nowait> <space> <Plug>(diff-stage-line)
  xmap <buffer><silent><nowait> <space> <Plug>(diff-stage-line)
  nmap <buffer><silent><nowait> <cr> <Plug>(diff-stage-file)
  nmap <buffer><silent><nowait> q <Plug>(diff-quit)
endfunction

augroup my_diff
  autocmd!
  autocmd FileType mydiff call s:my_diff_map()
augroup END
