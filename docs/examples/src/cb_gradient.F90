!< cb_gradient, cookbook: edit a colormap by its stops while a field drawn with it changes, and save it.
program cb_gradient
!< cb_gradient, cookbook: edit a colormap by its stops while a field drawn with it changes, and save it. With
!< `--test`, headless: a stop dragged, a stop added by a double click, the map saved and read back.
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_button, ig_end, ig_same_line, ig_set_next_window, ig_text, &
                   ig_gradient_edit, ip_begin_plot, ip_colormap, ip_colormap_legend, ip_colormap_stops, ip_end_plot, &
                   ip_field_image, ip_load_colormap, ip_setup_axes
use figure_cimgui, only : im_vec4
use figure_cimplot, only : ImPlot_SampleColormap
use figure_testing, only : test_item_rect, test_mouse_button, test_mouse_move, test_next_frame

implicit none
integer(int32), parameter :: N = 121_int32     !< Samples a side, over [-1, 1].
type(app_object)          :: app               !< Application.
real(real64), target      :: p(N, N)           !< A pressure-like field, in [-1, 1].
real(real64)              :: h                 !< Spacing.
integer(int32)            :: i, j              !< Counters.
character(len=16)         :: arg               !< `--test`: headless.
character(len=64)         :: text = ''         !< What the editor did.
!run cb_gradient ./cb_gradient --test

h = 2.0_real64 / (N - 1)
do j = 1_int32, N
   do i = 1_int32, N
      p(i, j) = cos(3.0_real64 * (-1.0_real64 + (i - 1) * h)) * sin(2.0_real64 * (-1.0_real64 + (j - 1) * h))
   enddo
enddo
call get_command_argument(1, arg)
if (trim(arg) == '--test') then
   call app%init_headless(620_int32, 600_int32)
   call frames(3_int32)
   call test()
else
   call app%init('FIGURE: a colormap edited', 620_int32, 600_int32)
   do while (app%next_frame())
      call draw()
   enddo
endif
call app%destroy()

