!< figure_mandelbrot, a Mandelbrot explorer: ImPlot pans and zooms, Fortran computes, one texture shows the image.
program figure_mandelbrot
!< figure_mandelbrot, a Mandelbrot explorer: ImPlot pans and zooms, Fortran computes, one texture shows the image.
!<
!< Drag to pan, wheel (or right-drag a box) to zoom, double-click to fit. Every frame the program reads the plot's
!< limits and pixel size: when they, or the iteration count, change, it recomputes the image at the plot's resolution
!< and uploads it in place (`tex%update`); otherwise it only draws the texture again, so an idle window costs nothing.
!< The escape-time loop is parallel when built with OpenMP (the fobos example modes enable it).
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ig_slider, ig_text, ip_begin_plot, ip_end_plot, &
                   ip_image, ip_plot_limits, ip_plot_size, ip_setup_axes_limits, texture_object

implicit none
type(app_object)           :: app           !< Application.
type(texture_object)       :: tex           !< The image on the GPU.
integer(int8), allocatable :: rgba(:,:,:)   !< The image: rgba(:, i, j), j = 1 at the bottom of the view.
real(real64)               :: view(4)       !< Current view: xmin, xmax, ymin, ymax.
real(real64)               :: shown(4)      !< View of the image in `rgba`.
real(real64)               :: w             !< Plot width [pixels].
real(real64)               :: h             !< Plot height [pixels].
integer(int32)             :: nx            !< Image width [pixels].
integer(int32)             :: ny            !< Image height [pixels].
integer(int32)             :: max_iter      !< Iterations before a point is taken as inside the set.
logical                    :: stale         !< The image must be recomputed.
integer(int64)             :: rate          !< Clock ticks per second.
integer(int64)             :: t0            !< Clock at a phase start.
integer(int64)             :: t1            !< Clock at a phase end.
real(real64)               :: compute_ms    !< Time of the last computation [ms].
real(real64)               :: upload_ms     !< Time of the last upload [ms].
character(len=160)         :: line          !< Text buffer.

max_iter = 256_int32
nx = 0_int32
ny = 0_int32
view = [-2.25_real64, 0.95_real64, -1.2_real64, 1.2_real64]
shown = 0.0_real64
compute_ms = 0.0_real64
upload_ms = 0.0_real64
stale = .true.
call system_clock(count_rate=rate)
call app%init('FIGURE: Mandelbrot', 1280_int32, 800_int32)
do while (app%next_frame())
   call ig_set_next_window(0.0_real64, 0.0_real64, 1280.0_real64, 800.0_real64)
   if (ig_begin('Mandelbrot')) then
      if (ig_slider('iterations', max_iter, 32_int32, 4096_int32)) stale = .true.
      write(line, '(A,I0,A,I0,A,F0.2,A,F0.2,A)') 'image ', nx, ' x ', ny, ' pixels: computed in ', compute_ms, &
                                                ' ms, uploaded in ', upload_ms, ' ms'
      call ig_text(trim(line))
      write(line, '(A,ES12.5,A,ES12.5,A,ES9.2)') 'centre ', 0.5_real64 * (view(1) + view(2)), ' + ', &
                                                 0.5_real64 * (view(3) + view(4)), ' i, width ', view(2) - view(1)
      call ig_text(trim(line))
      if (ip_begin_plot('##set', height=-1.0_real64, equal=.true.)) then
         call ip_setup_axes_limits(-2.25_real64, 0.95_real64, -1.2_real64, 1.2_real64)
         call ip_plot_limits(view(1), view(2), view(3), view(4))
         call ip_plot_size(w, h)
         if (w >= 1.0_real64 .and. h >= 1.0_real64) then
            if (nint(w, int32) /= nx .or. nint(h, int32) /= ny) then ! new size: new image and texture
               nx = nint(w, int32)
               ny = nint(h, int32)
               if (allocated(rgba)) deallocate(rgba)
               allocate(rgba(4, nx, ny))
               call tex%init(nx, ny)
               stale = .true.
            endif
            if (any(view /= shown)) stale = .true.
            if (stale) then
               call system_clock(t0)
               call mandelbrot(view, max_iter, rgba)
               call system_clock(t1)
               compute_ms = 1000.0_real64 * real(t1 - t0, real64) / real(rate, real64)
               call system_clock(t0)
               call tex%update(rgba)
               call system_clock(t1)
               upload_ms = 1000.0_real64 * real(t1 - t0, real64) / real(rate, real64)
               shown = view
               stale = .false.
            endif
            call ip_image('##image', tex, shown(1), shown(2), shown(3), shown(4))
         endif
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call tex%destroy()
call app%destroy()

