!< figure_plot3d_locators, the 3-D plot's ticks: ImPlot3D's ticker and locators.
module figure_plot3d_locators
!< figure_plot3d_locators, the 3-D plot's ticks: ImPlot3D's ticker and locators.
!<
!< szaghi/figure#15 P13. ImPlot3D places ticks its own way, not ImPlot's: `Locator_Default` takes its major count from
!< the axis's length (one per 80 pixels, at least 2) and up to 5 minor intervals (one per 30 pixels), labels minors
!< too, and thins the labels every other one from the first major outwards past 7 ticks. Reproduced here with
!< figure_plot_locators' `nice_num` (ImPlot's and ImPlot3D's `NiceNum` are the same), `floor`/`ceil`, and the labels
!< through figure_plot_format (glibc's printf of one real: "%g", ImPlot3D's `IMPLOT3D_LABEL_FORMAT`, or the axis's
!< format), measured with figure_core's `core_text_size` (`CalcTextSize`).
!<
!< The ticker (`ticks3d`, `ImPlot3DTicker`) keeps its arrays between frames (grown, never per frame).
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_next_after, ieee_positive_inf, ieee_value
use figure_core, only : core_text_size
use figure_plot_format, only : plot_format, fmt_real
use figure_plot_locators, only : nice_num, c_floor, c_ceil

implicit none
private
public :: ticks3d, ticks3_reset, ticks3_add, locate3_default
public :: TICK3_LABEL_LEN

integer(int32), parameter :: TICK3_LABEL_LEN = 31_int32 !< IMPLOT3D_LABEL_MAX_SIZE less its NUL.

type :: ticks3d
   !< An axis's ticks (`ImPlot3DTicker`).
   integer(int32)                              :: n = 0_int32    !< Ticks.
   real(real64),                   allocatable :: pos(:)         !< Value (PlotPos).
   logical,                        allocatable :: major(:)       !< A major tick.
   logical,                        allocatable :: show(:)        !< Its label shown.
   character(len=TICK3_LABEL_LEN), allocatable :: label(:)       !< Label (its first `label_len` characters).
   integer(int32),                 allocatable :: label_len(:)   !< Its length.
   real(real32),                   allocatable :: label_size(:,:) !< Its size (2, n) [pixels].
endtype ticks3d

