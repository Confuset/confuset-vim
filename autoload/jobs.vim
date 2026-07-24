vim9script

import autoload 'preview.vim'

# ===================================================================
# GLOBAL STATE
# ===================================================================

export class Job
    var title: string
    var cmd: string
    var job: job
    var errorformat: string

    def new(this.title, this.cmd, this.errorformat = v:none)
    enddef

    def SetJob(job: job)
        this.job = job
    enddef
endclass

var progress_popup = -1
var joblist: list<Job> = []

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
    if progress_popup != -1
        popup_close(progress_popup)
        progress_popup = -1
    endif
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
    endif
enddef

# ===================================================================
# COMMAND
# ===================================================================

export def StartJob(newJob: Job)
    # Quickfix leeren
    setqflist([], 'r')

    # Progress Hinweis
    ShowProgress(newJob.title .. " started…")
    var build_buffer = newJob.title .. "_Output_" .. strftime('%H%M%S')
    var b = bufadd(build_buffer)
    setbufvar(b, '&buftype', 'nofile')
    setbufvar(b, '&bufhidden', 'hide')
    setbufvar(b, '&swapfile', false)

    newJob.SetJob(job_start([&shell, &shellcmdflag, newJob.cmd], {
        "out_io": "buffer",
        "out_buf": b->bufnr(),
        "out_modifiable": 0,
        "err_io": "buffer",
        "err_buf": b->bufnr(),
        "err_modifiable": 0,
        "out_cb": function('OnStdout'),
        "err_cb": function('OnStdout'),
        "exit_cb": function('OnExit'),
    }))
    add(joblist, newJob)
enddef

export def ShowJobs()
    if len(joblist) == 0
        return
    endif

    var items: list<dict<any>> = []
    for j in joblist
        items->add({
            text: j.title .. "  [" .. job_status(j.job) .. "]",
            user_data: j
        })
    endfor

    preview.PopupPicker(
        joblist->map((_, j) => j.title .. '  [' .. job_status(j.job) .. ']',
        '',



    popup_menu(items,
        {
            title: 'Jobs',
            callback: (id, result) =>
                {
                    if result == -1
                        return
                    endif

                    var buffer = ch_getbufnr(items[result - 1].user_data.job, "out")
                    execute 'vert sbuffer ' .. buffer
                }
        })
enddef
