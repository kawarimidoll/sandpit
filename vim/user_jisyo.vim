function user_jisyo#add_word(context) abort
  echowindow a:context
  let s:p1 = a:context.pos
  let s:p2 = getpos('.')[1:2]
  let s:opts = {'okuri': a:context.okuri, 'exclusive': !a:context.is_trailing}
  autocmd BufEnter <buffer> ++once call h#henkan_buffer(s:p1, s:p2, s:opts)

  let yomi = a:context.machi .. a:context.consonant
  " let s:saved_context = a:context

  let jump_line = a:context.okuri ==# '' ? '/okuri-nasi' : '/okuri-ari'

  let user_jisyo_winnr = bufwinnr(bufnr(opts#get('user_jisyo_path')))
  if user_jisyo_winnr > 0
    " ユーザー辞書がすでに開いている場合は
    " okuri-ari/okuri-nasiの行へジャンプする
    execute user_jisyo_winnr .. 'wincmd w'
    normal! gg
    execute jump_line
  else
    call user_jisyo#open($'+{jump_line}')
  endif

  call feedkeys($"\<c-o>o{yomi} //\<c-g>U\<left>\<cmd>call h#enable()\<cr>", 'n')
endfunction

function user_jisyo#open(args = '') abort
  execute 'botright 5new' a:args opts#get("user_jisyo_path")
endfunction
