if (ig_begin_tab('Files')) then
   if (ig_input_text('grid file', grid_file, flags=ImGuiInputTextFlags_CharsNoBlank)) continue
   call ig_tooltip('Root name of the grid files (no blanks)')
   if (ig_input_text('output directory', output_dir, hint='OUT/')) continue
   if (ig_input('blocks', blocks, step=1_int32)) blocks = max(blocks, 1_int32)
   if (ig_combo('scheme', scheme, ['centred 2nd', 'TVD        ', 'WENO 5     '])) continue
   if (ig_collapsing_header('Restart')) then
      if (ig_checkbox('restart from a solution', restart)) continue
      call ig_begin_disabled(.not. restart)     ! greyed out until the box is ticked
      if (ig_input_text('restart file', restart_file)) continue
      call ig_end_disabled()
   endif
   call ig_end_tab()
endif
