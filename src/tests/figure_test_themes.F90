!< figure_test_themes, styles: the built-in themes unchanged (golden values), their contrast, looks and palettes.
program figure_test_themes
!< figure_test_themes, styles: the built-in themes unchanged (golden values), their contrast, looks and palettes.
!<
!< Looks and palettes: every bundled palette derives the colours its roles specify and keeps the contrast rule (text
!< on every surface it is drawn on, lines on the plot background); a look changes the geometry and keeps the colours,
!< a palette the colours and keeps the geometry; a look and palette pair saved and loaded back is the same style; a
!< palette with poor contrast or an unknown name is refused, with its message, and changes nothing; `palette='auto'`
!< follows a synthetic change of the system's light or dark setting; `app%palette_color` reads the roles in effect.
!<
!< Golden: every colour of Dear ImGui and ImPlot, every style variable of both, the line colours and the window's
!< background of the seven built-in themes, compared bit for bit with the values recorded before themes were split into
!< looks and palettes (`figure_test_themes_golden.inc`; `FIGURE_GOLDEN_RECORD=<file>` writes them again).
!<
!< Contrast: each theme is applied headless and its colours read back as Dear ImGui and ImPlot hold them (what a theme
!< file does not set comes from its base). Checked against the theme's promise:
!<
!< - text: `Text` against every surface it is drawn on (window, popup, frames, buttons, title bar, header), each
!<   composited over the window background: 4.5:1 (AA) for seal and seal-light, 7:1 (AAA) for paper and high-contrast;
!< - lines: every colour of the theme's own line set against the plot background: 3:1 (WCAG 1.4.11, graphics).
!<
!< Dear ImGui's own styles (dark, light, classic) are measured and reported, not held to a target.
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_f_pointer, c_int, c_null_char, c_ptr
use, intrinsic :: iso_fortran_env, only : error_unit, int32, output_unit, real32, real64
use figure, only : app_object, FIG_ERR_ARGUMENT, figure_last_error, ig_get_style_color, ig_get_style_var, &
                   ig_set_style_color, ig_set_style_var, ip_get_style_color, ip_get_style_var, ip_set_style_var
use figure_testing, only : test_system_theme
use figure_cimgui, only : im_vec4, igGetStyleColorName
use figure_cimgui_enums, only : ImGuiCol_COUNT
use figure_cimplot, only : ImPlot_GetColormapColor, ImPlot_GetColormapSize, ImPlot_GetStyleColorName
use figure_cimplot_enums, only : ImPlotCol_COUNT

implicit none
include 'figure_test_themes_golden.inc'
integer(int32),   parameter :: NT = 7_int32                        !< Themes.
character(len=13), parameter :: THEMES(NT) = [character(len=13) :: 'seal', 'seal-light', 'paper', 'high-contrast', &
                                              'dark', 'light', 'classic']
real(real64),     parameter :: TEXT_TARGET(NT) = [4.5_real64, 4.5_real64, 7.0_real64, 7.0_real64, 0.0_real64, &
                                                  0.0_real64, 0.0_real64] !< Minimum text contrast (0: report only).
real(real64),     parameter :: LINE_TARGET = 3.0_real64            !< Minimum line contrast, own themes.
integer(int32),   parameter :: NS = 8_int32                        !< Surfaces under text.
character(len=14), parameter :: SURFACES(NS) = [character(len=14) :: 'WindowBg', 'PopupBg', 'FrameBg', &
                                                'FrameBgHovered', 'Button', 'ButtonHovered', 'TitleBgActive', 'Header']
integer(int32),   parameter :: MAX_LINES = 16_int32                !< Line colours kept in a fingerprint.
integer(int32),   parameter :: NP = 14_int32                       !< Bundled palettes.
character(len=16), parameter :: PALETTES(NP) = [character(len=16) :: 'seal', 'seal-light', 'paper', 'high-contrast', &
   'nord', 'solarized-dark', 'solarized-light', 'gruvbox-dark', 'gruvbox-light', 'dracula', 'catppuccin-mocha', &
   'catppuccin-latte', 'tokyo-night', 'one-dark'] !< Every bundled palette.
