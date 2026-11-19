if (app%window_visible('Case')) then              ! a registered window is drawn while it is shown
   if (ig_begin('Case')) call draw_case()         ! no open=: FIGURE's flag, the close button hides it
   call ig_end()
endif
if (app%window_visible('Input')) then
   if (ig_begin('Input')) call draw_input()
   call ig_end()
endif
