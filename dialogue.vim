let s:is_dict = {item -> type(item) == v:t_dict}
let s:is_list = {item -> type(item) == v:t_list}
let s:is_string = {item -> type(item) == v:t_string}
let s:has_key = {item, key -> s:is_dict(item) && has_key(item, key)}
let s:get = {item, key, default -> s:has_key(item, key) ? item[key] : default}
let s:ensure_list = {item -> s:is_list(item) ? item : [item]}
let s:first_rest_char = {str -> [substitute(str, '^.\zs.*$', '', ''), substitute(str, '^.', '', '')]}

let s:dialogue = {}
" let s:border_h = '─'
" let s:border_v = '│'
" let s:border_corners = '╭╮╰╯'
" let s:next_marker = '▼'
let s:width = 50
" let s:height = 8
let s:height = 3
function s:pad_string(str, num = 1) abort
  return repeat(' ', a:num) .. a:str .. repeat(' ', a:num)
endfunction

function dialogue#open() abort
  if has('nvim')
    let line = 10
    let col = 10
    call nvim_open_win(nvim_create_buf(v:false, v:true), v:true, {
          \ 'relative': 'editor',
          \ 'row': line,
          \ 'col': col,
          \ 'width': s:width,
          \ 'height': s:height,
          \ 'style': 'minimal',
          \ 'border': 'single',
          \ 'bufpos': [0, 0],
          \ 'focusable': v:false,
          \ })
    call append(1, message)
  else
    " vim
    if !has_key(s:dialogue, 'id')
      let s:tmpwidth = 2
      " colを省略して中央に配置する
      let s:dialogue.id = popup_create('', {
            \ 'pos': 'botleft',
            \ 'line': winheight(0),
            \ 'padding': [0, 1, 0, 1],
            \ 'minwidth': s:tmpwidth,
            \ 'maxwidth': s:tmpwidth,
            \ 'minheight': s:height,
            \ 'maxheight': s:height,
            \ 'border': [],
            \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
            \ })
    elseif s:tmpwidth < s:width
      let s:tmpwidth += 10
      if s:tmpwidth > s:width
        let s:tmpwidth = s:width
      endif
      call popup_move(s:dialogue.id, {
            \ 'minwidth': s:tmpwidth,
            \ 'maxwidth': s:tmpwidth,
            \ })
    else
      " s:tmpwidth == s:width
      return
    endif
    return timer_start(30, {->dialogue#open()})
  endif
endfunction

function dialogue#close() abort
  if !has_key(s:dialogue, 'id')
    return
  endif
  if has('nvim')
  else
    call popup_close(s:dialogue.id)
    unlet! s:dialogue.id
  endif
endfunction

function s:dialogue_append() abort
  if empty(s:tmp_lines)
    return
  endif
  let [char, s:tmp_lines[0]] = s:first_rest_char(s:tmp_lines[0])

  let s:lines[-1] ..= char

  if empty(s:tmp_lines[0])
    call remove(s:tmp_lines, 0)
    if !empty(s:tmp_lines)
      call add(s:lines, '')
    endif
  endif

  if has('nvim')
  " todo: create this
  else
    call popup_settext(s:dialogue.id, s:lines)
  endif
  return timer_start(30, {->s:dialogue_append()})
endfunction

let s:lines = ['']
function dialogue#message(lines, opts = {}) abort
  if !has_key(s:dialogue, 'id')
    return
  endif

  let s:lines[-1] =  substitute(s:lines[-1], ' ▼$', '', '')

  " clear(default): clear existing messages and show message
  " newline: continue to next line
  " append: append to last line
  let line_type = get(a:opts, 'line_type', 'n')
  if line_type == 'newline'
    if s:lines != ['']
      call add(s:lines, '')
    endif
  elseif line_type == 'append'
  " nop
  else
    " clear
    let s:lines = ['']
  endif
  let s:tmp_lines = s:ensure_list(a:lines)

  if !has_key(a:opts, 'no_mark')
    let s:tmp_lines[-1] ..= ' ▼'
  endif

  if has_key(a:opts, 'title')
    let setoptions = {'title': s:pad_string(a:opts.title)}
    if has('nvim')
    " todo: create this
    else
      call popup_setoptions(s:dialogue.id, setoptions)
    endif
  endif
  call s:dialogue_append()
endfunction

function s:yn_filter(id, key) abort
  " ショートカットキーをハンドリングする
  if index(["j", "k", "\<Down>", "\<Up>", "\<C-N>", "\<C-P>"], a:key) >= 0
    let s:yn_idx = s:yn_idx == 1 ? 0 : 1
    let yn = ['  はい', '  いいえ']
    let yn[s:yn_idx] = substitute(yn[s:yn_idx], '^.', '▶', '')
    call popup_settext(a:id, yn)
  endif
  return popup_filter_menu(a:id, a:key)
endfunction

function dialogue#yn() abort
  if has('nvim')
  " todo: create this
  else
    let pos_info = popup_getpos(s:dialogue.id)
    let s:yn_idx = 0
    call popup_menu(['▶ はい', '  いいえ'], #{
          \ line: pos_info.line,
          \ col: pos_info.col + pos_info.width-1,
          \ pos: 'botright',
          \ wrap: 0,
          \ border: [],
          \ cursorline: 1,
          \ padding: [0, 1, 0, 1],
          \ mapping: 0,
          \ callback: {id, result->dialogue#greet()},
          \ filter: funcref('s:yn_filter')
          \ })
    " \ callback: {id, result->execute('echomsg ' .. string(result), '') },
  endif
endfunction

let s:waitkey_id = 0
function dialogue#waitkey() abort
  call s:dialogue_waitkey()
endfunction

let s:waitkey_id = 0
function s:dialogue_waitkey() abort
  let c = getcharstr(0)
  if c == "\<space>"
    return dialogue#greet()
  elseif !empty(c)
    echomsg c
  endif

  let s:waitkey_id = timer_start(0, {->s:dialogue_waitkey()})
endfunction

let s:cnt = 0
function dialogue#greet() abort
  let arg_list = [
        \ [['popupにカーソルを載せたい…'], #{title: 'りみ'}],
        \ [['popup-terminalの1枚制限がつらい…'], #{line_type:'newline'}],
        \ [['なるほど'], #{title: 'Vim'}],
        \ [['Vimじゃん'], #{title: 'りみ'}],
        \ [['あっ画像を出せる']],
        \ [['解像度粗くてワロタ'], #{title: 'Vim'}],
        \ [['なにわろてんねん'], #{title: 'りみ'}],
        \ [['sixel対応してよ～🙏']],
        \ [['複数popup-terminal対応してよ～🙏'], #{line_type:'newline'}],
        \ [['E861'], #{title: 'Vim'}],
        \ [['エラーを吐くなエラーを'], #{title: 'りみ'}],
        \ [['feature requestを出しなさい'], #{title: 'Vim'}],
        \ [['うーむ'], #{title: 'りみ'}],
        \ [['「sixelと複数popup-terminalができればVimでギャルゲが作れます！」で']],
        \ [['メンテナ陣を動かせる気はしないのだが…'], #{line_type:'newline'}],
        \ ]


  " let arg_list = [
  "       \ [['いらっしゃい！', 'ここは マドケシ堂だよ！'], #{title: '店主'}],
  "       \ [['Windowsを消していくかい？']],
  "       \ [['そうかそうか！', 'じゃあいくぞ！']],
  "       \ [['1… '], #{line_type:'newline', no_mark: 1}],
  "       \ [['2の… '], #{line_type:'append', no_mark: 1}],
  "       \ [['ポカン！'], #{line_type:'append'}],
  "       \ [['これできみのWindowsは きれいさっぱり消えさったぞ！']],
  "       \ [['Windowsを消したくなったらいつでも来てくれ！']],
  "       \ ]

  " let arg_list = [
  "       \ [['こんにちは！', 'Vim の世界へようこそ！'], #{title: '謎の声'}],
  "       \ [['ついに冒険が始まるときがやってきたんだ', '冒険するのは誰でもない…君だ']],
  "       \ [['Vim の世界の旅は、初めは広大な砂漠や難解な迷宮のように感じるかもしれない']],
  "       \ [['最初は不慣れで、やりたいことができなくて戸惑うだろう'], #{line_type: 'newline'}],
  "       \ [['でも心配はいらない']],
  "       \ [['君の目の前のキーボードは、まさに冒険のための剣や魔法の杖のようなものだ']],
  "       \ [['これから少しずつ技や呪文を身につけ、その力を感じていくはず'], #{line_type: 'newline'}],
  "       \ [['長い旅になると思うけど、これは価値のある冒険になるってことを信じてほしい']],
  "       \ [['自分の作業を効率的に行う方法を考え、'], #{line_type: 'newline'}],
  "       \ [['新しい武器を手に入れ、'], #{line_type: 'newline'}],
  "       \ [['オリジナルの技を創り出し、'], #{line_type: 'newline'}],
  "       \ [['まさに自分だけの冒険を描いていく'], #{line_type: 'newline'}],
  "       \ [['きっといつか、これが長い旅であることを喜ぶようになるはずだ']],
  "       \ [['そして最後に、一歩一歩進むことを忘れないでほしい']],
  "       \ [['すべての大冒険は、小さな一歩から始まる…'], #{line_type: 'newline'}],
  "       \ [['Vim の世界の旅も同じだ'], #{line_type: 'append'}],
  "       \ [['それでは、']],
  "       \ [['良い冒険を！'], #{line_type: 'append'}],
  "       \ ]

  if len(arg_list) <= s:cnt
    let s:cnt = 0
    call dialogue#close()
    return
  endif
  let args = arg_list[s:cnt]
  let s:cnt += 1
  call call('dialogue#message', args)
  " call s:dialogue_waitkey()
endfunction

nnoremap # <cmd>call dialogue#open()<cr>
" nnoremap $ <cmd>call dialogue#yn()<cr>
nnoremap <cr> <cmd>call dialogue#greet()<cr>
