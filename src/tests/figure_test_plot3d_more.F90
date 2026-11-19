!< figure_test_plot3d_more, ImPlot3D's per-point colours and sizes, axis formats and ticks, and its style pushed by
!< name, headless.
program figure_test_plot3d_more
!< figure_test_plot3d_more, ImPlot3D's per-point colours and sizes, axis formats and ticks, and its style pushed by
!< name, headless.
!<
!< 1. A scatter of two points with `colors` (a colour of its own each) and `sizes` (4 and 14 pixels): each colour is
!<    drawn, the large marker's extent wider than the small one's. A line of three points with `colors`: the
!<    segment from the second point is drawn in the second colour.
!< 2. The axes' tick labels in a colour of their own (`ip3_push_style_color('AxisText', ...)`): with
!<    `ip3_setup_axis(..., format=)` of a long format, their extent is wider than with the default format; with
!<    `ip3_setup_axis_ticks` of one blank label per axis, nothing is drawn in that colour.
!< 3. `ip3_push_style_var('PlotPadding', ...)`: the plot background (`PlotBg`, pushed to a colour of its own) is
!<    smaller than without it.
!< 4. Wrong calls refused with their statuses: colours not (4, n), a size below 0, an integer format, labels not one
!<    per value, an unknown colour, an unknown variable; no frame has a usage error (every push popped).
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_OK, app_object, figure_last_error, ig_begin, ig_end, ig_same_line,      &
                   ig_set_next_window, ip3_begin_plot, ip3_end_plot, ip3_line, ip3_pop_style_color,                 &
                   ip3_pop_style_var, ip3_push_style_color, ip3_push_style_var, ip3_scatter, ip3_setup_axes,        &
                   ip3_setup_axis, ip3_setup_axis_ticks, ip3_spec, ImPlot3DItemFlags_NoLegend
use figure_testing, only : test_drawn_extent

implicit none
real(real64), parameter :: C1(4) = [0.95_real64, 0.10_real64, 0.85_real64, 1.0_real64] !< First point's colour.
real(real64), parameter :: C2(4) = [0.10_real64, 0.85_real64, 0.95_real64, 1.0_real64] !< Second point's.
real(real64), parameter :: C3(4) = [0.85_real64, 0.95_real64, 0.10_real64, 1.0_real64] !< The line's second segment.
real(real64), parameter :: C4(4) = [0.50_real64, 0.50_real64, 0.50_real64, 1.0_real64] !< Its other segments.
real(real64), parameter :: T1(4) = [0.91_real64, 0.31_real64, 0.07_real64, 1.0_real64] !< Tick labels, default format.
real(real64), parameter :: T2(4) = [0.07_real64, 0.31_real64, 0.91_real64, 1.0_real64] !< Tick labels, long format.
real(real64), parameter :: T3(4) = [0.31_real64, 0.91_real64, 0.07_real64, 1.0_real64] !< Tick labels, blank ticks.
real(real64), parameter :: B1(4) = [0.20_real64, 0.05_real64, 0.30_real64, 1.0_real64] !< Plot background, default.
real(real64), parameter :: B2(4) = [0.05_real64, 0.30_real64, 0.20_real64, 1.0_real64] !< Plot background, padded.
type(app_object)        :: app                          !< Application.
logical                 :: ok(9)                        !< Per-check outcome.
real(real64)            :: e1(4), e2(4), e3(4)          !< Drawn extents of the two markers and the second segment.
real(real64)            :: t_plain(4), t_long(4)        !< Tick labels' extents, default and long format.
real(real64)            :: b_plain(4), b_pad(4), junk(4) !< Plot backgrounds' extents.
logical                 :: f1, f2, f3, ft1, ft2, ft3, fb1, fb2 !< Found.
integer(int32)          :: st(6)                        !< Statuses of the wrong calls.
character(len=160)      :: msg(6)                       !< Their messages.
integer(int32)          :: errors                       !< Frames with a usage error.
integer(int32)          :: s                            !< Status of a frame.
integer(int32)          :: f                            !< Frame.

