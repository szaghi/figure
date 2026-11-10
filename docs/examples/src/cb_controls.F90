!< cb_controls, reference example: workspace buttons, text and layout, icons and fonts, and a headless test that
!< clicks a button and edits a field as a user does.
program cb_controls
!< cb_controls, reference example: workspace buttons, text and layout, icons and fonts, and a headless test that
!< clicks a button and edits a field as a user does.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ig_align_text_to_frame_padding, ig_begin, ig_begin_child, ig_button, ig_em, ig_end, &
                   ig_end_child, ig_input, ig_item_rect, ig_pop_font, ig_push_font, ig_same_line, ig_selectable, &
                   ig_separator, ig_set_next_item_width, ig_set_next_window, ig_text, ig_text_colored, &
                   ig_text_disabled, ig_text_size, ig_text_wrapped, ig_tool_button, ig_tooltip, list_clipper_object, &
                   ICON_ACTIVITY, ICON_CHART_LINE, ICON_FILE_PEN, ICON_PLAY, ICON_TRIANGLE_ALERT
use figure_testing, only : test_click, test_key, test_type

implicit none
type(app_object)  :: app                        !< Application.
integer(int32)    :: tool = 1_int32               !< The workspace chosen: 1 input, 2 monitor.
real(real64)      :: cfl = 0.5_real64             !< CFL number.
integer(int32)    :: runs = 0_int32               !< Times "Run" was pressed.
real(real64)      :: monitor_at(2) = 0.0_real64   !< Centre of the Monitor button [pixels], for the test.
real(real64)      :: cfl_at(2) = 0.0_real64       !< Centre of the CFL field [pixels], for the test.
character(len=16) :: names(1000)                  !< The rows of a long list.
integer(int32)    :: current = 1_int32            !< The row chosen.
integer(int32)    :: frame                        !< Frame counter.
!run cb_controls ./cb_controls

do frame = 1_int32, size(names, kind=int32)
   write(names(frame), '(A,I0)') 'block ', frame
enddo
!region font
call app%init_headless(640_int32, 480_int32)
call app%set_font('plex-sans', 15.0_real64)                   ! the default font, at its default size
!endregion font
!region style
call app%set_style('paper')                                   ! or: call app%set_style('seal', lines='okabe-ito')
!endregion style
!region edit_field
do frame = 1_int32, 24_int32
   if (.not. app%next_frame()) exit
   call draw()
   if (frame == 2_int32) call test_click(monitor_at(1), monitor_at(2)) ! the Monitor workspace
   if (frame == 8_int32) then
      call test_click(cfl_at(1), cfl_at(2))                   ! focus the field
      call test_key('shortcut', down=.true.)                  ! select what is there: ctrl+a (cmd+a on macOS)
      call test_key('a')
      call test_key('shortcut', down=.false.)
      call test_type('0.8')                                   ! replace it
      call test_key('enter')                                  ! confirm: cfl becomes 0.8
   endif
enddo
!endregion edit_field
call app%destroy()
write(output_unit, '(A,I0,A,F5.3)') 'workspace: ', tool, ', CFL: ', cfl
if (tool /= 2_int32 .or. abs(cfl - 0.8_real64) > 1.0e-12_real64) error stop 'cb_controls: the clicks were lost'

contains
   subroutine draw()
   !< The window of controls, drawn every frame.
   real(real64)              :: r(4) !< An item's rectangle [pixels].
   real(real64)              :: w    !< The widest button label [pixels].
   type(list_clipper_object) :: clip !< Only the rows in view.
   integer(int32)            :: i    !< Row.

   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 460.0_real64, always=.true.)
   if (ig_begin('Controls')) then
      !region tools
      if (ig_tool_button('Input', ICON_FILE_PEN, selected=tool == 1)) tool = 1
      call ig_tooltip('the input files')
      call ig_same_line()
      if (ig_tool_button('Monitor', ICON_ACTIVITY, selected=tool == 2)) tool = 2
      call ig_tooltip('the residuals of the run')
      !endregion tools
      call ig_item_rect(r(1), r(2), r(3), r(4))
      monitor_at = [0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4))]
      !region text
      call ig_separator()
      call ig_align_text_to_frame_padding()                   ! the label level with the field's text
      call ig_text('CFL')
      call ig_same_line(ig_em(5))                             ! the field at 5 em from the left edge
      call ig_set_next_item_width(ig_em(8))
      if (ig_input('##cfl', cfl, format='%.3f')) continue
      call ig_item_rect(r(1), r(2), r(3), r(4))
      cfl_at = [0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4))]
      call ig_same_line()
      call ig_text_disabled('default 0.5')
      if (cfl > 1.0_real64) call ig_text_colored('[!!] above 1: the explicit scheme is unstable', &
                                                 [0.90_real64, 0.35_real64, 0.25_real64])
      r(1:2) = ig_text_size('Apply')                          ! width, height [pixels]
      r(3:4) = ig_text_size('Restore defaults')
      w = max(r(1), r(3))                                     ! the widest label
      if (ig_button('Apply', width=w + ig_em(1))) continue    ! two buttons of one width
      call ig_same_line()
      if (ig_button('Restore defaults', width=w + ig_em(1))) cfl = 0.5_real64
      call ig_text_wrapped('The CFL number bounds the time step: dt = CFL dx / max|u|. Values above 1 make the ' // &
                           'explicit scheme unstable; 0.5 is a safe start for a new case.')
      !endregion text
      call ig_separator()
      !region icons
      if (ig_button(ICON_PLAY//' Run')) runs = runs + 1_int32
      call ig_same_line()
      call ig_text(ICON_TRIANGLE_ALERT//' 3 warnings')
      call ig_push_font('', 32.0_real64)                      ! a big icon, alone: the current font, larger
      call ig_text(ICON_CHART_LINE)
      call ig_pop_font()
      !endregion icons
      !region fonts
      call ig_push_font('plex-mono')                          ! columns of numbers that line up
      call ig_text('   step   residual')
      call ig_text('    100   1.25e-03')
      call ig_text('   1000   4.10e-07')
      call ig_pop_font()
      call ig_push_font('', 28.0_real64)                      ! a big value, in the current font
      call ig_text('3.1416')
      call ig_pop_font()
      !endregion fonts
      call ig_separator()
      !region clipper
      if (ig_begin_child('rows', height=ig_em(6))) then        ! a region that scrolls on its own
         call clip%begin(size(names, kind=int32))
         do while (clip%step())                               ! only the rows in view are drawn
            do i = clip%first, clip%last
               if (ig_selectable(trim(names(i)), i == current)) current = i
            enddo
         enddo
      endif
      call ig_end_child()
      !endregion clipper
   endif
   call ig_end()
   endsubroutine draw
endprogram cb_controls
