" sample
" nnoremap sm <cmd>call inline_mark#put(line('.'), col('.'), {'name':'m','text':'▽'})<cr>
" nnoremap sM <cmd>call inline_sark#put(line('.'), col('.'), {'name':'M','text':'▼'})<cr>
" nnoremap snm <cmd>call inline_mark#clear('m')<cr>
" nnoremap snM <cmd>call inline_mark#clear('M')<cr>
" nnoremap snn <cmd>call inline_mark#clear()<cr>

" namespaceのキーまたはproptypeにファイルパスを使い、
" 名前が他のプラグインとぶつかるのを防ぐ
let s:file_name = expand('%:p')
let s:default_hl = 'Normal'

if has('nvim')
  let s:ns_dict = {}

  function! inline_mark#clear(name = '') abort
    if a:name ==# ''
      call nvim_buf_clear_namespace(0, -1, 0, -1)
      let s:ns_dict = {}
    elseif has_key(s:ns_dict, a:name)
      call nvim_buf_clear_namespace(0, s:ns_dict[a:name], 0, -1)
      call remove(s:ns_dict, a:name)
    endif
  endfunction

  function! inline_mark#put(lnum, col, opts = {}) abort
    let hl = get(a:opts, 'hl', '')->empty() ? s:default_hl : a:opts.hl
    let text = get(a:opts, 'text', '')
    let name = get(a:opts, 'name', s:file_name)

    call inline_mark#clear(name)
    let ns_id = nvim_create_namespace(name)
    let s:ns_dict[name] = ns_id

    " nvim_buf_set_extmarkは0-basedなので、1を引く
    call nvim_buf_set_extmark(0, ns_id, a:lnum - 1, a:col - 1, {
          \   'virt_text': [[text, hl]],
          \   'virt_text_pos': 'inline',
          \   'right_gravity': v:false
          \ })
  endfunction
else
  let s:prop_types = {}

  function! inline_mark#clear(name = '') abort
    if a:name ==# ''
      for k in s:prop_types->keys()
        call prop_type_delete(k, {})
      endfor
      let s:prop_types = {}
    elseif has_key(s:prop_types, a:name)
      call prop_type_delete(a:name, {})
      call remove(s:prop_types, a:name)
    endif
  endfunction

  function! inline_mark#put(lnum, col, opts = {}) abort
    let hl = get(a:opts, 'hl', '')->empty() ? s:default_hl : a:opts.hl
    let text = get(a:opts, 'text', '')
    let name = get(a:opts, 'name', s:file_name)

    call inline_mark#clear(name)
    call prop_type_add(name, {'highlight': hl, 'start_incl':1})
    let s:prop_types[name] = 1

    call prop_add(a:lnum, a:col, {
          \   'type': name,
          \   'text': text,
          \ })
  endfunction
endif
