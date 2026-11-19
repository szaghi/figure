call app%load_layout(DEFAULT_LAYOUT, stat=stat)   ! a file of the user's: it can be gone or broken
if (stat /= FIG_OK) call app%notify(code_name(stat)//': '//figure_last_error(), kind='error')
