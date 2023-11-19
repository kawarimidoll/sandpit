" :h :map-operator

nnoremap <expr> <c-j> CountSpaces()
xnoremap <expr> <c-j> CountSpaces()
" <c-j> 2回で行に作用
nnoremap <expr> <c-j><c-j> CountSpaces() .. '_'

function CountSpaces(context = {}, type = '') abort
  if a:type == ''
    let context = #{
          \ dot_command: v:false,
          \ extend_block: '',
          \ virtualedit: [&l:virtualedit, &g:virtualedit],
          \ }
    let &operatorfunc = function('CountSpaces', [context])
    set virtualedit=block
    return 'g@'
  endif

  let save = #{
        \ clipboard: &clipboard,
        \ selection: &selection,
        \ virtualedit: [&l:virtualedit, &g:virtualedit],
        \ register: getreginfo('"'),
        \ visual_marks: [getpos("'<"), getpos("'>")],
        \ }

  try
    set clipboard= selection=inclusive virtualedit=
    let commands = #{
          \ line: "'[V']",
          \ char: "`[v`]",
          \ block: "`[\<C-V>`]",
          \ }[a:type]
    let [_, _, col, off] = getpos("']")
    if off != 0
      let vcol = getline("'[")->strpart(0, col + off)->strdisplaywidth()
      let extend_block = vcol >= [line("'["), '$']->virtcol() - 1
            \ ? '$'
            \ : vcol .. '|'
      let commands ..= 'oO' .. extend_block
    endif
    let commands ..= 'y'
    execute 'silent noautocmd keepjumps normal!' commands
    echomsg getreg('"')->count(' ')
  finally
    call setreg('"', save.register)
    call setpos("'<", save.visual_marks[0])
    call setpos("'>", save.visual_marks[1])
    let &clipboard = save.clipboard
    let &selection = save.selection
    let [&l:virtualedit, &g:virtualedit] = get(a:context.dot_command ? save : a:context, 'virtualedit')
    let a:context.dot_command = v:true
  endtry
endfunction
