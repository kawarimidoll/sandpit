function! s:parse_henkan_list(lines, jisyo, okuri = '') abort
  if empty(a:lines)
    return []
  endif

  let henkan_list = []

  for line in a:lines
    " よみ /変換1/変換2/.../
    " stridxがバイトインデックスなのでstrpartを使う
    let space_idx = stridx(line, ' /')
    let yomi = strpart(line, 0, space_idx)
    let henkan_str = strpart(line, space_idx+1)
    for v in split(henkan_str, '/')
      " ;があってもなくても良いよう_restを使う
      let [word, info; _rest] = split(v, ';') + ['']
      " :h complete-items
      call add(henkan_list, {
            \ 'word': word .. a:okuri,
            \ 'menu': $'{a:jisyo.mark}{info}',
            \ 'info': $'{a:jisyo.mark}{info}',
            \ 'user_data': { 'yomi': trim(yomi), 'path': a:jisyo.path }
            \ })
    endfor
  endfor

  return henkan_list
endfunction

function! s:gen_henkan_query(str, opts = {}) abort
  let str = a:str
  if opts#get('merge_tsu')
  let str = substitute(str, 'っ\+', 'っ', 'g')
  endif
  if opts#get('trailing_n') && !get(a:opts, 'no_trailing_n', v:false)
    let str = substitute(str, 'n$', 'ん', '')
  endif
  if opts#get('smart_vu')
    let str = substitute(str, 'ゔ\|う゛', '(ゔ|う゛)', 'g')
  endif
  if opts#get('awk_ignore_case')
    let str = str->substitute('あ', '(あ|ぁ)', 'g')
          \ ->substitute('い', '(い|ぃ)', 'g')
          \ ->substitute('う', '(う|ぅ)', 'g')
          \ ->substitute('え', '(え|ぇ)', 'g')
          \ ->substitute('お', '(お|ぉ)', 'g')
          \ ->substitute('わ', '(わ|ゎ)', 'g')
          \ ->substitute('か', '(か|ゕ)', 'g')
          \ ->substitute('け', '(け|ゖ)', 'g')
  endif
  return str
endfunction

function! henkan_list#update_async(str, exact_match) abort
  call utils#debug_log($'async start {a:str}')
  let str = s:gen_henkan_query(a:str, { 'no_trailing_n': v:true })
  let suffix = a:exact_match ? '' : '[^!-~]*'

  let s:latest_async_henkan_list = []
  let s:run_job_list = []

  for jisyo in opts#get('jisyo_list')
    let cmd = substitute(jisyo.grep_cmd, ':q:', $'{str}{suffix} /', '')
    let job_id = job#start(cmd, { 'exit': funcref('s:on_exit') })
    call add(s:run_job_list, [job_id, jisyo])
    call utils#debug_log($'start {job_id}')
  endfor
endfunction

let s:async_result_dict = {}

function! s:on_exit(data, job_id) abort
  let s:async_result_dict[a:job_id] = a:data
  " call utils#debug_log($'on_exit {a:job_id}')
  " call utils#debug_log($'list {s:run_job_list->copy()->map("v:val[0]")->join(" ")} / {s:async_result_dict->keys()->join(" ")}')

  " 手動変換がスタートしていたら自動補完はキャンセルする
  if states#in('kouho')
    call utils#debug_log('manual select is started')
    return
  endif

  " 蓄積された候補を辞書リストの順に並び替える
  let henkan_list = []
  let is_finished = v:true
  for [job_id, jisyo] in s:run_job_list
    if !has_key(s:async_result_dict, job_id)
      " 検索が終わっていない辞書がある場合は早期終了
      " call utils#debug_log($'{job_id} is not finished')
      " return
      let is_finished = v:false
      continue
    endif

    call extend(henkan_list, s:parse_henkan_list(s:async_result_dict[job_id], jisyo))
  endfor
  " call utils#debug_log('create henkan list')
  " call utils#debug_log(henkan_list)

  if is_finished
    " すべての辞書の検索が終わったら蓄積変数をクリア
    let s:async_result_dict = {}
  endif
  if empty(henkan_list)
    return
  endif

  if opts#get('sort_auto_complete_by_length')
    call sort(henkan_list, {a, b -> strcharlen(a.user_data.yomi) - strcharlen(b.user_data.yomi)})
  endif

  let s:latest_async_henkan_list = henkan_list
  call feedkeys("\<c-r>=k#autocompletefunc()\<cr>", 'n')
endfunction

" 送りなし検索→str='けんさく',okuri=''
" 送りあり検索→str='しら',okuri='べ'
function! henkan_list#update_manual(str, okuri = '') abort
  let str = s:gen_henkan_query(a:str)

  if a:okuri !=# ''
    let consonant = utils#consonant(strcharpart(a:okuri, 0, 1))
    let str ..= consonant
  endif

  let henkan_list = []
  for jisyo in opts#get('jisyo_list')
    let cmd = substitute(jisyo.grep_cmd, ':q:', $'{str} /', '')
    let lines = systemlist(substitute(cmd, ':query:', $'{str} ', 'g'))
    call extend(henkan_list, s:parse_henkan_list(lines, jisyo, a:okuri))
  endfor
  let s:latest_henkan_list = henkan_list
endfunction

function! henkan_list#update_fuzzy(str, exact_match = '') abort
  let str = s:gen_henkan_query(a:str)
  let suffix = a:exact_match ? '' : '[^!-~]*'

  let henkan_list = []
  for jisyo in opts#get('jisyo_list')
    let cmd = substitute(jisyo.grep_cmd, ':q:', $'{str}{suffix} /', '')
    let lines = systemlist(substitute(cmd, ':query:', $'{str} ', 'g'))
    call extend(henkan_list, s:parse_henkan_list(lines, jisyo))
  endfor

  if opts#get('sort_auto_complete_by_length')
    call sort(henkan_list, {a, b -> strcharlen(a.user_data.yomi) - strcharlen(b.user_data.yomi)})
  endif

  let s:latest_fuzzy_henkan_list = henkan_list
endfunction
function! henkan_list#get_fuzzy() abort
  return get(s:, 'latest_fuzzy_henkan_list', [])
endfunction

function! henkan_list#get(async = v:false) abort
  let target = a:async ? 'latest_async_henkan_list' : 'latest_henkan_list'
  return get(s:, target, [])
endfunction

function! henkan_list#insert(item) abort
  return insert(s:latest_henkan_list, a:item)
endfunction
