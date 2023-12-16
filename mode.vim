let s:mode_dict = {
      \ 'hira': { 'conv': 'converters#as_is' },
      \ 'zen_kata': { 'conv': 'converters#hira_to_kata' },
      \ 'han_kata': { 'conv': 'converters#hira_to_han_kata' },
      \ 'zen_alnum': { 'conv': 'converters#alnum_to_zen_alnum', 'direct': v:true },
      \ 'abbrev': { 'conv': 'converters#as_is', 'direct': v:true, 'start_sticky': v:true },
      \ }

function! mode#current_name() abort
  return s:current_mode.name
endfunction

function! mode#is_start_sticky() abort
  return  get(s:current_mode, 'start_sticky', v:false)
endfunction

function! mode#is_direct() abort
  return get(s:current_mode, 'direct', v:false)
endfunction

function! mode#is_direct_v2(char) abort
  return a:char =~ '^[!-~]$' && get(s:current_mode, 'direct', v:false)
endfunction

function! mode#convert(...) abort
  return call(funcref(s:current_mode.conv), a:000)
endfunction

function! mode#clear() abort
  let s:current_mode = s:mode_dict.hira
endfunction

function! mode#set(mode_name) abort
  if phase#is_enabled('kouho') || phase#is_enabled('okuri')
    " nop
    return
  endif

  let selected_mode = (a:mode_name ==# mode#current_name()) ? s:mode_dict.hira
        \ : s:mode_dict[a:mode_name]

  if phase#is_enabled('machi')
    call store#clear('choku')
    let machistr = store#get('machi')
    let feed = repeat("\<bs>", strcharlen(machistr)) .. call(funcref(selected_mode.conv), [machistr])
    " echomsg 'feed' feed
    call feedkeys(feed, 'n')
    call store#clear('machi')
    call phase#disable('machi')
  else
    let s:current_mode = selected_mode
    echo $'{mode#current_name()} mode'
  endif
endfunction

function! mode#get_alt(mode_name) abort
  return (a:mode_name ==# mode#current_name()) ? s:mode_dict.hira : s:mode_dict[a:mode_name]
endfunction
function! mode#convert_alt(mode_name, ...) abort
  let selected_mode = mode#get_alt(a:mode_name)
  return call(selected_mode.conv, a:000)
endfunction
function! mode#set_alt(mode_name) abort
  let s:current_mode = mode#get_alt(a:mode_name)
  echo $'{mode#current_name()} mode'
  return s:current_mode
endfunction

" initialize dict
for [key, val] in items(s:mode_dict)
  let val.name = key
endfor

call mode#clear()
