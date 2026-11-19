if (about) then
   call ig_open_popup('About the studio')
   about = .false.
endif
call ig_set_next_window(400.0_real64, 230.0_real64, 320.0_real64, 160.0_real64) ! where it opens, and its size
if (ig_begin_popup_modal('About the studio')) then
   call ig_text(ICON_FLAME//' FIGURE studio')
   call ig_text_wrapped('The solver studio of FIGURE''s tutorial: a case, its input, a run of the solver and '// &
                        'its result, in one window.')
   call ig_text('Look: '//trim(look)//', palette: '//trim(palette))
   if (ig_button('Close')) call ig_close_current_popup()
   call ig_end_popup()
endif
