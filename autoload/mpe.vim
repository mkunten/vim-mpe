" autoload/mpe.vim

let s:mpe_job = v:null

function! s:conf(key) abort
  return get(g:mpe_config, a:key, v:null)
endfunction

" main functions

function! mpe#open(...) abort
  let l:target_file = a:0 > 0 ? a:1 : expand('%:t')
  if mpe#status()
    call s:open_browser_url(l:target_file)
  else
    echo "MPE: Starting server..."
    call mpe#start(l:target_file)
  endif
endfunction

function! mpe#status() abort
  return (type(s:mpe_job) == v:t_job && job_status(s:mpe_job) ==# 'run')
        \ ? 1 : 0
endfunction

function! mpe#start(filename) abort
  if mpe#status() | return | endif

  let l:node = s:conf('node_path')
  let l:server_root = s:conf('server_root')
  if !executable(l:node)
    echoerr "MPE: Node.js not found at " . l:node
    return
  endif
  if !isdirectory(l:server_root . '/node_modules') ||
        \ !filereadable(s:conf('jar_path'))
    echo "MPE: Dependencies missing. Running MpeInstall..."
    call mpe#install(0)
    return
  endif

  let l:env = {
        \ 'MPE_PORT': s:conf('port'),
        \ 'MPE_CODE_BLOCK_THEME': s:conf('code_block_theme'),
        \ 'MPE_MERMAID_THEME': s:conf('mermaid_theme'),
        \ 'MPE_JAR_PATH': s:conf('jar_path'),
        \ }

  let s:mpe_job = job_start([l:node, l:server_root . '/server.js'], {
        \ 'cwd': expand('%:p:h'),
        \ 'env': l:env,
        \ 'out_cb': {ch, msg -> s:on_server_output(msg, a:filename)},
        \ 'err_cb': {ch, msg -> s:on_server_error(msg)},
        \ 'exit_cb': {job, status -> s:on_server_exit(status)},
        \ })
endfunction

function! mpe#stop() abort
  if !mpe#status() | return | endif
  call job_stop(s:mpe_job)
  let s:mpe_job = v:null
  echomsg "MPE: Server stopped."
endfunction

" messaging

function! mpe#sync_line() abort
  if !mpe#status() | return | endif
  let l:url = 'http://localhost:' . s:conf('port') . '/_api/scroll'
  let l:data = json_encode({'file': expand('%:t'), 'line': line('.')})
  call job_start(['curl', '-s', '-X', 'POST',
        \  '-H', 'Content-Type: application/json', '-d', l:data, l:url],
        \ {'out_io': 'null', 'err_io': 'null'})
endfunction

function! mpe#reload() abort
  if !mpe#status() | return | endif
  let l:url = 'http://localhost:' . s:conf('port') . '/_api/reload'
  let l:data = json_encode({'file': expand('%:t')})
  call job_start(['curl', '-s', '-X', 'POST',
        \  '-H', 'Content-Type: application/json', '-d', l:data, l:url],
        \ {'out_io': 'null', 'err_io': 'null'})
endfunction

" installation

function! mpe#install(force) abort
  let l:server_dir = s:conf('server_root')
  let l:jar_path = s:conf('jar_path')
  if !isdirectory(l:server_dir) | call mkdir(l:server_dir, 'p') | endif

  if a:force
    echo "MPE: Cleaning up..."
    call s:rm_rf(l:server_dir . '/node_modules')
    if filereadable(l:jar_path) | call delete(l:jar_path) | endif
  endif

  echo "MPE: [1/2] Installing npm dependencies..."
  let l:npm_cmd = has('win32')
        \ ? ['cmd', '/c', 'npm', 'install'] : ['npm', 'install']
  call job_start(l:npm_cmd, {
        \ 'cwd': l:server_dir,
        \ 'exit_cb': {j, s -> s:on_npm_done(s)},
        \ 'err_io': 'buffer',
        \ 'err_name': 'mpe_npm_error'
        \ })
endfunction

" utilities

function! s:on_server_output(msg, filename) abort
  if a:msg =~# 'MPE Server is listening'
    echomsg "MPE: Server is ready."
    if type(a:filename) == v:t_string && !empty(a:filename)
      call s:open_browser_url(a:filename)
    endif
  endif
endfunction

function! s:on_server_exit(status) abort
  let s:mpe_job = v:null
  if a:status > 0
    echoerr "MPE: Server exited with status " . a:status
  endif
endfunction

function! s:on_server_error(msg) abort
  if a:msg =~# 'EADDRINUSE'
    echoerr "MPE: Port " . s:conf('port') . " is already in use."
  else
    echoerr "MPE Server Error: " . a:msg
  endif
endfunction

function! s:on_npm_done(status) abort
  if a:status != 0
    echoerr "MPE: npm install failed. Check buffer 'mpe_npm_error'."
    return
  endif
  let l:jar_path = s:conf('jar_path')
  if !filereadable(l:jar_path)
    echo "MPE: [2/2] Downloading PlantUML.jar ..."
    call job_start(['curl', '-L', '-o', l:jar_path, s:conf('jar_url')],
          \ {'exit_cb': {j, s -> s:on_install_complete(s)}})
  else
    call s:on_install_complete(0)
  endif
endfunction

function! s:on_install_complete(status) abort
  if a:status == 0
    echomsg "MPE: Installation completed!"
  else
    echoerr "MPE: Installation failed."
  endif
endfunction

function! s:open_browser_url(filename) abort
  let l:url = 'http://localhost:' . s:conf('port') . '/' . a:filename
  if executable('explorer.exe')
    call system('explorer.exe ' . shellescape(l:url))
  elseif has('mac') || executable('open')
    call system('open ' . shellescape(l:url))
  elseif executable('xdg-open')
    call system('xdg-open ' . shellescape(l:url) . ' &')
  else
    echoerr "MPE: No browser launcher found (explorer.exe, open, or xdg-open)."
  endif
endfunction

function! s:rm_rf(path) abort
  if empty(a:path) || a:path == '/' | return | endif
  let l:cmd = has('win32')
    ? ['cmd', '/c', 'rd', '/s', '/q'] : ['rm', '-rf']
  call job_start(l:cmd + [a:path])
endfunction
