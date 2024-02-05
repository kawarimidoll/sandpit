highlight! link myStageTitle Title
highlight! link myStageAdded Added
highlight! link myStageRemoved Removed

function! Showdiff() abort
  let filename = @%

  tabnew
  let t:my_stage_filename = filename
  setlocal filetype=mystage
  botright new
  setlocal filetype=mystage
  call s:refresh_diff_win()
endfunction

function! s:refresh_diff_win() abort
  1 wincmd w
  call s:init_diff_win(0)
  if exists('w:saved_stage_win')
    call winrestview(w:saved_stage_win)
  endif
  2 wincmd w
  call s:init_diff_win(1)
  if exists('w:saved_stage_win')
    call winrestview(w:saved_stage_win)
  endif
  1 wincmd w
endfunction

function! s:init_diff_win(staged) abort
  setlocal modifiable noreadonly
  silent %delete_
  if !a:staged && system('git status --porcelain ' .. t:my_stage_filename)->trim() =~# '?'
    " new file
    call append(0, repeat([''], 5))
    silent execute 'read! cat' t:my_stage_filename
    silent %substitute/^/+/e
    call setline(6, $'@@ -0,0 +1,{line("$")-6} @@')
  else
    let cmd = 'read! git --no-pager diff --no-color --no-ext-diff'
    silent execute cmd a:staged ? "--staged" : "" t:my_stage_filename
  endif

  call matchadd('myStageTitle', '^@@\v -\d+%(,\d+)? \+\d+%(,\d+)? \V@@')
  call matchadd('myStageRemoved', '^-.*')
  call matchadd('myStageAdded', '^+.*')
  normal! gg
  if line('$') == 1
    call setline(1, $'no {a:staged ? "" : "un"}staged changes')
  else
    silent 1,/^@@/-1delete_
  endif
  setlocal bufhidden=wipe buftype=nofile noswapfile readonly nomodifiable nomodified
  execute $'nnoremap <buffer> <Plug>(stage-line) <cmd>call <sid>stage_line({a:staged})<cr>'
  execute $'xnoremap <buffer> <Plug>(stage-range) <cmd>call <sid>stage_line({a:staged})<cr>'
  execute $'nnoremap <buffer> <Plug>(stage-hunk) <cmd>call <sid>stage_hunk({a:staged})<cr>'
  execute $'nnoremap <buffer> <Plug>(stage-file) <cmd>call <sid>stage_file({a:staged})<cr>'
  execute $'nnoremap <buffer> <Plug>(delete-line) <cmd>call <sid>delete_line({a:staged})<cr>'
  execute $'xnoremap <buffer> <Plug>(delete-line) <cmd>call <sid>delete_line({a:staged})<cr>'
  execute 'nnoremap <buffer> <Plug>(quit) <cmd>tabclose<cr>'
endfunction

function! s:lastindexof(object, expr) abort
  let rev_index = indexof(a:object->copy()->reverse(), a:expr)
  return rev_index == -1 ? -1 : len(a:object) - 1 - rev_index
endfunction

