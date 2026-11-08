call app%init('FIGURE studio', 960_int32, 600_int32, decorations='figure', buttons=side) ! FIGURE draws the frame
call app%set_icon(ICON_FLAME, stat=stat)          ! the task bar's icon, and the title bar's
if (stat /= FIG_OK) write(output_unit, '(A)') 'no window icon here: '//figure_last_error() ! the bar keeps its own
call app%set_confirm_quit(.true.)                 ! the close button asks the program first
