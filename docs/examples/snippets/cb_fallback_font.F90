!< cb_fallback_font, cookbook: symbols in any text font (the bundled fallback, Noto Sans Math, and a program's own).
program cb_fallback_font
!< cb_fallback_font, cookbook: symbols in any text font (the bundled fallback, Noto Sans Math, and a program's own).
!<
!< A residual table in IBM Plex Mono with Greek letters, operators and superscripts (rho, nabla, infinity, the square):
!< Plex Mono has no Greek and no nabla, the bundled fallback gives them. A font of the program's own, added with
!< app%add_fallback_font, gives what neither has. `cb_fallback_font --check FILE` opens no window: it adds FILE as a
!< fallback and prints which font gives each symbol (figure_testing's test_glyph).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_pop_font, ig_push_font, ig_set_next_window, ig_text
use figure_testing, only : test_glyph

implicit none
type(app_object)              :: app     !< Application.
character(len=256)            :: arg     !< First argument.
character(len=256)            :: file    !< The program's fallback font.
logical                       :: check   !< --check: headless.
integer(int32)                :: frame   !< Frame counter.
character(len=*), parameter   :: RHO = char(207)//char(129)                 !< U+03C1 rho.
character(len=*), parameter   :: NABLA = char(226)//char(136)//char(135)    !< U+2207 nabla.
character(len=*), parameter   :: INF = char(226)//char(136)//char(158)      !< U+221E infinity.
character(len=*), parameter   :: SQUARE = char(194)//char(178)              !< U+00B2 superscript two.
character(len=*), parameter   :: ALPHA_TONOS = char(206)//char(172)         !< U+03AC alpha with tonos.

call get_command_argument(1, arg)
check = trim(arg) == '--check'
file = ''
if (check) call get_command_argument(2, file)
if (check) then
   call app%init_headless(520_int32, 200_int32)
else
   call app%init('FIGURE: symbols', 520_int32, 200_int32)
endif
if (file /= '') call app%add_fallback_font(trim(file)) ! after Plex, the icons and Noto Sans Math, in every text font
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 500.0_real64, 180.0_real64)
   if (ig_begin('Residuals')) then
      call ig_push_font('plex-mono')
      call ig_text('field    residual   reference')
      call ig_text(RHO//'        1.2e-06    '//RHO//INF)          ! Greek and the operators: Noto Sans Math
      call ig_text(NABLA//'p       3.4e-05    |'//NABLA//'p|'//SQUARE) ! the superscripts: Plex Mono's own
      call ig_pop_font()
      if (check .and. frame == 2_int32) call report()
   endif
   call ig_end()
   if (check .and. frame == 2_int32) exit
enddo
call app%destroy()

contains
   subroutine report()
   !< Which font gives each symbol, in plex-mono and plex-sans.
   character(len=*), parameter   :: NAMES(6) = ['A          ', 'rho        ', 'nabla      ', 'infinity   ', &
                                                'square     ', 'alpha tonos'] !< Their names.
   character(len=:), allocatable :: glyph   !< A symbol.
   character(len=:), allocatable :: mono    !< The font giving it in plex-mono.
   character(len=:), allocatable :: sans    !< ... in plex-sans.
   integer(int64)                :: pixels  !< Pixels of its bitmap.
   character(len=25)             :: cell    !< A column of the table.
   integer(int32)                :: k       !< Counter.

   write(output_unit, '(A)') 'symbol       plex-mono                plex-sans'
   do k = 1_int32, size(NAMES, kind=int32)
      select case (k)
      case (1_int32)
         glyph = 'A'
      case (2_int32)
         glyph = RHO
      case (3_int32)
         glyph = NABLA
      case (4_int32)
         glyph = INF
      case (5_int32)
         glyph = SQUARE
      case default
         glyph = ALPHA_TONOS
      endselect
      call test_glyph(glyph, 'plex-mono', mono, pixels) ! mono: the font giving it ('' none); pixels: its bitmap's
      call test_glyph(glyph, 'plex-sans', sans, pixels)
      cell = mono
      write(output_unit, '(A)') NAMES(k)//'  '//cell//sans
   enddo
   endsubroutine report
endprogram cb_fallback_font