let s:hunk_info_line = {info->$'@@ -{info[0]},{info[1]} +{info[2]},{info[3]} @@{info[4]}'}

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

  let w:saved_stage_win = winsaveview()

  let first_mark_lnum = l_from + first_mark_idx
  let last_mark_lnum = l_from + last_mark_idx

  let hunk_info_pat = '^@@\v -(\d+)%(,(\d+))? \+(\d+)%(,(\d+))? \@\@(.*)$'
  " NotifyShow $'first_mark_lnum {first_mark_lnum} last_mark_lnum {last_mark_lnum}'

  let cmd = 'git apply --cached '
  " let cmd ..= ' --unidiff-zero '
  let [old_mark, new_mark, lines_idx] = ['-', '+', 3]
  if a:staged
    let cmd ..= '--reverse '
    let [old_mark, new_mark, lines_idx] = ['+', '-', 1]
    " %substitute/^+/_/
    " %substitute/^-/+/
    " %substitute/^_/-/
  endif

  call cursor(last_mark_lnum, 1)
  let next_hunk_info_lnum = search(hunk_info_pat, 'cnW')
  if next_hunk_info_lnum > 0
    silent execute $'{next_hunk_info_lnum},$global/^/delete_'
  endif
  normal! G
  if l_to < line('$')
    let last_hunk_info_lnum = search(hunk_info_pat, 'bcnW')
    let last_hunk_info = getline(last_hunk_info_lnum)
          \ ->matchlist(hunk_info_pat)[1:5]->map({i,v-> i==4 ? v : str2nr(v ?? '1')})
    for l in getline(l_to+1, '$')
      if l[0] == new_mark
        let last_hunk_info[lines_idx] -= 1
      elseif l[0] == old_mark
        let last_hunk_info[lines_idx] += 1
      endif
    endfor
    call setline(last_hunk_info_lnum, s:hunk_info_line(last_hunk_info))
    silent execute $'{l_to+1},$substitute /^{old_mark}/ /e'
    silent execute $'{l_to+1},$global /^{new_mark}/delete_'
  endif

  call cursor(first_mark_lnum, 1)
  let first_hunk_info_lnum = search(hunk_info_pat, 'bcnW')
  if first_hunk_info_lnum < first_mark_lnum - 1
    let first_hunk_info = getline(first_hunk_info_lnum)
          \ ->matchlist(hunk_info_pat)[1:5]->map({i,v-> i==4 ? v : str2nr(v ?? '1')})

    for l in getline(first_hunk_info_lnum, first_mark_lnum - 1)
      if l[0] == new_mark
        let first_hunk_info[lines_idx] -= 1
      elseif l[0] == old_mark
        let first_hunk_info[lines_idx] += 1
      endif
    endfor
    call setline(first_hunk_info_lnum, s:hunk_info_line(first_hunk_info))

    silent execute $'{first_hunk_info_lnum},{first_mark_lnum-1}substitute /^{old_mark}/ /e'
    silent execute $'{first_hunk_info_lnum},{first_mark_lnum-1}global /^{new_mark}/delete_'
  endif

  if first_hunk_info_lnum > 1
    silent execute $'1,{first_hunk_info_lnum-1}global/^/delete_'
  endif

  call append(0, [$'--- a/{t:my_stage_filename}', $'+++ b/{t:my_stage_filename}'])

  let tempfile = tempname()
  call writefile(getline(1, '$'), tempfile)
  call system(cmd .. tempfile)
  " NotifyShow tempfile

  if v:shell_error
    NotifyShow! 'error occurred'
  elseif a:staged
    NotifyShow 'successfully unstaged'
  else
    NotifyShow 'successfully staged'
  endif

  call s:refresh_diff_win()
endfunction

function! s:stage_file(staged) abort
  if line('$') == 1
    return
  endif
  call system($'git {a:staged ? "un" : ""}stage {t:my_stage_filename}')
  call s:refresh_diff_win()
endfunction

function! s:stage_hunk(staged) abort
  let pat = '^@@ '
  call search(pat, 'bcW')
  normal! V
  if search(pat, 'W')
    normal! k
  else
    normal! G
  endif
  call s:stage_line(a:staged)
endfunction

function! s:delete_line(staged) abort
  let msg = "Are you sure you want to discard this change (git reset)? It is irreversible.\n"
        \ .. 'To disable this dialogue, set g:skip_discard_change_warning to true.'
  let skip_warning = get(g:, 'skip_discard_change_warning', v:false)
  if a:staged || (!skip_warning && confirm(msg, "&Yes\n&No") == 1)
    call s:stage_line(v:true)
  endif
endfunction

function! s:my_stage_map() abort
  nmap <buffer><silent><nowait> <space> <Plug>(stage-line)
  xmap <buffer><silent><nowait> <space> <Plug>(stage-range)
  nmap <buffer><silent><nowait> <cr> <Plug>(stage-hunk)
  nmap <buffer><silent><nowait> <s-cr> <Plug>(stage-file)
  nmap <buffer><silent><nowait> q <Plug>(quit)
  nnoremap <buffer><silent><nowait> v V
endfunction

augroup my_stage
  autocmd!
  autocmd FileType mystage call s:my_stage_map()
augroup END

command! Stager call Showdiff()
