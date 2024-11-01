" ref: https://github.com/tani/vim-jetpack/blob/b5cf6209866c1acdf06d4047ff33e7734bfa2879/plugin/jetpack.vim#L170-L217

function s:jobcount(jobs) abort
  return len(filter(copy(a:jobs), {_, val -> s:jobstatus(val) ==# 'run'}))
endfunction

function s:jobwait(jobs, njobs) abort
  let running = s:jobcount(a:jobs)
  while running > a:njobs
    let running = s:jobcount(a:jobs)
  endwhile
endfunction

let s:jobs = {}

if has('nvim')
  function s:jobstatus(job) abort
    return jobwait([a:job], 0)[0] == -1 ? 'run' : 'dead'
  endfunction

  function job#list() abort
    let result = []
    for id in keys(s:jobs)
      call add(result, {'id': id, 'status': s:jobstatus(id)})
    endfor
    return result
  endfunction

  function job#start(cmd, opts = {}) abort
    let buf = []
    let On_out = get(a:opts, 'out', {data->0})
    let On_err = get(a:opts, 'err', {data->0})
    let On_exit = get(a:opts, 'exit', {data->0})
    let job_id = jobstart(a:cmd, {
          \   'stdin': 'null',
          \   'on_stdout': {job_id, data -> [extend(buf, data), On_out(data, job_id)]},
          \   'on_stderr': {job_id, data -> [extend(buf, data), On_err(data, job_id)]},
          \   'on_exit': {job_id-> On_exit(buf, job_id)}
          \ })
    let s:jobs[job_id] = 1
    return job_id
  endfunction
else
  function s:jobstatus(job) abort
    return job_status(a:job)
  endfunction

  function s:job_id(job)
    return job_info(a:job).process
  endfunction

  function s:job_exit_cb(buf, cb, job, ...) abort
    let ch = job_getchannel(a:job)
    while ch_status(ch) ==# 'open' | sleep 1ms | endwhile
    while ch_status(ch) ==# 'buffered' | sleep 1ms | endwhile
    call a:cb(a:buf, s:job_id(a:job))
  endfunction

  function job#list() abort
    let result = []
    for [id, job] in items(s:jobs)
      call add(result, {'id': id, 'status': s:jobstatus(job)})
    endfor
    return result
  endfunction

  function job#start(cmd, opts = {}) abort
    let buf = []
    let On_out = get(a:opts, 'out', {_->0})
    let On_err = get(a:opts, 'err', {_->0})
    let On_exit = get(a:opts, 'exit', {_->0})
    let job_opts = {
          \   'out_mode': 'raw',
          \   'out_cb': {ch, data -> [extend(buf, split(data, "\n")), On_out(split(data, "\n"), s:job_id(ch_getjob(ch)))]},
          \   'err_mode': 'raw',
          \   'err_cb': {ch, data -> [extend(buf, split(data, "\n")), On_err(split(data, "\n"), s:job_id(ch_getjob(ch)))]},
          \   'exit_cb': function('s:job_exit_cb', [buf, On_exit])
          \ }
    let in_opts = get(a:opts, 'in', {})
    if has_key(in_opts, 'buf')
      let job_opts['in_io'] = 'buffer'
      let job_opts['in_buf'] = in_opts['buf']
      if has_key(in_opts, 'top')
        let job_opts['in_top'] = in_opts['top']
      endif
      if has_key(in_opts, 'bot')
        let job_opts['in_bot'] = in_opts['bot']
      endif
    else
      let job_opts['in_io'] = 'null'
    endif
    let job = job_start(a:cmd, job_opts)
    let job_id = s:job_id(job)
    let s:jobs[job_id] = job
    return job_id
  endfunction
endif
