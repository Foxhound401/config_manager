" ----- Things to pursue further -----
" completeopt=??
" For regular expressions turn magic on
" set magic

" Plugin Manager
execute pathogen#infect()

" ----- Vim User Interface -----
" Ignore compiled files
set wildignore=*.o,*~,*.pyc

" Height of the command bar
set cmdheight=2

" Makes search act like search in modern browsers
set incsearch

" show matching brackets when text indicator is over them
set showmatch

" Show line numbers
set number

" Load filetype-specific indent files
" Also enables plugins?
filetype plugin indent on

" ----- Tab things -----
" Want auto indents automatically
set autoindent
set smartindent
set wrap

" Set the width of the tab to 4 wid
set tabstop=4
set shiftwidth=4
set softtabstop=4


" Always use spaces instead of tab characters
set expandtab

" ----- Status Line (Python) -----
" This currently doesn't work
" python from powerline.vim import setup as powerline_setup
" python powerline_setup()
" python del powerline_setup

" ----- Syntastic Things -----
"  Really not sure what these things do yet
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wg = 0

"  Sets the python checker to look for Python 3
let g:syntastic_python_python_exec = '/usr/bin/python3'


" ----- Color Things -----

" Enable syntax highlighting
syntax enable
syntax on

" Choose Color scheme
colorscheme desert
set background=dark
 
