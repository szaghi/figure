!< cb_color_picker, cookbook: a colour chosen with a picker drawn in the window, with a hue bar or a hue wheel.
program cb_color_picker
!< cb_color_picker, cookbook: a colour chosen with a picker drawn in the window, with a hue bar or a hue wheel.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_checkbox, ig_color_picker, ig_end, ig_pop_item_width, ig_push_item_width, &
                   ig_set_next_window, ig_text

implicit none
type(app_object)  :: app                                                        !< Application.
real(real64)      :: surface(4) = [0.85_real64, 0.45_real64, 0.15_real64, 1.0_real64] !< The surface's colour, RGBA.
logical           :: wheel = .false.                                            !< A hue wheel instead of the bar.
character(len=64) :: text = 'click or drag in the picker'                      !< What the picker did.

call app%init('FIGURE: a colour picker', 420_int32, 420_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 400.0_real64, 400.0_real64)
   if (ig_begin('Surface colour')) then
      !region picker
      if (ig_checkbox('hue wheel', wheel)) continue           ! the picker's form, chosen by the program
      call ig_push_item_width(260.0_real64)                    ! the picker's width; its height follows
      if (ig_color_picker('##surface', surface, wheel=wheel)) then ! true on the frames the user changes it
         write(text, '(A,4F6.2)') 'RGBA', surface
      endif
      call ig_pop_item_width()
      call ig_text(trim(text))
      !endregion picker
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_color_picker
