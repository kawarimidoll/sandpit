function! opts#parse(opts) abort
  " マーカー
  let s:henkan_marker = get(a:opts, 'henkan_marker', '▽')
  let s:select_marker = get(a:opts, 'select_marker', '▼')
  " let s:okuri_marker = get(a:opts, 'okuri_marker', '*')

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
  let kana_table = get(a:opts, 'kana_table', k#default_kana_table())

  let shift_key_list = []
  let s:keymap_dict = {}
  for [k, val] in items(kana_table)
    let key = utils#trans_special_key(k)
    let preceding_keys = slice(key, 0, -1)
    let start_key = slice(key, 0, 1)
    let end_key = slice(key, -1)

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
    call add(s:map_cmds, [k, $"inoremap {k} <cmd>call k#ins('{keytrans(k)}')<cr>"])
  endfor
  for k in shift_key_list
    call add(s:map_cmds, [k, $"inoremap {k} <cmd>call k#ins('{tolower(k)}',1)<cr>"])
  endfor
endfunction

function! opts#get(name) abort
  return s:[a:name]
endfunction
