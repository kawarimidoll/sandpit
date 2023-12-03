" sample
" nnoremap sm <cmd>call inline_mark#put(getpos('.')[1:2], '▽')<cr>
" nnoremap sn <cmd>call inline_mark#clear()<cr>

" namespaceのキーまたはproptypeにファイルパスを使い、
" 名前が他のプラグインとぶつかるのを防ぐ
let s:file_name = expand('%:p')
let s:default_hl = 'Normal'

if has('nvim')
  let s:ns_id = -1

  function! inline_mark#clear() abort
    if s:ns_id < 0
      return
    endif
    call nvim_buf_clear_namespace(0, s:ns_id, 0, -1)
    let s:ns_id = -1
  endfunction

  function! inline_mark#put(lnum, col, opts = {}) abort
    let hl = get(a:opts, 'hl', '')->empty() ? s:default_hl : a:opts.hl
    let text = get(a:opts, 'text', '')

    if s:ns_id < 0
      let s:ns_id = nvim_create_namespace(s:file_name)
    endif

    " nvim_buf_set_extmarkは0-basedなので、1を引く
    call nvim_buf_set_extmark(0, s:ns_id, a:lnum - 1, a:col - 1, {
          \   'virt_text': [[text, hl]],
          \   'virt_text_pos': 'inline',
          \   'right_gravity': v:false
          \ })
  endfunction
else
  function! inline_mark#clear() abort
    call prop_type_delete(s:file_name, {})
  endfunction

  function! inline_mark#put(lnum, col, opts = {}) abort
    let hl = get(a:opts, 'hl', '')->empty() ? s:default_hl : a:opts.hl
    let text = get(a:opts, 'text', '')

    if empty(prop_type_get(s:file_name))
      call prop_type_add(s:file_name, {'highlight': hl, 'start_incl':1})
    endif

    call prop_add(a:lnum, a:col, {
          \   'type': s:file_name,
          \   'text': text,
          \ })
  endfunction
endif