ok = .false.
st = -1_int32
msg = ''
errors = 0_int32
call app%init_headless(1000_int32, 700_int32)
do f = 1_int32, 6_int32
   if (.not. app%next_frame(s)) exit
   if (s /= FIG_OK) errors = errors + 1_int32
   call ig_set_next_window(0.0_real64, 0.0_real64, 1000.0_real64, 700.0_real64, always=.true.)
   if (ig_begin('3-D')) then
      ! 1. per-point colours and sizes
      if (ip3_begin_plot('points', width=300.0_real64, height=300.0_real64)) then
         call ip3_setup_axes('##x', '##y', '##z')
         call ip3_scatter('p', [-0.5_real64, 0.5_real64], [0.0_real64, 0.0_real64], [0.0_real64, 0.0_real64],     &
                          spec=ip3_spec(flags=ImPlot3DItemFlags_NoLegend), colors=reshape([C1, C2], [4, 2]),       &
                          sizes=[4.0_real64, 14.0_real64])
         call ip3_line('l', [-0.5_real64, 0.0_real64, 0.5_real64], [0.5_real64, 0.5_real64, 0.5_real64],         &
                       [0.5_real64, 0.5_real64, 0.5_real64], spec=ip3_spec(flags=ImPlot3DItemFlags_NoLegend),     &
                       colors=reshape([C4, C3, C4], [4, 3]))
         call ip3_end_plot()
      endif
      call test_drawn_extent(C1, e1(1), e1(2), e1(3), e1(4), found=f1)
      call test_drawn_extent(C2, e2(1), e2(2), e2(3), e2(4), found=f2)
      call test_drawn_extent(C3, e3(1), e3(2), e3(3), e3(4), found=f3)
      ! 2. the tick labels: the default format, a long one, blank ticks
      call ig_same_line()
      call ip3_push_style_color('AxisText', T1)
      if (ip3_begin_plot('plain', width=300.0_real64, height=300.0_real64)) then
         call ip3_setup_axes('##x', '##y', '##z')
         call ip3_line('l', [0.0_real64, 1.0_real64], [0.0_real64, 1.0_real64], [0.0_real64, 1.0_real64])
         call ip3_end_plot()
      endif
      call ip3_pop_style_color()
      call test_drawn_extent(T1, t_plain(1), t_plain(2), t_plain(3), t_plain(4), found=ft1)
      call ig_same_line()
      call ip3_push_style_color('AxisText', T2)
      if (ip3_begin_plot('long', width=300.0_real64, height=300.0_real64)) then
         call ip3_setup_axes('##x', '##y', '##z')
         call ip3_setup_axis('x', format='%.6f metres')
         call ip3_setup_axis('y', format='%.6f metres')
         call ip3_line('l', [0.0_real64, 1.0_real64], [0.0_real64, 1.0_real64], [0.0_real64, 1.0_real64])
         call ip3_end_plot()
      endif
      call ip3_pop_style_color()
      call test_drawn_extent(T2, t_long(1), t_long(2), t_long(3), t_long(4), found=ft2)
      call ip3_push_style_color('AxisText', T3)
      if (ip3_begin_plot('blank', width=300.0_real64, height=300.0_real64)) then
         call ip3_setup_axes('##x', '##y', '##z')
         call ip3_setup_axis_ticks('x', [0.5_real64], [' '])
         call ip3_setup_axis_ticks('y', [0.5_real64], [' '])
         call ip3_setup_axis_ticks('z', [0.5_real64], [' '])
         call ip3_line('l', [0.0_real64, 1.0_real64], [0.0_real64, 1.0_real64], [0.0_real64, 1.0_real64])
         call ip3_end_plot()
      endif
      call ip3_pop_style_color()
      call test_drawn_extent(T3, junk(1), junk(2), junk(3), junk(4), found=ft3)
      ! 3. the plot background, without and with padding
      call ig_same_line()
      call ip3_push_style_color('PlotBg', B1)
      if (ip3_begin_plot('unpadded', width=300.0_real64, height=300.0_real64)) then
         call ip3_setup_axes('##x', '##y', '##z')
         call ip3_end_plot()
      endif
      call ip3_pop_style_color()
      call test_drawn_extent(B1, b_plain(1), b_plain(2), b_plain(3), b_plain(4), found=fb1)
      call ig_same_line()
      call ip3_push_style_color('PlotBg', B2)
      call ip3_push_style_var('PlotPadding', [40.0_real64, 40.0_real64])
      if (ip3_begin_plot('padded', width=300.0_real64, height=300.0_real64)) then
         call ip3_setup_axes('##x', '##y', '##z')
         call ip3_end_plot()
      endif
      call ip3_pop_style_var()
      call ip3_pop_style_color()
      call test_drawn_extent(B2, b_pad(1), b_pad(2), b_pad(3), b_pad(4), found=fb2)
      ! 4. wrong calls (on the last frame)
      if (f == 6_int32) then
         if (ip3_begin_plot('wrong', width=200.0_real64, height=200.0_real64)) then
            call ip3_setup_axis('x', format='%d', stat=st(3))
            msg(3) = figure_last_error()
            call ip3_setup_axis_ticks('x', [0.0_real64, 1.0_real64], ['a'], stat=st(4))
            msg(4) = figure_last_error()
            call ip3_scatter('w', [0.0_real64], [0.0_real64], [0.0_real64], colors=reshape(C1(1:3), [3, 1]), &
                             stat=st(1))
            msg(1) = figure_last_error()
            call ip3_scatter('w', [0.0_real64], [0.0_real64], [0.0_real64], sizes=[-1.0_real64], stat=st(2))
            msg(2) = figure_last_error()
            call ip3_end_plot()
         endif
         call ip3_push_style_color('NoSuchColour', C1, stat=st(5))
         msg(5) = figure_last_error()
         call ip3_push_style_var('NoSuchVariable', 1.0_real64, stat=st(6))
         msg(6) = figure_last_error()
      endif
   endif
   call ig_end()
