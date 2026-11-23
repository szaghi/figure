!< figure_plot_locators, the plot frame's ticks: ImPlot's locators (linear, log10, symlog, time) and scale transforms.
module figure_plot_locators
!< figure_plot_locators, the plot frame's ticks: ImPlot's locators (linear, log10, symlog, time) and scale transforms.
!<
!< szaghi/figure#15 P10, step 5. Where the ticks of an axis go and what their labels say, as implot.cpp (ImPlot 1.2 WIP,
!< FIGURE's copy) computes them, its arithmetic kept (`float` where ImPlot's is, `double` elsewhere, C's integer
!< division and remainder):
!<
!< - `locate_default` (`Locator_Default`): the major count from the axis length, `NiceNum`, majors accumulated with the
!<   zero snapped, ten labelled minors per major, the labels thinned when they overflow;
!< - `locate_log10` (`Locator_Log10`: `CalcLogarithmicExponents`, `AddTicksLogarithmic`): a major per decade (or per
!<   3, 6, ... decades when they are many: the step a multiple of 3, the first exponent a multiple of it), labelled,
!<   eight or nine unlabelled minors between them (1 .. 9 times the decade);
!< - `locate_symlog` (`Locator_SymLog`): within [-1, 1] the default locator; crossing zero, 0 and the logarithmic
!<   ticks of [1, max] and [min, -1], their steps from the pixels each side takes (`CalcSymLogPixel`); else log10;
!< - `locate_time` (`Locator_Time`): two levels of labels, the unit of the minor ones from the range per 100 pixels
!<   (`GetUnitForRange`), the major ones a unit up; the minor step (`GetTimeStep`) from how many labels fit between two
!<   majors (half the room); a major's label hidden when it repeats the one before (`TimeLabelSame`); years by
!<   `NiceNum`; the labels of `FormatDateTime` (`TimeFormatLevel0`, `TimeFormatLevel1`, `TimeFormatLevel1First`,
!<   ImPlot's style defaults: 12-hour clock, not ISO 8601, unless asked) in UTC (`UseLocalTime` false: ImPlot's
!<   default; local time is not done);
!< - the transforms of `SetupAxisScale` (`TransformForward_Log10`, `TransformInverse_Log10`, `TransformForward_SymLog`,
!<   `TransformInverse_SymLog`): log10 of max(v, DBL_MIN), 2 asinh(v/2).
!<
!< Labels: `Formatter_Default` with "%g" (foresight's `c_real`, glibc's output) for linear, log and symlog axes, only on
!< the ticks shown (`AddTick(..., show_label, ...)`: a log axis's minors have none); the size of each label from the
!< caller's `text_measure` (Dear ImGui's `CalcTextSize` in the frame), which the time locator also asks for the width
!< of its formats (`GetDateTimeWidth`). The ticks are appended to a `plot_ticks` (ImPlotTicker): grown when needed, kept
!< between frames (no allocation per frame).
!<
!< Bit for bit: `pow`, `log10`, `asinh` and `sinh` are the C library's (bound, as ImPlot calls them: glibc's
!< `pow(10, e)` is not correctly rounded at e = 23 and 210, and nvfortran's own differ); the products added to another
!< term are computed in a statement of their own (nvfortran -O2 fuses `a*b + c` into an FMA, ImPlot's build does not).
use, intrinsic :: iso_c_binding, only : c_double
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use foresight_format, only : c_real

implicit none
private
public :: plot_ticks, text_measure, ticks_reset
public :: locate_default, locate_log10, locate_symlog, locate_time
public :: transform_log10, inverse_log10, transform_symlog, inverse_symlog
public :: nice_num, pow10, c_floor, c_ceil
public :: TICK_LABEL_LEN, TIME_MIN, TIME_MAX

integer(int32), parameter :: TICK_LABEL_LEN = 32_int32     !< IMPLOT_LABEL_MAX_SIZE.
real(real64),   parameter :: TIME_MIN = 0.0_real64         !< IMPLOT_MIN_TIME.
real(real64),   parameter :: TIME_MAX = 32503680000.0_real64 !< IMPLOT_MAX_TIME.
real(real32),   parameter :: TICK_FILL_X = 0.8_real32      !< Labels may fill this much of an x axis.
real(real32),   parameter :: TICK_FILL_Y = 1.0_real32      !< ... of a y axis.
integer(int32), parameter :: N_MINOR = 10_int32            !< Minor intervals per major (Locator_Default).
! ImPlotTimeUnit (zero-based as ImPlot's)
integer(int32), parameter :: TU_US = 0_int32, TU_MS = 1_int32, TU_S = 2_int32, TU_MIN = 3_int32, TU_HR = 4_int32, &
                             TU_DAY = 5_int32, TU_MO = 6_int32, TU_YR = 7_int32, TU_COUNT = 8_int32 !< Units.
! ImPlotDateFmt, ImPlotTimeFmt
integer(int32), parameter :: DF_NONE = 0_int32, DF_DAY_MO = 1_int32, DF_DAY_MO_YR = 2_int32, DF_MO_YR = 3_int32, &
                             DF_MO = 4_int32, DF_YR = 5_int32 !< Date formats.
integer(int32), parameter :: TF_NONE = 0_int32, TF_US = 1_int32, TF_SUS = 2_int32, TF_SMS = 3_int32, &
                             TF_S = 4_int32, TF_MIN_SMS = 5_int32, TF_HR_MIN_SMS = 6_int32, TF_HR_MIN_S = 7_int32, &
                             TF_HR_MIN = 8_int32, TF_HR = 9_int32 !< Time formats.
real(real64), parameter :: TIME_UNIT_SPANS(0:7) = [0.000001_real64, 0.001_real64, 1.0_real64, 60.0_real64, &
                                                   3600.0_real64, 86400.0_real64, 2629800.0_real64,      &
                                                   31557600.0_real64] !< TimeUnitSpans.
real(real64), parameter :: TIME_UNIT_CUTOFFS(0:7) = [0.001_real64, 1.0_real64, 60.0_real64, 3600.0_real64,     &
                                                     86400.0_real64, 2629800.0_real64, 31557600.0_real64, &
                                                     TIME_MAX] !< GetUnitForRange's cutoffs.
! TimeFormatLevel0, TimeFormatLevel1, TimeFormatLevel1First: (date, time) per unit
integer(int32), parameter :: FMT_LEVEL0(2, 0:7) = reshape([DF_NONE, TF_US, DF_NONE, TF_SMS, DF_NONE, TF_S,          &
                                                           DF_NONE, TF_HR_MIN, DF_NONE, TF_HR, DF_DAY_MO, TF_NONE, &
                                                           DF_MO, TF_NONE, DF_YR, TF_NONE], [2, 8]) !< Level 0.
integer(int32), parameter :: FMT_LEVEL1(2, 0:7) = reshape([DF_NONE, TF_HR_MIN, DF_NONE, TF_HR_MIN_S, DF_NONE,     &
                                                           TF_HR_MIN, DF_NONE, TF_HR_MIN, DF_DAY_MO_YR, TF_NONE, &
                                                           DF_DAY_MO_YR, TF_NONE, DF_YR, TF_NONE, DF_YR, TF_NONE], &
                                                          [2, 8]) !< Level 1.
integer(int32), parameter :: FMT_LEVEL1_FIRST(2, 0:7) = reshape([DF_DAY_MO_YR, TF_HR_MIN_S, DF_DAY_MO_YR,           &
                                                                 TF_HR_MIN_S, DF_DAY_MO_YR, TF_HR_MIN, DF_DAY_MO_YR, &
                                                                 TF_HR_MIN, DF_DAY_MO_YR, TF_NONE, DF_DAY_MO_YR,    &
                                                                 TF_NONE, DF_YR, TF_NONE, DF_YR, TF_NONE], &
                                                                [2, 8]) !< Level 1, the first major.
character(len=3), parameter :: MONTH_ABRVS(0:11) = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', &
                                                    'Oct', 'Nov', 'Dec'] !< MONTH_ABRVS.
integer(int32), parameter :: MONTH_DAYS(0:11) = [31_int32, 28_int32, 31_int32, 30_int32, 31_int32, 30_int32, &
                                                    31_int32, 31_int32, 30_int32, 31_int32, 30_int32, 31_int32] !< Days.

type :: plot_ticks
   !< An axis's ticks (ImPlotTicker): kept from frame to frame, grown when needed (no allocation per frame).
   integer(int32)                             :: n = 0_int32               !< Ticks.
   integer(int32)                             :: levels = 1_int32          !< Label levels (time axes: 2).
   real(real64),                  allocatable :: pos(:)                    !< Value.
   real(real32),                  allocatable :: pix(:)                    !< Pixel (rounded), the caller's.
   real(real32),                  allocatable :: label_size(:,:)           !< Label's size (2, n) [pixels].
   logical,                       allocatable :: major(:)                  !< A major tick.
   logical,                       allocatable :: show(:)                   !< Its label shown.
   integer(int32),                allocatable :: level(:)                  !< Its label's level (0, 1).
   character(len=TICK_LABEL_LEN), allocatable :: label(:)                  !< Label.
   real(real32)                               :: max_size(2) = 0.0_real32  !< The largest label shown.
endtype plot_ticks

type :: plot_time
   !< ImPlotTime: seconds since the UNIX epoch and microseconds.
   integer(int64) :: s = 0_int64  !< Seconds.
   integer(int32) :: us = 0_int32 !< Microseconds.
endtype plot_time

interface
   pure function c_pow(x, y) result(r) bind(C, name='pow')
   !< C's `pow`.
   import :: c_double
   implicit none
   real(c_double), value :: x, y !< Base, exponent.
   real(c_double)        :: r    !< Power.
   endfunction c_pow

   pure function c_log10(x) result(r) bind(C, name='log10')
   !< C's `log10`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Logarithm.
   endfunction c_log10

   pure function c_asinh(x) result(r) bind(C, name='asinh')
   !< C's `asinh`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Inverse hyperbolic sine.
   endfunction c_asinh

   pure function c_sinh(x) result(r) bind(C, name='sinh')
   !< C's `sinh`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Hyperbolic sine.
   endfunction c_sinh
endinterface

abstract interface
   subroutine text_measure(text, w, h)
   !< The size of a text in the plot's font [pixels] (`CalcTextSize`).
   import :: real32
   implicit none
   character(len=*), intent(in)  :: text !< Text.
   real(real32),     intent(out) :: w, h !< Size.
   endsubroutine text_measure
endinterface

contains
   ! ticks

   subroutine ticks_reset(t)
   !< `ImPlotTicker::Reset`: no ticks, one level.
   type(plot_ticks), intent(inout) :: t !< Ticks.

   t%n = 0_int32
   t%levels = 1_int32
   t%max_size = 0.0_real32
   endsubroutine ticks_reset

   subroutine add_tick(t, v, major, level, show, label, measure, total)
   !< `ImPlotTicker::AddTick`: a tick, its label (if shown) measured, the largest shown label kept; `total` (if given)
   !< adds its size.
   type(plot_ticks),       intent(inout)           :: t        !< Ticks.
   real(real64),           intent(in)              :: v        !< Value.
   logical,                intent(in)              :: major    !< A major tick.
   integer(int32),         intent(in)              :: level    !< Label's level.
   logical,                intent(in)              :: show     !< Label shown.
   character(len=*),       intent(in)              :: label    !< Label (when shown).
   procedure(text_measure)                         :: measure  !< Text sizes.
   real(real32),           intent(inout), optional :: total(2) !< Labels' total size.
   integer(int32)                                  :: k        !< The tick.

   if (.not. allocated(t%pos)) call grow(t, 64_int32)
   if (t%n == size(t%pos, kind=int32)) call grow(t, 2_int32 * t%n)
   k = t%n + 1_int32
   t%n = k
   t%pos(k) = v
   t%pix(k) = 0.0_real32
   t%major(k) = major
   t%level(k) = level
   t%show(k) = show
   t%label_size(:, k) = 0.0_real32
   t%label(k) = ''
   if (show) then
      t%label(k) = label
      call measure(trim(t%label(k)), t%label_size(1, k), t%label_size(2, k))
      t%max_size(1) = merge(t%label_size(1, k), t%max_size(1), t%label_size(1, k) > t%max_size(1))
      t%max_size(2) = merge(t%label_size(2, k), t%max_size(2), t%label_size(2, k) > t%max_size(2))
   endif
   if (present(total)) total = total + t%label_size(:, k)
   endsubroutine add_tick

   subroutine grow(t, m)
   !< Room for m ticks, those held kept.
   type(plot_ticks), intent(inout)            :: t     !< Ticks.
   integer(int32),   intent(in)               :: m     !< Ticks room.
   real(real64),                  allocatable :: pos(:)          !< New storage.
   real(real32),                  allocatable :: pix(:), ls(:,:) !< ...
   logical,                       allocatable :: major(:), show(:) !< ...
   integer(int32),                allocatable :: level(:)        !< ...
   character(len=TICK_LABEL_LEN), allocatable :: label(:)        !< ...
   integer(int32)                             :: n     !< Ticks held.

   n = t%n
   allocate(pos(m), pix(m), ls(2, m), major(m), show(m), level(m), label(m))
   if (n > 0_int32) then
      pos(1:n) = t%pos(1:n)
      pix(1:n) = t%pix(1:n)
      ls(:, 1:n) = t%label_size(:, 1:n)
      major(1:n) = t%major(1:n)
      show(1:n) = t%show(1:n)
      level(1:n) = t%level(1:n)
      label(1:n) = t%label(1:n)
   endif
   call move_alloc(pos, t%pos)
   call move_alloc(pix, t%pix)
   call move_alloc(ls, t%label_size)
   call move_alloc(major, t%major)
   call move_alloc(show, t%show)
   call move_alloc(level, t%level)
   call move_alloc(label, t%label)
   endsubroutine grow

   function label_g(v) result(s)
   !< `Formatter_Default` with "%g".
   real(real64), intent(in)      :: v !< Value.
   character(len=TICK_LABEL_LEN) :: s !< Label.

   s = c_real('', 0_int32, -1_int32, 'g', v)
   endfunction label_g

   ! the linear locator

   subroutine locate_default(t, rmin, rmax, pixels, vertical, measure)
   !< `Locator_Default`: the ticks of a linear range on an axis `pixels` long.
   type(plot_ticks),       intent(inout) :: t          !< Ticks (appended).
   real(real64),           intent(in)    :: rmin, rmax !< Range.
   real(real32),           intent(in)    :: pixels     !< Axis's length [pixels].
   logical,                intent(in)    :: vertical   !< A y axis.
   procedure(text_measure)               :: measure    !< Text sizes.
   integer(int32)                        :: n_major    !< Majors wanted.
   real(real64)                          :: nice_range, interval, magnitude, min_interval !< The step.
   real(real64)                          :: graphmin, graphmax !< The majors' span.
   real(real64)                          :: major, minor !< Tick values.
   real(real32)                          :: total(2)   !< Labels' total size [pixels].
   integer(int32)                        :: first      !< The first major's tick (0: none).
   integer(int32)                        :: idx0       !< Ticks before.
   integer(int32)                        :: i          !< Counter.

   if (rmin == rmax) return
   n_major = max(2_int32, int(real(int(pixels / merge(300.0_real32, 400.0_real32, vertical) + 0.5_real32, int32), &
                                  real32), int32))
   nice_range = nice_num((rmax - rmin) * 0.99_real64, .false.)
   interval = nice_num(nice_range / real(n_major - 1_int32, real64), .true.)
   magnitude = max(abs(rmin), abs(rmax))
   min_interval = nearest(magnitude, 1.0_real64) - magnitude
   if (interval < min_interval) interval = min_interval
   graphmin = c_floor(rmin / interval) * interval
   graphmax = c_ceil(rmax / interval) * interval
   first = 0_int32
   idx0 = t%n
   total = 0.0_real32
   major = graphmin
   do while (major < graphmax + 0.5_real64 * interval)
      if (major - interval < 0.0_real64 .and. major + interval > 0.0_real64) major = 0.0_real64
      if (major >= rmin .and. major <= rmax) then
         if (first == 0_int32) first = t%n + 1_int32
         call add_tick(t, major, .true., 0_int32, .true., label_g(major), measure, total)
      endif
      do i = 1_int32, N_MINOR - 1_int32
         minor = major + real(i, real64) * interval / real(N_MINOR, real64)
         if (minor >= rmin .and. minor <= rmax) call add_tick(t, minor, .false., 0_int32, .true., label_g(minor), &
                                                              measure, total)
      enddo
      major = major + interval
   enddo
   if ((.not. vertical .and. total(1) > pixels * TICK_FILL_X) .or. &
       (vertical .and. total(2) > pixels * TICK_FILL_Y)) then
      if (first == 0_int32) first = 1_int32 ! ImPlot's first_major_idx left 0: the first tick
      do i = first - 1_int32, idx0 + 1_int32, -2_int32
         t%show(i) = .false.
      enddo
      do i = first + 1_int32, t%n, 2_int32
         t%show(i) = .false.
      enddo
   endif
   endsubroutine locate_default

   ! the logarithmic locators

   subroutine log_exponents(rmin, rmax, pix, vertical, exp_min, exp_max, exp_step, ok)
   !< `CalcLogarithmicExponents`: the decades of a range of one sign, the step between labelled ones.
   real(real64),   intent(in)  :: rmin, rmax                 !< Range.
   real(real32),   intent(in)  :: pix                        !< Axis's length [pixels].
   logical,        intent(in)  :: vertical                   !< A y axis.
   integer(int32), intent(out) :: exp_min, exp_max, exp_step !< Exponents and step.
   logical,        intent(out) :: ok                         !< The range has one sign.
   integer(int32)              :: n_major                    !< Majors wanted.
   real(real64)                :: log_min, log_max, log_a, log_b !< Logarithms.
   real(real32)                :: scaled                     !< Pixels times the majors' density.

   exp_min = 0_int32
   exp_max = 0_int32
   exp_step = 1_int32
   ok = rmin * rmax > 0.0_real64
   if (.not. ok) return
   if (vertical) then
      scaled = pix * 0.02_real32
   else
      scaled = pix * 0.01_real32
   endif
   n_major = max(2_int32, int(real(int(scaled + 0.5_real32, int32), real32), int32))
   log_min = c_log10(abs(rmin))
   log_max = c_log10(abs(rmax))
   log_a = merge(log_min, log_max, log_min < log_max)  ! ImMin
   log_b = merge(log_min, log_max, log_min >= log_max) ! ImMax
   exp_step = max(1_int32, int(log_b - log_a, int32) / n_major)
   exp_min = int(log_a, int32)
   exp_max = int(log_b, int32)
   if (exp_step /= 1_int32) then
      do while (mod(exp_step, 3_int32) /= 0_int32)
         exp_step = exp_step + 1_int32
      enddo
      do while (mod(exp_min, exp_step) /= 0_int32)
         exp_min = exp_min - 1_int32
      enddo
   endif
   endsubroutine log_exponents

   subroutine log_ticks(t, rmin, rmax, exp_min, exp_max, exp_step, measure)
   !< `AddTicksLogarithmic`: the labelled majors at the decades of the step, the unlabelled minors 2 .. 9 times each
   !< decade (and the decade itself inside a step of several), within DBL_EPSILON of the range.
   type(plot_ticks),       intent(inout) :: t          !< Ticks (appended).
   real(real64),           intent(in)    :: rmin, rmax !< Range.
   integer(int32),         intent(in)    :: exp_min, exp_max, exp_step !< Exponents and step.
   procedure(text_measure)               :: measure    !< Text sizes.
   real(real64)                          :: sgn        !< The range's sign.
   real(real64)                          :: major1, major2, interval, minor !< Values.
   integer(int32)                        :: e, i, j    !< Counters.

   sgn = merge(-1.0_real64, merge(1.0_real64, 0.0_real64, rmax > 0.0_real64), rmax < 0.0_real64) ! ImSign
   e = exp_min - exp_step
   do while (e < exp_max + exp_step)
      major1 = sgn * pow10(e)
      major2 = sgn * pow10(e + 1_int32)
      interval = (major2 - major1) / 9.0_real64
      if (major1 >= rmin - epsilon(1.0_real64) .and. major1 <= rmax + epsilon(1.0_real64)) &
         call add_tick(t, major1, .true., 0_int32, .true., label_g(major1), measure)
      do j = 0_int32, exp_step - 1_int32
         major1 = sgn * pow10(e + j)
         major2 = sgn * pow10(e + j + 1_int32)
         interval = (major2 - major1) / 9.0_real64
         do i = 1_int32, 9_int32 + merge(1_int32, 0_int32, j < exp_step - 1_int32) - 1_int32
            minor = real(i, real64) * interval
            minor = major1 + minor
            if (minor >= rmin - epsilon(1.0_real64) .and. minor <= rmax + epsilon(1.0_real64)) &
               call add_tick(t, minor, .false., 0_int32, .false., '', measure)
         enddo
      enddo
      e = e + exp_step
   enddo
   endsubroutine log_ticks

   subroutine locate_log10(t, rmin, rmax, pixels, vertical, measure)
   !< `Locator_Log10`: the ticks of a log10 axis (none if the range crosses or touches zero).
   type(plot_ticks),       intent(inout) :: t          !< Ticks (appended).
   real(real64),           intent(in)    :: rmin, rmax !< Range.
   real(real32),           intent(in)    :: pixels     !< Axis's length [pixels].
   logical,                intent(in)    :: vertical   !< A y axis.
   procedure(text_measure)               :: measure    !< Text sizes.
   integer(int32)                        :: exp_min, exp_max, exp_step !< Exponents and step.
   logical                               :: ok         !< One sign.

   call log_exponents(rmin, rmax, pixels, vertical, exp_min, exp_max, exp_step, ok)
   if (ok) call log_ticks(t, rmin, rmax, exp_min, exp_max, exp_step, measure)
   endsubroutine locate_log10

   subroutine locate_symlog(t, rmin, rmax, pixels, vertical, measure)
   !< `Locator_SymLog`: within [-1, 1] the linear ticks; crossing zero 0 and the logarithmic ticks of both sides (one
   !< step, the larger of the two sides'); else the log10 ticks.
   type(plot_ticks),       intent(inout) :: t          !< Ticks (appended).
   real(real64),           intent(in)    :: rmin, rmax !< Range.
   real(real32),           intent(in)    :: pixels     !< Axis's length [pixels].
   logical,                intent(in)    :: vertical   !< A y axis.
   procedure(text_measure)               :: measure    !< Text sizes.
   real(real32)                          :: pix_p1, pix_n1 !< The pixels of 1 and -1.
   integer(int32)                        :: exp_min_p, exp_max_p, exp_step_p !< The positive side's exponents.
   integer(int32)                        :: exp_min_n, exp_max_n, exp_step_n !< The negative side's.
   logical                               :: ok         !< Exponents found.

   if (rmin >= -1.0_real64 .and. rmax <= 1.0_real64) then
      call locate_default(t, rmin, rmax, pixels, vertical, measure)
   elseif (rmin * rmax < 0.0_real64) then
      pix_p1 = symlog_pixel(1.0_real64, rmin, rmax, pixels)
      pix_n1 = symlog_pixel(-1.0_real64, rmin, rmax, pixels)
      call log_exponents(1.0_real64, rmax, abs(pixels - pix_p1), vertical, exp_min_p, exp_max_p, exp_step_p, ok)
      call log_exponents(rmin, -1.0_real64, abs(pix_n1 - 0.0_real32), vertical, exp_min_n, exp_max_n, exp_step_n, ok)
      call add_tick(t, 0.0_real64, .true., 0_int32, .true., label_g(0.0_real64), measure)
      call log_ticks(t, 1.0_real64, rmax, exp_min_p, exp_max_p, max(exp_step_n, exp_step_p), measure)
      call log_ticks(t, rmin, -1.0_real64, exp_min_n, exp_max_n, max(exp_step_n, exp_step_p), measure)
   else
      call locate_log10(t, rmin, rmax, pixels, vertical, measure)
   endif
   endsubroutine locate_symlog

   function symlog_pixel(plt, rmin, rmax, pixels) result(px)
   !< `CalcSymLogPixel`: the pixel of a value on a symlog axis `pixels` long, from its start.
   real(real64), intent(in) :: plt        !< Value.
   real(real64), intent(in) :: rmin, rmax !< Range.
   real(real32), intent(in) :: pixels     !< Axis's length [pixels].
   real(real32)             :: px         !< Pixel.
   real(real64)             :: scale, smin, smax, s, tt, v !< Transform.

   scale = real(pixels, real64) / (rmax - rmin)
   smin = transform_symlog(rmin)
   smax = transform_symlog(rmax)
   s = transform_symlog(plt)
   tt = (s - smin) / (smax - smin)
   v = (rmax - rmin) * tt
   v = rmin + v
   v = scale * (v - rmin)
   px = real(0.0_real64 + v, real32)
   endfunction symlog_pixel

   ! the transforms

   pure function transform_log10(v) result(s)
   !< `TransformForward_Log10`: log10 of v, of DBL_MIN for v <= 0.
   real(real64), intent(in) :: v !< Value.
   real(real64)             :: s !< Scaled value.

   if (v <= 0.0_real64) then
      s = c_log10(tiny(1.0_real64))
   else
      s = c_log10(v)
   endif
   endfunction transform_log10

   pure function inverse_log10(s) result(v)
   !< `TransformInverse_Log10`: 10**s.
   real(real64), intent(in) :: s !< Scaled value.
   real(real64)             :: v !< Value.

   v = c_pow(10.0_real64, s)
   endfunction inverse_log10

   pure function transform_symlog(v) result(s)
   !< `TransformForward_SymLog`: 2 asinh(v / 2).
   real(real64), intent(in) :: v !< Value.
   real(real64)             :: s !< Scaled value.

   s = 2.0_real64 * c_asinh(v / 2.0_real64)
   endfunction transform_symlog

   pure function inverse_symlog(s) result(v)
   !< `TransformInverse_SymLog`: 2 sinh(s / 2).
   real(real64), intent(in) :: s !< Scaled value.
   real(real64)             :: v !< Value.

   v = 2.0_real64 * c_sinh(s / 2.0_real64)
   endfunction inverse_symlog

   ! the time locator

   subroutine locate_time(t, rmin, rmax, pixels, measure, use_24h, use_iso8601)
   !< `Locator_Time`: the ticks of a time axis (UNIX seconds, UTC): two label levels below 1 year per 100 pixels, else
   !< years.
   type(plot_ticks),       intent(inout)        :: t           !< Ticks (appended).
   real(real64),           intent(in)           :: rmin, rmax  !< Range [s].
   real(real32),           intent(in)           :: pixels      !< Axis's length [pixels].
   procedure(text_measure)                      :: measure     !< Text sizes.
   logical,                intent(in), optional :: use_24h     !< 24-hour clock (ImPlotStyle::Use24HourClock).
   logical,                intent(in), optional :: use_iso8601 !< ISO 8601 dates (ImPlotStyle::UseISO8601).
   real(real32), parameter                      :: MAX_DENSITY = 0.5_real32 !< Labels per their room at most.
   integer(int32)                :: unit0, unit1         !< The units of levels 0 and 1.
   integer(int32)                :: fmt0(2), fmt1(2), fmtf(2) !< Their formats, and the first major's.
   type(plot_time)               :: t_min, t_max, t1, t2, t12 !< Times.
   real(real32)                  :: pix_per_major_div, w0, w1, wf, px_to_t2, label_width !< Sizes [pixels].
   integer(int32)                :: minor_per_major, step, max_labels !< Counts.
   integer(int32)                :: year_min, year_max, graphmin, graphmax, y !< Years.
   real(real64)                  :: nice_range, interval !< The years' step.
   character(len=TICK_LABEL_LEN) :: lab, last          !< Labels.
   logical                       :: h24, iso, has_last !< Options, a major labelled before.

   h24 = .false.
   if (present(use_24h)) h24 = use_24h
   iso = .false.
   if (present(use_iso8601)) iso = use_iso8601
   t%levels = 2_int32 ! SetupAxisScale(ImPlotScale_Time): Ticker.Levels = 2
   unit0 = unit_for_range((rmax - rmin) / real(pixels / 100.0_real32, real64))
   unit1 = min(max(unit0 + 1_int32, 0_int32), TU_COUNT - 1_int32)
   fmt0 = FMT_LEVEL0(:, unit0)
   fmt1 = FMT_LEVEL1(:, unit1)
   fmtf = FMT_LEVEL1_FIRST(:, unit1)
   t_min = time_from_double(rmin)
   t_max = time_from_double(rmax)
   has_last = .false.
   last = ''
   if (unit0 /= TU_YR) then
      pix_per_major_div = pixels / real((rmax - rmin) / TIME_UNIT_SPANS(unit1), real32)
      w0 = format_width(fmt0, h24, iso, measure)
      w1 = format_width(fmt1, h24, iso, measure)
      wf = format_width(fmtf, h24, iso, measure)
      minor_per_major = int(MAX_DENSITY * pix_per_major_div / w0, int32)
      step = time_step(minor_per_major, unit0)
      t1 = floor_time(time_from_double(rmin), unit1)
      do while (time_lt(t1, t_max))
         t2 = add_time(t1, unit1, 1_int32)
         if (time_le(t_min, t1) .and. time_le(t1, t_max)) then
            call add_tick(t, time_to_double(t1), .true., 0_int32, .true., date_time_label(t1, fmt0, h24, iso), measure)
            if (has_last) then
               lab = date_time_label(t1, fmt1, h24, iso)
            else
               lab = date_time_label(t1, fmtf, h24, iso)
            endif
            call add_tick(t, time_to_double(t1), .true., 1_int32, .true., lab, measure)
            if (has_last) then
               if (label_same(last, lab)) t%show(t%n) = .false.
            endif
            last = lab
            has_last = .true.
         endif
         if (minor_per_major > 1_int32 .and. (time_le(t_min, t2) .and. time_le(t1, t_max))) then
            t12 = add_time(t1, unit0, step)
            do while (time_lt(t12, t2))
               px_to_t2 = real(time_to_double(time_sub(t2, t12)) / (rmax - rmin), real32) * pixels
               if (time_le(t_min, t12) .and. time_le(t12, t_max)) then
                  call add_tick(t, time_to_double(t12), .false., 0_int32, px_to_t2 >= w0, &
                                date_time_label(t12, fmt0, h24, iso), measure)
                  if (.not. has_last .and. px_to_t2 >= w0 .and. px_to_t2 >= (w1 + wf) / 2.0_real32) then
                     lab = date_time_label(t12, fmtf, h24, iso)
                     call add_tick(t, time_to_double(t12), .true., 1_int32, .true., lab, measure)
                     last = lab
                     has_last = .true.
                  endif
               endif
               t12 = add_time(t12, unit0, step)
            enddo
         endif
         t1 = t2
      enddo
   else
      label_width = format_width(FMT_LEVEL0(:, TU_YR), h24, iso, measure)
      max_labels = int(MAX_DENSITY * pixels / label_width, int32)
      year_min = time_year(t_min)
      year_max = time_year(ceil_time(t_max, TU_YR))
      nice_range = nice_num(real(year_max - year_min, real64) * 0.99_real64, .false.)
      interval = nice_num(nice_range / real(max_labels - 1_int32, real64), .true.)
      graphmin = int(c_floor(real(year_min, real64) / interval) * interval, int32)
      graphmax = int(c_ceil(real(year_max, real64) / interval) * interval, int32)
      step = merge(1_int32, int(interval, int32), int(interval, int32) <= 0_int32)
      y = graphmin
      do while (y < graphmax)
         t1 = make_time(y, 0_int32, 1_int32, 0_int32, 0_int32, 0_int32, 0_int32)
         if (time_le(t_min, t1) .and. time_le(t1, t_max)) &
            call add_tick(t, time_to_double(t1), .true., 0_int32, .true., &
                          date_time_label(t1, FMT_LEVEL0(:, TU_YR), h24, iso), &
                          measure)
         y = y + step
      enddo
   endif
   endsubroutine locate_time

   function format_width(fmt, h24, iso, measure) result(w)
   !< `GetDateTimeWidth`: the width of a format's label of 2888-12-22 12:58:58.888888 (its widest, ImPlot's guess).
   integer(int32),         intent(in) :: fmt(2)   !< (date, time) format.
   logical,                intent(in) :: h24, iso !< 24-hour clock, ISO 8601.
   procedure(text_measure)            :: measure  !< Text sizes.
   real(real32)                       :: w        !< Width [pixels].
   real(real32)                       :: h        !< Height [pixels].

   call measure(trim(date_time_label(make_time(2888_int32, 12_int32, 22_int32, 12_int32, 58_int32, 58_int32, &
                                               888888_int32), fmt, h24, iso)), w, h)
   endfunction format_width

   pure function unit_for_range(r) result(u)
   !< `GetUnitForRange`: the time unit of a span.
   real(real64), intent(in) :: r !< Span [s].
   integer(int32)           :: u !< ImPlotTimeUnit.
   integer(int32)           :: i !< Counter.

   u = TU_YR
   do i = 0_int32, TU_COUNT - 1_int32
      if (r <= TIME_UNIT_CUTOFFS(i)) then
         u = i
         return
      endif
   enddo
   endfunction unit_for_range

   pure function time_step(max_divs, unit) result(step)
   !< `GetTimeStep`: the minor step of a unit when at most `max_divs` minors fit (`LowerBoundStep`).
   integer(int32), intent(in) :: max_divs !< Minors that fit.
   integer(int32), intent(in) :: unit     !< ImPlotTimeUnit.
   integer(int32)             :: step     !< Step (0: none).

   select case (unit)
   case (TU_US, TU_MS)
      step = lower_bound_step(max_divs, [2, 4, 5, 10, 20, 40, 50, 100, 200, 500, 1000], &
                              [500, 250, 200, 100, 50, 25, 20, 10, 5, 2, 1])
   case (TU_S, TU_MIN)
      step = lower_bound_step(max_divs, [2, 4, 6, 12, 60], [30, 15, 10, 5, 1])
   case (TU_HR)
      step = lower_bound_step(max_divs, [2, 4, 8, 12, 24], [12, 6, 3, 2, 1])
   case (TU_DAY)
      step = lower_bound_step(max_divs, [2, 4, 14, 28], [14, 7, 2, 1])
   case (TU_MO)
      step = lower_bound_step(max_divs, [2, 4, 6, 12], [6, 3, 2, 1])
   case default
      step = 0_int32
   endselect
   endfunction time_step

   pure function lower_bound_step(max_divs, divs, steps) result(step)
   !< `LowerBoundStep`.
   integer(int32), intent(in) :: max_divs !< Minors that fit.
   integer,        intent(in) :: divs(:)  !< Divisions.
   integer,        intent(in) :: steps(:) !< Their steps.
   integer(int32)             :: step     !< Step.
   integer(int32)             :: i        !< Counter.

   step = 0_int32
   if (max_divs < divs(1)) return
   do i = 2_int32, size(divs, kind=int32)
      if (max_divs < divs(i)) then
         step = int(steps(i - 1_int32), int32)
         return
      endif
   enddo
   step = int(steps(size(steps)), int32)
   endfunction lower_bound_step

   pure function label_same(l1, l2) result(same)
   !< `TimeLabelSame`: the shorter label ends the longer one.
   character(len=*), intent(in) :: l1, l2 !< Labels.
   logical                      :: same   !< Same ending.
   integer(int32)               :: n1, n2, n !< Lengths.

   n1 = len_trim(l1, kind=int32)
   n2 = len_trim(l2, kind=int32)
   n = min(n1, n2)
   same = l1(n1 - n + 1_int32:n1) == l2(n2 - n + 1_int32:n2)
   endfunction label_same

   ! time: ImPlotTime, UTC calendar (gmtime_r, timegm)

   pure function time_make(s, us) result(t)
   !< `ImPlotTime(s, us)`: microseconds beyond a second carried (C's division and remainder).
   integer(int64), intent(in) :: s  !< Seconds.
   integer(int64), intent(in) :: us !< Microseconds.
   type(plot_time)            :: t  !< Time.

   t%s = s + us / 1000000_int64
   t%us = int(mod(us, 1000000_int64), int32)
   endfunction time_make

   pure function time_from_double(v) result(t)
   !< `ImPlotTime::FromDouble`: (time_t)v and (int)(v 1e6 - floor(v) 1e6).
   real(real64), intent(in) :: v !< Seconds.
   type(plot_time)          :: t !< Time.
   real(real64)             :: a, b !< v 1e6, floor(v) 1e6.

   a = v * 1000000.0_real64
   b = c_floor(v) * 1000000.0_real64
   t = time_make(int(v, int64), int(int(a - b, int32), int64))
   endfunction time_from_double

   pure function time_to_double(t) result(v)
   !< `ImPlotTime::ToDouble`.
   type(plot_time), intent(in) :: t !< Time.
   real(real64)                :: v !< Seconds.

   v = real(t%s, real64) + real(t%us, real64) / 1000000.0_real64
   endfunction time_to_double

   pure function time_sub(a, b) result(t)
   !< `operator-` of two times.
   type(plot_time), intent(in) :: a, b !< Times.
   type(plot_time)             :: t    !< Difference.

   t = time_make(a%s - b%s, int(a%us - b%us, int64))
   endfunction time_sub

   pure function time_lt(a, b) result(yes)
   !< `operator<`.
   type(plot_time), intent(in) :: a, b !< Times.
   logical                     :: yes  !< a < b.

   if (a%s == b%s) then
      yes = a%us < b%us
   else
      yes = a%s < b%s
   endif
   endfunction time_lt

   pure function time_le(a, b) result(yes)
   !< `operator<=`.
   type(plot_time), intent(in) :: a, b !< Times.
   logical                     :: yes  !< a <= b.

   yes = time_lt(a, b) .or. (a%s == b%s .and. a%us == b%us)
   endfunction time_le

   pure subroutine gm_time(s, year, mon, mday, hour, minute, sec)
   !< `gmtime_r`: the UTC calendar of a time (year, month 0-11, day 1-31, hour, minute, second).
   integer(int64), intent(in)  :: s                       !< Seconds since the epoch.
   integer(int32), intent(out) :: year, mon, mday, hour, minute, sec !< Calendar.
   integer(int64)              :: days, rem, z, era, doe, yoe, doy, mp, d, m, y !< Civil from days (H. Hinnant).

   days = s / 86400_int64
   rem = s - days * 86400_int64
   if (rem < 0_int64) then
      rem = rem + 86400_int64
      days = days - 1_int64
   endif
   hour = int(rem / 3600_int64, int32)
   minute = int(mod(rem, 3600_int64) / 60_int64, int32)
   sec = int(mod(rem, 60_int64), int32)
   z = days + 719468_int64
   era = merge(z, z - 146096_int64, z >= 0_int64) / 146097_int64
   doe = z - era * 146097_int64
   yoe = (doe - doe / 1460_int64 + doe / 36524_int64 - doe / 146096_int64) / 365_int64
   y = yoe + era * 400_int64
   doy = doe - (365_int64 * yoe + yoe / 4_int64 - yoe / 100_int64)
   mp = (5_int64 * doy + 2_int64) / 153_int64
   d = doy - (153_int64 * mp + 2_int64) / 5_int64 + 1_int64
   m = merge(mp + 3_int64, mp - 9_int64, mp < 10_int64)
   if (m <= 2_int64) y = y + 1_int64
   year = int(y, int32)
   mon = int(m - 1_int64, int32)
   mday = int(d, int32)
   endsubroutine gm_time

   pure function days_from_civil(year, mon, mday) result(days)
   !< Days since the epoch of a UTC date (month 0-11; the day may run past the month, as `timegm` normalises it).
   integer(int32), intent(in) :: year, mon, mday !< Date.
   integer(int64)             :: days            !< Days.
   integer(int64)             :: y, m, era, yoe, doy, doe !< Days from civil (H. Hinnant).

   y = int(year, int64) + int(mon / 12_int32, int64)
   m = int(mod(mon, 12_int32), int64) + 1_int64
   if (m < 1_int64) then
      m = m + 12_int64
      y = y - 1_int64
   endif
   if (m <= 2_int64) y = y - 1_int64
   era = merge(y, y - 399_int64, y >= 0_int64) / 400_int64
   yoe = y - era * 400_int64
   doy = (153_int64 * merge(m - 3_int64, m + 9_int64, m > 2_int64) + 2_int64) / 5_int64 + 1_int64 - 1_int64
   doe = yoe * 365_int64 + yoe / 4_int64 - yoe / 100_int64 + doy
   days = era * 146097_int64 + doe - 719468_int64 + int(mday - 1_int32, int64)
   endfunction days_from_civil

   pure function mk_time(year, mon, mday, hour, minute, sec) result(t)
   !< `MkGmtTime` (`timegm`, a negative time made 0).
   integer(int32), intent(in) :: year, mon, mday, hour, minute, sec !< Calendar (year itself, month 0-11).
   type(plot_time)            :: t                                  !< Time.

   t%s = days_from_civil(year, mon, mday) * 86400_int64 + int(hour, int64) * 3600_int64 + &
         int(minute, int64) * 60_int64 + int(sec, int64)
   t%us = 0_int32
   if (t%s < 0_int64) t%s = 0_int64
   endfunction mk_time

   pure function make_time(year, month, day, hour, minute, sec, us) result(t)
   !< `MakeTime`: a time from its components (years before 1900 made 1900).
   integer(int32), intent(in) :: year, month, day, hour, minute, sec, us !< Components (month 0-11).
   type(plot_time)            :: t                                       !< Time.
   integer(int32)             :: s, u                                    !< Seconds, microseconds.

   s = sec + us / 1000000_int32
   u = mod(us, 1000000_int32)
   t = mk_time(max(year, 1900_int32), month, day, hour, minute, s)
   t%us = u
   endfunction make_time

   pure function time_year(t) result(year)
   !< `GetYear`.
   type(plot_time), intent(in) :: t    !< Time.
   integer(int32)              :: year !< Year.
   integer(int32)              :: mon, mday, hour, minute, sec !< The rest.

   call gm_time(t%s, year, mon, mday, hour, minute, sec)
   endfunction time_year

   pure function leap_year(year) result(yes)
   !< `IsLeapYear`.
   integer(int32), intent(in) :: year !< Year.
   logical                    :: yes  !< Leap.

   yes = mod(year, 4_int32) == 0_int32 .and. (mod(year, 100_int32) /= 0_int32 .or. mod(year, 400_int32) == 0_int32)
   endfunction leap_year

   pure function days_in_month(year, mon) result(n)
   !< `GetDaysInMonth` (month 0-11).
   integer(int32), intent(in) :: year, mon !< Month.
   integer(int32)             :: n         !< Days.

   n = MONTH_DAYS(mon)
   if (mon == 1_int32 .and. leap_year(year)) n = n + 1_int32
   endfunction days_in_month

   pure function add_time(t, unit, count) result(r)
   !< `AddTime` of a positive count of a unit.
   type(plot_time), intent(in) :: t     !< Time.
   integer(int32),  intent(in) :: unit  !< ImPlotTimeUnit.
   integer(int32),  intent(in) :: count !< Units (> 0).
   type(plot_time)             :: r     !< Time.
   integer(int32)              :: i, year, mon, mday, hour, minute, sec !< Counter, calendar.
   integer(int64)              :: us    !< Microseconds.

   r = t
   us = int(r%us, int64)
   select case (unit)
   case (TU_US)
      us = us + int(count, int64)
   case (TU_MS)
      us = us + int(count, int64) * 1000_int64
   case (TU_S)
      r%s = r%s + int(count, int64)
   case (TU_MIN)
      r%s = r%s + int(count, int64) * 60_int64
   case (TU_HR)
      r%s = r%s + int(count, int64) * 3600_int64
   case (TU_DAY)
      r%s = r%s + int(count, int64) * 86400_int64
   case (TU_MO)
      do i = 1_int32, abs(count)
         call gm_time(r%s, year, mon, mday, hour, minute, sec)
         r%s = r%s + 86400_int64 * int(days_in_month(year, mon), int64)
      enddo
   case (TU_YR)
      do i = 1_int32, abs(count)
         r%s = r%s + 86400_int64 * int(365_int32 + merge(1_int32, 0_int32, leap_year(time_year(r))), int64)
      enddo
   case default
   endselect
   r = time_make(r%s, us) ! RollOver
   endfunction add_time

   pure function floor_time(t, unit) result(r)
   !< `FloorTime`: a time down to its unit.
   type(plot_time), intent(in) :: t    !< Time.
   integer(int32),  intent(in) :: unit !< ImPlotTimeUnit.
   type(plot_time)             :: r    !< Time.
   integer(int32)              :: year, mon, mday, hour, minute, sec !< Calendar.

   call gm_time(t%s, year, mon, mday, hour, minute, sec)
   select case (unit)
   case (TU_S)
      r = time_make(t%s, 0_int64)
      return
   case (TU_MS)
      r = time_make(t%s, int((t%us / 1000_int32) * 1000_int32, int64))
      return
   case (TU_US)
      r = t
      return
   case (TU_YR)
      mon = 0_int32
      mday = 1_int32
      hour = 0_int32
      minute = 0_int32
      sec = 0_int32
   case (TU_MO)
      mday = 1_int32
      hour = 0_int32
      minute = 0_int32
      sec = 0_int32
   case (TU_DAY)
      hour = 0_int32
      minute = 0_int32
      sec = 0_int32
   case (TU_HR)
      minute = 0_int32
      sec = 0_int32
   case (TU_MIN)
      sec = 0_int32
   case default
      r = t
      return
   endselect
   r = mk_time(year, mon, mday, hour, minute, sec)
   endfunction floor_time

   pure function ceil_time(t, unit) result(r)
   !< `CeilTime`.
   type(plot_time), intent(in) :: t    !< Time.
   integer(int32),  intent(in) :: unit !< ImPlotTimeUnit.
   type(plot_time)             :: r    !< Time.

   r = add_time(floor_time(t, unit), unit, 1_int32)
   endfunction ceil_time

   function date_time_label(t, fmt, h24, iso) result(s)
   !< `FormatDateTime`: the date, a blank and the time, as the formats ask (`FormatDate`, `FormatTime`).
   type(plot_time), intent(in)   :: t      !< Time.
   integer(int32),  intent(in)   :: fmt(2) !< (ImPlotDateFmt, ImPlotTimeFmt).
   logical,         intent(in)   :: h24    !< 24-hour clock.
   logical,         intent(in)   :: iso    !< ISO 8601 dates.
   character(len=TICK_LABEL_LEN) :: s      !< Label.
   character(len=TICK_LABEL_LEN) :: d, c   !< Date, clock.
   integer(int32)                :: year, mon, mday, hour, minute, sec, ms, us, hr !< Calendar.
   character(len=2)              :: ap     !< am/pm.

   call gm_time(t%s, year, mon, mday, hour, minute, sec)
   us = mod(t%us, 1000_int32)
   ms = t%us / 1000_int32
   d = ''
   c = ''
   if (iso) then
      select case (fmt(1))
      case (DF_DAY_MO)
         write(d, '(A,I2.2,A,I2.2)') '--', mon + 1_int32, '-', mday
      case (DF_DAY_MO_YR)
         write(d, '(I0,A,I2.2,A,I2.2)') year, '-', mon + 1_int32, '-', mday
      case (DF_MO_YR)
         write(d, '(I0,A,I2.2)') year, '-', mon + 1_int32
      case (DF_MO)
         write(d, '(A,I2.2)') '--', mon + 1_int32
      case (DF_YR)
         write(d, '(I0)') year
      case default
      endselect
   else
      select case (fmt(1))
      case (DF_DAY_MO)
         write(d, '(I0,A,I0)') mon + 1_int32, '/', mday
      case (DF_DAY_MO_YR)
         write(d, '(I0,A,I0,A,I2.2)') mon + 1_int32, '/', mday, '/', mod(year, 100_int32)
      case (DF_MO_YR)
         write(d, '(A,A,I0)') MONTH_ABRVS(mon), ' ', year
      case (DF_MO)
         d = MONTH_ABRVS(mon)
      case (DF_YR)
         write(d, '(I0)') year
      case default
      endselect
   endif
   if (h24) then
      hr = hour
      ap = ''
   else
      hr = merge(12_int32, mod(hour, 12_int32), hour == 0_int32 .or. hour == 12_int32)
      ap = merge('am', 'pm', hour < 12_int32)
   endif
   select case (fmt(2))
   case (TF_US)
      write(c, '(A,I3.3,A,I3.3)') '.', ms, ' ', us
   case (TF_SUS)
      write(c, '(A,I2.2,A,I3.3,A,I3.3)') ':', sec, '.', ms, ' ', us
   case (TF_SMS)
      write(c, '(A,I2.2,A,I3.3)') ':', sec, '.', ms
   case (TF_S)
      write(c, '(A,I2.2)') ':', sec
   case (TF_MIN_SMS)
      write(c, '(A,I2.2,A,I2.2,A,I3.3)') ':', minute, ':', sec, '.', ms
   case (TF_HR_MIN_SMS)
      if (h24) then
         write(c, '(I2.2,A,I2.2,A,I2.2,A,I3.3)') hr, ':', minute, ':', sec, '.', ms
      else
         write(c, '(I0,A,I2.2,A,I2.2,A,I3.3,A)') hr, ':', minute, ':', sec, '.', ms, ap
      endif
   case (TF_HR_MIN_S)
      if (h24) then
         write(c, '(I2.2,A,I2.2,A,I2.2)') hr, ':', minute, ':', sec
      else
         write(c, '(I0,A,I2.2,A,I2.2,A)') hr, ':', minute, ':', sec, ap
      endif
   case (TF_HR_MIN)
      if (h24) then
         write(c, '(I2.2,A,I2.2)') hr, ':', minute
      else
         write(c, '(I0,A,I2.2,A)') hr, ':', minute, ap
      endif
   case (TF_HR)
      if (h24) then
         write(c, '(I2.2,A)') hr, ':00'
      else
         write(c, '(I0,A)') hr, ap
      endif
   case default
   endselect
   if (fmt(1) /= DF_NONE .and. fmt(2) /= TF_NONE) then
      s = trim(d)//' '//trim(c)
   elseif (fmt(1) /= DF_NONE) then
      s = d
   else
      s = c
   endif
   endfunction date_time_label

   ! numerics shared with the linear locator

   pure function nice_num(x, round) result(nice)
   !< `NiceNum`: a nice number (1, 2, 5 or 10 times a power of ten) near x, rounded or not below it.
   real(real64), intent(in) :: x     !< Value (> 0).
   logical,      intent(in) :: round !< Round (else the nice number at least x).
   real(real64)             :: nice  !< Nice number.
   real(real64)             :: f, nf !< Fraction, nice fraction.
   integer(int32)           :: e     !< Exponent.

   e = int(c_floor(c_log10(x)), int32)
   f = x / pow10(e)
   if (round) then
      if (f < 1.5_real64) then
         nf = 1.0_real64
      elseif (f < 3.0_real64) then
         nf = 2.0_real64
      elseif (f < 7.0_real64) then
         nf = 5.0_real64
      else
         nf = 10.0_real64
      endif
   elseif (f <= 1.0_real64) then
      nf = 1.0_real64
   elseif (f <= 2.0_real64) then
      nf = 2.0_real64
   elseif (f <= 5.0_real64) then
      nf = 5.0_real64
   else
      nf = 10.0_real64
   endif
   nice = nf * pow10(e)
   endfunction nice_num

   pure function pow10(e) result(p)
   !< 10**e as ImPlot's `ImPow(10, e)`: C's `pow`.
   integer(int32), intent(in) :: e !< Exponent.
   real(real64)               :: p !< Power.

   p = c_pow(10.0_real64, real(e, real64))
   endfunction pow10

   pure function c_floor(x) result(f)
   !< C's `floor` of a real, as a real (no integer overflow).
   real(real64), intent(in) :: x !< Value.
   real(real64)             :: f !< Floor.

   f = aint(x)
   if (f > x) f = f - 1.0_real64
   endfunction c_floor

   pure function c_ceil(x) result(f)
   !< C's `ceil` of a real, as a real.
   real(real64), intent(in) :: x !< Value.
   real(real64)             :: f !< Ceiling.

   f = aint(x)
   if (f < x) f = f + 1.0_real64
   endfunction c_ceil
endmodule figure_plot_locators
