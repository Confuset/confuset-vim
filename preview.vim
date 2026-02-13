vim9script
# ===============================
# PopupPicker.vim – generic popup picker with preview
# ===============================
# Usage:
#   PopupPicker(items, initial_query, on_select [, on_preview])
#
# Example:
#   PopupPicker(
#     ['apple','banana','cherry'],
#     '',
#     {x -> execute('echo ' .. x)},
#     {x -> ['Preview:', x]}
#   )

if exists('g:loaded_popup_picker')
  finish
endif
g:loaded_popup_picker = 1

# -------------------------------
# PopupPicker
# -------------------------------
def PopupPicker(
  items: list<string>,
  query: string,
  OnSelect: func,
  OnPreview: func = null_function
)
  var state = {
    items: items,
    query: query,
    filtered: [],
    index: 0,
    popup: -1,
    preview: -1,
    on_select: OnSelect,
    on_preview: OnPreview,
  }

  # -----------------------------
  def Filter(s: dict<any>)
    if s.query ==# ''
        s.filtered = s.items
    else
        s.filtered = matchfuzzy(s.items, s.query)
    endif
    s.index = min([s.index, len(s.filtered) - 1])
  enddef

  # -----------------------------
  def RenderPreview(s: dict<any>)
      if s.preview < 0 || s.on_preview == null_function
          return
      endif

      var sel = get(s.filtered, s.index, '')
      if sel ==# ''
          return
      endif

      var buf = s.preview->winbufnr()
      setbufvar(buf, '&buftype', '')
      setbufvar(buf, '&bufhidden', 'wipe')
      setbufvar(buf, '&swapfile', false)

      setbufvar(buf, '&modifiable', true)
      var lines = call(s.on_preview, [sel])
      if type(lines) != v:t_list
          lines = [string(lines)]
      endif
      setbufline(buf, 1, lines)
      setbufvar(buf, '&modifiable', false)

      if filereadable(sel)
          win_execute(s.preview, 'noautocmd keepalt file ' .. fnameescape(sel))
          win_execute(s.preview, 'filetype detect')
      endif
  enddef

  # -----------------------------
  def Render(s: dict<any>)
    var lines = []
    lines->add('Search: ' .. s.query)
    lines->add(repeat('─', 40))
    for i in range(len(s.filtered))
      var p = (i == s.index) ? '> ' : '  '
      lines->add(p .. s.filtered[i])
    endfor
    popup_settext(s.popup, lines)
    s->RenderPreview()
  enddef

  # -----------------------------
  def Close(s: dict<any>)
    if s.popup >= 0
      popup_close(s.popup)
    endif
    if s.preview >= 0
      popup_close(s.preview)
    endif
  enddef

  # -----------------------------
  def Key(s: dict<any>, id: number, key: string): number
    if key ==# "\<Esc>"
      s->Close()
      return 1

    elseif key ==# "\<CR>"
      var sel = get(s.filtered, s.index, '')
      s->Close()
      if sel !=# ''
        call(s.on_select, [sel])
      endif
      return 1

    elseif key ==# "\<BS>"
      if len(s.query) > 0
        s.query = s.query[ : -2]
      endif

    elseif key ==# 'j' || key ==# "\<Down>"
      s.index = min([s.index + 1, len(s.filtered) - 1])

    elseif key ==# 'k' || key ==# "\<Up>"
      s.index = max([s.index - 1, 0])

    elseif key =~# '^\k$'
      s.query ..= key

    else
      return 0
    endif

    s->Filter()
    s->Render()
    return 1
  enddef

  # -----------------------------
  # Init
  # -----------------------------
  state->Filter()

  var total_width = float2nr(&columns * 0.8)   # 80% vom Terminal
  var total_height = float2nr(&lines * 0.7)    # 70% Höhe

  var gap = 2
  var picker_width = float2nr((total_width - gap) * 0.5)
  var preview_width = total_width - picker_width - gap
  if OnPreview == null_function
      picker_width = total_width
  endif

  # Gesamtblock zentrieren
  var start_col = (&columns - total_width) / 2
  var start_line = (&lines - total_height) / 2

  state.popup = popup_create([], {
      line: start_line,
      col: start_col,
      minwidth: total_width,
      maxwidth: total_width,
      minheight: total_height,
      maxheight: total_height,
      scrollbar: 0,
      border: [1, 1, 1, 1],
      #borderchars:  ['-', '|', '-', '|', '┌', '┐', '┘', '└'],
      borderchars: ['═', '║', '═', '║', '╔', '╗', '╝', '╚'],
      padding: [0, 1, 0, 1],
      filter: (id, key) => Key(state, id, key),
  })

  if OnPreview != null_function
      state.preview = popup_create([], {
          line: start_line + 1,
          col: start_col + picker_width + gap,
          minwidth: preview_width - 1,
          maxwidth: preview_width - 1,
          minheight: total_height - gap,
          maxheight: total_height - gap,
          scrollbar: 0,
          border: [1, 1, 1, 1],
          borderchars:  ['-', '|', '-', '|', '┌', '┐', '┘', '└'],
          padding: [0, 1, 0, 1],
          zindex: popup_getoptions(state.popup).zindex + 1
      })
  endif

  state->Render()
enddef

# ===============================
# Example: File picker with preview
# ===============================
def FilePreview(f: string): list<string>
    if filereadable(f)
        return readfile(f, '', 200)
    endif
    return ['<not readable>']
enddef

def GetFiles(): list<string>
  var func_name = &findfunc
  if func_name != ''
      return call(func_name, ['', false])
  endif
  return glob('**/*', 0, 1)
enddef

def OpenFilePicker(start: string = '')
  PopupPicker(
    GetFiles(),
    start,
    (f) => execute('edit ' .. fnameescape(f)),
    FilePreview
  )
enddef

command! -nargs=? FilePicker OpenFilePicker(<q-args>)
