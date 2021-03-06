""  ------------------------------------------------------------
" *  @file       foundation.vim
" *  @date       2014
" *  @author     Jim Zhan <jim.zhan@me.com>
" *
" Copyright © 2014 Jim Zhan.
" ------------------------------------------------------------
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"     http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.
" ------------------------------------------------------------
"  Constants
" ---------------------------------------------------------------------------
let g:dotvim = {}
let g:dotvim.autochdir = 1
let g:dotvim.restore_cursor = 1
let g:dotvim.trailing_whitespace = 1
let g:dotvim.use_system_clipboard = 0

let g:dotvim.bundle = {}
let g:dotvim.bundle.Initialized = 1

let g:dotvim.path = {}
" ---------------------------------------------------------------------------
"  Functions
" ---------------------------------------------------------------------------
" Initialize directories 
function! dotvim.InitializeDirectories()
    let parent = $HOME
    let prefix = 'vim'
    let dir_list = {
                \ 'backup': 'backupdir',
                \ 'views': 'viewdir',
                \ 'swap': 'directory' }

    if has('persistent_undo')
        let dir_list['undo'] = 'undodir'
    endif

    " To specify a different directory in which to place the vimbackup,
    " vimviews, vimundo, and vimswap files/directories, add the following to
    " your .vimrc.before.local file:
    "   let g:dotvim.consolidated_directory = <full path to desired directory>
    "   eg: let g:dotvim.consolidated_directory = $HOME . '/.vim/'
    if exists('g:dotvim.consolidated_directory')
        let common_dir = g:dotvim.consolidated_directory . prefix
    else
        let common_dir = parent . '/.' . prefix
    endif

    for [dirname, settingname] in items(dir_list)
        let directory = common_dir . dirname . '/'
        if exists("*mkdir")
            if !isdirectory(directory)
                call mkdir(directory)
            endif
        endif
        if !isdirectory(directory)
            echo "Warning: Unable to create backup directory: " . directory
            echo "Try: mkdir -p " . directory
        else
            let directory = substitute(directory, " ", "\\\\ ", "g")
            exec "set " . settingname . "=" . directory
        endif
    endfor
endfunction
call dotvim.InitializeDirectories()

" Initialize NERDTree as needed 
function! dotvim.NERDTreeInitAsNeeded()
    redir => bufoutput
    buffers!
    redir END
    let idx = stridx(bufoutput, "NERD_tree")
    if idx > -1
        NERDTreeMirror
        NERDTreeFind
        wincmd l
    endif
endfunction

" Strip whitespace
function! dotvim.StripTrailingWhitespace()
    " Preparation: save last search, and cursor position.
    let _s=@/
    let l = line(".")
    let c = col(".")
    " do the business:
    %s/\s\+$//e
    " clean up: restore previous search history, and cursor position
    let @/=_s
    call cursor(l, c)
endfunction

" Shell command
function! s:RunShellCommand(cmdline)
    botright new

    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal noswapfile
    setlocal nowrap
    setlocal filetype=shell
    setlocal syntax=shell

    call setline(1, a:cmdline)
    call setline(2, substitute(a:cmdline, '.', '=', 'g'))
    execute 'silent $read !' . escape(a:cmdline, '%#')
    setlocal nomodifiable
    1
endfunction

" e.g. Grep current file for <search_term>: Shell grep -Hn <search_term> %
command! -complete=file -nargs=+ Shell call s:RunShellCommand(<q-args>)


" ---------------------------------------------------------------------------
"  Python: indent Python in the Google's way.
" ---------------------------------------------------------------------------
setlocal indentexpr=GetGooglePythonIndent(v:lnum)
let s:maxoff = 50 " maximum number of lines to look backwards.
function dotvim.GetGooglePythonIndent(lnum)

  " Indent inside parens.
  " Align with the open paren unless it is at the end of the line.
  " E.g.
  "   open_paren_not_at_EOL(100,
  "                         (200,
  "                          300),
  "                         400)
  "   open_paren_at_EOL(
  "       100, 200, 300, 400)
  call cursor(a:lnum, 1)
  let [par_line, par_col] = searchpairpos('(\|{\|\[', '', ')\|}\|\]', 'bW',
        \ "line('.') < " . (a:lnum - s:maxoff) . " ? dummy :"
        \ . " synIDattr(synID(line('.'), col('.'), 1), 'name')"
        \ . " =~ '\\(Comment\\|String\\)$'")
  if par_line > 0
    call cursor(par_line, 1)
    if par_col != col("$") - 1
      return par_col
    endif
  endif

  " Delegate the rest to the original function.
  return dotvim.GetPythonIndent(a:lnum)
