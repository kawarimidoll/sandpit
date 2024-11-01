source ./inline_mark.vim
" state管理:
" kana
" キー入力時に有効化 既に有効ならそのまま
" キー入力によって文字列変換が発生し、かつ最後の文字列が先行入力になりうるならそのまま
" それ以外なら確定とみなし無効化
" okuri状態でkana無効化が発生した場合は送り変換を起動
" machi
" 変換ポイント設定で有効化
" 確定または変換位置キャンセルで無効化
" kouho起動でマーカーを変更
" kouhoキャンセルで位置は変えずにマーカーを復旧
" 変換実行中確定で無効化→確定で必ず無効化
" 自動補完が動いているかどうかはmachi&pumで判定
" okuri
" machiかつkanaの状態でのみ発生 手前の入力文字が未完成の状態では送りポイントを打たない
" machiの状態で再度machiに入ろうとした場合とも言える
" 確定または送り位置キャンセルで無効化
" kouho
" machi状態で変換発動またはokuri状態でkana終了で起動
" machiもokuriもなければここに入ることはない
" 手動変換pumと一蓮托生
" pumの確定またはキャンセルで無効化
" kana開始したらその時点の選択を確定してこのステートは無効化

let s:states = {
      \ 'choku': [],
      \ 'machi': [],
      \ 'okuri': [],
      \ 'kouho': [],
      \ }

function s:getpos() abort
  return getpos('.')[1:2]
endfunction

function states#show() abort
  echomsg s:states
endfunction

function states#on(target) abort
  " validate
  if a:target ==# 'choku'
    if states#in('choku')
      return
    endif
  elseif a:target ==# 'machi'
    if states#in('okuri') || states#in('kouho')
      return
    elseif states#in('machi')
      call states#on('okuri')
      return
    endif
  elseif a:target ==# 'okuri'
    if !states#in('machi') || states#getstr('choku') =~ '\a$' || states#getstr('machi') =~ '^$\|\a$'
      return
    endif
  elseif a:target ==# 'kouho'
    if !states#in('machi')
      return
    endif
  endif

  let [lnum, col] = s:getpos()
  if a:target ==# 'kouho'
    let [lnum, col] = states#get('machi')
    call inline_mark#clear('machi')
  endif
  let opt_states = opts#get('states')[a:target]
  let text = opt_states.marker
  let hl = opt_states.hl
  call inline_mark#put(lnum, col, {'name': a:target, 'text': text, 'hl': hl})
  let s:states[a:target] = [lnum, col]
endfunction

function states#clear() abort
  call states#off('choku')
  " machiがoffになったらkouhoとokuriもoffなのでこれでよし
  call states#off('machi')
endfunction

function states#off(target) abort
  call inline_mark#clear(a:target)
  let s:states[a:target] = []
  if a:target ==# 'machi'
    call states#off('okuri')
  endif
  if a:target ==# 'okuri'
    call states#off('kouho')
  endif
  if a:target ==# 'kouho' && states#in('machi')
    let [lnum, col] = states#get('machi')
    let opt_states = opts#get('states')['machi']
    let text = opt_states.marker
    let hl = opt_states.hl
    call inline_mark#put(lnum, col, {'name': 'machi', 'text': text, 'hl': hl})
  endif
endfunction

function states#get(target) abort
  return s:states[a:target]
endfunction

function states#in(target) abort
  if empty(s:states[a:target])
    return v:false
  elseif a:target ==# 'kouho'
    " kouhoだけは存在すればOK
    return v:true
  endif

  let [pos_l, pos_c] = s:states[a:target]
  let [cur_l, cur_c] = s:getpos()
  return pos_l ==# cur_l && pos_c <= cur_c
endfunction

function states#getstr(target) abort
  if empty(s:states[a:target]) || !states#in(a:target)
    return ''
  endif

  " strpartはあくまで文字列操作なので0-index
  let from_c = s:states[a:target][1] - 1
  let to_c = col('.') - 1
  let len = to_c - from_c
  let str = getline('.')->strpart(from_c, len)

  " call utils#debug_log($'getstr {getline(".")} from {from_c} to {to_c} str {str}')
  " let str = opts#get('merge_tsu') ? substitute(str, 'っ\+', 'っ', 'g') : str
  " let str = a:trim_trail_n ? str->substitute("n$", "ん", "") : str
  return str
endfunction
