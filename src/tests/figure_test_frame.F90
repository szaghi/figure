!< figure_test_frame, the window's frame drawn by FIGURE (decorations='figure') and the window's icon, headless.
program figure_test_frame
!< figure_test_frame, the window's frame drawn by FIGURE (decorations='figure') and the window's icon, headless.
!<
!< The title bar drawn on top with the program's main menu bar inside it (the menu's rectangle within the bar's, a
!< click on the menu opening it); the hit test point by point: the empty bar and the title drag, each edge and corner
!< resizes, each button and a menu are the program's, below the bar too; the maximize, minimize and close buttons
!< recorded as state (maximized, minimized) and close as a quit request (confirm_quit on); a double-click on the bar
!< toggles maximize; a maximized window has no resize edges; the buttons on the left when asked; no bar without the
!< option; set_icon refused headless (an image and an ICON_*); an unknown option refused. The bar's height: the menu
!< bar's by default; a theme file's `[figure.vars] TitleBarHeight` makes it taller, the menu centred in it and the
!< bar's lower part dragging the window; saved and loaded back; a new look resets it; a wrong value refused.
use, intrinsic :: iso_fortran_env, only : int8, int32, real64, output_unit
use figure, only : app_object, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, ICON_CHART_LINE, ig_begin, &
                   ig_begin_main_menu_bar, ig_begin_menu, ig_end, ig_end_main_menu_bar, ig_end_menu, &
                   ig_get_style_var, ig_item_rect, ig_menu_item, ig_set_next_window, ig_text, ig_text_size
use figure_testing, only : test_click, test_frame_hit, test_frame_rect, test_frame_state

implicit none
real(real64), parameter :: W = 800.0_real64       !< Display width [pixels].
real(real64), parameter :: H = 600.0_real64       !< Display height [pixels].
type(app_object)        :: app                    !< Application (headless).
logical                 :: test_passed(11)        !< Per-check outcome.
real(real64)            :: bar(4)                 !< The bar.
real(real64)            :: menus(4)               !< The menus inside it.
real(real64)            :: title(4)               !< The title.
real(real64)            :: bmin(4)                !< Minimize.
real(real64)            :: bmax(4)                !< Maximize.
real(real64)            :: bclose(4)              !< Close.
real(real64)            :: file_menu(4)           !< The program's File menu.
logical                 :: found(6)               !< Parts drawn.
logical                 :: menu_open              !< The File menu opened.
logical                 :: minimized              !< Recorded minimized.
logical                 :: maximized              !< Recorded maximized.
logical                 :: hits_ok                !< The hit test, point by point.
integer(int8)           :: image(4, 16, 16)       !< An icon image.
integer(int32)          :: stat                   !< Status.
integer(int32)          :: stat2                  !< Another.

test_passed = .false.
menu_open = .false.
call app%init_headless(int(W, int32), int(H, int32), decorations='figure', buttons='right') ! (macOS: left by default)
call app%set_title('FIGURE: frame test')
call app%set_confirm_quit(.true.)
call frames(3_int32)

! 1. the bar on top, full width, the program's menu inside it, the title in it
call test_frame_rect('bar', bar(1), bar(2), bar(3), bar(4), found(1))
call test_frame_rect('menus', menus(1), menus(2), menus(3), menus(4), found(2))
call test_frame_rect('title', title(1), title(2), title(3), title(4), found(3))
call test_frame_rect('minimize', bmin(1), bmin(2), bmin(3), bmin(4), found(4))
call test_frame_rect('maximize', bmax(1), bmax(2), bmax(3), bmax(4), found(5))
call test_frame_rect('close', bclose(1), bclose(2), bclose(3), bclose(4), found(6))
test_passed(1) = all(found) .and. bar(1) == 0.0_real64 .and. bar(2) == 0.0_real64 .and. bar(3) == W .and.  &
                 inside(file_menu, bar) .and. inside(file_menu, menus) .and.                        &
                 title(1) > menus(3) .and. title(3) <= bmin(1) .and. bmin(3) <= bmax(1) .and.           &
                 bmax(3) <= bclose(1) .and. abs(bclose(3) - W) < 1.0e-3_real64
