call app%init('FIGURE: frame', 900_int32, 520_int32, decorations='figure') ! no system frame: FIGURE draws it
call app%set_icon(ICON_CHART_LINE, stat=stat)                              ! the task bar's icon, and the bar's
call app%set_confirm_quit(.true.)                                          ! the bar's close button asks too