logical,          parameter :: DERIVED(NP) = [.false., .false., .false., .false., .true., .true., .true., .true., &
                                              .true., .true., .true., .true., .true., .true.] !< Colours derived
                                                                   !< from the roles (FIGURE's own four give theirs).
integer(int32),   parameter :: NL = 4_int32                        !< Bundled looks.
character(len=8), parameter :: LOOKS(NL) = [character(len=8) :: 'seal', 'fusion', 'adwaita', 'fluent'] !< Looks.
real(real64),     parameter :: LOOK_ROUNDING(NL) = [0.0_real64, 2.0_real64, 6.0_real64, 4.0_real64] !< FrameRounding.
integer(int32),   parameter :: NX = 16_int32                       !< Surfaces under text, palettes.
character(len=14), parameter :: SURFACES_X(NX) = [character(len=14) :: 'WindowBg', 'PopupBg', 'FrameBg', &
   'FrameBgHovered', 'FrameBgActive', 'Button', 'ButtonHovered', 'ButtonActive', 'Header', 'HeaderHovered', &
   'HeaderActive', 'TitleBgActive', 'MenuBarBg', 'Tab', 'TabHovered', 'TabSelected'] !< Every fill text is drawn on.
integer(int32),   parameter :: NR = 12_int32                       !< Palette roles.
character(len=14), parameter :: ROLES(NR) = [character(len=14) :: 'background', 'surface', 'raised_surface', &
   'border', 'text', 'dimmed_text', 'accent', 'text_on_accent', 'selection', 'success', 'warning', 'error'] !< Roles.
character(len=*), parameter :: SAVED = 'figure_test_themes.tmp.toml' !< Scratch theme file.
character(len=32), parameter :: IMGUI_VARS(72) = [character(len=32) :: &
   'Alpha', 'DisabledAlpha', 'WindowPadding', 'WindowRounding', 'WindowBorderSize', 'WindowBorderHoverPadding', &
   'WindowMinSize', 'WindowTitleAlign', 'WindowMenuButtonPosition', 'ChildRounding', 'ChildBorderSize', &
   'PopupRounding', 'PopupBorderSize', 'FramePadding', 'FrameRounding', 'FrameBorderSize', 'ItemSpacing', &
   'ItemInnerSpacing', 'CellPadding', 'TouchExtraPadding', 'IndentSpacing', 'ColumnsMinSpacing', 'ScrollbarSize', &
   'ScrollbarRounding', 'ScrollbarPadding', 'GrabMinSize', 'GrabRounding', 'LogSliderDeadzone', 'ImageRounding', &
   'ImageBorderSize', 'TabRounding', 'TabBorderSize', 'TabMinWidthBase', 'TabMinWidthShrink', &
   'TabCloseButtonMinWidthSelected', 'TabCloseButtonMinWidthUnselected', 'TabBarBorderSize', 'TabBarOverlineSize', &
   'TableAngledHeadersAngle', 'TableAngledHeadersTextAlign', 'TreeLinesFlags', 'TreeLinesSize', &
   'TreeLinesRounding', 'MenuItemRounding', 'SelectableRounding', 'DragDropTargetRounding', &
   'DragDropTargetBorderSize', 'DragDropTargetPadding', 'ColorMarkerSize', 'ColorButtonPosition', &
   'ButtonTextAlign', 'SelectableTextAlign', 'InputTextCursorSize', 'SeparatorSize', 'SeparatorTextBorderSize', &
   'SeparatorTextAlign', 'SeparatorTextPadding', 'DisplayWindowPadding', 'DisplaySafeAreaPadding', &
   'DockingNodeHasCloseButton', 'DockingSeparatorSize', 'MouseCursorScale', 'AntiAliasedLines', &
   'AntiAliasedLineEnds', 'AntiAliasedFill', 'CurveTessellationMaxError', 'CircleTessellationMaxError', &
   'HoverStationaryDelay', 'HoverDelayShort', 'HoverDelayNormal', 'HoverFlagsForTooltipMouse', &
   'HoverFlagsForTooltipNav'] !< Every field of ImGuiStyle bound by name.
character(len=18), parameter :: IMPLOT_VARS(21) = [character(len=18) :: &
   'PlotDefaultSize', 'PlotMinSize', 'PlotBorderSize', 'MinorAlpha', 'MajorTickLen', 'MinorTickLen', &
   'MajorTickSize', 'MinorTickSize', 'MajorGridSize', 'MinorGridSize', 'PlotPadding', 'LabelPadding', &
   'LegendPadding', 'LegendInnerPadding', 'LegendSpacing', 'MousePosPadding', 'AnnotationPadding', 'FitPadding', &
   'DigitalPadding', 'DigitalSpacing', 'UseLocalTime'] !< Every field of ImPlotStyle bound by name.
integer(int32),   parameter :: FP_N = 4_int32 * (ImGuiCol_COUNT + ImPlotCol_COUNT) + 2_int32 * (size(IMGUI_VARS) + &
                                  size(IMPLOT_VARS)) + 1_int32 + 4_int32 * MAX_LINES + 3_int32 !< Fingerprint size.
type(app_object)            :: app                                 !< Application.
integer(int32), allocatable :: record(:,:)                         !< Fingerprints being recorded.
character(len=4096)         :: record_file                         !< Where to record the golden values.
logical                     :: recording                           !< Recording instead of checking.
logical                     :: golden_passed(NT)                   !< Per-theme outcome, golden.
logical                     :: contrast_passed(NT)                 !< Per-theme outcome, contrast.
logical                     :: palette_passed(NP)                  !< Per-palette outcome.
logical                     :: look_passed(NL)                     !< Per-look outcome.
logical                     :: other_passed(4)                     !< Round trips, refusals, auto, roles.
integer(int32)              :: t                                   !< Theme.
integer(int32)              :: stat                                !< Status.

call get_environment_variable('FIGURE_GOLDEN_RECORD', record_file, status=stat)
recording = stat == 0_int32 .and. len_trim(record_file) > 0
call app%init_headless(800_int32, 600_int32)

! golden: the seven themes as they were
allocate(record(FP_N, NT))
golden_passed = .true.
do t = 1_int32, NT
   call app%set_style(trim(THEMES(t)), stat=stat)
   if (stat /= 0_int32) error stop 'figure_test_themes: a built-in theme does not apply'
   record(:, t) = fingerprint()
   if (.not. recording) golden_passed(t) = same_as_golden(t, record(:, t))
enddo
if (recording) then
   call write_golden(trim(record_file), record)
   write(output_unit, '(A)') 'figure_test_themes: golden values recorded in '//trim(record_file)
   call app%destroy()
   stop
endif

! contrast of the seven themes
do t = 1_int32, NT
   contrast_passed(t) = theme_contrast(t)
enddo
! palettes, looks, round trips, refusals, auto, roles
do t = 1_int32, NP
   palette_passed(t) = palette_check(t)
enddo
do t = 1_int32, NL
   look_passed(t) = look_check(t)
enddo
other_passed(1) = round_trip_check()
other_passed(2) = refusal_check()
other_passed(3) = auto_check()
other_passed(4) = roles_check()
call app%destroy()

write(output_unit, '(A,7L2)') 'figure_test_themes golden:  ', golden_passed
write(output_unit, '(A,7L2)') 'figure_test_themes contrast:', contrast_passed
write(output_unit, '(A,14L2)') 'figure_test_themes palettes:', palette_passed
write(output_unit, '(A,4L2)') 'figure_test_themes looks:   ', look_passed
write(output_unit, '(A,4L2)') 'figure_test_themes save/load, refusals, auto, roles:', other_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(golden_passed) .and. all(contrast_passed) .and. &
                             all(palette_passed) .and. all(look_passed) .and. all(other_passed)
if (.not. (all(golden_passed) .and. all(contrast_passed) .and. all(palette_passed) .and. all(look_passed) .and. &
           all(other_passed))) then
   write(error_unit, '(A)') 'figure_test_themes: a check failed (see above)'
   error stop 1
endif

contains
   function fingerprint() result(fp)
   !< Every colour, variable, line colour and the background of the style in effect, as the bits of 32-bit reals.
   integer(int32)    :: fp(FP_N)  !< Fingerprint.
   real(real64)      :: rgba(4)   !< A colour.
   real(real64)      :: v(2)      !< A variable.
   type(im_vec4)     :: c         !< A line colour.
   integer(int32)    :: n         !< Values of a variable.
   integer(int32)    :: i         !< Counter.
   integer(int32)    :: k         !< Position in fp.

   fp = 0_int32
   k = 0_int32
   do i = 0_int32, ImGuiCol_COUNT - 1_int32
      call ig_get_style_color(c_string(igGetStyleColorName(int(i, c_int))), rgba)
      fp(k + 1:k + 4) = bits(rgba)
      k = k + 4_int32
   enddo
   do i = 0_int32, ImPlotCol_COUNT - 1_int32
      call ip_get_style_color(c_string(ImPlot_GetStyleColorName(int(i, c_int))), rgba)
      fp(k + 1:k + 4) = bits(rgba)
      k = k + 4_int32
   enddo
   do i = 1_int32, size(IMGUI_VARS, kind=int32)
      v = 0.0_real64
      call ig_get_style_var(trim(IMGUI_VARS(i)), v, n)
      fp(k + 1:k + 2) = bits(v)
      k = k + 2_int32
   enddo
   do i = 1_int32, size(IMPLOT_VARS, kind=int32)
      v = 0.0_real64
      call ip_get_style_var(trim(IMPLOT_VARS(i)), v, n)
      fp(k + 1:k + 2) = bits(v)
      k = k + 2_int32
   enddo
   n = min(int(ImPlot_GetColormapSize(-1_c_int), int32), MAX_LINES)
   fp(k + 1) = n
   k = k + 1_int32
   do i = 0_int32, n - 1_int32
      call ImPlot_GetColormapColor(int(i, c_int), -1_c_int, c)
      fp(k + 4 * i + 1:k + 4 * i + 4) = bits([real(c%x, real64), real(c%y, real64), real(c%z, real64), &
                                              real(c%w, real64)])
   enddo
   k = k + 4_int32 * MAX_LINES
   fp(k + 1:k + 3) = saved_background()
   endfunction fingerprint

   pure function bits(x) result(b)
   !< The bits of each value as a 32-bit real (the native layer holds floats: the conversion is exact).
   real(real64), intent(in) :: x(:)         !< Values.
   integer(int32)           :: b(size(x))   !< Their bits.
   integer(int32)           :: i            !< Counter.

   do i = 1_int32, size(x, kind=int32)
      b(i) = transfer(real(x(i), real32), 0_int32)
   enddo
   endfunction bits

   function saved_background() result(rgb)
   !< The window's background as `app%save_style` writes it (`background = "#rrggbb"`), as three bytes.
   integer(int32)      :: rgb(3) !< Red, green, blue in 0..255.
   character(len=1024) :: line   !< A line of the file.
   integer(int32)      :: u      !< Unit.
   integer(int32)      :: ios    !< I/O status.
   integer(int32)      :: p      !< Position of '#'.

   rgb = -1_int32
   call app%save_style(SAVED)
   open(newunit=u, file=SAVED, status='old', action='read')
   do
      read(u, '(A)', iostat=ios) line
      if (ios /= 0_int32) exit
      if (index(line, 'background = "#') == 1) then
         p = index(line, '#')
         read(line(p + 1:p + 6), '(3Z2)') rgb
         exit
      endif
   enddo
   close(u, status='delete')
   endfunction saved_background

   function c_string(p) result(s)
   !< A NUL-terminated C string as a Fortran string.
   type(c_ptr), intent(in)                     :: p    !< C string.
   character(len=:), allocatable               :: s    !< Its text.
   character(kind=c_char), pointer             :: a(:) !< Its characters.
   integer(int32)                              :: n    !< Length.
   integer(int32)                              :: i    !< Counter.

   s = ''
   if (.not. c_associated(p)) return
   call c_f_pointer(p, a, [256])
   n = 0_int32
   do while (n < 256_int32)
      if (a(n + 1) == c_null_char) exit
      n = n + 1_int32
   enddo
   s = repeat(' ', n)
   do i = 1_int32, n
      s(i:i) = a(i)
   enddo
   endfunction c_string

   function same_as_golden(t, fp) result(same)
   !< The fingerprint of theme `t` equals its golden values (within 4 ulps); the differences are reported.
   integer(int32), intent(in) :: t         !< Theme.
   integer(int32), intent(in) :: fp(:)     !< Fingerprint.
   logical                    :: same      !< Equal.
   integer(int32)             :: i         !< Counter.
   integer(int32)             :: reported  !< Differences reported.
   real(real32)               :: a, b      !< A value and its golden one.

   same = GOLDEN_RECORDED .and. size(fp) == GOLDEN_N
   if (.not. same) then
      write(error_unit, '(A)') 'figure_test_themes: no golden values for this build (record them first)'
      return
   endif
   reported = 0_int32
   do i = 1_int32, GOLDEN_N
      if (fp(i) == GOLDEN(i, t)) cycle
      ! a few ulps apart is the same value: compilers round Dear ImGui's own colour arithmetic differently (Apple
      ! clang and g++ differ by 1 ulp on some of the dark and light colours)
      a = transfer(fp(i), 1.0_real32)
      b = transfer(GOLDEN(i, t), 1.0_real32)
      if (abs(a - b) <= 4.0_real32 * spacing(max(abs(a), abs(b)))) cycle
      same = .false.
      reported = reported + 1_int32
      if (reported <= 5_int32) write(error_unit, '(A,A,A,I0,A,Z8.8,A,Z8.8)') 'figure_test_themes: ', &
         trim(THEMES(t)), ' differs at value ', i, ': ', fp(i), ' instead of ', GOLDEN(i, t)
   enddo
   endfunction same_as_golden

   subroutine write_golden(file, fps)
   !< Write the golden values (`figure_test_themes_golden.inc`).
   character(len=*), intent(in) :: file      !< File.
   integer(int32),   intent(in) :: fps(:,:)  !< One fingerprint per theme.
   integer(int32)               :: u         !< Unit.
   integer(int32)               :: t         !< Theme.
   integer(int32)               :: i         !< Counter.
   character(len=16)            :: item      !< A value.
   character(len=128)           :: line      !< A line being filled.

   open(newunit=u, file=file, status='replace', action='write')
   write(u, '(A)') '! golden values of the seven built-in themes, written by figure_test_themes (FIGURE_GOLDEN_RECORD)'
   write(u, '(A)') '! from the themes as they were before looks and palettes: the bits of every colour and variable'
   write(u, '(A,I0,A)') 'integer(int32), parameter :: GOLDEN_N = ', size(fps, 1), '_int32 !< Values per theme.'
   do t = 1_int32, size(fps, 2, kind=int32)
      write(u, '(A,I0,A)') 'integer(int32), parameter :: GOLDEN_', t, '(GOLDEN_N) = [ &'
      line = ''
      do i = 1_int32, size(fps, 1, kind=int32)
         write(item, '(I0)') fps(i, t)
         if (i < size(fps, 1, kind=int32)) item = trim(item)//','
         if (len_trim(line) + len_trim(item) + 1 > 110) then
            write(u, '(A)') '   '//trim(line)//' &'
            line = ''
         endif
         line = trim(line)//' '//trim(item)
      enddo
      write(u, '(A)') '   '//trim(line)//'] !< '//trim(THEMES(t))//'.'
   enddo
   write(u, '(A)') 'integer(int32), parameter :: GOLDEN(GOLDEN_N, 7) = reshape([GOLDEN_1, GOLDEN_2, GOLDEN_3, &'
   write(u, '(A)') '   GOLDEN_4, GOLDEN_5, GOLDEN_6, GOLDEN_7], [GOLDEN_N, 7_int32]) !< One column per theme.'
   write(u, '(A)') 'logical,        parameter :: GOLDEN_RECORDED = .true. !< The values are recorded.'
   close(u)
   endsubroutine write_golden

   function palette_check(p) result(passed)
   !< Palette `p`: applied alone, its roles kept by the rule, the colours its roles specify, text readable on every
   !< fill, lines on the plot background at 3:1, the geometry in effect kept.
   integer(int32), intent(in) :: p          !< Palette.
   logical                    :: passed     !< Outcome.
   real(real64)               :: role(4, NR) !< Roles in effect.
   real(real64)               :: c(4)       !< A colour.
   real(real64)               :: hov(4)     !< A hovered colour.
   real(real64)               :: v(2)       !< A variable.
   real(real64)               :: text_min   !< Lowest text contrast on a fill.
   real(real64)               :: line_min   !< Lowest line contrast.
   real(real64)               :: plot_bg(4) !< Plot background.
   type(im_vec4)              :: lc         !< A line colour.
   integer(int32)             :: k          !< Counter.
   integer(int32)             :: n          !< Values of a variable.
   integer(int32)             :: stat       !< Status.
   character(len=14)          :: worst      !< Where the text contrast is lowest.

   passed = .false.
   call app%set_style(look='fusion', stat=stat)
   call ip_set_style_var('MinorAlpha', 0.5_real64)
   call app%set_style(palette=trim(PALETTES(p)), stat=stat)
   if (stat /= 0_int32) then
      write(error_unit, '(A)') 'figure_test_themes: palette '//trim(PALETTES(p))//' refused: '//figure_last_error()
      return
   endif
   call ig_get_style_var('FrameRounding', v, n)
   if (v(1) /= 2.0_real64) return ! the look in effect is kept
   call ip_get_style_var('MinorAlpha', v, n)
   if (v(1) /= 0.5_real64) return ! so are the variables changed by name
   do k = 1_int32, NR
      call app%palette_color(trim(ROLES(k)), role(:, k))
   enddo
   ! the rule, recomputed here
   if (contrast(role(:, 5), role(:, 1)) < 4.5_real64 .or. contrast(role(:, 5), role(:, 2)) < 4.5_real64 .or.   &
       contrast(role(:, 5), role(:, 3)) < 4.5_real64 .or. contrast(role(:, 5), role(:, 9)) < 4.5_real64 .or.   &
       contrast(role(:, 6), role(:, 1)) < 3.0_real64 .or. contrast(role(:, 8), role(:, 7)) < 4.5_real64) return
   ! the specified colours: the fills, text and borders are the roles
   if (.not. (same_color('Text', role(:, 5)) .and. same_color('TextDisabled', role(:, 6)) .and.            &
              same_color('WindowBg', role(:, 1)) .and. same_color('FrameBg', role(:, 2)) .and.             &
              same_color('Button', role(:, 3)) .and. same_color('Border', role(:, 4)) .and.                &
              same_color('Header', role(:, 9)))) then
      write(error_unit, '(A)') 'figure_test_themes: palette '//trim(PALETTES(p))//' does not give its roles'
      return
   endif
   if (DERIVED(p)) then
      if (.not. (same_color('CheckMark', role(:, 7)) .and. same_color('SliderGrab', role(:, 7)) .and.     &
                 same_color('TextSelectedBg', role(:, 9)) .and. same_color('TitleBgActive', role(:, 2)))) return
      call ig_get_style_color('ButtonHovered', hov)
      if (all(hov == role(:, 3))) return ! hovered differs from the fill
   endif
   text_min = huge(1.0_real64)
   worst = ''
   do k = 1_int32, NX
      call ig_get_style_color(trim(SURFACES_X(k)), c)
      c = over(c, role(:, 1))
      if (contrast(role(:, 5), c) < text_min) then
         text_min = contrast(role(:, 5), c)
         worst = SURFACES_X(k)
      endif
   enddo
   call ip_get_style_color('PlotBg', plot_bg)
   plot_bg = over(plot_bg, role(:, 1))
   line_min = huge(1.0_real64)
   do k = 0_int32, ImPlot_GetColormapSize(-1_c_int) - 1_int32
      call ImPlot_GetColormapColor(int(k, c_int), -1_c_int, lc)
      line_min = min(line_min, contrast([real(lc%x, real64), real(lc%y, real64), real(lc%z, real64), 1.0_real64], &
                                        plot_bg))
   enddo
   passed = text_min >= 4.5_real64 .and. line_min >= 3.0_real64
   write(output_unit, '(A16,A,F6.2,A,A14,A,F5.2,A,L1)') PALETTES(p), ' text ', text_min, ':1 (lowest on ', &
                                                          adjustl(worst), ') lines ', line_min, ':1  ', passed
   endfunction palette_check

   function look_check(l) result(passed)
   !< Look `l`: its geometry applied, the colours in effect (a palette) kept; a palette after it keeps the geometry.
   integer(int32), intent(in) :: l          !< Look.
   logical                    :: passed     !< Outcome.
   integer(int32)             :: before(FP_N) !< Fingerprint before.
   integer(int32)             :: after(FP_N)  !< Fingerprint after.
   real(real64)               :: v(2)       !< A variable.
   integer(int32)             :: n          !< Values of a variable.
   integer(int32)             :: nc         !< Colour values in a fingerprint.
   integer(int32)             :: stat       !< Status.

   nc = 4_int32 * (ImGuiCol_COUNT + ImPlotCol_COUNT)
   call app%set_style('dark')
   call app%set_style(palette='nord')
   before = fingerprint()
   call app%set_style(look=trim(LOOKS(l)), stat=stat)
   after = fingerprint()
   call ig_get_style_var('FrameRounding', v, n)
   passed = stat == 0_int32 .and. v(1) == LOOK_ROUNDING(l) .and. all(before(1:nc) == after(1:nc))
   call app%set_style(palette='dracula')
   call ig_get_style_var('FrameRounding', v, n)
   passed = passed .and. v(1) == LOOK_ROUNDING(l)
   write(output_unit, '(A,A8,A,F4.1,A,L1)') 'look ', LOOKS(l), ' FrameRounding ', v(1), '  ', passed
   endfunction look_check

   function round_trip_check() result(passed)
   !< A look and palette pair, with a colour and a variable changed by name, saved and loaded back: the same style;
   !< the same for a palette given as a [palette] table and for 'auto'.
   logical                     :: passed     !< Outcome.
   integer(int32)              :: before(FP_N) !< Fingerprint saved.
   character(len=1024)         :: line       !< A line of the file.
   logical                     :: has_look   !< The file names the look.
   logical                     :: has_pal    !< The file names the palette.
   integer(int32)              :: u          !< Unit.
   integer(int32)              :: ios        !< I/O status.
   integer(int32)              :: stat       !< Status.
   character(len=*), parameter :: FILE = 'figure_test_themes.pair.toml' !< Round-trip file.

   passed = .true.
   call app%set_style(look='fluent', palette='nord')
   call ig_set_style_color('Button', '#5e81ac')
   call ig_set_style_var('FrameRounding', 7.0_real64)
   before = fingerprint()
   call app%save_style(FILE)
   has_look = .false.
   has_pal = .false.
   open(newunit=u, file=FILE, status='old', action='read')
   do
      read(u, '(A)', iostat=ios) line
      if (ios /= 0_int32) exit
      if (trim(line) == 'look = "fluent"') has_look = .true.
      if (trim(line) == 'palette = "nord"') has_pal = .true.
   enddo
   close(u)
   call app%set_style('classic')
   call app%load_style(FILE, stat=stat)
   passed = passed .and. has_look .and. has_pal .and. stat == 0_int32 .and. all(fingerprint() == before)
   if (.not. passed) write(error_unit, '(A,3L2)') 'figure_test_themes: look+palette round trip', has_look, has_pal, &
                                                  stat == 0_int32
   ! a [palette] table (a custom palette), written out in full and read back
   open(newunit=u, file=FILE, status='replace', action='write')
   write(u, '(A)') 'look = "adwaita"'
   write(u, '(A)') 'palette = "gruvbox-dark"'
   write(u, '(A)') '[palette]'
   write(u, '(A)') 'accent = "#83a598"'
   close(u)
   call app%load_style(FILE, stat=stat)
   passed = passed .and. stat == 0_int32 .and. same_color('CheckMark', hex('#83a598'))
   before = fingerprint()
   call app%save_style(FILE)
   call app%set_style('seal')
   call app%load_style(FILE, stat=stat)
   passed = passed .and. stat == 0_int32 .and. all(fingerprint() == before)
   ! auto, saved as auto
   call app%set_style(palette='auto', auto_dark='tokyo-night', auto_light='catppuccin-latte')
   before = fingerprint()
   call app%save_style(FILE)
   call app%set_style('seal')
   call app%load_style(FILE, stat=stat)
   passed = passed .and. stat == 0_int32 .and. all(fingerprint() == before)
   open(newunit=u, file=FILE, status='old')
   close(u, status='delete')
   endfunction round_trip_check

   function refusal_check() result(passed)
   !< A palette below the contrast rule, an unknown palette or look, and no argument are refused with their message;
   !< the style in effect is unchanged.
   logical                     :: passed     !< Outcome.
   integer(int32)              :: before(FP_N) !< Fingerprint before.
   integer(int32)              :: u          !< Unit.
   integer(int32)              :: stat       !< Status.
   character(len=*), parameter :: FILE = 'figure_test_themes.poor.toml' !< A palette with poor contrast.

   call app%set_style('seal')
   before = fingerprint()
   open(newunit=u, file=FILE, status='replace', action='write')
   write(u, '(A)') 'palette = "nord"'
   write(u, '(A)') '[palette]'
   write(u, '(A)') 'text = "#4c566a"'
   close(u)
   call app%load_style(FILE, stat=stat)
   passed = stat == FIG_ERR_ARGUMENT .and. index(figure_last_error(), 'text on background is 1.') > 0
   if (.not. passed) write(error_unit, '(A)') 'figure_test_themes: poor contrast: '//figure_last_error()
   open(newunit=u, file=FILE, status='old')
   close(u, status='delete')
   call app%set_style(palette='nowhere', stat=stat)
   passed = passed .and. stat == FIG_ERR_ARGUMENT .and. index(figure_last_error(), 'unknown palette "nowhere"') > 0
   call app%set_style(look='nowhere', palette='nord', stat=stat) ! all or none: the palette is not applied either
   passed = passed .and. stat == FIG_ERR_ARGUMENT .and. index(figure_last_error(), 'unknown look "nowhere"') > 0
   call app%set_style(stat=stat)
   passed = passed .and. stat == FIG_ERR_ARGUMENT
   passed = passed .and. all(fingerprint() == before)
   endfunction refusal_check

   function auto_check() result(passed)
   !< palette='auto' follows synthetic changes of the system's setting (headless: unknown, so dark, at first); the
   !< look is kept.
   logical        :: passed !< Outcome.
   real(real64)   :: v(2)   !< A variable.
   integer(int32) :: n      !< Values of a variable.
   integer(int32) :: stat   !< Status.

   call app%set_style(look='adwaita', palette='auto', auto_dark='nord', auto_light='solarized-light', stat=stat)
   passed = stat == 0_int32 .and. same_color('WindowBg', hex('#2e3440'))
   call test_system_theme('light')
   call frames(2_int32)
   passed = passed .and. same_color('WindowBg', hex('#fdf6e3'))
   call test_system_theme('dark')
   call frames(2_int32)
   passed = passed .and. same_color('WindowBg', hex('#2e3440'))
   call test_system_theme('light')
   call frames(1_int32)
   call test_system_theme('system') ! unknown in headless mode: dark
   call frames(1_int32)
   passed = passed .and. same_color('WindowBg', hex('#2e3440'))
   call ig_get_style_var('FrameRounding', v, n)
   passed = passed .and. v(1) == 6.0_real64
   call app%set_style(palette='nord') ! no longer auto: a change of the system's setting changes nothing
   call test_system_theme('light')
   call frames(2_int32)
   passed = passed .and. same_color('WindowBg', hex('#2e3440'))
   call test_system_theme('system')
   call test_system_theme('dusk', stat=stat)
   passed = passed .and. stat == FIG_ERR_ARGUMENT
   if (.not. passed) write(error_unit, '(A)') 'figure_test_themes: palette auto does not follow the system'
   endfunction auto_check

   function roles_check() result(passed)
   !< app%palette_color: a palette's roles, the roles read from Dear ImGui's colours without a palette, an unknown role.
   logical        :: passed  !< Outcome.
   real(real64)   :: rgba(4) !< A role.
   real(real64)   :: text(4) !< Text colour.
   integer(int32) :: stat    !< Status.

   call app%set_style(palette='catppuccin-mocha')
   call app%palette_color('accent', rgba)
   passed = all(abs(rgba - hex('#cba6f7')) < 1.0e-6_real64)
   call app%set_style('dark')
   call app%palette_color('text', rgba)
   call ig_get_style_color('Text', text)
   passed = passed .and. all(rgba == text)
   call app%palette_color('glow', rgba, stat=stat)
   passed = passed .and. stat == FIG_ERR_ARGUMENT
   endfunction roles_check

   subroutine frames(n)
   !< Draw `n` empty frames.
   integer(int32), intent(in) :: n !< Frames.
   integer(int32)             :: k !< Counter.

   do k = 1_int32, n
      if (.not. app%next_frame()) exit
   enddo
   endsubroutine frames

   function same_color(name, rgba) result(same)
   !< The Dear ImGui colour `name` equals `rgba` (to the precision of a float).
   character(len=*), intent(in) :: name    !< Colour name.
   real(real64),     intent(in) :: rgba(4) !< Expected.
   logical                      :: same    !< Equal.
   real(real64)                 :: c(4)    !< In effect.

   call ig_get_style_color(name, c)
   same = all(abs(c - rgba) < 1.0e-6_real64)
   endfunction same_color

   pure function hex(h) result(rgba)
   !< `'#rrggbb'` as `[r, g, b, 1]`.
   character(len=7), intent(in) :: h       !< Hex colour.
   real(real64)                 :: rgba(4) !< Components.
   integer(int32)               :: b(3)    !< Bytes.

   read(h(2:7), '(3Z2)') b
   rgba = [real(b, real64) / 255.0_real64, 1.0_real64]
   endfunction hex

   function theme_contrast(t) result(passed)
   !< The contrast of theme `t` against its promise (text on every surface; lines on the plot background).
   integer(int32), intent(in) :: t           !< Theme.
   logical                    :: passed      !< Promise kept.
   type(im_vec4)              :: c           !< A line colour.
   real(real64)               :: text(4)     !< Text colour.
   real(real64)               :: window(4)   !< Window background.
   real(real64)               :: surface(4)  !< A surface.
   real(real64)               :: plot_bg(4)  !< Plot background.
   real(real64)               :: ratio       !< A contrast ratio.
   real(real64)               :: text_min    !< Lowest text contrast.
   real(real64)               :: line_min    !< Lowest line contrast.
   character(len=14)          :: text_worst  !< Where the text contrast is lowest.
   integer(int32)             :: k           !< Counter.
   integer(int32)             :: stat        !< Status.

   call app%set_style(trim(THEMES(t)), stat=stat)
   if (stat /= 0_int32) error stop 'figure_test_themes: a built-in theme does not apply'
   call ig_get_style_color('Text', text)
   call ig_get_style_color('WindowBg', window)
   window = over(window, [0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64]) ! a translucent window over black
   text_min = huge(1.0_real64)
   text_worst = ''
   do k = 1_int32, NS
      call ig_get_style_color(trim(SURFACES(k)), surface)
      ratio = contrast(over(text, over(surface, window)), over(surface, window))
      if (ratio < text_min) then
         text_min = ratio
         text_worst = SURFACES(k)
      endif
   enddo
   call ip_get_style_color('PlotBg', plot_bg)
   plot_bg = over(plot_bg, window)
   line_min = huge(1.0_real64)
   do k = 0_int32, ImPlot_GetColormapSize(-1_c_int) - 1_int32
      call ImPlot_GetColormapColor(int(k, c_int), -1_c_int, c)
      line_min = min(line_min, contrast(over([real(c%x, real64), real(c%y, real64), real(c%z, real64), &
                                               real(c%w, real64)], plot_bg), plot_bg))
   enddo
   passed = .true.
   if (TEXT_TARGET(t) > 0.0_real64) passed = text_min >= TEXT_TARGET(t) .and. line_min >= LINE_TARGET
   write(output_unit, '(A14,A,F6.2,A,A14,A,F5.2,A,L1)') THEMES(t), ' text ', text_min, ':1 (lowest on ', &
                                                         adjustl(text_worst), ') lines ', line_min, ':1  ', passed
   endfunction theme_contrast

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
