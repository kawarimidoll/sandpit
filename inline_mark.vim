" sample
" nnoremap sm <cmd>call inline_mark#display(getpos('.')[1:2], '▽')<cr>
" nnoremap sn <cmd>call inline_mark#clear()<cr>

" namespaceのキーまたはproptypeにファイルパスを使い、
" 名前が他のプラグインとぶつかるのを防ぐ
let s:file_name = expand('%:p')
let s:hl = 'Normal'

if has('nvim')
  let s:ns_id = -1

  function! inline_mark#clear() abort
    if s:ns_id < 0
      return
    endif
    call nvim_buf_clear_namespace(0, s:ns_id, 0, -1)
    let s:ns_id = -1
  endfunction

  function! inline_mark#display(lnum, col, text) abort
    if s:ns_id < 0
      let s:ns_id = nvim_create_namespace(s:file_name)
    endif

    " nvim_buf_set_extmarkは0-basedなので、1を引く
    call nvim_buf_set_extmark(0, s:ns_id, a:lnum - 1, a:col - 1, {
          \   'virt_text': [[a:text, s:hl]],
          \   'virt_text_pos': 'inline',
          \   'right_gravity': v:false
          \ })
  endfunction
else
  function! inline_mark#clear() abort
    call prop_type_delete(s:file_name, {})
  endfunction

  function! inline_mark#display(lnum, col, text) abort
    if empty(prop_type_get(s:file_name))
      call prop_type_add(s:file_name, {'highlight': s:hl, 'start_incl':1})
    endif

    call prop_add(a:lnum, a:col, {
          \   'type': s:file_name,
          \   'text': a:text,
          \ })
  endfunction
endif