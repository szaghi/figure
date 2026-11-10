!< cb_canvas, cookbook: a domain sketch with clickable boundaries, drawn on a canvas.
program cb_canvas
!< cb_canvas, cookbook: a domain sketch with clickable boundaries, drawn on a canvas.
!<
!< A channel 4 m x 1 m with a cylinder, drawn with the canvas's primitives: each boundary in the colour of its
!< condition and named by a word beside it. The boundary under the pointer is drawn thicker, with a tooltip; a click
!< selects it, and the radio buttons below set its condition. `cb_canvas --check` opens no window: it moves over the
!< top wall, clicks the cylinder, chooses "slip wall" for it, and prints what the canvas reported.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, canvas_event_object, ig_begin, ig_begin_tooltip, ig_canvas, ig_draw_circle,        &
                   ig_draw_line, ig_draw_rect, ig_draw_text, ig_end, ig_end_tooltip, ig_item_rect, ig_radio,      &
                   ig_same_line, ig_set_next_window, ig_text
use figure_testing, only : test_click, test_mouse_move
implicit none
integer(int32),    parameter :: NB = 5_int32                 !< Boundaries.
integer(int32),    parameter :: NC = 4_int32                 !< Conditions.
character(len=8),  parameter :: BOUNDARY(NB) = [character(len=8) :: 'inlet', 'outlet', 'bottom', 'top', 'cylinder']
character(len=15), parameter :: CONDITION(NC) = [character(len=15) :: 'velocity inlet', 'pressure outlet', &
                                                 'no-slip wall', 'slip wall'] !< The conditions.
real(real64),      parameter :: HUE(4, NC) = reshape([0.35_real64, 0.65_real64, 1.00_real64, 1.0_real64,  &
                                                      1.00_real64, 0.60_real64, 0.25_real64, 1.0_real64,  &
                                                      0.85_real64, 0.85_real64, 0.85_real64, 1.0_real64,  &
                                                      0.40_real64, 0.85_real64, 0.45_real64, 1.0_real64], [4, NC])
