!< figure_test_plot_links, plots across plots driven by synthetic input, headless: linked axes, aligned plots, the
!< legend's hover and popup, hidden items, digital and grouped bars, and the usage errors.
program figure_test_plot_links
!< figure_test_plot_links, plots across plots driven by synthetic input, headless: linked axes, aligned plots, the
!< legend's hover and popup, hidden items, digital and grouped bars, and the usage errors.
!<
!< Three plots stacked in an aligned group, their x axes linked in the group 'it': the first frames each fits its own
!< data (iterations 1 to 100, 1 to 200, 1 to 300), then the three share the first plot's range; the wheel over the
!< third zooms all three alike. Their y tick labels differ in width (1 to 1e6 and 0 to 1): aligned, their plot areas
!< start at the same pixel, while the same two plots outside a group do not. In the first plot a legend entry: hovered,
!< `ip_legend_hovered` says so; a right click on it opens its popup, whose contents are drawn. An item hidden by
!< `ip_hide_next_item` is not drawn, the same item shown is. A digital signal and two items in three bar groups (side
!< by side, then stacked) drawn in their colours where they belong. The refusals with their statuses and messages.
! oracle: wheel plot-zoom plot-legend
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, app_object, figure_last_error, ig_begin, ig_end,         &
                   ip_colormap, ip_load_colormap, ig_begin_child, ig_end_child,                                     &
                   ig_set_next_window, ig_text, ip_bar_groups, ip_begin_aligned, ip_begin_legend_popup, ip_begin_plot, &
                   ip_digital, ip_end_aligned, ip_end_legend_popup, ip_end_plot, ip_hide_next_item,                 &
                   ip_legend_hovered, ip_line, ip_link_axis, ip_plot_limits, ip_plot_to_pixels, ip_setup_axes,     &
                   ip_spec, plot_spec_object, ImPlotItemFlags_NoLegend
use figure_testing, only : test_click, test_drawn_extent, test_mouse_move, test_wheel

implicit none
real(real64), parameter :: HIDDEN_COLOR(4) = [0.95_real64, 0.10_real64, 0.85_real64, 1.0_real64] !< The hidden item.
real(real64), parameter :: SHOWN_COLOR(4) = [0.10_real64, 0.95_real64, 0.85_real64, 1.0_real64]  !< ... shown.
real(real64), parameter :: DIGITAL_COLOR(4) = [0.95_real64, 0.85_real64, 0.10_real64, 1.0_real64] !< The digital item.
real(real64), parameter :: BAR1_COLOR(4) = [0.2_real64, 0.4_real64, 1.0_real64, 1.0_real64]     !< Bar item 1: the
real(real64), parameter :: BAR2_COLOR(4) = [1.0_real64, 0.4_real64, 0.2_real64, 1.0_real64]     !< ... colormap's 2.
character(len=*), parameter :: MAP_FILE = 'figure_test_plot_links.csv' !< The bar items' colormap.
type(app_object)       :: app            !< Application.
type(plot_spec_object) :: spec_hidden    !< Style of the hidden item.
type(plot_spec_object) :: spec_shown     !< ... of the shown one.
type(plot_spec_object) :: spec_digital   !< ... of the digital one.
integer(int32)         :: bar_map        !< The bar items' colormap.
integer(int32)         :: u              !< File unit.
logical                :: ok(14)         !< Per-check outcome.
real(real64)           :: x(300)         !< Iterations.
real(real64)           :: lim(4, 3)      !< x limits of the three plots, at frame 4 (xmin, xmax) and 30 (xmin, xmax).
real(real64)           :: left(2, 2)     !< Plot areas' left edges [pixels]: aligned (1, 2), not aligned (1, 2).
real(real64)           :: entry(2)       !< A point of the legend entry [pixels].
real(real64)           :: centre(2)      !< The third plot's centre [pixels].
real(real64)           :: r(4)           !< A drawn extent.
real(real64)           :: bars(4, 2)     !< Extents of the two bar items, side by side.
real(real64)           :: stacked(4, 2)  !< ... stacked.
real(real64)           :: digital(4)     !< Extent of the digital item.
real(real64)           :: area(4)        !< The bar plot's area [pixels]: left, top, right, bottom.
real(real64)           :: x0, x1, y0, y1 !< Limits.
real(real64)           :: items_bottom   !< The items plot's bottom edge [pixels].
logical                :: found          !< Something was drawn in a colour.
logical                :: hidden_drawn   !< The hidden item was drawn, on some frame.
logical                :: shown_drawn    !< The shown item was drawn, on every frame after the first.
logical                :: digital_found  !< The digital item was drawn.
logical                :: bars_found(2)  !< The bar items were drawn.
logical                :: stacked_found(2) !< ... stacked.
logical                :: hovered        !< The legend entry was hovered, on some frame.
logical                :: hovered_early  !< ... before the pointer went there.
logical                :: popup          !< The popup's contents were drawn.
logical                :: popup_early    !< ... before the click.
integer(int32)         :: st(8)          !< Statuses of refused calls.
character(len=160)     :: msg(8)         !< Their messages.
integer(int32)         :: errors         !< Frames with a usage error.
integer(int32)         :: f              !< Frame.
integer(int32)         :: i              !< Index.
integer(int32)         :: s              !< Status of a frame.

