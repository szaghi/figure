!< cb_layout, cookbook: a form that keeps its proportions at any font size.
program cb_layout
!< cb_layout, cookbook: a form that keeps its proportions at any font size.
!<
!< Every length of the form is given in em, the font size: the window's width and place, the column where the fields
!< start, the fields' width; its height is left to its content. Its buttons are a right-aligned group, whatever their
!< width at this font. Ctrl+up and ctrl+down change the font size by 3 pixels (12 to 36): the form grows or shrinks
!< and keeps its shape.
!< `cb_layout --check` opens no window: it measures the form at 15 pixels, makes the font 24 pixels with three
!< ctrl+up, and measures it again.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_align_begin, ig_align_end, ig_align_text_to_frame_padding, ig_begin, ig_button, &
                   ig_checkbox, ig_em, ig_end, ig_font_size, ig_input, ig_input_text, ig_last_item,              &
                   ig_pop_item_width, ig_push_item_width, ig_same_line, ig_separator_text, ig_set_next_window,  &
                   ig_shortcut, ig_spacing, ig_text, ig_text_disabled, item_status_object
use figure_testing, only : test_key, test_window_rect
implicit none
type(app_object)         :: app        !< Application.
type(item_status_object) :: s          !< Status of an item.
character(len=24)        :: case_name  !< The form's values.
integer(int32)           :: cells      !< ...
real(real64)             :: cfl        !< ...
real(real64)             :: t_end      !< ...
logical                  :: viscous    !< ...
real(real64)             :: text_size  !< The font size set [logical pixels].
real(real64)             :: field(4)   !< The name field's rectangle [pixels].
real(real64)             :: buttons(4) !< The buttons' group's rectangle [pixels].
character(len=64)        :: line       !< The status line.
character(len=16)        :: arg        !< First argument.
logical                  :: check      !< --check: headless, scripted input.
integer(int32)           :: frame      !< Frame counter.
!run cb_layout ./cb_layout --check
case_name = 'wing-body'
cells = 128_int32
cfl = 0.8_real64
t_end = 2.5_real64
viscous = .true.
text_size = 15.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(900_int32, 640_int32)
else
   call app%init('FIGURE: a form in em', 900_int32, 640_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   !region font
   if (ig_shortcut('ctrl+up', scope='global')) call resize(text_size + 3.0_real64)
   if (ig_shortcut('ctrl+down', scope='global')) call resize(text_size - 3.0_real64)
   !endregion font
   !region window
   call ig_set_next_window(ig_em(1), ig_em(1), ig_em(24), 0.0_real64, always=.true.) ! 24 em wide, as high as its
                                                                                     ! content (height 0)
   if (ig_begin('Case')) call form()
   call ig_end()
   !endregion window
   if (check) then
      call script(frame)
      if (frame == 16_int32) exit
   endif
enddo
call app%destroy()
contains
   subroutine form()
   !< The form: labels in one column, fields in another, buttons at the right.
   !region form
   call ig_push_item_width(ig_em(12))                ! every field 12 em wide
   call ig_separator_text('Grid')
   call label('name')
   if (ig_input_text('##name', case_name)) continue
   s = ig_last_item()
   field = s%rect
   call label('cells')
   if (ig_input('##cells', cells, step=16_int32)) continue
   call ig_separator_text('Run')
   call label('CFL')
   if (ig_input('##cfl', cfl)) continue
   call label('end time [s]')
   if (ig_input('##t_end', t_end)) continue
   call label('viscous')
   if (ig_checkbox('##viscous', viscous)) continue
   call ig_pop_item_width()
   call ig_spacing()
   call ig_align_begin('buttons', 'right')           ! at the right edge, whatever their width at this font
   if (ig_button('Reset')) continue
   call ig_same_line()
   if (ig_button('Run')) continue
   call ig_align_end()
   !endregion form
   s = ig_last_item()
   buttons = s%rect
   write(line, '(A,I0,A)') 'text ', nint(ig_font_size()), ' px: ctrl+up larger, ctrl+down smaller'
   call ig_text_disabled(trim(line))
   endsubroutine form

   !region label
   subroutine label(text)
   !< A label, then the next item 7 em from the window's left edge, level with it.
   character(len=*), intent(in) :: text !< Label.
   call ig_align_text_to_frame_padding()
   call ig_text(text)
   call ig_same_line(ig_em(7))
   endsubroutine label
   !endregion label

   subroutine resize(size_px)
   !< The font size, kept in [12, 36] pixels.
   real(real64), intent(in) :: size_px !< New size [logical pixels].
   text_size = min(36.0_real64, max(12.0_real64, size_px))
   call app%set_font('plex-sans', size=text_size)
   endsubroutine resize

   subroutine report()
   !< In --check: the form's lengths in em, and where the buttons end.
   real(real64) :: w(4) !< The window's rectangle [pixels].
   real(real64) :: em   !< The font size [pixels].
   call test_window_rect('Case', w(1), w(2), w(3), w(4))
   em = text_size * app%content_scale()
   write(output_unit, '(A,I0,A,F0.1,A,F0.1,A,F0.1,A,I0,A)') 'font ', nint(em), ' px: window ', &
      (w(3) - w(1)) / em, ' em wide, fields ', field(3) / em, ' em wide from ', &
      (field(1) - w(1)) / em, ' em, buttons end ', nint(w(3) - (buttons(1) + buttons(3))), &
      ' px from the right edge (the window padding)'
   endsubroutine report

   subroutine script(f)
   !< The input of --check, by frame.
   integer(int32), intent(in) :: f !< Frame.
   select case (f)
   case (4_int32)
      call report()
   case (5_int32, 7_int32, 9_int32)        ! ctrl+up, three times: 15 -> 24 pixels
      call test_key('shortcut', down=.true.)
      call test_key('up')
      call test_key('shortcut', down=.false.)
   case (15_int32)
      call report()
   endselect
   endsubroutine script
endprogram cb_layout
