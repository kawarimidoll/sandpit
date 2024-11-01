function PopupEcho(command) abort
  " シェルコマンドを実行して結果を取得
  let result = systemlist(a:command)

  " 空でない場合はポップアップウィンドウで表示
  if !empty(result)
    let s:popid = popup_create(result, {})
    " let s:popid = popup_create(result, {'time': 6000})
    " autocmd! PopupClose <buffer>
    " autocmd PopupClose call popup_close(popid)
  endif
endfunction
function PopupToggle(command) abort
  if exists('s:popid')
    call popup_close(s:popid)
    unlet! s:popid
  else
    call PopupEcho(a:command)
  endif
endfunction
" nnoremap # <cmd>call PopupToggle('timg -g20x20 /Users/kawarimidoll/Downloads/kawarimi.png')<cr>

function OpenTimg(command) abort
  " シェルコマンドを実行して結果を取得
  let lines = systemlist(a:command)

  for line in lines
    call append(line('$'), line)
  endfor
endfunction

let s:img_cnt = 0
function PopupImage() abort
  if exists('s:popid')
    call popup_close(s:popid)
  endif
  let width = 20
  let height = 10
  if s:img_cnt == 0
  " execute 'terminal timg -g20x20' a:path
    execute 'terminal timg -g20x20  -Bwhite /Users/kawarimidoll/Downloads/vim-logo.png'
  elseif s:img_cnt == 1
    execute 'terminal timg -g20x20  -Bwhite /Users/kawarimidoll/Downloads/kawarimi.png'
  else
    execute 'terminal timg -g60x20 --grid=2 -Bwhite /Users/kawarimidoll/Downloads/vim-logo.png /Users/kawarimidoll/Downloads/kawarimi.png'
    let width = 50
    let height = 11
  endif
  let s:img_cnt += 1
  let bn = bufnr()
  sleep 50ms
  q
  let s:popid = popup_create(bn, {
            \ 'line': 1,
            \ 'minwidth': width,
            \ 'maxwidth': width,
            \ 'minheight': height,
            \ 'maxheight': height,
            \ 'scrollbar': 0,
            \ })
  normal! gg
endfunction

nnoremap $ <cmd>call PopupImage()<cr>
