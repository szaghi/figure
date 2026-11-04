call ig_set_next_window(20.0_real64, 20.0_real64, 400.0_real64, 300.0_real64, always=.true.)
if (ig_begin('Fixed')) then                    ! false when collapsed: skip the content, not the end
   call ig_text('Placed and sized every frame: cannot be moved.')
endif
call ig_end()                                  ! always, whatever ig_begin returned

call ig_set_next_window(440.0_real64, 20.0_real64, 400.0_real64, 300.0_real64)
if (ig_begin('Expensive')) then
   y = sin(x) * exp(-x)                        ! computed only while the window is visible
   if (ip_begin_plot('##damped')) then         ! end the plot only if it began
      call ip_line('damped', x, y)
      call ip_end_plot()
   endif
endif
call ig_end()
