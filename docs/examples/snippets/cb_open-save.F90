if (ig_button('Save as...')) call app%save_file_dialog('save', FILTERS, default_path='case.input')
call app%file_dialog_result('save', chosen, done, cancelled, stat=stat)
if (done .and. .not. cancelled .and. stat == FIG_OK) path = chosen  ! the file to write; it may exist
