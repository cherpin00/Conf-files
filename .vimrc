set nocompatible              " be iMproved, required
filetype off                  " required                                                                                                                                                                                                                                                                                                                                                                                              " set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

" The following are examples of different formats supported.
" Keep Plugin commands between vundle#begin/end.
" plugin on GitHub repo
" Plugin 'tpope/vim-fugitive'
" plugin from http://vim-scripts.org/vim/scripts.html
" Plugin 'L9'
" Git plugin not hosted on GitHub
" Plugin 'git://git.wincent.com/command-t.git'
" git repos on your local machine (i.e. when working on your own plugin)
" Plugin 'file:///home/gmarik/path/to/plugin'
" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
" Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
" Install L9 and avoid a Naming conflict if you've already installed a
" different version somewhere else.
" Plugin 'ascenator/L9', {'name': 'newL9'}

" Plugin 'ycm-core/YouCompleteMe'
Plugin 'preservim/nerdtree'
Plugin 'morhetz/gruvbox'
Plugin 'kien/ctrlp.vim'
Plugin 'vim-airline/vim-airline'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

:let mapleader = " "

" NERDTree settings
" autocmd vimenter * NERDTree
" autocmd StdinReadPre * let s:std_in=1
" autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
" autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" gruvbox settings
autocmd vimenter * ++nested colorscheme gruvbox
" autocmd vimenter * ++nested colorscheme gruvbox " Use this for older versions if you get this error: autocmd vimenter * ++nested colorscheme gruvbox

"CtrlP settings
set runtimepath^=~/.vim/bundle/ctrlp.vim
let g:ctrlp_show_hidden = 1

"gruvbox settings
set bg=dark

"airline settings
let g:airline#extensions#tabline#enabled = 1


" general settings
set showmode
set nowrap
set tabstop=4
set smarttab
set noexpandtab
set shiftwidth=4
set shiftround
set autoindent
set copyindent
set number
set smartcase
set visualbell
set noerrorbells

nmap <leader>p :CtrlP<cr>
map <leader>b :NERDTree<CR>
map <F5> :w <CR> :!g++ % -o %< -lrt && ./%< <CR>
map <leader><tab> :bn<CR>
map <leader><TAB> :bp<cr>
map <leader>w :bd<cr>
map <leader><f> :YcmCompleter FixIt<CR>
