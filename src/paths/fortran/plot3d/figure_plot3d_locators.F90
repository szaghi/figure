!< figure_plot3d_locators, the 3-D plot's ticks: ImPlot3D's ticker and locators.
module figure_plot3d_locators
!< figure_plot3d_locators, the 3-D plot's ticks: ImPlot3D's ticker and locators.
!<
!< szaghi/figure#15 P13. ImPlot3D places ticks its own way, not ImPlot's: `Locator_Default` takes its major count from
!< the axis's length (one per 80 pixels, at least 2) and up to 5 minor intervals (one per 30 pixels), labels minors
!< too, and thins the labels every other one from the first major outwards past 7 ticks; `Locator_Log10` and
!< `Locator_SymLog` (decades, their minors unlabelled; a symlog range across zero split at -1 and 1). Reproduced here with
!< figure_plot_locators' `nice_num` (ImPlot's and ImPlot3D's `NiceNum` are the same), `floor`/`ceil`, and the labels
!< through figure_plot_format (glibc's printf of one real: "%g", ImPlot3D's `IMPLOT3D_LABEL_FORMAT`, or the axis's
!< format), measured with figure_core's `core_text_size` (`CalcTextSize`).
!<
!< The ticker (`ticks3d`, `ImPlot3DTicker`) keeps its arrays between frames (grown, never per frame).
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_next_after, ieee_positive_inf, ieee_value
use figure_core, only : core_text_size
use figure_plot_format, only : plot_format, fmt_real
use figure_plot_locators, only : nice_num, c_floor, c_ceil, pow10, transform_symlog

implicit none
private
public :: ticks3d, ticks3_reset, ticks3_add, locate3_default, locate3_log10, locate3_symlog
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

interface
   pure function c_log10(x) result(r) bind(C, name='log10')
   !< C's `log10`.
   import :: real64
   implicit none
   real(real64), value :: x !< Value.
   real(real64)        :: r !< Logarithm.
   endfunction c_log10