ok = .false.
x = [(real(i, real64), i = 1, 300)]
lim = 0.0_real64
left = 0.0_real64
hidden_drawn = .false.
shown_drawn = .true.
digital_found = .false.
bars_found = .false.
stacked_found = .false.
hovered = .false.
hovered_early = .false.
popup = .false.
popup_early = .false.
errors = 0_int32
st = -1_int32
msg = ''
spec_hidden = ip_spec(line_color=HIDDEN_COLOR, line_weight=3.0_real64)
spec_shown = ip_spec(line_color=SHOWN_COLOR, line_weight=3.0_real64)
spec_digital = ip_spec(fill_color=DIGITAL_COLOR, line_color=DIGITAL_COLOR, flags=ImPlotItemFlags_NoLegend) ! no icon
call app%init_headless(1000_int32, 1150_int32)
open(newunit=u, file=MAP_FILE, status='replace', action='write')
write(u, '(A)') '0.2 0.4 1.0', '1.0 0.4 0.2'
close(u)
call ip_load_colormap('two bars', MAP_FILE)
bar_map = ip_colormap('two bars')
do f = 1_int32, 60_int32
   if (.not. app%next_frame(s)) exit
   if (s /= FIG_OK) errors = errors + 1_int32
   call ig_set_next_window(0.0_real64, 0.0_real64, 1000.0_real64, 1150.0_real64, always=.true.)
   if (ig_begin('Plots')) then
      if (ip_begin_aligned('history')) then
         do i = 1_int32, 3_int32
            if (ip_begin_plot('plot '//achar(48 + i), height=140.0_real64)) then
               call ip_setup_axes('iteration', 'value')
               call ip_link_axis('x1', 'it')
               if (i == 1_int32) then
                  call ip_line('residual', x(1:100), 1.0e6_real64 * exp(-x(1:100) / 30.0_real64))
                  if (ip_legend_hovered('residual')) then
                     hovered = .true.
                     if (f < 20_int32) hovered_early = .true.
                  endif
                  if (ip_begin_legend_popup('residual')) then
                     call ig_text('residual: a menu of the entry')
                     popup = .true.
                     if (f < 30_int32) popup_early = .true.
                     call ip_end_legend_popup()
                  endif
               else
                  call ip_line('series', x(1:100 * i), 0.5_real64 + 0.5_real64 * sin(x(1:100 * i) / 10.0_real64))
               endif
               if (i == 3_int32) call ip_plot_to_pixels(50.0_real64, 0.5_real64, centre(1), centre(2))
               call ip_plot_limits(x0, x1, y0, y1)
               if (i == 1_int32) then                     ! the first legend entry, below the north-west corner
                  call ip_plot_to_pixels(x0, y1, entry(1), entry(2))
                  entry = entry + [40.0_real64, 22.0_real64]
               endif
               if (f == 4_int32) lim(1:2, i) = [x0, x1]
               if (f == 30_int32) lim(3:4, i) = [x0, x1]
               if (i <= 2_int32) call ip_plot_to_pixels(x0, y0, left(i, 1), r(1))
               if (f == 50_int32 .and. i == 2_int32) then
                  call ip_link_axis('x1', 'late', stat=st(1))                     ! the setup is over
                  msg(1) = figure_last_error()
                  if (ip_begin_aligned('nested', stat=st(2))) call ip_end_aligned() ! a group in a group
                  msg(2) = figure_last_error()
               endif
               call ip_end_plot()
            endif
         enddo
         call ip_end_aligned()
      endif
      ! the same two plots as the group's first two, not aligned: their y labels differ in width
      do i = 1_int32, 2_int32
         if (ip_begin_plot('loose '//achar(48 + i), height=80.0_real64)) then
            if (i == 1_int32) then
               call ip_line('residual', x(1:100), 1.0e6_real64 * exp(-x(1:100) / 30.0_real64))
            else
               call ip_line('series', x(1:100), 0.5_real64 + 0.5_real64 * sin(x(1:100) / 10.0_real64))
            endif
            call ip_plot_limits(x0, x1, y0, y1)
            call ip_plot_to_pixels(x0, y0, left(i, 2), r(1))
            call ip_end_plot()
         endif
      enddo
      ! hidden and shown items, a digital signal
      if (ip_begin_plot('items', height=140.0_real64)) then
         if (f == 50_int32) then
            call ip_link_axis('x1', '', stat=st(7))                        ! no group name
            msg(7) = figure_last_error()
         endif
         call ip_hide_next_item()
         call ip_line('hidden', x(1:10), x(1:10), spec=spec_hidden)
         call ip_hide_next_item(.false.)
         call ip_line('shown', x(1:10), 10.0_real64 - x(1:10), spec=spec_shown)
         call ip_digital('digital', x(1:10), [(real(mod(i, 2), real64), i = 1, 10)], spec=spec_digital)
         call ip_plot_limits(x0, x1, y0, y1)
         call ip_plot_to_pixels(x0, y0, r(1), items_bottom)
         call ip_end_plot()
      endif
      call test_drawn_extent(HIDDEN_COLOR, r(1), r(2), r(3), r(4), found=found)
      if (found) hidden_drawn = .true.
      call test_drawn_extent(SHOWN_COLOR, r(1), r(2), r(3), r(4), found=found)
      if (f > 1_int32) shown_drawn = shown_drawn .and. found
      call test_drawn_extent(DIGITAL_COLOR, digital(1), digital(2), digital(3), digital(4), found=digital_found)
      ! two items in three groups, side by side then stacked
      do i = 1_int32, 2_int32
         if (ig_begin_child('bars '//achar(48 + i), height=120.0_real64)) then
         if (ip_begin_plot('groups '//achar(48 + i), height=110.0_real64)) then
            call ip_bar_groups(['flow ', 'solid'], reshape([1.0_real64, 2.0_real64, 3.0_real64, &
                                                            3.0_real64, 2.0_real64, 1.0_real64], [3, 2]), &
                               stacked=(i == 2_int32), colormap=bar_map)
            if (i == 1_int32) then
               call ip_plot_to_pixels(-0.5_real64, 0.0_real64, area(1), area(4))
               call ip_plot_to_pixels(2.5_real64, 3.0_real64, area(3), area(2))
            endif
            if (f == 50_int32 .and. i == 1_int32) then
               call ip_bar_groups(['one'], reshape([1.0_real64, 2.0_real64], [1, 2]), stat=st(3)) ! 1 label, 2 items
               msg(3) = figure_last_error()
               call ip_bar_groups(['one', 'two'], reshape([1.0_real64, 2.0_real64], [1, 2]), group_size=0.0_real64, &
                                  stat=st(4))
               msg(4) = figure_last_error()
            endif
            call ip_end_plot()
         endif
         if (i == 1_int32) then
            call test_drawn_extent(BAR1_COLOR, bars(1, 1), bars(2, 1), bars(3, 1), bars(4, 1), found=bars_found(1))
            call test_drawn_extent(BAR2_COLOR, bars(1, 2), bars(2, 2), bars(3, 2), bars(4, 2), found=bars_found(2))
         else
            call test_drawn_extent(BAR1_COLOR, stacked(1, 1), stacked(2, 1), stacked(3, 1), stacked(4, 1), &
                                   found=stacked_found(1))
            call test_drawn_extent(BAR2_COLOR, stacked(1, 2), stacked(2, 2), stacked(3, 2), stacked(4, 2), &
                                   found=stacked_found(2))
         endif
         endif
         call ig_end_child()
      enddo
      if (f == 50_int32) then
         if (ip_legend_hovered('residual', stat=st(5))) continue          ! outside a plot
         msg(5) = figure_last_error()
         call ip_link_axis('x1', 'it', stat=st(6))                         ! outside a plot
         msg(6) = figure_last_error()
         call ip_end_aligned(stat=st(8))                                   ! no group open
         msg(8) = figure_last_error()
      endif
   endif
   call ig_end()
   select case (f)
   case (6_int32)
      call test_mouse_move(centre(1), centre(2))
   case (8_int32, 10_int32, 12_int32)
      call test_wheel(1.0_real64)                                          ! ImPlot zooms by steps: three, the third plot
   case (20_int32)
      call test_mouse_move(entry(1), entry(2))                             ! over the legend entry
   case (30_int32)
      call test_click(entry(1), entry(2), button='right')                  ! its popup
   endselect
enddo
if (app%next_frame(s)) continue
if (s /= FIG_OK) errors = errors + 1_int32
call app%destroy()
open(newunit=u, file=MAP_FILE)
close(u, status='delete')

ok(1) = abs(lim(1, 3) - 1.0_real64) < 1.0_real64 .and. abs(lim(2, 3) - 100.0_real64) < 2.0_real64 ! the first plot's fit
ok(2) = all(abs(lim(3, 2:3) - lim(3, 1)) < 1.0e-9_real64) .and. all(abs(lim(4, 2:3) - lim(4, 1)) < 1.0e-9_real64)
ok(3) = lim(4, 1) - lim(3, 1) < 0.9_real64 * (lim(2, 1) - lim(1, 1))     ! ... the zoom in the third, in all three
ok(4) = abs(left(1, 1) - left(2, 1)) < 0.5_real64                         ! aligned: the plot areas start together
ok(5) = abs(left(1, 2) - left(2, 2)) > 5.0_real64                         ! not aligned: they do not
ok(6) = hovered .and. .not. hovered_early                                 ! the legend entry's hover
ok(7) = popup .and. .not. popup_early                                     ! its popup, after the right click
ok(8) = .not. hidden_drawn .and. shown_drawn                              ! hidden, shown
ok(9) = digital_found .and. digital(4) <= items_bottom + 1.0_real64 .and. digital(4) > items_bottom - 40.0_real64 ! bottom band
ok(10) = all(bars_found) .and. bars(3, 1) < bars(3, 2) .and. bars(1, 1) < bars(1, 2) ! side by side: item 2 right
ok(11) = all(stacked_found) .and. stacked(2, 2) < stacked(2, 1) .and. abs(stacked(1, 1) - stacked(1, 2)) < 1.0_real64
ok(12) = all(st([1, 2, 5, 6, 8]) == int(FIG_ERR_STATE, int32)) .and.                                               &
         msg(1) == 'ip_link_axis: the setup of the plot is over (call the ip_setup_* procedures before the first '// &
                   'item, ip_set_axes and ip_plot_limits)' .and.                                                   &
         msg(2) == 'ip_begin_aligned: a group of aligned plots is open (ImPlot aligns one group at a time)' .and.   &
         msg(5) == 'ip_legend_hovered: no plot is being declared (call it between a true ip_begin_plot and '//     &
                   'ip_end_plot)' .and.                                                                            &
         msg(8)(1:15) == 'ip_end_aligned:'
ok(13) = all(st([3, 4, 7]) == int(FIG_ERR_ARGUMENT, int32)) .and.                                                 &
         msg(3) == 'ip_bar_groups: 1 labels for 2 items (size(values, 2))' .and.                                  &
         msg(4) == 'ip_bar_groups: group_size must be in (0, 1]' .and.                                           &
         msg(7) == 'ip_link_axis: the group has no name'
ok(14) = errors == 0_int32

write(output_unit, '(A,*(L2))') 'figure_test_plot_links checks:', ok
if (.not. all(ok)) then
   write(output_unit, '(A,12F9.2)') 'limits ', lim
   write(output_unit, '(A,4F8.1)') 'left ', left
   write(output_unit, '(A,4F8.1,A,4F8.1)') 'digital ', digital, ' area ', area
   write(output_unit, '(A,8F8.1)') 'bars ', bars
   write(output_unit, '(A,8F8.1)') 'stacked ', stacked
   write(output_unit, '(A,8I3)') 'statuses ', st
   do i = 1_int32, 8_int32
      write(output_unit, '(A)') trim(msg(i))
   enddo
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1
endprogram figure_test_plot_links
