let s:is_dict = {item -> type(item) == v:t_dict}
let s:is_list = {item -> type(item) == v:t_list}
let s:is_string = {item -> type(item) == v:t_string}
let s:has_key = {item, key -> s:is_dict(item) && has_key(item, key)}
let s:get = {item, key, default -> s:has_key(item, key) ? item[key] : default}
let s:ensure_list = {item -> s:is_list(item) ? item : [item]}
" let s:throw = {msg -> execute($'throw {string(msg)}')}

function s:sub_special(str) abort
  return substitute(a:str, '<[^>]*>', {m -> eval($'"\{m[0]}"')}, 'g')
endfunction

function s:split(str) abort
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

let s:recursive_feed_list = []
let s:recall = $"\<cmd>call {expand('<SID>')}autoplay()\<cr>"
function s:autoplay() abort
  if empty(s:recursive_feed_list)
    return
  endif
  let proc = remove(s:recursive_feed_list, 0)
  let feed = s:has_key(proc, 'call') ? [call(proc.call, get(proc, 'args', [])), ''][1]
        \ : s:has_key(proc, 'expr') ? call(proc.expr, get(proc, 'args', []))
        \ : s:has_key(proc, 'eval') ? eval(proc.eval)
        \ : s:has_key(proc, 'exec') ? [execute(proc.exec), ''][1]
        \ : s:has_key(proc, 'text') ? proc.text
        \ : proc
  let wait = s:get(proc, 'wait', s:wait)

  if s:is_list(feed)
    call extend(s:recursive_feed_list, feed, 0)
    let feed = ''
    let wait = 0
  endif

  call timer_start(wait, {->feedkeys(s:sub_special(feed) .. s:recall, s:flag)})
endfunction

function autoplay#run(key = '') abort
  let config = s:configs[a:key]
  let s:wait = get(config, 'wait', 0)
  let s:flag = 'i' .. (get(config, 'mappings', v:true) ? 'm' : 'n')
  let scripts = get(config, 'scripts', [])->s:ensure_list()
  if empty(scripts)
    return
  endif
  if get(config, 'spell_out', 0)
    call map(scripts, {_,v -> s:is_string(v) ? s:split(v) : v })
  endif
  let s:recursive_feed_list = scripts
  call s:autoplay()
endfunction

let s:configs = {}
function autoplay#reserve(config) abort
  let s:configs[get(a:config, 'key', '')] = a:config
endfunction

call autoplay#reserve({
      \ 'wait': 40,
      \ 'spell_out': 1,
      \ 'scripts': [
      \   "\<c-l>iAutoplay start!\<cr>",
      \   "This plugin will operate Vim automatically.\<cr>",
      \   "You can use any commands in Vim!\<cr>",
      \   "For example, open help window :)\<esc>",
      \   {'text': '', 'wait': 200},
      \   {'exec': 'h index'},
      \   {'exec': 'wincmd w'},
      \   {'text': '', 'wait': 150},
      \   "\<c-l>GoIt looks cool, right?\<esc>",
      \   {'exec': 'only!'},
      \   "oIt will be useful for making Demo.\<esc>",
      \ ],
      \ })

" call autoplay#run()