endinterface

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

   subroutine locate3_log10(t, rmin, rmax, pixels, f)
   !< `Locator_Log10`: decades (a step of a multiple of three when there are many), their minors unlabelled; nothing
   !< for a range that crosses or touches zero.
   type(ticks3d),     intent(inout) :: t          !< Ticks.
   real(real64),      intent(in)    :: rmin, rmax !< Range.
   real(real32),      intent(in)    :: pixels     !< The axis's length [pixels].
   type(plot_format), intent(in)    :: f          !< The axis's format.
   integer(int32)                   :: emin, emax, estep !< Exponents.

   if (log_exponents(rmin, rmax, pixels, emin, emax, estep)) call add_log_ticks(t, rmin, rmax, emin, emax, estep, f)
   endsubroutine locate3_log10

   subroutine locate3_symlog(t, rmin, rmax, pixels, f)
   !< `Locator_SymLog`: within [-1, 1] the default ticks; across zero 0 and the decades on both sides (each side's
   !< share of the pixels from `CalcSymLogPixel`, the larger step); else the log10 ticks.
   type(ticks3d),     intent(inout) :: t          !< Ticks.
   real(real64),      intent(in)    :: rmin, rmax !< Range.
   real(real32),      intent(in)    :: pixels     !< The axis's length [pixels].
   type(plot_format), intent(in)    :: f          !< The axis's format.
   real(real32)                     :: pp1, pn1   !< Pixels of 1 and -1.
   integer(int32)                   :: eminp, emaxp, estepp, eminn, emaxn, estepn, estep !< Exponents.
   logical                          :: ok         !< Found.

   if (rmin >= -1.0_real64 .and. rmax <= 1.0_real64) then
      call locate3_default(t, rmin, rmax, pixels, f)
   elseif (rmin * rmax < 0.0_real64) then
      pp1 = symlog_pixel(1.0_real64, rmin, rmax, pixels)
      pn1 = symlog_pixel(-1.0_real64, rmin, rmax, pixels)
      eminp = 0_int32
      emaxp = 0_int32
      estepp = 0_int32
      eminn = 0_int32
      emaxn = 0_int32
      estepn = 0_int32
      ok = log_exponents(1.0_real64, rmax, abs(pixels - pp1), eminp, emaxp, estepp)
      ok = log_exponents(rmin, -1.0_real64, abs(pn1 - 0.0_real32), eminn, emaxn, estepn)
      estep = max(estepn, estepp)
      call ticks3_add(t, 0.0_real64, .true., .true., f)
      call add_log_ticks(t, 1.0_real64, rmax, eminp, emaxp, estep, f)
      call add_log_ticks(t, rmin, -1.0_real64, eminn, emaxn, estep, f)
   else
      call locate3_log10(t, rmin, rmax, pixels, f)
   endif
   endsubroutine locate3_symlog

   ! private

   function log_exponents(rmin, rmax, pix, emin, emax, estep) result(ok)
   !< `CalcLogarithmicExponents`: the decades' exponents and step for a range of one sign (false otherwise, the
   !< outputs untouched).
   real(real64),   intent(in)    :: rmin, rmax        !< Range.
   real(real32),   intent(in)    :: pix               !< Pixels.
   integer(int32), intent(inout) :: emin, emax, estep !< Exponents.
   logical                       :: ok                !< Found.
   integer(int32)                :: n_major           !< Majors.
   real(real64)                  :: lmin, lmax, la, lb !< Logarithms.

   ok = rmin * rmax > 0.0_real64
   if (.not. ok) return
   n_major = max(2_int32, int(im_round(pix * 0.01_real32), int32))
   lmin = c_log10(abs(rmin))
   lmax = c_log10(abs(rmax))
   la = min(lmin, lmax)
   lb = max(lmin, lmax)
   estep = max(1_int32, int(lb - la, int32) / n_major)
   emin = int(la, int32)
   emax = int(lb, int32)
   if (estep /= 1_int32) then
      do while (mod(estep, 3_int32) /= 0_int32)
         estep = estep + 1_int32
      enddo
      do while (mod(emin, estep) /= 0_int32)
         emin = emin - 1_int32
      enddo
   endif
   endfunction log_exponents

   subroutine add_log_ticks(t, rmin, rmax, emin, emax, estep, f)
   !< `AddTicksLogarithmic`: each decade in range a labelled major, its nine (eight at a step's last decade but one)
   !< minors unlabelled, the sign of the range's maximum.
   type(ticks3d),     intent(inout) :: t                 !< Ticks.
   real(real64),      intent(in)    :: rmin, rmax        !< Range.
   integer(int32),    intent(in)    :: emin, emax, estep !< Exponents.
   type(plot_format), intent(in)    :: f                 !< Format.
   real(real64)                     :: sgn, m1, m2, iv, minor !< Sign, decades, interval, a minor.
   integer(int32)                   :: e, j, i, ni       !< Exponent, decade, minor, minors.

   sgn = 0.0_real64
   if (rmax < 0.0_real64) sgn = -1.0_real64
   if (rmax > 0.0_real64) sgn = 1.0_real64
   e = emin - estep
   do while (e < emax + estep)
      m1 = sgn * pow10(e)
      if (m1 >= rmin - epsilon(1.0_real64) .and. m1 <= rmax + epsilon(1.0_real64)) call ticks3_add(t, m1, .true., .true., f)
      do j = 0_int32, estep - 1_int32
         m1 = sgn * pow10(e + j)
         m2 = sgn * pow10(e + j + 1_int32)
         iv = (m2 - m1) / 9.0_real64
         ni = 9_int32
         if (j < estep - 1_int32) ni = 10_int32
         do i = 1_int32, ni - 1_int32
            minor = m1 + real(i, real64) * iv
            if (minor >= rmin - epsilon(1.0_real64) .and. minor <= rmax + epsilon(1.0_real64)) &
               call ticks3_add(t, minor, .false., .false., f)
         enddo
      enddo
      e = e + estep
   enddo
   endsubroutine add_log_ticks

   function symlog_pixel(v, rmin, rmax, pixels) result(px)
   !< `CalcSymLogPixel`: the pixel of v along a symlog axis.
   real(real64), intent(in) :: v, rmin, rmax !< Value, range.
   real(real32), intent(in) :: pixels        !< The axis's length.
   real(real32)             :: px            !< Pixel.
   real(real64)             :: k, smin, smax, s, tt, q !< Scale, scaled ends, scaled value, fraction, the value back.

   k = real(pixels, real64) / (rmax - rmin)
   smin = transform_symlog(rmin)
   smax = transform_symlog(rmax)
   s = transform_symlog(v)
   tt = (s - smin) / (smax - smin)
   q = rmin + (rmax - rmin) * tt
   px = real(0.0_real64 + k * (q - rmin), real32)
   endfunction symlog_pixel

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
