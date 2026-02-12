vim9script

source $VIMRUNTIME/defaults.vim

# be iMproved, required
set nocompatible
set shiftwidth=4
set softtabstop=4
set expandtab
set hidden
set ignorecase
set hlsearch
set incsearch
set number
set confirm
set clipboard=unnamed
set backspace=indent,eol,start
set listchars=tab:\|-,trail:~,extends:>,precedes:<
set list

set history=1000

# add all subfolders to the :find path
set path+=**
# show all wildchar mappings in command mode
set wildmenu
set wildoptions=pum,fuzzy
set wildmode=longest:full
set wildmode=noselect:lastused,full
set updatetime=100

syntax on
filetype plugin indent on

if has("gui_running") && (has('win32') || has('win64'))
    #set renderoptions=type:directx,level:0.75,gamma:1.25,contrast:0.25,geom:1,renmode:5,taamode:1
    set guioptions-=r
    set guioptions+=l
endif

# cursor style unter linux?!
&t_SI = "\e[6 q"
&t_EI = "\e[2 q"

#set guifont=DejaVu_Sans_Mono:h11:cANSI:qDRAFT
set guifont=Consolas:h11:cANSI:qDRAFT
set termguicolors
colorscheme gruvbox8
set background=dark

# grep ripgrep
if executable('rg')
    set grepformat+=%f:%l:%c:%m
    set grepprg=rg\ --vimgrep\ --smart-case\ --follow\ --no-messages

    # Globaler Cache
    g:grep_word_cache = {}

    # Funktion, um Cache eines Buffers zu aktualisieren
    def UpdateBufferCache(buf: number)
        if !buflisted(buf)
            return
        endif
        var words = {}
        for line in getbufline(buf,  1, '$')
            for w in split(line, '\W\+')
                if strlen(w) > 1
                    words[w] = 1
                endif
            endfor
        endfor
        g:grep_word_cache[buf] = keys(words)
    enddef

    def BufferWords(ArgLead: string, CmdLine: string, CursorPos: number): list<string>
        var all_words = {}
        # Alle gecachten Buffers durchgehen
        for buf_words in values(g:grep_word_cache)
            for w in buf_words
                all_words[w] = 1
            endfor
        endfor
        # Einzigartige Wörter zurückgeben
        return matchfuzzy(keys(all_words), ArgLead, {limit: 20})
    enddef

    def Grep(...args: list<string>): string
        return system(join([&grepprg] + [expandcmd(join(args, ' '))], ' '))
    enddef

    command! -nargs=+ -complete=customlist,BufferWords Grep cgetexpr Grep(<f-args>)

    augroup my_grep
        autocmd!
        # Alle Buffers beim Laden/Ändern aktualisieren
        autocmd BufReadPost,BufWritePost * call UpdateBufferCache(bufnr('%'))
    augroup END

    #command! -nargs=+ -complete=file_in_path -bar Grep  cgetexpr Grep(<f-args>)
    #command! -nargs=+ -complete=file_in_path -bar LGrep lgetexpr Grep(<f-args>)

    #cnoreabbrev <expr> grep  (getcmdtype() ==# ':' && getcmdline() ==# 'grep')  ? 'Grep'  : 'grep'
    #cnoreabbrev <expr> lgrep (getcmdtype() ==# ':' && getcmdline() ==# 'lgrep') ? 'LGrep' : 'lgrep'

    g:filescache = []
    def Find(arg: string, _: any): list<string>
        if empty(g:filescache)
            g:filescache = systemlist('rg --files --no-messages --color=never')
        endif
        return arg == '' ? g:filescache : matchfuzzy(g:filescache, arg, {limit: 20})
    enddef
    set findfunc=Find
endif

# set default leader to <space>
g:mapleader = " "
nnoremap <LEADER>n :lnext<CR>
nnoremap <LEADER>p :lprevious<CR>
nnoremap <LEADER>r :lrewind<CR>

g:tfcli = "C:\\Program Files\\Microsoft Visual Studio\\2022\\Enterprise\\Common7\\IDE\\CommonExtensions\\Microsoft\\TeamFoundation\\Team Explorer\\TF.exe"
nnoremap <LEADER>co :exe "!\"" .. g:tfcli .. "\" checkout %:p"<RETURN><RETURN>
nnoremap <LEADER>cu :exe "!\"" .. g:tfcli .. "\" undo %:p"<RETURN><RETURN>
nnoremap <LEADER>gd :exe "!\"" .. g:tfcli .. "\" diff %:p"<RETURN><RETURN>

#completions in insertmode
#complete filename
inoremap <silent> ,f <C-x><C-f>
#first keyword in the current and included files
inoremap <silent> ,i <C-x><C-i>
#complete line
inoremap <silent> ,l <C-x><C-l>
#complete word
inoremap <silent> ,n <C-x><C-n>
#inoremap <silent> ,o <C-x><C-o> #omnicomplete
#inoremap <silent> ,t <C-x><C-]> #tag complete
#inoremap <silent> ,u <C-x><C-u> #completfunc complete

nnoremap <leader>a :argadd <c-r>=fnameescape(expand('%:p:h'))<cr>/*<C-d>
nnoremap <leader>b :b <C-d>
nnoremap <leader>e :e **/
nnoremap <leader>g :grep<space>
nnoremap <leader>q :b#<cr>

