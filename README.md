# vim-mpe

A Vim plugin for Markdown previewing, powered by [Crossnote](https://github.com/shd101wyy/crossnote).

## Features

- **Real-time Sync**: ファイル保存時自動リロードおよびカーソル追従
- **Markdown Preview Enhanced (MPE) Compatible**: Crossnote engine の採用
  - Mermaid/PlantUML 対応
- **WSL2 Support**

## Prerequisites

- Vim 8.1+ (Job functionality)
- Node.js & npm (MPE server)
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
" 設定例
let g:mpe_config = { 'port': 9000, 'jar_path': '/path/to/your_plantuml.jar' }
```

※ デフォルトの設定値については `plugin/mpe.vim` `s:default_config` を参照

※ ほかの MPE の設定についての対応は未定

## Usage

| Command | Description |
|---------|-------------|
| `:MpeOpen` | ブラウザでプレビューを開きます。MPE サーバーが起動していない場合は起動後開きます。 |
| `:MpeStart` | MPE サーバーを起動します。 |
| `:MpeStop` | MPE サーバーを終了します。<br/>vim 終了時に自動実行されます。 |
| `:MpeStatus` | MPE サーバーの起動状態を表示します。 |
| `:MpeInstall(!)` | node サーバー環境の初期化、および `plantuml.jar` の配置を行います。<br/>初回実行時に自動実行されます。<br/>`!`: `node_modules` および `plantuml.jar` を削除後、再インストールを行います。 |
