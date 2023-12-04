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

function! s:getpos() abort
  return getpos('.')[1:2]
endfunction

function! states#clear() abort
  for t in s:states->keys()
    call states#off(t)
  endfor
endfunction

function! states#on(target) abort
  let [lnum, col] = s:getpos()
  let opt_states = opts#get('states')[a:target]
  let text = opt_states.marker
  let hl = opt_states.hl
  call inline_mark#put(lnum, col, {'name': a:target, 'text': text, 'hl': hl})
  let s:states[a:target] = [lnum, col]
endfunction

function! states#off(target) abort
  call inline_mark#clear(a:target)
  let s:states[a:target] = []
endfunction

function! states#get(target) abort
  return s:states[a:target]
endfunction

function! states#in(target) abort
  if empty(s:states[a:target])
    return v:false
  endif
  let [pos_l, pos_c] = s:states[a:target]
  let [cur_l, cur_c] = s:getpos()
  return pos_l ==# cur_l && pos_c <= cur_c
endfunction

function! states#getstr(target) abort
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
