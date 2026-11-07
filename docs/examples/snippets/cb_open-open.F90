if (ig_button('Open...')) then
   call app%open_file_dialog('open', FILTERS, stat=stat)
   if (stat /= FIG_OK) call app%open_file_browser('open', FILTERS) ! remote: no system dialog, FIGURE's browser
endif
call app%file_dialog_result('open', chosen, done, cancelled, stat=stat) ! either one answers here
if (done .and. .not. cancelled .and. stat == FIG_OK) path = chosen