endfunction

let pyindent_nested_paren="&sw*2"
let pyindent_open_paren="&sw*2"

" ---------------------------------------------------------------------------
"  Logger: debug logger..
" ---------------------------------------------------------------------------
"function! dotvim.log(msg, ...)
    "let is_unite = get(a:000, 0, 0)
    "let msg = type(a:msg) == type([]) ? a:msg : split(a:msg, '\n')
    "call extend(s:log, msg)

    "if !(&filetype == 'unite' || is_unite)
        "call neobundle#util#redraw_echo(msg)
    "endif

    "call s:append_log_file(msg)
"endfunction


" ---------------------------------------------------------------------------
"  Plugin Manager: Initialize Vundle to manage plugins.
" ---------------------------------------------------------------------------
function! dotvim.InitializePlugins(config)
    " Ensure NeoBundle's Existence.
    if !filereadable(expand('$HOME/.vim/bundle/neobundle.vim/README.md'))
        echo "[*] Installing NeoBundle..."
        echo ""
        silent !git clone https://github.com/Shougo/neobundle.vim $HOME/.vim/bundle/neobundle.vim
        let g:dotvim.bundle.Initialized = 0
    endif

    set runtimepath+=~/.vim/bundle/neobundle.vim/
    call neobundle#begin(expand('~/.vim/bundle/'))
    NeoBundleFetch 'Shougo/neobundle.vim'
    source ~/.vim/plugins.vim
    if filereadable(a:config)
        source a:config
    endif
    call neobundle#end()
    filetype indent plugin on
    NeoBundleCheck
    if g:dotvim.bundle.Initialized == 0
        :NeoBundleInstall
    endif
endfunction
" ---------------------------------------------------------------------------
" Make the ErrorSign of Syntastic in red along with default background color.
function! dotvim.ResetSyntasticColors()
    exec 'hi SyntasticErrorSign guifg=#FF0000 ctermfg=196' .
            \' guibg=' . synIDattr(synIDtrans(hlID('SignColumn')), 'bg', 'gui') .
            \' ctermbg=' . synIDattr(synIDtrans(hlID('SignColumn')), 'bg', 'cterm')
endfunction
" ---------------------------------------------------------------------------
" Toggle NERDTree along with Tagbar.
nnoremap <Leader>nt     :call dotvim.ToggleNERDTreeAndTagbar()<CR>
function! dotvim.ToggleNERDTreeAndTagbar()
    let w:jumpbacktohere = 1

    " Detect which plugins are open
    if exists('t:NERDTreeBufName')
        let nerdtree_open = bufwinnr(t:NERDTreeBufName) != -1
    else
        let nerdtree_open = 0
    endif
    let tagbar_open = bufwinnr('__Tagbar__') != -1

    " Perform the appropriate action
    if nerdtree_open && tagbar_open
        NERDTreeClose
        TagbarClose
    elseif nerdtree_open
        TagbarOpen
    elseif tagbar_open
        NERDTree
    else
        NERDTree
        TagbarOpen
    endif

    " Jump back to the original window
    for window in range(1, winnr('$'))
        execute window . 'wincmd w'
        if exists('w:jumpbacktohere')
            unlet w:jumpbacktohere
            break
        endif
    endfor
endfunction



" ---------------------------------------------------------------------------
"  Finalizer: To finalize settings after all.
" ---------------------------------------------------------------------------
function! dotvim.Finalize()
    call g:dotvim.ResetSyntasticColors()
endfunction
