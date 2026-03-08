" plugin/vim-mpe.vim

if exists('g:loaded_mpe_vim') | finish | endif
let g:loaded_mpe_vim = 1

" default
let g:mpe_port = get(g:, 'mpe_port', 3000)
let g:mpe_node_path = get(g:, 'mpe_node_path', 'node')
let g:mpe_root = expand('<sfile>:p:h:h')
let g:mpe_jar_url = get(g:, 'mpe_jar_url', 'https://github.com/plantuml/plantuml/releases/download/v1.2026.2/plantuml-1.2026.2.jar')
let g:mpe_jar_path = get(g:, 'mpe_jar_path', g:mpe_root . '/server/plantuml.jar')

" commands
command! MpeStart call mpe#start()
command! MpeStop call mpe#stop()
command! MpeInstall call mpe#install()