contains
   subroutine ticks3_reset(t)
   !< `ImPlot3DTicker::Reset`: no ticks.
   type(ticks3d), intent(inout) :: t !< Ticks.

   t%n = 0_int32
   endsubroutine ticks3_reset

   subroutine ticks3_add(t, v, major, show, f, label)
   !< `AddTick`: a tick, its label (shown ones only) the given text or the value through the format, measured.
   type(ticks3d),     intent(inout)        :: t     !< Ticks.
   real(real64),      intent(in)           :: v     !< Value.
   logical,           intent(in)           :: major !< A major tick.
   logical,           intent(in)           :: show  !< Label shown.
   type(plot_format), intent(in)           :: f     !< The axis's format.
   character(len=*),  intent(in), optional :: label !< Given label.
   real(real64)                            :: w, h  !< Label's size.
   integer(int32)                          :: k     !< The tick.

   if (.not. allocated(t%pos)) call grow(t, 32_int32)
   if (t%n == size(t%pos, kind=int32)) call grow(t, 2_int32 * t%n)
   k = t%n + 1_int32
   t%n = k
   t%pos(k) = v
   t%major(k) = major
   t%show(k) = show
   t%label_len(k) = 0_int32
   t%label_size(:, k) = 0.0_real32
   if (.not. show) return
   if (present(label)) then
      t%label_len(k) = min(len(label, kind=int32), TICK3_LABEL_LEN)
      t%label(k)(1:t%label_len(k)) = label(1:t%label_len(k))
   else
      call fmt_real(t%label(k), t%label_len(k), f, v)
   endif
   call core_text_size(t%label(k)(1:t%label_len(k)), w, h)
   t%label_size(1, k) = real(w, real32)
   t%label_size(2, k) = real(h, real32)
   endsubroutine ticks3_add

   subroutine locate3_default(t, rmin, rmax, pixels, f)
   !< `Locator_Default`: majors at a nice interval for the axis's length, up to 5 minors between them, every tick
   !< labelled; past 7 ticks every other label hidden, from the first major outwards.
   type(ticks3d),     intent(inout) :: t          !< Ticks (appended to custom ones).
   real(real64),      intent(in)    :: rmin, rmax !< Range.
   real(real32),      intent(in)    :: pixels     !< The axis's length [pixels].
   type(plot_format), intent(in)    :: f          !< The axis's format.
   integer(int32)                   :: n_minor, n_major, first, i0, i !< Minors, majors, the first major, counters.
   real(real64)                     :: nice_range, interval, mag, min_interval, gmin, gmax, major, minor !< Work.
   logical                          :: first_set !< The first major found.

   if (rmin == rmax) return
   n_minor = min(max(1_int32, int(im_round(pixels / 30.0_real32), int32)), 5_int32)
   n_major = max(2_int32, int(im_round(pixels / 80.0_real32), int32))
   nice_range = nice_num((rmax - rmin) * 0.99_real64, .false.)
   interval = nice_num(nice_range / real(n_major - 1_int32, real64), .true.)
   mag = max(abs(rmin), abs(rmax))
   min_interval = ieee_next_after(mag, ieee_value(1.0_real64, ieee_positive_inf)) - mag
   if (interval < min_interval) interval = min_interval
   gmin = c_floor(rmin / interval) * interval
   gmax = c_ceil(rmax / interval) * interval
   first_set = .false.
   first = 0_int32
   i0 = t%n
   major = gmin
   do while (major < gmax + 0.5_real64 * interval)
      if (major - interval < 0.0_real64 .and. major + interval > 0.0_real64) major = 0.0_real64
      if (major >= rmin .and. major <= rmax) then
         if (.not. first_set) then
            first = t%n
            first_set = .true.
         endif
         call ticks3_add(t, major, .true., .true., f)
      endif
      do i = 1_int32, n_minor - 1_int32
         minor = major + real(i, real64) * interval / real(n_minor, real64)
         if (minor >= rmin .and. minor <= rmax) call ticks3_add(t, minor, .false., .true., f)
      enddo
      major = major + interval
   enddo
   if (t%n > 7_int32) then ! 0-based indices as ImPlot3D's: tick k is t(k + 1)
      do i = first - 1_int32, i0, -2_int32
         t%show(i + 1_int32) = .false.
      enddo
      do i = first + 1_int32, t%n - 1_int32, 2_int32
         t%show(i + 1_int32) = .false.
      enddo
   endif
   endsubroutine locate3_default

   ! private

   pure function im_round(f) result(r)
   !< `IM_ROUND`: `(float)(int)(f + 0.5f)`.
   real(real32), intent(in) :: f !< Value.
   real(real32)             :: r !< Rounded.

   r = real(int(f + 0.5_real32, int32), real32)
   endfunction im_round

   subroutine grow(t, m)
   !< Room for m ticks, those held kept.
   type(ticks3d),  intent(inout)               :: t        !< Ticks.
   integer(int32), intent(in)                  :: m        !< Room.
   real(real64),                   allocatable :: pos(:)   !< New storage.
   logical,                        allocatable :: major(:), show(:) !< ...
   character(len=TICK3_LABEL_LEN), allocatable :: label(:) !< ...
   integer(int32),                 allocatable :: label_len(:) !< ...
   real(real32),                   allocatable :: ls(:,:)  !< ...
   integer(int32)                              :: n        !< Held.

   n = t%n
   allocate(pos(m), major(m), show(m), label(m), label_len(m), ls(2, m))
   if (n > 0_int32) then
      pos(1:n) = t%pos(1:n)
      major(1:n) = t%major(1:n)
      show(1:n) = t%show(1:n)
      label(1:n) = t%label(1:n)
      label_len(1:n) = t%label_len(1:n)
      ls(:, 1:n) = t%label_size(:, 1:n)
   endif
   call move_alloc(pos, t%pos)
   call move_alloc(major, t%major)
   call move_alloc(show, t%show)
   call move_alloc(label, t%label)
   call move_alloc(label_len, t%label_len)
   call move_alloc(ls, t%label_size)
   endsubroutine grow
endmodule figure_plot3d_locators
