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
  setlocal modifiable
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
  setlocal filetype=mydiff bufhidden=wipe buftype=nofile noswapfile readonly nomodifiable nomodified
  execute $'nnoremap <buffer> <Plug>(diff-stage-line) <cmd>call <sid>stage_line({a:staged})<cr>'
  execute $'xnoremap <buffer> <Plug>(diff-stage-line) <cmd>call <sid>stage_line({a:staged})<cr>'
  execute $'nnoremap <buffer> <Plug>(diff-stage-file) <cmd>call <sid>stage_file({a:staged})<cr>'
  execute 'nnoremap <buffer> <Plug>(diff-quit) <cmd>tabclose<cr>'
endfunction

function! s:stage_line(staged) abort
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
