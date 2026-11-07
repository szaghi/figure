if (ig_button('Open...')) call app%open_file_browser('open', [character(len=32) :: &
                                                     'Xall files|input;grd;log;dat', 'All files|*'], &
                                                     default_path=trim(cases))
call ig_same_line()
if (ig_button('Save as...')) call app%save_file_browser('save', default_path=trim(cases)//'/copy.input')
call app%file_dialog_result('open', chosen, done, cancelled, stat=stat)
if (done .and. .not. cancelled .and. stat == FIG_OK) path = chosen
call app%file_dialog_result('save', chosen, done, cancelled, stat=stat)
if (done .and. .not. cancelled .and. stat == FIG_OK) saved = chosen
