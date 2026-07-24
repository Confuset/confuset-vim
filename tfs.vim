vim9script

import autoload 'vsenv.vim'

def TFStatus()
    if !vsenv.Ensure()
        return
    endif

    echo 'Fetching tfs status...'
    var cmd = 'TF.exe vc status'
    var output = system(cmd)
    # Split the string into an array, and remove all that don't match the pattern:
    # filename        <action>    fullpath
    #var pattern = '^\S\+\s\+\(add\|edit\|delete\)\s\+\([^[:space:]]\+\)\r\?$'
    var pattern = '^\S\+\s\+\(\S\+\)\s\+\(.*\)$'
    var locations = split(output, "\n", false)
        ->slice(2)
        ->map((_, l) => matchlist(l, pattern))
        ->filter((_, ml) => !empty(ml))
        ->map((_, ml) => ({'filename': ml[2], 'text': ml[1], 'valid': 1}))
    if get(g:, 'wtfs_translate_wsl', 0)
        for loc in locations
            loc.filename = system(printf('wslpath "%s"', loc.filename))->trim()
        endfor
    endif
    call setqflist([], ' ', {nr: '$', items: locations, title: 'TF Status'})
    if get(g:, 'wtfs_open_quickfix', 1)
        cwindow
    endif
enddef

def TFDiff()
    if !vsenv.Ensure()
        return
    endif

    var file = expand('%:p')

    # neuen vertikalen Split erzeugen
    vert new

    # TFVC-Version direkt in Buffer lesen
    execute $'read !tf view /version:T /console /noprompt "{file}"'

    # erste Leerzeile entfernen (kommt von :read)
    normal! ggdd

    # Buffer readonly/no-file
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal readonly
    setlocal nomodifiable

    set diffopt+=vertical
    set diffopt+=algorithm:histogram
    set diffopt+=indent-heuristic
    set diffopt+=iwhite

    # diff mode auf beiden Seiten aktivieren
    diffthis
    wincmd p
    diffthis
enddef

def TFCheckout()
    if !vsenv.Ensure()
        return
    endif

    var file = expand('%:p')
    var cmd = $'TF.exe vc checkout "{file}"'
    system(cmd)
    checktime
enddef

def TFUndo()
    if !vsenv.Ensure()
        return
    endif

    var file = expand('%:p')
    var cmd = $'tf.exe vc undo "{file}"'
    system(cmd)
    checktime
enddef

command TFStatus call TFStatus()
command TFDiff call TFDiff()
command TFCheckout call TFCheckout()
command TFUndo call TFUndo()
