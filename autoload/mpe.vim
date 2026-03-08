" autoload/vim-mpe.vim

let s:mpe_job = v:none

" mpe#install()
function! mpe#install() abort
  let l:server_dir = g:mpe_root . '/server'

  echo "MPE: [1/2] Installing npm dependencies..."
  let l:npm_job = job_start(['npm', 'install'], {
        \ 'cwd': l:server_dir,
        \ 'exit_cb': {j, s -> s:on_npm_done(s)},
        \ 'err_io': 'buffer',
        \ 'err_name': 'npm_error_log'
        \ })
endfunction

function! s:on_npm_done(status) abort
  if a:status != 0
    echoerr "MPE: npm install failed. Check 'server/node_modules' setup."
    return
  endif

  if !filereadable(g:mpe_jar_path)
    echo "MPE: [2/2] Downloading PlantUML.jar ..."
    call job_start(['curl', '-L', '-o', g:mpe_jar_path, g:mpe_jar_url], {
          \ 'exit_cb': {j, s -> s:on_install_complete(s)}
          \ })
  else
    echo "MPE: PlantUML.jar already exists. Skipping download."
    call s:on_install_complete(0)
  endif
endfunction

function! s:on_install_complete(status) abort
  if a:status == 0
    echomsg "MPE: All installations completed!"
  else
    echoerr "MPE: Failed to download PlantUML.jar."
  endif
endfunction

" mpe#start()
function! mpe#start() abort
  let l:node_modules = g:mpe_root . '/server/node_modules'
  if !isdirectory(l:node_modules)
    echo "MPE: node_modules not found. Running mpe#install()..."
    call mpe#install()
    return
  endif

  if type(s:mpe_job) == v:t_job && job_status(s:mpe_job) ==# 'run'
    call s:open_browser_url()
    return
  endif

  let l:file_name = expand('%:t')
  let l:work_dir = expand('%:p:h')
  let l:server_script = g:mpe_root . '/server/server.js'

  let l:env = {
        \ 'MPE_PORT': g:mpe_port,
        \ 'MPE_JAR_PATH': g:mpe_jar_path
        \ }

  let s:mpe_job = job_start([g:mpe_node_path, l:server_script, l:file_name], {
        \ 'cwd': l:work_dir,
        \ 'env': l:env,
        \ })

  " delay to open: 1s
  call timer_start(1000, { -> s:open_browser_url() })

  augroup Mpe_Sync
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> call mpe#sync_line()
    autocmd BufWritePost <buffer> call mpe#reload()
    autocmd VimLeave * call mpe#stop()
  augroup END
endfunction

" mpe#stop
function! mpe#stop() abort
  if type(s:mpe_job) == v:t_job && job_status(s:mpe_job) ==# 'run'
    call job_stop(s:mpe_job)
    let s:mpe_job = v:none
    echo "MPE Server stopped."
  endif
endfunction

function! s:open_browser_url() abort
  let l:url = 'http://localhost:' . g:mpe_port . '/preview/' . expand('%:t')
  if executable('explorer.exe')
    " for wsl
    call system('explorer.exe "' . l:url . '"')
  elseif executable('xdg-open')
    call system('xdg-open "' . l:url . '" &')
  endif
endfunction

function! mpe#sync_line() abort
  let l:url = 'http://localhost:' . g:mpe_port . '/line'
  let l:data = json_encode({'line': line('.')})
  call job_start(['curl', '-s', '-X', 'POST', '-H',
        \ 'Content-Type: application/json', '-d', l:data, l:url],
        \ {'out_io': 'null', 'err_io': 'null'})
endfunction

function! mpe#reload() abort
  let l:url = 'http://localhost:' . g:mpe_port . '/reload'
  call job_start(['curl', '-s', '-X', 'POST', l:url])
endfunction
