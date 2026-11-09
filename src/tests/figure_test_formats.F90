!< figure_test_formats, printf formats checked against the value's kind, headless.
program figure_test_formats
!< figure_test_formats, printf formats checked against the value's kind, headless.
!<
!< The checker (figure_base's format_ok): formats of one real and of one integer accepted; a conversion of the other
!< family or of none, '*', length modifiers, more than one conversion or none refused. Every procedure that takes a
!< format refuses a bad one with FIG_ERR_ARGUMENT and a message naming the argument and the family, changes nothing,
!< and takes a good one with FIG_OK. ip_colormap_legend keeps v0.3.0's documented behaviour: '' is the default format, a
!< text without conversion is printed as it is (both accepted and drawn); a format with a conversion is checked.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real32, real64
use figure, only : app_object, figure_last_error, FIG_ERR_ARGUMENT, FIG_OK, ig_begin, ig_end, ig_input, ip_begin_plot, &
                   ig_item_rect, &
                   ip_colormap_legend, ip_colormap_scale, ip_end_plot, ip_heatmap, ip_setup_axes
use figure_base, only : format_ok, FORMAT_INTEGER, FORMAT_REAL

implicit none
type(app_object) :: app             !< Application.
logical          :: test_passed(7)  !< Per-check outcome.
integer(int32)   :: text_stat(2)    !< Statuses of the legend's '' and text-only label formats.
real(real64)     :: rect(4, 2)      !< Their legends' rectangles [pixels].
integer(int32)   :: bad(7)          !< Statuses of the bad formats, one per procedure and argument.
integer(int32)   :: good(7)         !< Statuses of good ones.
character(len=:), allocatable :: msg(:) !< The messages of the bad formats (as figure_last_error gave them).
real(real64)     :: v               !< A field's value.
real(real64)     :: f64(3, 2)       !< A field.
real(real32)     :: f32(3, 2)       !< The same, single precision.
logical          :: changed         !< ig_input's result with a bad format.
integer(int32)   :: frame           !< Frame.

test_passed = .false.
test_passed(1) = all([format_ok('%.3f', FORMAT_REAL), format_ok('%8.2e', FORMAT_REAL), format_ok('%g %%', FORMAT_REAL), &
                      format_ok('x = %.4g m', FORMAT_REAL), format_ok('%-+ #012.4G', FORMAT_REAL),                     &
                      format_ok('%a', FORMAT_REAL), format_ok('%%%E%%', FORMAT_REAL)])
test_passed(2) = all([format_ok('%d', FORMAT_INTEGER), format_ok('%5i', FORMAT_INTEGER), format_ok('%u', FORMAT_INTEGER)])
test_passed(3) = .not. any([format_ok('%d', FORMAT_REAL), format_ok('%f', FORMAT_INTEGER), format_ok('%s', FORMAT_REAL), &
                            format_ok('%n', FORMAT_REAL), format_ok('%*d', FORMAT_INTEGER),                             &
                            format_ok('%f %f', FORMAT_REAL), format_ok('no conversion', FORMAT_REAL),                    &
                            format_ok('', FORMAT_REAL), format_ok('%.*f', FORMAT_REAL), format_ok('%lf', FORMAT_REAL), &
                            format_ok('%Lg', FORMAT_REAL), format_ok('%ld', FORMAT_INTEGER), format_ok('%', FORMAT_REAL),&
                            format_ok('100%', FORMAT_REAL), format_ok('%x', FORMAT_INTEGER), format_ok('%%', FORMAT_REAL)])
! text accepted where asked: no conversion, '' and '%%' included; formats with a conversion still checked
test_passed(6) = all([format_ok('', FORMAT_REAL, text=.true.), format_ok('units', FORMAT_REAL, text=.true.),         &
                      format_ok('100%%', FORMAT_REAL, text=.true.), format_ok('%.2f K', FORMAT_REAL, text=.true.)]) &
                 .and. .not. any([format_ok('%d', FORMAT_REAL, text=.true.), format_ok('%f %f', FORMAT_REAL, text=.true.), &
                                  format_ok('%n', FORMAT_REAL, text=.true.), format_ok('%*f', FORMAT_REAL, text=.true.),   &
                                  format_ok('%lf', FORMAT_REAL, text=.true.), format_ok('%', FORMAT_REAL, text=.true.)])

allocate(character(len=200) :: msg(7))
f64 = reshape([1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64, 5.0_real64, 6.0_real64], [3, 2])
f32 = real(f64, real32)
v = 0.5_real64
changed = .true.
call app%init_headless(800_int32, 600_int32)
do frame = 1_int32, 2_int32
   if (.not. app%next_frame()) exit
   if (ig_begin('formats')) then
      changed = ig_input('bad', v, format='%d', stat=bad(1))
      msg(1) = figure_last_error()
      if (ig_input('good', v, format='x = %.4g m', stat=good(1))) continue
      if (ip_begin_plot('plot')) then
         call ip_setup_axes('x', 'y', xformat='%s', stat=bad(2))
         msg(2) = figure_last_error()
         call ip_setup_axes('x', 'y', yformat='%f %f', stat=bad(3))
         msg(3) = figure_last_error()
         call ip_setup_axes('x', 'y', xformat='%.2f s', yformat='%8.2e', stat=good(2))
         good(3) = good(2)
         call ip_heatmap('bad64', f64, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, label_format='%n', stat=bad(4))
         msg(4) = figure_last_error()
         call ip_heatmap('bad32', f32, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, label_format='%*f', stat=bad(5))
         msg(5) = figure_last_error()
         call ip_heatmap('good64', f64, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, label_format='%.1f', stat=good(4))
         call ip_heatmap('good32', f32, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, label_format='%g', stat=good(5))
         call ip_end_plot()
      endif
      call ip_colormap_scale('bad scale', 0.0_real64, 1.0_real64, label_format='no conversion', stat=bad(6))
      msg(6) = figure_last_error()
      call ip_colormap_scale('good scale', 0.0_real64, 1.0_real64, label_format='%.2f', stat=good(6))
      call ip_colormap_legend('bad legend', 0_int32, 0.0_real64, 1.0_real64, label_format='%lf', stat=bad(7))
      msg(7) = figure_last_error()
      call ip_colormap_legend('good legend', 0_int32, 0.0_real64, 1.0_real64, label_format='%.0f%%', stat=good(7))
      call ip_colormap_legend('default legend', 0_int32, 0.0_real64, 1.0_real64, label_format='', stat=text_stat(1))
      call ig_item_rect(rect(1, 1), rect(2, 1), rect(3, 1), rect(4, 1))
      call ip_colormap_legend('text legend', 0_int32, 0.0_real64, 1.0_real64, label_format='units', stat=text_stat(2))
      call ig_item_rect(rect(1, 2), rect(2, 2), rect(3, 2), rect(4, 2))
   endif
   call ig_end()
enddo
call app%destroy()

test_passed(4) = all(bad == FIG_ERR_ARGUMENT) .and. all(good == FIG_OK) .and. .not. changed .and. v == 0.5_real64
test_passed(5) = index(msg(1), "ig_input: format '%d' is not a format of a real") == 1 .and.                   &
                 index(msg(2), "ip_setup_axes: xformat '%s'") == 1 .and. index(msg(3), "ip_setup_axes: yformat") == 1 .and. &
                 index(msg(4), "ip_heatmap: label_format '%n'") == 1 .and. index(msg(5), "ip_heatmap: label_format") == 1 .and. &
                 index(msg(6), "ip_colormap_scale: label_format 'no conversion'") == 1 .and.                                &
                 index(msg(7), "ip_colormap_legend: label_format '%lf'") == 1 .and.                                          &
                 all(index(msg, 'conversion %f, %e, %g or %a') > 0) .and. index(msg(7), '(or none: text') > 0
test_passed(7) = all(text_stat == FIG_OK) .and. all(rect(3, :) - rect(1, :) > 1.0_real64) .and. &
                 all(rect(4, :) - rect(2, :) > 1.0_real64) .and. rect(2, 2) >= rect(4, 1)       ! accepted, drawn: two items

write(output_unit, '(A,*(L2))') 'figure_test_formats checks:', test_passed
if (.not. test_passed(4)) write(output_unit, '(A,7I3,A,7I3,A,L2,F6.2)') 'bad', bad, ', good', good, ', changed, v', &
                                                                     changed, v
if (.not. test_passed(7)) write(output_unit, '(A,2I3,A,8F8.1)') 'legend text formats: ', text_stat, ', rects', rect
if (.not. test_passed(5)) write(output_unit, '(A)') (trim(msg(frame)), frame = 1_int32, 7_int32)
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1
endprogram figure_test_formats
