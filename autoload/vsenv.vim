vim9script

var msvc_loading = false
var msvc_loaded = false
var msvc_job = null_job

export def Ensure(): bool

    if msvc_loaded
        return true
    endif

    if !msvc_loading
        LoadAsync()
    endif

    while job_status(msvc_job) == 'run'
        sleep 10m
    endwhile

    return msvc_loaded
enddef

def LoadAsync()
    msvc_loading = true

    var install = trim(system(
        '"C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe" ' ..
        '-latest -products * ' ..
        '-requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ' ..
        '-property installationPath'
    ))

    var cmd = $'cmd /c ""{install}\Common7\Tools\VsDevCmd.bat" -no_logo -arch=x64 && set"'

    job_start(cmd, {
        out_io: 'buffer',
        out_name: '[VsDevCmd]',
        exit_cb: OnMSVCExit,
    })
enddef

def OnMSVCExit(job: job, status: number)

    if status != 0
        echom 'VsDevCmd failed: ' .. status
        return
    endif

    var buf = ch_getbufnr(job, 'out')
    if buf < 0
        echom 'No output buffer'
        return
    endif

    var env: dict<string> = {}

    for line in getbufline(buf, 1, '$')
        var i = stridx(line, '=')
        if i > 0
            env[line[: i - 1]] = substitute(line[i + 1 :], '\r$', '', '')
        endif
    endfor

    for [name, value] in items(env)
        setenv(name, value)
    endfor

    msvc_loaded = true
    msvc_loading = false
    echom 'MSVC environment loaded'
enddef