contains
   subroutine mandelbrot(v, max_iter, rgba)
   !< Escape-time image of the view `v`, smoothly coloured; points inside the set are black.
   real(real64),   intent(in)  :: v(4)        !< View: xmin, xmax, ymin, ymax.
   integer(int32), intent(in)  :: max_iter    !< Iteration limit.
   integer(int8),  intent(out) :: rgba(:,:,:) !< Image: rgba(:, i, j) at x(i), y(j), j = 1 at ymin.
   real(real64)                :: dx          !< Pixel width.
   real(real64)                :: dy          !< Pixel height.
   real(real64)                :: cr          !< Real part of c.
   real(real64)                :: ci          !< Imaginary part of c.
   real(real64)                :: zr          !< Real part of z.
   real(real64)                :: zi          !< Imaginary part of z.
   real(real64)                :: t           !< Temporary.
   real(real64)                :: mu          !< Smooth iteration count.
   integer(int32)              :: i           !< Column.
   integer(int32)              :: j           !< Row.
   integer(int32)              :: n           !< Iterations done.

   dx = (v(2) - v(1)) / real(size(rgba, 2), real64)
   dy = (v(4) - v(3)) / real(size(rgba, 3), real64)
   !$omp parallel do default(none) shared(rgba, v, dx, dy, max_iter) private(i, j, n, cr, ci, zr, zi, t, mu) &
   !$omp schedule(dynamic)
   do j = 1_int32, size(rgba, 3)
      ci = v(3) + (real(j, real64) - 0.5_real64) * dy
      do i = 1_int32, size(rgba, 2)
         cr = v(1) + (real(i, real64) - 0.5_real64) * dx
         zr = 0.0_real64
         zi = 0.0_real64
         n = 0_int32
         do while (n < max_iter .and. zr * zr + zi * zi <= 256.0_real64)
            t = zr * zr - zi * zi + cr
            zi = 2.0_real64 * zr * zi + ci
            zr = t
            n = n + 1_int32
         enddo
         if (n >= max_iter) then
            rgba(1:3, i, j) = 0_int8
         else
            mu = real(n, real64) + 1.0_real64 - log(log(sqrt(zr * zr + zi * zi))) / log(2.0_real64)
            rgba(1, i, j) = byte(0.5_real64 + 0.5_real64 * cos(0.1_real64 * mu + 3.0_real64))
            rgba(2, i, j) = byte(0.5_real64 + 0.5_real64 * cos(0.1_real64 * mu + 3.6_real64))
            rgba(3, i, j) = byte(0.5_real64 + 0.5_real64 * cos(0.1_real64 * mu + 4.2_real64))
         endif
         rgba(4, i, j) = -1_int8 ! opaque (255)
      enddo
   enddo
   endsubroutine mandelbrot

   elemental function byte(c) result(b)
   !< A colour channel in [0, 1] as an RGBA byte (0-255 stored in int8's bit pattern).
   real(real64), intent(in) :: c !< Channel value in [0, 1].
   integer(int8)            :: b !< Byte.
   integer(int32)           :: v !< Value in 0-255.

   v = min(255_int32, max(0_int32, nint(255.0_real64 * c, int32)))
   b = int(v - merge(256_int32, 0_int32, v > 127_int32), int8)
   endfunction byte
endprogram figure_mandelbrot
