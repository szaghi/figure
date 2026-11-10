!< cb_scheme, cookbook: choose a scheme: a few options shown at once (radio buttons), many in a drop-down list (combo),
!< a long list kept in view (list box).
program cb_scheme
!< cb_scheme, cookbook: choose a scheme: a few options shown at once (radio buttons), many in a drop-down list (combo),
!< a long list kept in view (list box).
!<
!< The reconstruction scheme is one of three, all shown: radio buttons. The limiter is one of seven, shown when asked:
!< a combo. The block whose scheme is set is one of 64, a list that stays on screen and scrolls: a list box.
!< `cb_scheme --check` opens no window: it clicks headless and prints the choices.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_combo, ig_em, ig_end, ig_item_rect, ig_list_box, ig_radio, ig_same_line, &
                   ig_separator_text, ig_set_next_item_width, ig_set_next_window, ig_text
use figure_testing, only : test_click, test_mouse_move, test_wheel
implicit none
integer(int32), parameter :: NBLOCKS = 64_int32 !< Blocks of the grid.
type(app_object)          :: app                !< Application.
integer(int32)            :: scheme             !< 1 WENO5, 2 WENO7, 3 TVD.
integer(int32)            :: limiter            !< Index into limiters.
integer(int32)            :: block              !< Index into blocks.
character(len=12)         :: limiters(7)        !< The limiters.
character(len=16)         :: blocks(NBLOCKS)    !< The blocks.
character(len=5), parameter :: SCHEMES(3) = ['WENO5', 'WENO7', 'TVD  '] !< The schemes, for the output.
real(real64)              :: radio_at(4)        !< Rectangle of the last radio button [pixels].
real(real64)              :: list_at(4)         !< Rectangle of the list box [pixels].
character(len=16)         :: arg                !< First argument.
logical                   :: check              !< --check: headless, scripted input.
integer(int32)            :: frame              !< Frame counter.
integer(int32)            :: i                  !< Counter.
!run cb_scheme ./cb_scheme --check
scheme = 1_int32
limiter = 1_int32
block = 1_int32
limiters = [character(len=12) :: 'minmod', 'van Leer', 'van Albada', 'superbee', 'MC', 'Koren', 'none']
do i = 1_int32, NBLOCKS
   write(blocks(i), '(A,I0)') 'block ', i
enddo
radio_at = 0.0_real64
list_at = 0.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(460_int32, 360_int32)
else
   call app%init('FIGURE: choose a scheme', 460_int32, 360_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 440.0_real64, 340.0_real64)
   if (ig_begin('Numerics')) then
      !region radio
      call ig_separator_text('scheme')
      if (ig_radio('WENO5', scheme, 1_int32)) call said('scheme')
      call ig_same_line()
      if (ig_radio('WENO7', scheme, 2_int32)) call said('scheme')
      call ig_same_line()
      if (ig_radio('TVD', scheme, 3_int32)) call said('scheme')
      !endregion radio
      call ig_item_rect(radio_at(1), radio_at(2), radio_at(3), radio_at(4))
      !region list
      if (scheme == 3_int32) then                          ! a limiter only for TVD
         call ig_set_next_item_width(ig_em(10.0_real64))
         if (ig_combo('limiter', limiter, limiters)) call said('limiter')
      endif
      call ig_separator_text('applied to')
      call ig_set_next_item_width(ig_em(10.0_real64))
      if (ig_list_box('block', block, blocks, height=ig_em(9.0_real64))) call said('block')
      !endregion list
      call ig_item_rect(list_at(1), list_at(2), list_at(3), list_at(4))
      call ig_text(trim(SCHEMES(scheme))//' on '//trim(blocks(block)))
   endif
   call ig_end()
   if (check) then
      call script(frame)
      if (frame == 45_int32) exit
   endif
enddo
call app%destroy()
contains
   subroutine script(f)
   !< The input of --check, by frame: TVD chosen, the list scrolled by the wheel, the row at its top clicked.
   integer(int32), intent(in) :: f !< Frame.

   select case (f)
   case (5_int32)
      call test_click(radio_at(1) + 8.0_real64, 0.5_real64 * (radio_at(2) + radio_at(4)))
   case (15_int32)
      call test_mouse_move(0.5_real64 * (list_at(1) + list_at(3)), 0.5_real64 * (list_at(2) + list_at(4)))
      call test_wheel(-4.0_real64)
   case (25_int32)
      call test_click(list_at(1) + 30.0_real64, list_at(2) + 12.0_real64)
   endselect
   endsubroutine script

   subroutine said(what)
   !< A choice changed (printed in --check).
   character(len=*), intent(in) :: what !< What changed.
   if (.not. check) return
   select case (what)
   case ('scheme')
      write(output_unit, '(A,I0,A)') 'frame ', frame, ': scheme '//trim(SCHEMES(scheme))
   case ('limiter')
      write(output_unit, '(A,I0,A)') 'frame ', frame, ': limiter '//trim(limiters(limiter))
   case default
      write(output_unit, '(A,I0,A)') 'frame ', frame, ': '//trim(blocks(block))//' (scrolled, then picked)'
   endselect
   endsubroutine said
endprogram cb_scheme
