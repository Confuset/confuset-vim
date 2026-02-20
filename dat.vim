vim9script

# ===================================================================
# GLOBAL STATE
# ===================================================================

# This option must be set to override the default files.
g:current_compiler = "MSBuild"
var msbuild = "msbuild"
#var msbuild = "\"C:\\Program Files\\Microsoft Visual Studio\\2022\\Enterprise\\MSBuild\\Current\\Bin\\amd64\\MSBuild.exe\""
var configuration = "Debug" # Other option : Release.
var platform = "Mixed Platform"

var progress_popup = -1

if exists(":CompilerSet") != 2
    command -nargs=* CompilerSet setlocal <args>
endif

# ===================================================================
# BUILD COMMAND HELPERS
# ===================================================================

def g:FindBranchRoot(): string
    var domain_root_file = findfile('master.targets', '.;')
    var domain_root_folder = fnamemodify(domain_root_file, ":p:h")
    return domain_root_folder
enddef

def g:FindSolutionForFile(file_name: string): string
    var file_dir_name = fnamemodify(file_name, ":p:h")
    var solution_dir = finddir('Solutions', file_dir_name .. ";")
    var domain_name = fnamemodify(solution_dir, ":p:h:h:t")
    var solution_name = solution_dir .. "\\subsystem" .. domain_name .. ".sln"
    # lug is special...
    if filereadable(solution_dir .. "\\LOHN_P0000000_Gesamt.sln")
        solution_name = solution_dir .. "\\LOHN_P0000000_Gesamt.sln"
    endif
    return solution_name
enddef

def g:FindProjectForFile(solution_file_name: string, file_name: string): string
    var paths = []
    for line in readfile(solution_file_name)
        if line =~ 'Project(".*") = ".*", "\zs[^"]\+\.vcxproj'
            var match = matchstr(line, '\v\.\.\\[^"]+\.vcxproj')
            add(paths, match)
        endif
    endfor
    var solution_dir = fnamemodify(solution_file_name, ":p:h")
    for proj in paths
        var projfile = solution_dir .. "\\" .. proj
        for line in readfile(projfile)
            if line =~? file_name
                return projfile
            endif
        endfor
    endfor
    return ""
enddef

def g:FindSolutionForCurrentFile(): string
    var solution = g:FindSolutionForFile(expand('%:p'))
    return solution
enddef


def FindProject(solution: string): string
    return g:FindProjectForFile(solution, expand('%:t'))
enddef

# ===================================================================
# PROGRESS POPUP
# ===================================================================

def ShowProgress(msg: string)
    if progress_popup == -1
        progress_popup = popup_create(msg, {
            pos: "topright",
            line: 2,
            col: &columns - 2,
            time: 0,
            #padding: [1, 1, 1, 1],
            highlight: "Question",
            border: [],
            close: 'click',
        })
    else
        popup_settext(progress_popup, msg)
    endif
enddef

def CloseProgress()
    echo "close"
    if progress_popup != -1
        popup_close(progress_popup)
        progress_popup = -1
    endif
enddef

# ===================================================================
# SYNC BUILD BUFFER → QUICKFIX
# ===================================================================

def SyncQuickfixFromBuffer(bufnr: number)
    if bufnr < 0
        return
    endif

    #cgetbuffer(bufnr)
    #CompilerSet errorformat=\ %#%f(%l\\\,%c):\ %m
    #execute ('cgetbuffer ' .. bufnr)
    var lines = getbufline(bufnr, 1, '$')
    var filtered = lines->filter((_, v) =>
        v =~ '\v: error\s|: warning\s'
    )
    # Quickfix neu befüllen basierend auf errorformat
    setqflist([], 'r', {
        'lines': filtered,
        'efm': &errorformat
    })
enddef

# ===================================================================
# CALLBACKS
# ===================================================================

def OnStdout(channel: channel, msg: string)
    if msg =~ '\v(\[\d+/\d+\])|(Compiling)'
        ShowProgress(msg)
    endif
    if msg =~ '\v: error\s|: warning\s'
        var m = getqflist({'efm': &errorformat, 'lines': [msg]})
        setqflist([m.items[0]], 'a')
    endif
enddef

def OnExit(channel: job, exitcode: number)
    CloseProgress()

    # Quickfix anzeigen falls Fehler
    if !empty(getqflist())
        copen
    else
        cclose
        echohl MoreMsg | echom "Build OK" | echohl None
    endif
enddef


# ===================================================================
# RUN BUILD (async job_start)
# ===================================================================
var myJob = null_job

def RunBuild(cmd: string)
    # Quickfix leeren
    setqflist([], 'r')

    # Progress Hinweis
    ShowProgress("Build started…")
    var build_buffer = "BuildOutput"
    # Existierenden Buffer löschen
#    var exists = build_buffer->bufexists()
#    echo exists
#    if build_buffer->bufexists()
#        echo "delete buffer"
#        execute 'bdelete ' .. build_buffer
#    endif

    myJob = null_job
    myJob = job_start([&shell, &shellcmdflag, cmd], {
        "out_io": "buffer",
        "out_name": "BuildOutput", # build_buffer,
        "err_io": "buffer",
        "err_name": "BuildError", # build_buffer,
        "out_cb": function('OnStdout'),
        "err_cb": function('OnStdout'),
        "exit_cb": function('OnExit'),
    })
enddef


# ===================================================================
# COMMAND
# ===================================================================

def BuildCurrentFile()
    var sol = g:FindSolutionForCurrentFile()
    var proj = FindProject(sol)

    CompilerSet errorformat=\ %#%f(%l\\\,%c):\ %m

    var cmd = msbuild .. " " .. proj
        .. " /m"
        .. " /noLogo /v:q"
        .. " /t:ClCompile"
        .. " /p:Configuration=Debug"
        .. " /p:Platform=Win32"
        .. " /p:SelectedFiles=" .. expand("%:t")

    RunBuild(cmd)
enddef

def BuildProject()
    var sol = g:FindSolutionForCurrentFile()
    var proj = FindProject(sol)

    CompilerSet errorformat=\ %#%f(%l\\\,%c):\ %m

    var cmd = msbuild .. " " .. proj
        .. " /m"
        .. " /noLogo /v:m"
        .. " /t:Build"
        .. " /p:Configuration=Debug"
        .. " /p:Platform=Win32"

    RunBuild(cmd)
enddef

def BuildSolution()
    var sol = g:FindSolutionForCurrentFile()

    CompilerSet errorformat=\ %#%f(%l\\\,%c):\ %m

    var cmd = msbuild .. " " .. sol
        .. " /m"
        .. " /noLogo /v:m"
        .. " /t:Build"
        .. " /p:Configuration=Debug"
        .. " /p:Platform=Win32"

    RunBuild(cmd)
enddef

command -nargs=0 Bf BuildCurrentFile()
command -nargs=0 Bp BuildProject()
command -nargs=0 Bs BuildSolution()

