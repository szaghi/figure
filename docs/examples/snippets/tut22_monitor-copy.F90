call ig_same_line()
if (ig_button(ICON_COPY//'##copy the path')) then ! to paste it in a terminal: cd, or sbatch
   call ig_set_clipboard(case_dir)                ! remote: the page writes it to the browser's clipboard
   call app%notify('The case''s path is on the clipboard', kind='info', seconds=3.0_real64)
endif
call ig_tooltip('Copy the case''s path')
