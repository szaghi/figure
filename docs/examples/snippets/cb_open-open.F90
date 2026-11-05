if (ig_button('Open...')) then
   call app%open_file_dialog('open', [character(len=24) :: 'Input files|input;inp', 'All files|*'], stat=stat)
   typed = stat /= FIG_OK                          ! remote or headless: no dialog, a path field
endif
call app%file_dialog_result('open', chosen, done, cancelled, stat=stat)
if (done .and. .not. cancelled .and. stat == FIG_OK) path = chosen
if (typed) then
   if (ig_input_text('path', path, hint='CASE/overset.input')) continue
endif
