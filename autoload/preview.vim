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
export def PopupPicker(
    items: list<dict<any>>,
    query: string,
    OnSelect: func,
    OnPreview: func = null_function
)

    def Filter(s: dict<any>)
        if s.query ==# ''
            s.filtered = s.items
        else
            s.filtered = matchfuzzy(
                s.items,
                s.query,
                {'key': 'text'}
            )
        endif

        s.index = min([s.index, max([len(s.filtered) - 1, 0])])
    enddef


    def RenderPreview(s: dict<any>)
        if s.preview < 0 || s.on_preview == null_function
            return
        endif

        var item = get(s.filtered, s.index, null)
        if item == null
            return
        endif

        var preview = call(s.on_preview, [item])

        var bufnr = s.preview->winbufnr()
        setbufvar(bufnr, '&modifiable', true)

        setbufline(bufnr, 1, preview.lines)
        deletebufline(bufnr, len(preview.lines) + 1, '$')

        setbufvar(bufnr, '&modifiable', false)

        var winid = s.preview
        var name = preview.name
        if name !=# ''
            win_execute(winid, 'noautocmd keepalt file ' .. fnameescape(name))
            win_execute(winid, 'filetype detect')
        else
            win_execute(winid, 'noautocmd keepalt file')
            win_execute(winid, 'setlocal filetype=')
        endif
    enddef


    def Render(s: dict<any>)
        var lines = []

        lines->add('Search: ' .. s.query)
        lines->add(repeat('─', 40))

        for i in range(len(s.filtered))
            var prefix = (i == s.index) ? '> ' : '  '
            lines->add(prefix .. s.filtered[i].text)
        endfor

        popup_settext(s.popup, lines)

        s->RenderPreview()
    enddef


    def Close(s: dict<any>)
        if s.popup >= 0
            popup_close(s.popup)
        endif

        if s.preview >= 0
            popup_close(s.preview)
        endif
    enddef


    def Key(s: dict<any>, id: number, key: string): number
        if key ==# "\<Esc>" || key ==# "x"
            s->Close()
            return 1

        elseif key ==# "\<CR>"
            var item = get(s.filtered, s.index, null)

            s->Close()

            if item != null
                call(s.on_select, [item])
            endif

            return 1

        elseif key ==# "\<BS>"
            if len(s.query) > 0
                s.query = s.query[: -2]
            endif

        elseif key ==# "\<Down>"
            if s.index < len(s.filtered) - 1
                s.index += 1
            endif

        elseif key ==# "\<Up>"
            if s.index > 0
                s.index -= 1
            endif

        else
            var trans = keytrans(key)

            # interne Vim-Sondercodes ignorieren
            if trans =~# '^<.*>$'
                return 1
            endif
            s.query ..= key
        endif

        s->Filter()
        s->Render()

        return 1
    enddef


    var state: dict<any> = {
        items: items,
        query: query,
        filtered: items,
        index: 0,
        popup: -1,
        preview: -1,
        on_select: OnSelect,
        on_preview: OnPreview,
    }

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
      borderchars: ['═', '║', '═', '║', '╔', '╗', '╝', '╚'],
      padding: [0, 2, 0, 1],
      filter: (id, key) => Key(state, id, key),
      mapping: false
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
          borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
          padding: [0, 1, 0, 1],
          zindex: popup_getoptions(state.popup).zindex + 1
      })
      win_execute(state.preview, 'setlocal nofoldenable nomodeline')
  endif

  state->Render()
enddef

