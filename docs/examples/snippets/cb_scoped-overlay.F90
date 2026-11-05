call ig_set_next_window(420.0_real64, 30.0_real64)
if (ig_begin('##overlay', flags=ior(ImGuiWindowFlags_NoDecoration,                     &
                                    ior(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground)))) then
   call ig_text('no title, no frame,')
   call ig_text('no background')
endif
call ig_end()
