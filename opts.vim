let s:keyboard_key_list = 'abcdefghijklmnopqrstuvwxyz'
      \ .. 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      \ .. '0123456789!@#$%^&*()'
" \ .. "`-=[]|;',./"
" \ .. '~_+{}\:"<>?'
let s:keyboard_key_list = s:keyboard_key_list->split('\zs')
" let s:keyboard_key_list = range(32, 126)->map('nr2char(v:val)')
" if strcharlen(key) > 1 && preceding_keys !~ '\p'
"   echoerr $"[t#initialize] マッピング対象の文字列は最後の1字以外に特殊文字は使えません {k}"
"   return
" endif

function! s:strsplit(str) abort
  " 普通にsplitすると<bs>など<80>k?のコードを持つ文字を正しく切り取れないので対応
  let chars = split(a:str, '\zs')
  let prefix = split("\<bs>", '\zs')
  let result = []
  let i = 0
  while i < len(chars)
    if chars[i] == prefix[0] && chars[i+1] == prefix[1]
      call add(result, chars[i : i+2]->join(''))
      let i += 2
    else
      call add(result, chars[i])
    endif
    let i += 1
  endwhile
  return result
endfunction

function! opts#parse(opts) abort
  " マーカー
  let s:choku_marker = get(a:opts, 'choku_marker', '')
  let s:henkan_marker = get(a:opts, 'henkan_marker', '▽')
  let s:select_marker = get(a:opts, 'select_marker', '▼')
  let s:okuri_marker = get(a:opts, 'okuri_marker', '*')
  let s:choku_hl = get(a:opts, 'choku_hl', 'Normal')
  let s:henkan_hl = get(a:opts, 'henkan_hl', 'Normal')
  let s:select_hl = get(a:opts, 'select_hl', 'Normal')
  let s:okuri_hl = get(a:opts, 'okuri_hl', 'Normal')
  let s:states = {
        \ 'choku': { 'marker': s:choku_marker, 'hl': s:choku_hl },
        \ 'machi': { 'marker': s:henkan_marker, 'hl': s:henkan_hl },
        \ 'kouho': { 'marker': s:select_marker, 'hl': s:select_hl },
        \ 'okuri': { 'marker': s:okuri_marker, 'hl': s:okuri_hl },
        \ }

  " 自動補完最小文字数 (0の場合は自動補完しない)
  let s:min_auto_complete_length = get(a:opts, 'min_auto_complete_length', 0)

  " 自動補完を文字数でソートする
  let s:sort_auto_complete_by_length = get(a:opts, 'min_auto_complete_length', v:false)

  " enable時にtextwidthを0にする
  let s:textwidth_zero = get(a:opts, 'textwidth_zero', v:false)

  " Google CGI変換
  let s:use_google_cgi = get(a:opts, 'use_google_cgi', v:false)

  " 'っ'が連続したら1回と見做す
  let s:merge_tsu = get(a:opts, 'merge_tsu', v:false)

  " ユーザー辞書
  " デフォルトは~/.cache/vim/SKK-JISYO.user
  let s:user_jisyo_path = get(a:opts, 'user_jisyo_path', expand('~/.cache/vim/SKK-JISYO.user'))
  if !isabsolutepath(s:user_jisyo_path)
    throw $"user_jisyo_path must be absolute path {s:user_jisyo_path}"
  endif
  " 指定されたパスにファイルがなければ作成する
  if glob(s:user_jisyo_path)->empty()
    call fnamemodify(s:user_jisyo_path, ':p:h')
          \ ->iconv(&encoding, &termencoding)
          \ ->mkdir('p')
    call writefile([
          \ ';; フォーマットは以下',
          \ ';; yomi /(henkan(;setsumei)?/)+',
          \ ';; コメント行は変更しないでください',
          \ ';;',
          \ ';; okuri-ari entries.',
          \ ';; okuri-nasi entries.',
          \ ], s:user_jisyo_path)
  endif

  " 変換辞書リスト
  let s:jisyo_list = get(a:opts, 'jisyo_list', [])
  if indexof(s:jisyo_list, $'v:val.path ==# "{s:user_jisyo_path}"') < 0
    " ユーザー辞書がリストに無ければ先頭に追加する
    " マークはU エンコードはutf-8
    call insert(s:jisyo_list, { 'path': s:user_jisyo_path, 'encoding': 'utf-8', 'mark': '[U]' })
  endif
  for jisyo in s:jisyo_list
    if jisyo.path =~ ':'
      throw $"jisyo.path must NOT includes ':' {jisyo.path}"
    elseif !filereadable(jisyo.path)
      throw $"jisyo.path can't be read {jisyo.path}"
    endif

    let jisyo.mark = get(jisyo, 'mark', '')
    let encoding = get(jisyo, 'encoding', '') ==# '' ? 'auto' : jisyo.encoding
    let jisyo.grep_cmd = $'rg --no-line-number --encoding {encoding} "^:q:" {jisyo.path}'
  endfor

  " かなテーブル
  let kana_table = get(a:opts, 'kana_table', t#default_kana_table())

  let shift_key_list = []
  let s:keymap_dict = {}
  for [k, val] in items(kana_table)
    let keys = utils#trans_special_key(k)->s:strsplit()
    let preceding_keys = slice(keys, 0, -1)->join('')
    let start_key = slice(keys, 0, 1)->join('')
    let end_key = slice(keys, -1)->join('')

    if !has_key(s:keymap_dict, end_key)
      let s:keymap_dict[end_key] = {}
    endif
    let s:keymap_dict[end_key][preceding_keys] = val

    " start_keyもkeymap_dictに登録する(入力開始位置の指定のため)
    if !has_key(s:keymap_dict, start_key)
      let s:keymap_dict[start_key] = {}
    endif
    " 文字入力を開始するアルファベットのキーは変換開始キーとして使用する
    if type(val) == v:t_string && start_key =~# '^\l$'
      call utils#uniq_add(shift_key_list, toupper(start_key))
    endif
  endfor

  " 入力テーブルに既に含まれている大文字は変換開始に使わない
  call filter(shift_key_list, '!has_key(s:keymap_dict, v:val)')

  let s:map_cmds = []
  for key in s:keymap_dict->keys()
    let k = keytrans(key)
    call add(s:map_cmds, [k, $"inoremap {k} <cmd>call t#ins('{keytrans(k)}')<cr>"])
  endfor
  for k in shift_key_list
    call add(s:map_cmds, [k, $"inoremap {k} <cmd>call t#ins('{tolower(k)}',1)<cr>"])
  endfor
endfunction

function! opts#get(name) abort
  return s:[a:name]
endfunction
