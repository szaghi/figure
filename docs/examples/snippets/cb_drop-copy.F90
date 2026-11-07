call ig_begin_disabled(len(case_dir) == 0)
if (ig_button(ICON_COPY//' Copy the case path')) then
   call ig_set_clipboard(case_dir)              ! pasted elsewhere with ctrl+v
   copied = .true.
endif
call ig_end_disabled()
