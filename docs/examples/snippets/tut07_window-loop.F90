do while (app%next_frame())                          ! .false. once the user confirmed the quit
   call draw_studio()
enddo
call app%destroy()
