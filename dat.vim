vim9script

import autoload 'jobs.vim'

# ===================================================================
# GLOBAL STATE
# ===================================================================

# This option must be set to override the default files.
g:current_compiler = "MSBuild"
var msbuild = "msbuild"
var configuration = "Debug" # Other option : Release.
var platform = "Mixed Platform"

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
# SYNC BUILD BUFFER → QUICKFIX
# ===================================================================

def SyncQuickfixFromBuffer(bufnr: number)
    if bufnr < 0
        return
    endif

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
# RUN BUILD (async job_start)
# ===================================================================

def BuildCurrentFile()
    var sol = g:FindSolutionForCurrentFile()
    var proj = FindProject(sol)

    var errorformat = '\ %#%f(%l\\\,%c):\ %m'

    var cmd = msbuild .. " " .. proj
        .. " /m"
        .. " /noLogo /v:q"
        .. " /t:ClCompile"
        .. " /p:Configuration=Debug"
        .. " /p:Platform=Win32"
        .. " /p:SelectedFiles=" .. expand("%:t")

    StartJob(Job.new("Build " .. expand("%:h"), cmd, errorformat))
enddef

def BuildProject()
    var sol = g:FindSolutionForCurrentFile()
    var proj = FindProject(sol)

    CompilerSet errorformat=\ %#%f(%l\\\,%c):\ %m

    var cmd = msbuild .. " " .. proj
        .. " /m"
        .. " /noLogo /v:m"
        .. " /t:Build-"
        .. " /p:Configuration=Debug"
        .. " /p:Platform=Win32"

    StartJob("Build " .. proj, cmd)
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

    StartJob("Build " .. sol, cmd)
enddef

def Ping()
    jobs.StartJob(jobs.Job.new("Ping", "ping -t google.de -n 10"))
enddef

command -nargs=0 Bf BuildCurrentFile()
command -nargs=0 Bp BuildProject()
command -nargs=0 Bs BuildSolution()
command -nargs=0 Ping Ping()
command -nargs=0 JobShow ShowJobs()

# ===================================================================
# DatCommands
# ===================================================================

var dat_first_args: list<string> = ['cl', 'rb', 'b', 'rf']
var dat_subsystems = ['pmsc', 'lug', 'lodas', 'rscl', 'fwpp', 'all']

def DatComplete(ArgLead: string, CmdLine: string, CursorPos: number): list<string>
    var args = split(CmdLine, '\s\+')
    if empty(args) || len(args) == 1
        return dat_first_args
    else
        return dat_subsystems
    endif
enddef

command! -nargs=+ -complete=customlist,DatComplete Dat call DatHandler([<f-args>])

def DatHandler(args: list<string>)
    if len(args) > 0
        echo "Erstes Argument: " args[0]
        echo "Subsysteme: " join(args[ 1 : ], ', ')
    endif
enddef
