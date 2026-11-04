call app%init('FIGURE: first window', 640_int32, 360_int32)
do while (app%next_frame())
   if (ig_begin('Hello')) then
      call ig_text('Hello from Fortran.')
   endif
   call ig_end()
enddo
call app%destroy()
