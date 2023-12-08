source ./inline_mark.vim
source ./utils.vim
source ./phase.vim

function! s:is_completed() abort
  return get(complete_info(), 'selected', -1) >= 0
endfunction

function! s:set_store(target, str) abort
  let s:store[a:target] = a:str
endfunction
function! s:get_store(target) abort
  return s:store[a:target]
endfunction
function! s:clear_store() abort
  let s:store = { 'choku': '', 'machi': '', 'okuri': '' }
endfunction

function! virt_poc#enable() abort
  if s:is_enable
    return
  endif

  let s:keys_to_remaps = []
  for key in keys(s:map_keys_dict)
    let current_map = maparg(key, 'i', 0, 1)
    let k = keytrans(key)
    call add(s:keys_to_remaps, empty(current_map) ? k : current_map)
    execute $"inoremap {k} <cmd>call virt_poc#ins('{keytrans(k)}')<cr><cmd>call virt_poc#after_ins()<cr>"
  endfor

  augroup virt_poc#augroup
    autocmd!
    autocmd InsertLeave * call virt_poc#disable()
    autocmd CompleteDonePre *
          \   call phase#disable('kouho')
          \ | if s:is_completed()
          \ |   call phase#disable('machi')
          \ |   call s:set_store('machi', '')
          \ |   call s:set_store('okuri', '')
          \ | endif
  augroup END

  call phase#clear()
  call s:clear_store()
  let s:is_enable = v:true
endfunction

function! virt_poc#disable() abort
  if !s:is_enable
    return
  endif
  for k in s:keys_to_remaps
    try
      if type(k) == v:t_string
        execute 'iunmap' k
      else
        call mapset('i', 0, k)
      endif
    catch
      echomsg k v:exception
    endtry
  endfor

  call phase#clear()
  call s:clear_store()
  " call inline_mark#clear()
  let s:is_enable = v:false
endfunction

function! virt_poc#toggle() abort
  return s:is_enable ? virt_poc#disable() : virt_poc#enable()
endfunction

function! virt_poc#init() abort
  let raw_kana_table = json_decode(join(readfile('./kana_table.json'), "\n"))

  let s:preceding_keys_dict = {}
  let s:map_keys_dict = {}
  let s:kana_table = {}
  for [k, val] in items(raw_kana_table)
    let key = utils#trans_special_key(k)->keytrans()
    let s:kana_table[key] = val

    let chars = utils#trans_special_key(k)->utils#strsplit()

    if len(chars) > 1
      let s:preceding_keys_dict[slice(chars, 0, -1)->join('')] = 1
    endif
    for char in chars
      let s:map_keys_dict[char] = 1
    endfor
  endfor
  " echo s:preceding_keys_dict
  let s:is_enable = v:false
endfunction

let s:kana_input_namespace = 'kana_input_namespace'

