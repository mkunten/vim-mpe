" plugin/mpe.vim

if exists('g:loaded_mpe_vim') | finish | endif
let g:loaded_mpe_vim = 1

" config
if !exists('g:mpe_config')
  let g:mpe_config = {}
endif

let s:plugin_root = expand('<sfile>:p:h:h')
let s:server_root = simplify(s:plugin_root . '/server')
let s:default_config = {
      \ 'node_path': 'node',
      \ 'root': s:plugin_root,
      \ 'server_root': s:server_root,
      \ 'port': 3000,
      \ 'code_block_theme': 'auto.css',
      \ 'mermaid_theme': 'default',
      \ 'jar_path': simplify(s:server_root . '/plantuml.jar'),
      \ 'jar_url': 'https://github.com/plantuml/plantuml/releases/download/v1.2026.2/plantuml-1.2026.2.jar',
      \ }
let g:mpe_config = extend(s:default_config, g:mpe_config)

augroup Mpe
  autocmd!
  autocmd FileType markdown call s:setup_buffer_sync()
  autocmd VimLeavePre * call mpe#stop()
augroup END

" commands
command! -bang MpeInstall call mpe#install(<bang>0)
command! -nargs=? MpeOpen call mpe#open(<f-args>)
command! MpeStart call mpe#start(v:null)
command! MpeStatus call s:show_status()
command! MpeStop call mpe#stop()

function! s:show_status() abort
  if mpe#status()
    echomsg "MPE: Server is running on port " .
          \ get(g:mpe_config, 'port', 'unknown')
  else
    echomsg "MPE: Server is stopped."
  endif
endfunction

function! s:setup_buffer_sync() abort
  echomsg "MPE: initialized"
  augroup Mpe_Sync_Buffer
    autocmd! * <buffer>
    autocmd CursorMoved <buffer>
          \ if mpe#status() | call mpe#sync_line() | endif
    autocmd BufWritePost <buffer>
          \ if mpe#status() | call mpe#reload() | endif
  augroup END
endfunction
