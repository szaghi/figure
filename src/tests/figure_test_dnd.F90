!< figure_test_dnd, drag and drop driven by synthetic input, headless: from a tree node to a plot, to a widget, to an
!< axis, a target of another type refusing, and the usage errors.
program figure_test_dnd
!< figure_test_dnd, drag and drop driven by synthetic input, headless: from a tree node to a plot, to a widget, to an
!< axis, a target of another type refusing, and the usage errors.
!<
!< A tree of two leaves: 'mesh-A' a source of type 'case' (its preview "case mesh-A"), 'a note' a source of type
!< 'note'. A button 'Bin' accepts 'case'; a plot accepts 'case' on its area (the point it lands on in plot units) and on
!< its x axis alone. The drags, each a press on the source, two moves and a release over the target: 'mesh-A' to the
!< plot area (delivered once, at the point under the pointer), 'a note' to the plot (not delivered: another type),
!< 'mesh-A' to the button, 'mesh-A' to the x axis (the axis target, not the area). `ig_dragging('case')` is true while
!< a case is dragged and only then. Wrong types, a plot target outside a plot, an axis with the legend: refused with
!< their statuses and messages.
! oracle: drag
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, app_object, figure_last_error, ig_begin, ig_button,     &
                   ig_drag_source, ig_dragging, ig_drop_target, ig_end, ig_item_rect, ig_set_next_window,           &
                   ig_tree_node, ig_tree_pop, ip_begin_plot, ip_drop_target, ip_end_plot, ip_line, ip_plot_to_pixels, &
                   ip_setup_axes_limits
use figure_testing, only : test_mouse_button, test_mouse_move, test_next_frame

implicit none
type(app_object)              :: app            !< Application.
logical                       :: ok(12)         !< Per-check outcome.
real(real64)                  :: mesh(4)        !< The 'mesh-A' node's rectangle.
real(real64)                  :: note(4)        !< The 'a note' node's rectangle.
real(real64)                  :: bin(4)         !< The button's rectangle.
real(real64)                  :: area(2)        !< A point of the plot area [pixels]: plot (2, 0.5).
real(real64)                  :: xaxis(2)       !< A point on the x axis's tick labels [pixels].
real(real64)                  :: x, y           !< Where a payload was dropped [plot units].
real(real64)                  :: drop_xy(2)     !< ... on the plot area.
character(len=:), allocatable :: payload        !< A payload received.
character(len=:), allocatable :: got_plot       !< What the plot area received.
character(len=:), allocatable :: got_bin        !< What the button received.
character(len=:), allocatable :: got_axis       !< What the axis received.
character(len=160)            :: msg(6)         !< Messages of refused calls.
integer(int32)                :: st(6)          !< Their statuses.
integer(int32)                :: plot_drops     !< Deliveries to the plot area.
integer(int32)                :: bin_drops      !< ... to the button.
integer(int32)                :: axis_drops     !< ... to the x axis.
logical                       :: dragged(90)    !< ig_dragging('case') per frame.
integer(int32)                :: sourcing       !< Frames 'mesh-A' reported itself dragged.
integer(int32)                :: errors         !< Frames with a usage error.
integer(int32)                :: f              !< Frame.
integer(int32)                :: s              !< Status of a frame.

ok = .false.
plot_drops = 0_int32
bin_drops = 0_int32
axis_drops = 0_int32
dragged = .false.
sourcing = 0_int32
errors = 0_int32
st = -1_int32
msg = ''
got_plot = ''
got_bin = ''
got_axis = ''
drop_xy = -1.0_real64
call app%init_headless(900_int32, 700_int32)
do f = 1_int32, 90_int32
   if (.not. app%next_frame(s)) exit
   if (s /= FIG_OK) errors = errors + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 860.0_real64, 660.0_real64, always=.true.)
   if (ig_begin('Cases')) then
      if (ig_tree_node('Cases', default_open=.true.)) then
         if (ig_tree_node('mesh-A', leaf=.true.)) call ig_tree_pop()
         call ig_item_rect(mesh(1), mesh(2), mesh(3), mesh(4))
         if (ig_drag_source('case', 'mesh-A', preview='case mesh-A')) sourcing = sourcing + 1_int32
         if (ig_tree_node('a note', leaf=.true.)) call ig_tree_pop()
         call ig_item_rect(note(1), note(2), note(3), note(4))
         if (ig_drag_source('note', 'a note')) continue
         call ig_tree_pop()
      endif
      if (ig_button('Bin')) continue
      call ig_item_rect(bin(1), bin(2), bin(3), bin(4))
      if (ig_drop_target('case', payload)) then
         bin_drops = bin_drops + 1_int32
         got_bin = payload
      endif
      dragged(f) = ig_dragging('case')
      if (ip_begin_plot('Drop here', height=360.0_real64)) then
         call ip_setup_axes_limits(0.0_real64, 4.0_real64, 0.0_real64, 1.0_real64)
         call ip_line('line', [0.0_real64, 4.0_real64], [0.0_real64, 1.0_real64])
         call ip_plot_to_pixels(2.0_real64, 0.5_real64, area(1), area(2))
         call ip_plot_to_pixels(1.0_real64, 0.0_real64, xaxis(1), xaxis(2))
         xaxis(2) = xaxis(2) + 12.0_real64 ! below the plot area: the tick labels
         if (ip_drop_target('case', payload, x=x, y=y)) then
            plot_drops = plot_drops + 1_int32
            got_plot = payload
            drop_xy = [x, y]
         endif
         if (ip_drop_target('case', payload, axis='x1')) then
            axis_drops = axis_drops + 1_int32
            got_axis = payload
         endif
         if (f == 80_int32) then
            if (ip_drop_target('case', payload, axis='x1', legend=.true., stat=st(5))) continue
            msg(5) = figure_last_error()
         endif
         call ip_end_plot()
      endif
      if (f == 80_int32) then
         if (ig_drag_source('', 'x', stat=st(1))) continue
         msg(1) = figure_last_error()
         if (ig_drag_source('_private', 'x', stat=st(2))) continue
         msg(2) = figure_last_error()
         if (ig_drop_target(repeat('t', 33), payload, stat=st(3))) continue
         msg(3) = figure_last_error()
         if (ip_drop_target('case', payload, stat=st(4))) continue ! outside a plot
         msg(4) = figure_last_error()
      endif
   endif
   call ig_end()
   select case (f)
   case (5_int32)
      call drag(mesh, area)                    ! a case to the plot area
   case (20_int32)
      call drag(note, area)                    ! a note to the plot: refused
   case (35_int32)
      call drag(mesh, [0.5_real64 * (bin(1) + bin(3)), 0.5_real64 * (bin(2) + bin(4))]) ! a case to the button
   case (50_int32)
      call drag(mesh, xaxis)                   ! a case to the x axis
   endselect