write(output_unit, '(A,4F8.1,A,4F8.1)') 'bar ', bar, '  File menu ', file_menu

! 2. the hit test, point by point
hits_ok = .true.
call hit(0.5_real64 * (title(1) + title(3)), 0.5_real64 * (bar(2) + bar(4)), 'drag')        ! the title
call hit(0.5_real64 * (menus(3) + title(1)), 0.5_real64 * (bar(2) + bar(4)), 'drag')        ! the empty bar
call hit(1.0_real64, 1.0_real64, 'resize-top-left')
call hit(W / 2.0_real64, 1.0_real64, 'resize-top')
call hit(W - 1.0_real64, 1.0_real64, 'resize-top-right')
call hit(W - 1.0_real64, H / 2.0_real64, 'resize-right')
call hit(W - 1.0_real64, H - 1.0_real64, 'resize-bottom-right')
call hit(W / 2.0_real64, H - 1.0_real64, 'resize-bottom')
call hit(1.0_real64, H - 1.0_real64, 'resize-bottom-left')
call hit(1.0_real64, H / 2.0_real64, 'resize-left')
call hit(0.5_real64 * (bmin(1) + bmin(3)), 0.5_real64 * (bmin(2) + bmin(4)), 'client')
call hit(0.5_real64 * (bmax(1) + bmax(3)), 0.5_real64 * (bmax(2) + bmax(4)), 'client')
call hit(0.5_real64 * (bclose(1) + bclose(3)), 0.5_real64 * (bclose(2) + bclose(4)), 'client')
call hit(0.5_real64 * (file_menu(1) + file_menu(3)), 0.5_real64 * (file_menu(2) + file_menu(4)), 'client')
call hit(W / 2.0_real64, H / 2.0_real64, 'client')
test_passed(2) = hits_ok

! 3. the menu opens from the bar
call test_click(0.5_real64 * (file_menu(1) + file_menu(3)), 0.5_real64 * (file_menu(2) + file_menu(4)))
call frames(6_int32)
test_passed(3) = menu_open
call test_click(W / 2.0_real64, H / 2.0_real64) ! close it
call frames(6_int32)

! 4. maximize, recorded; no resize edges then; restored by a double-click on the empty bar
call test_click(0.5_real64 * (bmax(1) + bmax(3)), 0.5_real64 * (bmax(2) + bmax(4)))
call frames(6_int32)
call test_frame_state(minimized, maximized)
test_passed(4) = maximized .and. .not. minimized
hits_ok = .true.
call hit(1.0_real64, H - 1.0_real64, 'client')
call hit(1.0_real64, 1.0_real64, 'client')                                    ! the menus reach the corner
call hit(W / 2.0_real64, 1.0_real64, 'drag')
test_passed(5) = hits_ok
call test_click(0.5_real64 * (menus(3) + title(1)), 0.5_real64 * (bar(2) + bar(4)))
call test_click(0.5_real64 * (menus(3) + title(1)), 0.5_real64 * (bar(2) + bar(4)))
call frames(10_int32)
call test_frame_state(minimized, maximized)
test_passed(6) = .not. maximized

! 5. minimize, recorded; close: a quit request
call test_click(0.5_real64 * (bmin(1) + bmin(3)), 0.5_real64 * (bmin(2) + bmin(4)))
call frames(6_int32)
call test_frame_state(minimized, maximized)
test_passed(7) = minimized
call test_click(0.5_real64 * (bclose(1) + bclose(3)), 0.5_real64 * (bclose(2) + bclose(4)))
call frames(6_int32)
test_passed(8) = app%quit_requested()

! 6. the icon: refused without a window
call app%set_icon(ICON_CHART_LINE, stat=stat)
image = 0_int8
call app%set_icon(image, stat=stat2)
test_passed(9) = stat == FIG_ERR_STATE .and. stat2 == FIG_ERR_STATE
call app%destroy()