contains
   subroutine draw()
   !< The window: the gradient editor of cool-warm, a field drawn with it and its legend, a button saving the map.
   call ig_set_next_window(10.0_real64, 10.0_real64, 600.0_real64, 580.0_real64)
   if (ig_begin('Colormap')) then
      !region edit
      if (ig_gradient_edit('stops', 'cool-warm', width=-90.0_real64)) text = 'cool-warm changed' ! the field follows
      call ig_same_line()
      if (ig_button('Save')) then
         call save('cool-warm', 'my-cool-warm.csv')
         text = 'saved to my-cool-warm.csv'
      endif
      if (ip_begin_plot('pressure', width=480.0_real64, height=440.0_real64, equal=.true.)) then
         call ip_setup_axes('x', 'y')
         call ip_field_image('p', p, -1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, colormap=ip_colormap('cool-warm'), &
                             vmin=-1.0_real64, vmax=1.0_real64)
         call ip_end_plot()
      endif
      call ig_same_line()
      call ip_colormap_legend('p', ip_colormap('cool-warm'), -1.0_real64, 1.0_real64, height=440.0_real64)
      !endregion edit
      call ig_text(trim(text))
   endif
   call ig_end()
   endsubroutine draw

   !region save
   subroutine save(name, file)
   !< The map's stops as a CSV table of `x, r, g, b` rows, which `ip_load_colormap` reads back as the same map.
   character(len=*), intent(in) :: name          !< Colormap.
   character(len=*), intent(in) :: file          !< CSV file.
   real(real64), allocatable    :: positions(:)  !< Stops: positions in [0, 1].
   real(real64), allocatable    :: colours(:,:)  !< ... their colours, RGB in [0, 1].
   integer(int32)               :: u, k          !< Unit, counter.

   call ip_colormap_stops(name, positions, colours)
   open(newunit=u, file=file, status='replace', action='write')
   write(u, '(A)') 'x, r, g, b'
   do k = 1_int32, size(positions, kind=int32)
      write(u, '(F9.6,3(", ",F9.6))') positions(k), colours(:, k)
   enddo
   close(u)
   endsubroutine save
   !endregion save

   subroutine frames(n)
   !< Draw `n` frames.
   integer(int32), intent(in) :: n !< Frames.
   integer(int32)             :: k !< Counter.

   do k = 1_int32, n
      if (.not. app%next_frame()) exit
      call draw()
   enddo
   endsubroutine frames

   subroutine test()
   !< Drag the middle stop to the right, add a stop near the end by a double click, save, read back, compare.
   real(real64), allocatable :: positions(:), colours(:,:) !< Stops.
   real(real64)              :: x, y, w, hr                !< The stops' row [pixels].
   real(real64)              :: cx                         !< A stop's centre.
   integer(int32)            :: k, mid                     !< Counter, the middle stop.
   real(real64)              :: diff                       !< The saved map against the edited one.
   type(im_vec4)             :: a, b                       !< Their colours.

   !region test
   call ip_colormap_stops('cool-warm', positions, colours)
   write(output_unit, '(A,I0,A)') 'cool-warm: ', size(positions), ' stops'
   if (.not. test_item_rect('##points', x, y, w, hr)) error stop 'no stops row'
   mid = (size(positions, kind=int32) + 1_int32) / 2_int32
   write(output_unit, '(A,F6.3,A,3F6.3)') 'its middle stop at ', positions(mid), ', colour', colours(:, mid)
   cx = x + positions(mid) * (w - hr) + 0.5_real64 * hr     ! ImGradient's square of the stop at t
   call drag(cx, y + 0.5_real64 * hr, cx + 0.03_real64 * w, y + 0.5_real64 * hr)
   call ip_colormap_stops('cool-warm', positions, colours)
   write(output_unit, '(A,F6.3)') 'dragged by 3% of the row, now at ', positions(mid)
   call test_mouse_move(x + 0.9_real64 * w, y + 0.5_real64 * hr) ! a double click adds a stop
   call test_next_frame()
   call test_next_frame()
   do k = 1_int32, 2_int32
      call test_mouse_button(.true.)
      call test_next_frame()
      call test_mouse_button(.false.)
      call test_next_frame()
   enddo
   call frames(8_int32)
   call ip_colormap_stops('cool-warm', positions, colours)
   write(output_unit, '(A,I0,A)') 'after a double click: ', size(positions), ' stops'
   call save('cool-warm', 'cb_gradient.csv.tmp')
   call ip_load_colormap('cool-warm-saved', 'cb_gradient.csv.tmp')
   diff = 0.0_real64
   do k = 0_int32, 100_int32
      call ImPlot_SampleColormap(real(k, c_float) / 100.0_c_float, int(ip_colormap('cool-warm'), c_int), a)
      call ImPlot_SampleColormap(real(k, c_float) / 100.0_c_float, int(ip_colormap('cool-warm-saved'), c_int), b)
      diff = max(diff, abs(real(a%x - b%x, real64)), abs(real(a%y - b%y, real64)), abs(real(a%z - b%z, real64)))
   enddo
   write(output_unit, '(A,I0,A)') 'saved and read back: within ', nint(diff * 255.0_real64), ' of 255 per channel'
   !endregion test
   open(newunit=k, file='cb_gradient.csv.tmp', status='old')
   close(k, status='delete')
   endsubroutine test

   subroutine drag(x0, y0, x1, y1)
   !< A drag from (x0, y0) to (x1, y1): rest, press and hold, move, release.
   real(real64), intent(in) :: x0, y0, x1, y1 !< Start and end [pixels].

   call test_mouse_move(x0, y0)
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_next_frame()
   call test_mouse_move(x1, y1)
   call test_next_frame()
   call test_mouse_button(.false.)
   call frames(8_int32)
   endsubroutine drag
endprogram cb_gradient
