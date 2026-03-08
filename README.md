# vim-mpe

A Vim plugin for Markdown previewing, powered by [Crossnote](https://github.com/shd101wyy/crossnote).

## Features

- リアルタイムプレビュー (ファイル保存時プレビュー更新)
- スクロール同期
- Crossnote Engine: VSCode の Markdown Preview Enhanced (MPE) 対応
  - PlantUML 対応

## Prerequisites

- Vim 8.1+ (Job functionality)
- Node.js (crossnote server)
- curl
- java, dot (graphviz) (PlantUML 使用時)

## Installation

```vim
" 例: vim-plug
Plug 'mkunten/vim-mpe'

" 例: Jetpack
Jetpack 'mkunten/vim-mpe'
```

## Settings

```vim
" MPE サーバーで使用するポート番号
let g:mpe_port = get(g:, 'mpe_port', 3000)`
" MPE サーバーを起動するためのコマンド (<node> server/server.js)
let g:mpe_node_path = get(g:, 'mpe_node_path', 'node')
" vim-mpe のルートパス
let g:mpe_root = expand('<sfile>:p:h:h')
" PlantUML の JAR ファイルのダウンロード先
let g:mpe_jar_url = get(g:, 'mpe_jar_url', 'https://github.com/plantuml/plantuml/releases/download/v1.2026.2/plantuml-1.2026.2.jar')
" JAR の保存先
let g:mpe_jar_path = get(g:, 'mpe_jar_path', g:mpe_root . '/server/plantuml.jar')
```

※ ほかの MPE の設定についての対応は未定

## Usage

| Command | Description |
|---------|-------------|
| `:MpeStart` | backend node サーバーを起動し、ブラウザでプレビューを開きます。 |
| `:MpeStop` | backend node サーバーを終了します。<br/>vim 終了時に自動実行されます。 |
| `:MpeInstall` | node サーバー環境の初期化、および plantuml.jar の配置を行います。<br/>初回実行時に自動実行されます。 |