! 7. the buttons on the left (close first); no bar without the option; an unknown option refused
call app%init_headless(int(W, int32), int(H, int32), decorations='figure', buttons='left')
call frames(3_int32)
call test_frame_rect('close', bclose(1), bclose(2), bclose(3), bclose(4), found(1))
call test_frame_rect('maximize', bmax(1), bmax(2), bmax(3), bmax(4), found(2))
call test_frame_rect('menus', menus(1), menus(2), menus(3), menus(4), found(3))
test_passed(10) = all(found(1:3)) .and. bclose(1) == 0.0_real64 .and. bmax(3) <= menus(1)
call app%destroy()
call app%init_headless(int(W, int32), int(H, int32))
call frames(2_int32)
call test_frame_rect('bar', bar(1), bar(2), bar(3), bar(4), found(1))
test_passed(10) = test_passed(10) .and. .not. found(1) .and. test_frame_hit(1.0_real64, 1.0_real64) == 'client'
call app%destroy()
call app%init_headless(int(W, int32), int(H, int32), decorations='fancy', stat=stat)
test_passed(10) = test_passed(10) .and. stat == FIG_ERR_ARGUMENT

! 8. the bar's height: the menu bar's, or a theme's TitleBarHeight
test_passed(11) = bar_height_check()

write(output_unit, '(A,11L2)') 'figure_test_frame checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine frames(n)
   !< Draw `n` frames of the program: a main menu bar (in the title bar) and a window below it.
   integer(int32), intent(in) :: n     !< Frames.
   integer(int32)             :: k     !< Counter.

   do k = 1_int32, n
      if (.not. app%next_frame()) exit
      if (ig_begin_main_menu_bar()) then
         if (ig_begin_menu('File')) then
            menu_open = .true.
            if (ig_menu_item('Quit')) continue
            call ig_end_menu()
         endif
         call ig_item_rect(file_menu(1), file_menu(2), file_menu(3), file_menu(4))
         call ig_end_main_menu_bar()
      endif
      call ig_set_next_window(100.0_real64, 100.0_real64, 300.0_real64, 200.0_real64)
      if (ig_begin('Below')) call ig_text('below the bar')
      call ig_end()
   enddo
   endsubroutine frames

   function bar_height_check() result(passed)
   !< The bar as tall as the menu bar by default; 44 pixels with a theme's TitleBarHeight = 44, the program's menu
   !< centred, the lower part of the bar dragging; the same after save_style and load_style; back to the menu bar's
   !< after a new look; a negative height and an unknown FIGURE variable refused.
   logical                     :: passed      !< Outcome.
   real(real64)                :: pad(2)      !< FramePadding [pixels].
   real(real64)                :: text(2)     !< A line of text [pixels].
   real(real64)                :: menu_h      !< The menu bar's height [pixels].
   real(real64)                :: tall(4)     !< The bar, taller.
   real(real64)                :: again(4)    !< ... loaded back.
   real(real64)                :: reset(4)    !< ... after a new look.
   integer(int32)              :: n           !< Values of a variable.
   integer(int32)              :: s(5)        !< Statuses.
   integer(int32)              :: u           !< Unit.
   logical                     :: hits_before !< hits_ok kept.
   character(len=*), parameter :: FILE = 'figure_test_frame.tmp.toml'    !< A theme.
   character(len=*), parameter :: SAVED = 'figure_test_frame.saved.toml' !< It, saved.

   s = -1_int32
   call app%init_headless(int(W, int32), int(H, int32), decorations='figure', buttons='right')
   call frames(3_int32)
   call ig_get_style_var('FramePadding', pad, n)
   text = ig_text_size('File')
   menu_h = text(2) + 2.0_real64 * pad(2)
   call test_frame_rect('bar', bar(1), bar(2), bar(3), bar(4), found(1))
   passed = found(1) .and. abs(bar(4) - bar(2) - menu_h) < 1.0e-3_real64
   open(newunit=u, file=FILE, status='replace')
   write(u, '(A)') 'look = "seal"', 'palette = "seal"', '[figure.vars]', 'TitleBarHeight = 44'
   close(u)
   call app%load_style(FILE, stat=s(1))
   call frames(3_int32)
   call test_frame_rect('bar', tall(1), tall(2), tall(3), tall(4), found(2))
   hits_before = hits_ok
   hits_ok = .true.
   call hit(0.5_real64 * W, 42.0_real64, 'drag')                                ! the bar's lower part
   call hit(0.5_real64 * (file_menu(1) + file_menu(3)), 0.5_real64 * (file_menu(2) + file_menu(4)), 'client')
   passed = passed .and. found(2) .and. abs(tall(4) - tall(2) - 44.0_real64) < 1.0e-3_real64 .and. hits_ok .and. &
            abs(0.5_real64 * (file_menu(2) + file_menu(4)) - 22.0_real64) <= 1.0_real64 .and. inside(file_menu, tall)
   hits_ok = hits_before
   call app%save_style(SAVED, stat=s(2))
   call app%set_style('seal')
   call app%load_style(SAVED, stat=s(3))
   call frames(3_int32)
   call test_frame_rect('bar', again(1), again(2), again(3), again(4), found(3))
   call app%set_style(look='fusion')
   call frames(3_int32)
   call test_frame_rect('bar', reset(1), reset(2), reset(3), reset(4), found(4))
   call ig_get_style_var('FramePadding', pad, n)
   passed = passed .and. all(found(3:4)) .and. abs(again(4) - again(2) - 44.0_real64) < 1.0e-3_real64 .and. &
            abs(reset(4) - reset(2) - (text(2) + 2.0_real64 * pad(2))) < 1.0e-3_real64
   open(newunit=u, file=FILE, status='replace')
   write(u, '(A)') '[figure.vars]', 'TitleBarHeight = -3'
   close(u)
   call app%load_style(FILE, stat=s(4))
   open(newunit=u, file=FILE, status='replace')
   write(u, '(A)') '[figure.vars]', 'MenuHeight = 30'
   close(u)
   call app%load_style(FILE, stat=s(5))
   passed = passed .and. all(s(1:3) == FIG_OK) .and. all(s(4:5) == FIG_ERR_ARGUMENT)
   open(newunit=u, file=FILE, status='old')
   close(u, status='delete')
   open(newunit=u, file=SAVED, status='old')
   close(u, status='delete')
   call app%destroy()
   if (.not. passed) write(output_unit, '(A,F7.1,A,3F7.1,A,5(I0,1X),A,4F8.1)') 'bar height: menu bar ', menu_h, &
      ', tall, loaded, reset ', tall(4) - tall(2), again(4) - again(2), reset(4) - reset(2), ', statuses ', s, &
      ', File menu ', file_menu
   endfunction bar_height_check

   pure function inside(a, b) result(yes)
   !< Rectangle a within rectangle b.
   real(real64), intent(in) :: a(4) !< Inner.
   real(real64), intent(in) :: b(4) !< Outer.
   logical                  :: yes  !< Inside.

   yes = a(1) >= b(1) .and. a(2) >= b(2) .and. a(3) <= b(3) .and. a(4) <= b(4)
   endfunction inside

   subroutine hit(x, y, expected)
   !< The hit test at (x, y) is `expected`; reported otherwise.
   real(real64),     intent(in) :: x        !< Abscissa [pixels].
   real(real64),     intent(in) :: y        !< Ordinate [pixels].
   character(len=*), intent(in) :: expected !< Class.

   if (test_frame_hit(x, y) /= expected) then
      hits_ok = .false.
      write(output_unit, '(A,2F8.1,A,A,A,A)') 'hit test at ', x, y, ': ', test_frame_hit(x, y), ' instead of ', expected
   endif
   endsubroutine hit
endprogram figure_test_frame
