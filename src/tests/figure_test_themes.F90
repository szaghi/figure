!< figure_test_themes, the contrast of every built-in theme, measured on the colours in effect (WCAG 2).
program figure_test_themes
!< figure_test_themes, the contrast of every built-in theme, measured on the colours in effect (WCAG 2).
!<
!< Each theme is applied headless and its colours read back as Dear ImGui and ImPlot hold them (what a theme file does
!< not set comes from its base). Checked against the theme's promise:
!<
!< - text: `Text` against every surface it is drawn on (window, popup, frames, buttons, title bar, header), each
!<   composited over the window background: 4.5:1 (AA) for seal and seal-light, 7:1 (AAA) for paper and high-contrast;
!< - lines: every colour of the theme's own line set against the plot background: 3:1 (WCAG 1.4.11, graphics).
!<
!< Dear ImGui's own styles (dark, light, classic) are measured and reported, not held to a target.
use, intrinsic :: iso_c_binding, only : c_int
use, intrinsic :: iso_fortran_env, only : error_unit, int32, output_unit, real64
use figure, only : app_object, ig_get_style_color, ip_get_style_color
use figure_cimgui, only : im_vec4
use figure_cimplot, only : ImPlot_GetColormapColor, ImPlot_GetColormapSize

implicit none
integer(int32),   parameter :: NT = 7_int32                        !< Themes.
character(len=13), parameter :: THEMES(NT) = [character(len=13) :: 'seal', 'seal-light', 'paper', 'high-contrast', &
                                              'dark', 'light', 'classic']
real(real64),     parameter :: TEXT_TARGET(NT) = [4.5_real64, 4.5_real64, 7.0_real64, 7.0_real64, 0.0_real64, &
                                                  0.0_real64, 0.0_real64] !< Minimum text contrast (0: report only).
real(real64),     parameter :: LINE_TARGET = 3.0_real64            !< Minimum line contrast, own themes.
integer(int32),   parameter :: NS = 8_int32                        !< Surfaces under text.
character(len=14), parameter :: SURFACES(NS) = [character(len=14) :: 'WindowBg', 'PopupBg', 'FrameBg', &
                                                'FrameBgHovered', 'Button', 'ButtonHovered', 'TitleBgActive', 'Header']
type(app_object)            :: app                                 !< Application.
type(im_vec4)               :: c                                   !< A line colour.
real(real64)                :: text(4)                             !< Text colour.
real(real64)                :: window(4)                           !< Window background.
real(real64)                :: surface(4)                          !< A surface.
real(real64)                :: plot_bg(4)                          !< Plot background.
real(real64)                :: ratio                               !< A contrast ratio.
real(real64)                :: text_min(NT)                        !< Lowest text contrast per theme.
real(real64)                :: line_min(NT)                        !< Lowest line contrast per theme.
character(len=14)           :: text_worst(NT)                      !< Where the text contrast is lowest.
logical                     :: test_passed(NT)                     !< Per-theme outcome.
integer(int32)              :: t                                   !< Theme.
integer(int32)              :: k                                   !< Counter.
integer(int32)              :: stat                                !< Status.

call app%init_headless(800_int32, 600_int32)
do t = 1_int32, NT
   call app%set_style(trim(THEMES(t)), stat=stat)
   if (stat /= 0_int32) error stop 'figure_test_themes: a built-in theme does not apply'
   call ig_get_style_color('Text', text)
   call ig_get_style_color('WindowBg', window)
   window = over(window, [0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64]) ! a translucent window over black
   text_min(t) = huge(1.0_real64)
   do k = 1_int32, NS
      call ig_get_style_color(trim(SURFACES(k)), surface)
      ratio = contrast(over(text, over(surface, window)), over(surface, window))
      if (ratio < text_min(t)) then
         text_min(t) = ratio
         text_worst(t) = SURFACES(k)
      endif
   enddo
   call ip_get_style_color('PlotBg', plot_bg)
   plot_bg = over(plot_bg, window)
   line_min(t) = huge(1.0_real64)
   do k = 0_int32, ImPlot_GetColormapSize(-1_c_int) - 1_int32
      call ImPlot_GetColormapColor(int(k, c_int), -1_c_int, c)
      line_min(t) = min(line_min(t), contrast(over([real(c%x, real64), real(c%y, real64), real(c%z, real64), &
                                                     real(c%w, real64)], plot_bg), plot_bg))
   enddo
   if (TEXT_TARGET(t) > 0.0_real64) then
      test_passed(t) = text_min(t) >= TEXT_TARGET(t) .and. line_min(t) >= LINE_TARGET
   else
      test_passed(t) = .true.
   endif
   write(output_unit, '(A14,A,F6.2,A,A14,A,F5.2,A,L1)') THEMES(t), ' text ', text_min(t), ':1 (lowest on ', &
                                                         adjustl(text_worst(t)), ') lines ', line_min(t), ':1  ', &
                                                         test_passed(t)
enddo
call app%destroy()

write(output_unit, '(A,7L2)') 'figure_test_themes checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) then
   write(error_unit, '(A)') 'figure_test_themes: a theme misses its contrast target'
   error stop 1
endif

contains
   pure function over(fg, bg) result(c)
   !< `fg` (with its alpha) composited over the opaque `bg`.
   real(real64), intent(in) :: fg(4) !< Foreground, alpha in fg(4).
   real(real64), intent(in) :: bg(4) !< Background (opaque).
   real(real64)             :: c(4)  !< Result, opaque.

   c(1:3) = fg(4) * fg(1:3) + (1.0_real64 - fg(4)) * bg(1:3)
   c(4) = 1.0_real64
   endfunction over

   pure function luminance(c) result(l)
   !< WCAG 2 relative luminance of an sRGB colour.
   real(real64), intent(in) :: c(4) !< Colour.
   real(real64)             :: l    !< Luminance.
   real(real64)             :: v(3) !< Linear components.
   integer(int32)           :: i    !< Component.

   do i = 1_int32, 3_int32
      if (c(i) <= 0.04045_real64) then
         v(i) = c(i) / 12.92_real64
      else
         v(i) = ((c(i) + 0.055_real64) / 1.055_real64)**2.4_real64
      endif
   enddo
   l = 0.2126_real64 * v(1) + 0.7152_real64 * v(2) + 0.0722_real64 * v(3)
   endfunction luminance

   pure function contrast(a, b) result(r)
   !< WCAG 2 contrast ratio of two opaque colours.
   real(real64), intent(in) :: a(4) !< A colour.
   real(real64), intent(in) :: b(4) !< Another.
   real(real64)             :: r    !< Ratio, 1 to 21.

   r = (max(luminance(a), luminance(b)) + 0.05_real64) / (min(luminance(a), luminance(b)) + 0.05_real64)
   endfunction contrast
endprogram figure_test_themes