enddo
if (app%next_frame(s)) continue
if (s /= FIG_OK) errors = errors + 1_int32
call app%destroy()

ok(1) = f1 .and. f2                                                                        ! each marker in its colour
ok(2) = (e2(3) - e2(1)) > (e1(3) - e1(1)) + 10.0_real64                                    ! 14 px against 4 px
ok(3) = f3                                                                                 ! the second segment
ok(4) = ft1 .and. ft2 .and. (t_long(3) - t_long(1)) > (t_plain(3) - t_plain(1)) + 20.0_real64 ! the long format
ok(5) = .not. ft3                                                                          ! blank ticks: no label
ok(6) = fb1 .and. fb2 .and. (b_pad(3) - b_pad(1)) < (b_plain(3) - b_plain(1)) - 40.0_real64   ! the padding
ok(7) = all(st == FIG_ERR_ARGUMENT)
ok(8) = index(msg(1), 'ip3_scatter: colors must be (4, size(x))') == 1 .and.                         &
        msg(2) == 'ip3_scatter: sizes must be finite and not below 0' .and.                          &
        index(msg(3), 'ip3_setup_axis:') == 1 .and.                                                  &
        msg(4) == 'ip3_setup_axis_ticks: labels must be one per value' .and.                         &
        index(msg(5), 'NoSuchColour') > 0 .and. index(msg(6), 'NoSuchVariable') > 0
ok(9) = errors == 0_int32

write(output_unit, '(A,2(4F8.1,1X))') 'markers ', e1, e2
write(output_unit, '(A,4F8.1,L2)') 'segment ', e3, f3
write(output_unit, '(A,2(4F8.1,1X),3L2)') 'ticks   ', t_plain, t_long, ft1, ft2, ft3
write(output_unit, '(A,2(4F8.1,1X),2L2)') 'plot bg ', b_plain, b_pad, fb1, fb2
write(output_unit, '(A,6I3,A,I0)') 'statuses ', st, ', frames with errors ', errors
write(output_unit, '(A)') (trim(msg(f)), f = 1_int32, 6_int32)
write(output_unit, '(A,*(L2))') 'figure_test_plot3d_more checks:', ok
if (.not. all(ok)) error stop 'figure_test_plot3d_more: FAILED'
write(output_unit, '(A)') 'figure_test_plot3d_more: all checks passed'
endprogram figure_test_plot3d_more