enddo
if (app%next_frame(s)) continue
if (s /= FIG_OK) errors = errors + 1_int32
call app%destroy()

ok(1) = plot_drops == 1_int32 .and. got_plot == 'mesh-A'                   ! the case reached the plot area, once
ok(2) = abs(drop_xy(1) - 2.0_real64) < 0.1_real64 .and. abs(drop_xy(2) - 0.5_real64) < 0.1_real64 ! where it landed
ok(3) = bin_drops == 1_int32 .and. got_bin == 'mesh-A'                     ! the case reached the button
ok(4) = axis_drops == 1_int32 .and. got_axis == 'mesh-A'                   ! ... and the axis, alone
ok(5) = sourcing > 0_int32                                                 ! the source reported its drag
ok(6) = any(dragged(5:19)) .and. .not. any(dragged(20:34)) .and. any(dragged(35:49)) .and. & ! a case's drags,
        .not. any(dragged(1:4)) .and. .not. any(dragged(65:89))  ! not a note's, nor before or after
ok(7) = all(st(1:3) == int(FIG_ERR_ARGUMENT, int32)) .and.                                                   &
        msg(1) == "ig_drag_source: type '' must have 1 to 32 characters" .and.                              &
        msg(2) == "ig_drag_source: type '_private' starts with '_' (Dear ImGui's own types)" .and.          &
        msg(3) == "ig_drop_target: type '"//repeat('t', 33)//"' must have 1 to 32 characters"
ok(8) = st(4) == int(FIG_ERR_STATE, int32) .and. msg(4) == 'ip_drop_target: no plot is being declared (call it '// &
        'between a true ip_begin_plot and ip_end_plot)'
ok(9) = st(5) == int(FIG_ERR_ARGUMENT, int32) .and. msg(5) == 'ip_drop_target: give axis or legend, not both'
ok(10) = errors == 0_int32                                                 ! no usage error kept for a frame
ok(11) = mesh(3) > mesh(1) .and. area(1) > 0.0_real64                      ! the geometry was read
ok(12) = plot_drops + bin_drops + axis_drops == 3_int32                    ! the note was delivered nowhere

write(output_unit, '(A,*(L2))') 'figure_test_dnd checks:', ok
if (.not. all(ok)) then
   write(output_unit, '(A,3I3,A,2F8.3,A,I5)') 'drops ', plot_drops, bin_drops, axis_drops, ' at ', drop_xy, &
      ' sourcing ', sourcing
   write(output_unit, '(A,4F8.1,A,2F8.1,A,2F8.1)') 'mesh ', mesh, ' area ', area, ' xaxis ', xaxis
   write(output_unit, '(A,6I3)') 'statuses ', st
   write(output_unit, '(A,90L1)') 'dragged ', dragged
   do f = 1_int32, 6_int32
      write(output_unit, '(A)') trim(msg(f))
   enddo
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1
contains
   subroutine drag(from, to)
   !< Queue a drag with the left button from the centre of rectangle `from` to point `to`: a press, two moves (Dear
   !< ImGui starts a drag past a threshold), a pause over the target (it accepts the payload a frame before the
   !< release delivers it), the release.
   real(real64), intent(in) :: from(4) !< Source rectangle [pixels].
   real(real64), intent(in) :: to(2)   !< Target point [pixels].
   real(real64)             :: c(2)    !< Source centre.

   c = [0.5_real64 * (from(1) + from(3)), 0.5_real64 * (from(2) + from(4))]
   call test_mouse_move(c(1), c(2))
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_mouse_move(c(1) + 20.0_real64, c(2) + 10.0_real64)
   call test_next_frame()
   call test_mouse_move(to(1), to(2))
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.false.)
   call test_next_frame()
   endsubroutine drag
endprogram figure_test_dnd
