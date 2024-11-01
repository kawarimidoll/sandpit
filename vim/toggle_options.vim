function s:toggle_options() abort
  let pid = popup_create([], {
        \ 'pos': 'center',
        \ 'title': 'Toggle Options',
        \ 'padding': [],
        \ 'border': [],
        \  })
  let option_list = ['number', 'ruler', 'showcmd', 'cursorline', 'cursorcolumn']
  while 1
    let text = []
    for i in option_list->len()->range()
      let current = execute($'echo &{option_list[i]}')->trim() == '0' ? 'off' : 'on'
      call add(text, $'{i+1}: {option_list[i]} {current}')
    endfor
    call add(text, '')
    call add(text, 'otherwise: quit')

    call popup_settext(pid, text)

    redraw
    " execute 'normal! :<esc>'

    let c = getcharstr()
    let nr = str2nr(c)

    if c =~ '\d' && 0 < nr && nr < len(option_list) + 1
      execute 'set' option_list[nr-1] '!'
    else
      break
    endif
  endwhile
  call popup_close(pid)
  redraw
endfunction
command! Toggleoptions call s:toggle_options()
