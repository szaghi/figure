call app%file_dialog_result('case', chosen, done, cancelled, stat=stat) ! the browser's or the system's dialog
if (done .and. .not. cancelled) then
   if (stat == FIG_OK) then
      call request('open', chosen)
   else
      call app%notify(figure_last_error(), kind='error')                 ! the dialog could not be shown
   endif
endif
if (app%dropped(paths)) call request('open', case_folder(trim(paths(1)))) ! a case folder, or its heat.inp
