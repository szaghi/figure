if (remote) then                                  ! no window, no display, no GPU: a cluster node will do
   call app%init_remote(port=port, width=1100_int32, height=680_int32, max_fps=30.0_real64, compress='auto', &
                        quiet=.true., url=url, stat=stat) ! the address to open, with its access token
   if (stat /= FIG_OK) then
      write(output_unit, '(A)') 'tut24_editor: '//figure_last_error() ! a port in use, say
      stop 1, quiet=.true.
   endif
   call app%set_title('FIGURE studio')            ! the browser's tab shows it
else
   call app%init('FIGURE studio', 1100_int32, 680_int32, decorations='figure')
   call app%set_icon(ICON_FLAME, stat=stat)
   if (stat /= FIG_OK) write(output_unit, '(A)') 'no window icon here: '//figure_last_error()
endif