real(real64),      parameter :: XC = 1.0_real64              !< The cylinder's centre [m].
real(real64),      parameter :: YC = 0.5_real64              !< ...
real(real64),      parameter :: RC = 0.15_real64             !< Its radius [m].
real(real64),      parameter :: PICK = 6.0_real64            !< How near the pointer picks a boundary [pixels].
type(app_object)             :: app                          !< Application.
type(canvas_event_object)    :: ev                           !< What happened over the canvas.
integer(int32)               :: bc(NB)                       !< Each boundary's condition.
integer(int32)               :: hovered                      !< The boundary under the pointer (0: none).
integer(int32)               :: selected                     !< The boundary clicked last (0: none).
real(real64)                 :: scale                        !< Pixels per metre.
real(real64)                 :: radio_at(4)                  !< The last radio button [pixels].
character(len=16)            :: arg                          !< First argument.
logical                      :: check                        !< --check: headless, scripted input.
integer(int32)               :: frame                        !< Frame counter.
integer(int32)               :: k                            !< Condition.
!run cb_canvas ./cb_canvas --check
bc = [1_int32, 2_int32, 3_int32, 3_int32, 3_int32]
hovered = 0_int32
selected = 0_int32
radio_at = 0.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(640_int32, 340_int32)
else
   call app%init('FIGURE: a domain sketch', 640_int32, 340_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 320.0_real64)
   if (ig_begin('Domain')) then
      !region canvas
      call ig_canvas('domain', 0.0_real64, 200.0_real64, ev)  ! the window's width, 200 pixels high
      scale = (ev%size(1) - 80.0_real64) / 4.0_real64        ! 4 m across, 40 pixels free each side
      hovered = 0_int32
      if (ev%hovered) hovered = nearest(ev%mouse(1), ev%mouse(2))
      if (ev%clicked(1)) selected = hovered                  ! a click on empty space clears the selection
      if (hovered > 0_int32) then
         if (ig_begin_tooltip()) then
            call ig_text(trim(BOUNDARY(hovered))//': '//trim(CONDITION(bc(hovered)))//' (click to change)')
            call ig_end_tooltip()
         endif
      endif
      !endregion canvas
      call sketch()
      if (selected > 0_int32) then
         call ig_text(trim(BOUNDARY(selected))//':')
         do k = 1_int32, NC
            call ig_same_line()
            if (ig_radio(trim(CONDITION(k)), bc(selected), k)) continue
         enddo
         call ig_item_rect(radio_at(1), radio_at(2), radio_at(3), radio_at(4))
      else
         call ig_text('Click a boundary to set its condition.')
      endif
   endif
   call ig_end()
   if (check) then
      call script(frame)
      if (frame == 40_int32) exit
   endif
enddo
call app%destroy()
contains
   subroutine sketch()
   !< The domain: the fluid in grey, each boundary in its condition's colour and named; the hovered one thicker, the
   !< selected one with a mark. Canvas metres (x right, y up) become screen pixels by `px` and `py`.
   real(real64) :: w(NB) !< Line thickness of each boundary [pixels].
   integer(int32) :: b   !< Boundary.

   !region draw
   do b = 1_int32, NB
      w(b) = merge(4.0_real64, 2.0_real64, b == hovered .or. b == selected)
   enddo
   call ig_draw_rect(px(0.0_real64), py(0.0_real64), px(4.0_real64), py(1.0_real64), &
                     [0.5_real64, 0.5_real64, 0.5_real64, 0.25_real64], filled=.true.)
   call ig_draw_line(px(0.0_real64), py(0.0_real64), px(0.0_real64), py(1.0_real64), HUE(:, bc(1)), w(1))
   call ig_draw_line(px(4.0_real64), py(0.0_real64), px(4.0_real64), py(1.0_real64), HUE(:, bc(2)), w(2))
   call ig_draw_line(px(0.0_real64), py(0.0_real64), px(4.0_real64), py(0.0_real64), HUE(:, bc(3)), w(3))
   call ig_draw_line(px(0.0_real64), py(1.0_real64), px(4.0_real64), py(1.0_real64), HUE(:, bc(4)), w(4))
   call ig_draw_circle(px(XC), py(YC), RC * scale, [0.1_real64, 0.1_real64, 0.1_real64], filled=.true.)
   call ig_draw_circle(px(XC), py(YC), RC * scale, HUE(:, bc(5)), w(5))
   call ig_draw_text(px(0.0_real64) - 36.0_real64, py(0.5_real64) - 8.0_real64, 'inlet', HUE(:, bc(1)))
   call ig_draw_text(px(4.0_real64) + 4.0_real64, py(0.5_real64) - 8.0_real64, 'outlet', HUE(:, bc(2)))
   call ig_draw_text(px(2.0_real64), py(0.0_real64) + 4.0_real64, 'bottom', HUE(:, bc(3)))
   call ig_draw_text(px(2.0_real64), py(1.0_real64) - 20.0_real64, 'top', HUE(:, bc(4)))
   call ig_draw_text(px(XC) + RC * scale + 6.0_real64, py(YC) - 8.0_real64, 'cylinder', HUE(:, bc(5)))
   !endregion draw
   endsubroutine sketch

   pure function px(x) result(p)
   !< Screen abscissa of `x` metres.
   real(real64), intent(in) :: x !< Abscissa [m].
   real(real64)             :: p !< [pixels].
   p = ev%origin(1) + 40.0_real64 + x * scale
   endfunction px

   pure function py(y) result(p)
   !< Screen ordinate of `y` metres (y up, the screen's down).
   real(real64), intent(in) :: y !< Ordinate [m].
   real(real64)             :: p !< [pixels].
   p = ev%origin(2) + 0.5_real64 * ev%size(2) + (0.5_real64 - y) * scale
   endfunction py

   !region pick
   function nearest(cx, cy) result(b)
   !< The boundary within PICK pixels of the canvas point (`cx`, `cy`), 0 if none.
   real(real64), intent(in) :: cx !< Canvas abscissa [pixels].
   real(real64), intent(in) :: cy !< Canvas ordinate [pixels].
   integer(int32)           :: b  !< Boundary.
   real(real64)             :: x  !< The point [m].
   real(real64)             :: y  !< ...
   real(real64)             :: d(NB) !< Its distance to each boundary [pixels].

   x = (cx - 40.0_real64) / scale
   y = 0.5_real64 - (cy - 0.5_real64 * ev%size(2)) / scale
   d(1) = segment(x, y, 0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64)
   d(2) = segment(x, y, 4.0_real64, 0.0_real64, 4.0_real64, 1.0_real64)
   d(3) = segment(x, y, 0.0_real64, 0.0_real64, 4.0_real64, 0.0_real64)
   d(4) = segment(x, y, 0.0_real64, 1.0_real64, 4.0_real64, 1.0_real64)
   d(5) = abs(hypot(x - XC, y - YC) - RC)
   b = minloc(d, 1)
   if (d(b) * scale > PICK) b = 0_int32
   endfunction nearest
   !endregion pick

   pure function segment(x, y, xa, ya, xb, yb) result(d)
   !< Distance of (`x`, `y`) from the segment (`xa`, `ya`)-(`xb`, `yb`).
   real(real64), intent(in) :: x, y   !< The point.
   real(real64), intent(in) :: xa, ya !< The segment's start.
   real(real64), intent(in) :: xb, yb !< Its end.
   real(real64)             :: d      !< Distance.
   real(real64)             :: t      !< Parameter of the nearest point, in [0, 1].
   t = ((x - xa) * (xb - xa) + (y - ya) * (yb - ya)) / ((xb - xa)**2 + (yb - ya)**2)
   t = min(max(t, 0.0_real64), 1.0_real64)
   d = hypot(x - xa - t * (xb - xa), y - ya - t * (yb - ya))
   endfunction segment

   subroutine script(f)
   !< The input of --check, by frame: over the top wall, a click on the cylinder, then "slip wall" for it.
   integer(int32), intent(in) :: f !< Frame.

   select case (f)
   case (3_int32)
      call test_mouse_move(px(3.0_real64), py(1.0_real64) + 2.0_real64)
   case (6_int32)
      call said('the pointer 2 pixels below the top wall')
      call test_click(px(XC + RC), py(YC))
   case (12_int32)
      call said('a click on the cylinder''s edge')
      call test_click(radio_at(1) + 8.0_real64, 0.5_real64 * (radio_at(2) + radio_at(4)))
   case (18_int32)
      call said('"slip wall" chosen')
   endselect
   endsubroutine script

   subroutine said(what)
   !< Print what the canvas reports after `what` happened.
   character(len=*), intent(in) :: what !< What happened.
   write(output_unit, '(A)') what//':'
   write(output_unit, '(A,2F8.1,A)') '  pointer in the canvas', ev%mouse, ' px'
   if (hovered > 0_int32) then
      write(output_unit, '(A)') '  hovered  '//trim(BOUNDARY(hovered))
   else
      write(output_unit, '(A)') '  hovered  none'
   endif
   if (selected > 0_int32) then
      write(output_unit, '(A)') '  selected '//trim(BOUNDARY(selected))//', '//trim(CONDITION(bc(selected)))
   else
      write(output_unit, '(A)') '  selected none'
   endif
   endsubroutine said
endprogram cb_canvas