inoremap <c-u> <ESC>viwUea
nnoremap <space>ev :vsplit $MYVIMRC<cr>
nnoremap <space>sv :source $MYVIMRC<cr>
nnoremap <space>" viw<esc>a"<esc>bi"<esc>lel
nnoremap <c-n> :cn<enter>
nnoremap <c-p> :cp<enter>


def UpdateQF()
    if &modified
        var curline = line('.')
        setlocal errorformat=%f\|%l\ col\ %c\|%m
        cgetbuffer
        if line("'\"") >= 1 && line("'\"") <= line("$") && &ft !~# 'commit'
            cursor(curline, 0)
        endif
        set nomodified
    endif
enddef

def ToggleQuickFix()
    #:set modifiable
    #dd or :g/pattern/d or g!-> :v/pattern/d
    #:cgetbuffer or :cbuffer
    #:.cc   " Go to error under cursor (if cursor is in quickfix window)
    augroup qf
        autocmd!
        autocmd BufEnter <buffer> setlocal modifiable
        autocmd BufLeave <buffer> call UpdateQF()
        #autocmd BufLeave <buffer> if &modified | cgetbuffer | endif
    augroup END
enddef

augroup my_vimrc
    autocmd!
    autocmd GUIEnter * simalt ~x
    # automatically open quickfix window after build is completed
    autocmd QuickFixCmdPost [^l]* ++nested cwindow
    autocmd QuickFixCmdPost    l* ++nested lwindow

    autocmd BufReadPost quickfix ToggleQuickFix()

    #mark whitespaces etc.
    autocmd BufWinEnter <buffer> match Error /\s\r$/
    autocmd InsertEnter <buffer> match Error /\s\+\%#\@<!$/
    autocmd InsertLeave <buffer> match Error /\s\+$/
    autocmd BufWinLeave <buffer> call clearmatches()

    #wildmenu update
    autocmd CmdlineEnter : g:filescache = []
    autocmd CmdlineChanged [:\/\?] call wildtrigger()

    # color in qf list on selected line is bad...
    autocmd FileType qf highlight QuickFixLine guibg=#3c3836
augroup END

def GallFunction(re: string)
  cexpr []
  execute 'silent! noautocmd bufdo vimgrepadd /' .. re .. '/j %'
  cw
enddef

# grep over all open buffers.
# cn/cp für quickfix list
command! -nargs=1 Gall call GallFunction(<q-args>)

# selet an open buffer by :Buffer
def BufferCommand(arg: string, bang: string)
    var buffers = getbufinfo({'buflisted': 1})
    var matches = []

    if arg != ''
        for b in buffers
            if matchfuzzy([b.name], arg)->len() > 0
                matches->add(b)
            endif
        endfor
    else
        for b in buffers
            matches->add(b)
        endfor
    endif

    if matches->len() == 0
        echohl ErrorMsg | echo 'No matching buffer found' | echohl None
        return
    elseif matches->len() == 1
        execute 'buffer ' .. matches[0].bufnr
    else
        echo 'Matching buffers:'
        for i in range(matches->len())
            echo printf('%d: %s', matches[i].bufnr, fnamemodify(matches[i].name, ':~:.'))
        endfor
        var choice = input('Which buffer number? ')
        if choice != ''
            execute 'buffer ' .. choice
        endif
    endif
enddef

def BufferCompletion(A: string, L: string, P: number): list<string>
    var buffers = getbufinfo({'buflisted': 1})
    var names = mapnew(buffers, (_, v) => fnamemodify(v.name, ':~:.'))
    if A != ''
        return names->matchfuzzy(A)
    else
        return names
    endif
enddef

command! -nargs=? -bang -complete=customlist,BufferCompletion Buffer call BufferCommand(<q-args>, '<bang>')

#packadd! editorconfig
#packadd lsp
def LoadLsp()
    g:LspAddServer([{
        name: 'clangd',
        filetype: ['c', 'cpp'],
        path: 'clangd',
        args: ['--background-index']
    }])

    var mapleader = " "
    nnoremap <leader>dd :LspGotoDeclaration<cr>
    nnoremap <leader>ii :LspGotoDefinition<cr>
    nnoremap <leader>tt :LspGotoTypeDef<cr>

    nnoremap <leader>d :LspPeekDeclaration<cr>
    nnoremap <leader>i :LspPeekDefinition<cr>
    nnoremap <leader>t :LspPeekTypeDef<cr>

    nnoremap <leader>s :LspSymbolSearch<cr>
    nnoremap <leader>u :LspShowReferences<cr>
    nnoremap <leader>m :LspDocumentSymbol<cr>
    nnoremap <leader>f :call feedkeys(":Files \<Tab>", 'tn')<CR>

    nnoremap <leader>e :LspHover<CR>
    nnoremap <leader>r :LspRename<CR>
    nnoremap <leader>o :LspSwitchSourceHeader<CR>

    nnoremap <leader>ic :LspIncomingCalls<cr>
    nnoremap <leader>oc :LspOutgoingCalls<cr>

    #nnoremap <leader>cc :vsc Edit.CommentSelection<CR>
    #xnoremap <leader>cc :vsc Edit.CommentSelection<CR>
    #nnoremap <leader>ci :vsc Edit.UncommentSelection<CR>
    #xnoremap <leader>ci :vsc Edit.UncommentSelection<CR>
enddef
command! LoadLsp call LoadLsp()