function! virt_poc#ins(key) abort
  " echomsg $'key {a:key}'
  let spec = s:get_spec(a:key)

  if type(spec) == v:t_string
    if phase#is_enabled('kouho')
      call feedkeys("\<c-y>", 'ni')
    endif
    if spec !=# ''
      echomsg 'feed' spec
      call feedkeys(spec, 'ni')
      if phase#is_enabled('okuri')
        call s:set_store('okuri', s:get_store('okuri') .. spec)
      elseif phase#is_enabled('machi')
        call s:set_store('machi', s:get_store('machi') .. spec)
      endif
    endif
    return
  endif

  echomsg spec
  if has_key(spec, 'func')
    if spec.func ==# 'backspace'
      if phase#is_enabled('kouho')
        call phase#disable('kouho')
      elseif phase#is_enabled('okuri') && utils#compare_pos(getpos('.')[1:2], phase#getpos('okuri')) == 0
        call phase#disable('okuri')
        return
      elseif phase#is_enabled('machi') && utils#compare_pos(getpos('.')[1:2], phase#getpos('machi')) == 0
        call phase#disable('machi')
        return
      endif

      if s:get_store('choku') ==# ''
        call feedkeys("\<bs>", 'ni')
      else
        call s:set_store('choku', s:get_store('choku')->substitute('.$', '', ''))
      endif
    elseif spec.func ==# 'kakutei'
      if phase#is_enabled('kouho')
        call feedkeys("\<c-y>", 'ni')
        call phase#disable('machi')
      elseif phase#is_enabled('machi')
        call phase#disable('machi')
      else
        call feedkeys("\<cr>", 'ni')
        call s:set_store('choku', '')
      endif
    elseif spec.func ==# 'henkan'
      if phase#is_enabled('kouho')
        call feedkeys("\<c-n>", 'ni')
      elseif phase#is_enabled('machi')
        echomsg $'machi {s:get_store("machi")} okuri {s:get_store("okuri")}'
        call complete(phase#getpos('machi')[1], ['a', 'b', 'c'])
        call phase#enable('kouho')
        call feedkeys("\<c-n>", 'ni')
      else
        call feedkeys(utils#trans_special_key(a:key), 'ni')
      endif
    elseif spec.func ==# 'sticky'
      if phase#is_enabled('kouho')
      " nop
      elseif phase#is_enabled('okuri')
      " nop
      elseif phase#is_enabled('machi')
        call phase#enable('okuri')
      else
        call phase#enable('machi')
      endif
    endif
  endif
endfunction

function! s:get_spec(key) abort
  let current = s:get_store('choku') .. a:key
  " echomsg $'spec choku {s:get_store("choku")}'

  if has_key(s:kana_table, current)
    " s:store.chokuの残存文字と合わせて完成した場合
    if type(s:kana_table[current]) == v:t_dict
      return s:kana_table[current]
    endif
    let [kana, roma; _rest] = s:kana_table[current]->split('\A*\zs') + ['']
    call s:set_store('choku', roma)
    return kana
  elseif has_key(s:preceding_keys_dict, current)
    " 完成はしていないが、先行入力の可能性がある場合
    call s:set_store('choku', current)
    " echomsg $'choku {s:get_store("choku")}'
    return ''
  endif

  let spec = get(s:kana_table, a:key, '')

  " 半端な文字はバッファに載せる
  " ただしdel_mis_charがtrueなら消す
  if !s:del_mis_char || type(spec) == v:t_dict
    call feedkeys(s:get_store('choku'), 'ni')
  endif
  if type(spec) == v:t_string
    call s:set_store('choku', a:key)
  else
    call s:set_store('choku', '')
  endif

  return spec
endfunction

let s:del_mis_char = 1

function! virt_poc#after_ins() abort
  " echomsg $'after choku {s:get_store("choku")}'
  if s:get_store('choku') ==# ''
    call inline_mark#clear(s:kana_input_namespace)
    if phase#is_enabled('okuri')
      if utils#compare_pos(phase#getpos('okuri'), getpos('.')[1:2]) > 0
        call complete(phase#getpos('machi')[1], ['x', 'y', 'z']->map({_,v->v .. s:get_store('okuri')}))
        call phase#disable('okuri')
        call phase#enable('kouho')
        call feedkeys("\<c-n>", 'ni')
      endif
    elseif !phase#is_enabled('kouho') && phase#is_enabled('machi') && s:get_store('machi') !=# ''
      " auto complete
      call complete(phase#getpos('machi')[1], ['s', 't', 'u'])
    endif
  else
    call inline_mark#put(line('.'), col('.'), {
          \ 'name': s:kana_input_namespace,
          \ 'text': s:get_store('choku')})
  endif
endfunction

inoremap <c-j> <cmd>call virt_poc#toggle()<cr>
inoremap <c-k> <cmd>imap<cr>
inoremap <c-p> <cmd>echo phase#getpos('kana_input_namespace')<cr>

call virt_poc#init()
