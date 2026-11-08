!< tut07_window, tutorial chapter 7: the studio's own window, its frame drawn by FIGURE.
program tut07_window
!< tut07_window, tutorial chapter 7: the studio's own window, its frame drawn by FIGURE.
!<
!< The solver studio of part two starts here: a window whose frame (title bar, icon, title, buttons, drag and resize)
!< FIGURE draws, the same on every system, with a question before it closes. `tut07_window --left` puts the buttons
!< on the left, as on macOS; `tut07_window --frame-map` opens no window: it draws the studio headless and prints what
!< each point of the window does.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, FIG_OK, figure_last_error, ICON_FLAME, ig_begin, ig_begin_main_menu_bar, &
                   ig_begin_menu, ig_begin_popup_modal, ig_button, ig_close_current_popup, ig_end,          &
                   ig_end_main_menu_bar, ig_end_menu, ig_end_popup, ig_menu_item, ig_open_popup, ig_same_line, &
                   ig_set_next_window, ig_text, ig_text_disabled
use figure_testing, only : test_click, test_frame_hit, test_frame_rect, test_frame_state

implicit none
type(app_object)  :: app      !< Application.
character(len=16) :: arg      !< First argument.
logical           :: ask_quit !< File > Quit was picked.
logical           :: asking   !< The quit question was shown.
!run tut07 ./tut07_window --frame-map

ask_quit = .false.
asking = .false.
call get_command_argument(1, arg)
select case (trim(arg))
case ('--frame-map')
   call frame_map()
   stop
case ('--left')
   call open_window('left')
case default
   call open_window()                               ! the buttons on the platform's side
endselect
!region loop
do while (app%next_frame())                          ! .false. once the user confirmed the quit
   call draw_studio()
enddo
call app%destroy()
!endregion loop

contains
   subroutine open_window(side)
   !< Open the studio's window, its frame drawn by FIGURE.
   character(len=*), intent(in), optional :: side !< Where the buttons go: 'left' or 'right' (absent: the platform's).
   integer(int32)                         :: stat !< Status of the icon.

   !region window
   call app%init('FIGURE studio', 960_int32, 600_int32, decorations='figure', buttons=side) ! FIGURE draws the frame
   call app%set_icon(ICON_FLAME, stat=stat)          ! the task bar's icon, and the title bar's
   if (stat /= FIG_OK) write(output_unit, '(A)') 'no window icon here: '//figure_last_error() ! the bar keeps its own
   call app%set_confirm_quit(.true.)                 ! the close button asks the program first
   !endregion window
   endsubroutine open_window

   subroutine draw_studio()
   !< One frame of the studio: the menus in the title bar, the welcome panel, the question before quitting.
   !region menus
   if (ig_begin_main_menu_bar()) then                ! inside the title bar, after the icon
      if (ig_begin_menu('File')) then
         if (ig_menu_item('Quit')) ask_quit = .true.  ! the same question as the close button, asked below
         call ig_end_menu()
      endif
      call ig_end_main_menu_bar()
   endif
   !endregion menus
   call ig_set_next_window(40.0_real64, 70.0_real64, 520.0_real64, 170.0_real64)
   if (ig_begin('Welcome')) then
      call ig_text('No case open.')
      call ig_text_disabled('Drag the window by its title bar; double-click the bar to maximize it;')
      call ig_text_disabled('resize it from any edge or corner. Close it with the button or File > Quit.')
   endif
   call ig_end()
   !region quit
   if (app%quit_requested() .or. ask_quit) then      ! the close button was clicked, or File > Quit
      call ig_open_popup('Quit the studio?')        ! here, outside the menu: the popup's id is the modal's
      ask_quit = .false.
   endif
   if (ig_begin_popup_modal('Quit the studio?')) then
      asking = .true.
      call ig_text('The studio closes.')
      if (ig_button('Quit')) call app%quit()         ! the next next_frame returns .false.
      call ig_same_line()
      if (ig_button('Cancel')) call ig_close_current_popup()
      call ig_end_popup()
   endif
   !endregion quit
   endsubroutine draw_studio

   subroutine frame_map()
   !< Draw the studio headless, with the same frame, and print what each point of its window does.
   real(real64), parameter :: W = 480.0_real64 !< Display width [pixels].
   real(real64), parameter :: H = 72.0_real64 !< Display height [pixels].
   real(real64)            :: r(4)             !< A part of the bar.
   logical                 :: minimized        !< Recorded minimized.
   logical                 :: maximized        !< Recorded maximized.

   !region map
   call app%init_headless(int(W, int32), int(H, int32), decorations='figure', buttons='right') ! the bar, no window
   call app%set_confirm_quit(.true.)
   call frames(3_int32)
   call print_map()
   call test_frame_rect('bar', r(1), r(2), r(3), r(4))
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))   ! a double-click on the bar
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
   call frames(10_int32)
   call test_frame_state(minimized, maximized)
   write(output_unit, '(A,L1,A,A)') 'double-click on the bar: maximized ', maximized, &
                                    ', the top-left corner: ', test_frame_hit(1.0_real64, 1.0_real64)
   call test_frame_rect('close', r(1), r(2), r(3), r(4))
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))   ! the close button
   call frames(6_int32)
   write(output_unit, '(A,L1)') 'close: the question is shown ', asking
   call app%destroy()
   !endregion map
   endsubroutine frame_map

   subroutine frames(n)
   !< Draw `n` frames of the studio.
   integer(int32), intent(in) :: n !< Frames.
   integer(int32)             :: k !< Counter.

   do k = 1_int32, n
      if (.not. app%next_frame()) exit
      call draw_studio()
   enddo
   endsubroutine frames

   subroutine print_map()
   !< One character per cell of 8 x 6 pixels: what the frame's hit test answers at the cell's centre (at the
   !< window's very edge for the first and last rows and columns).
   real(real64), parameter :: W = 480.0_real64 !< Display width [pixels].
   real(real64), parameter :: H = 72.0_real64 !< Display height [pixels].
   character(len=60)       :: row              !< One row of the map.
   real(real64)            :: x                !< Abscissa [pixels].
   real(real64)            :: y                !< Ordinate [pixels].
   integer(int32)          :: i                !< Column.
   integer(int32)          :: j                !< Row.

   do j = 0_int32, 11_int32
      y = merge(1.0_real64, merge(H - 1.0_real64, 6.0_real64 * j + 3.0_real64, j == 11_int32), j == 0_int32)
      do i = 0_int32, 59_int32
         x = merge(1.0_real64, merge(W - 1.0_real64, 8.0_real64 * i + 4.0_real64, i == 59_int32), i == 0_int32)
         row(i + 1:i + 1) = mark(x, y)
      enddo
      write(output_unit, '(A)') row
   enddo
   write(output_unit, '(A)') '= drags the window   < > ^ v / \ resize it   M menus   _ # X the buttons   . the program'
   endsubroutine print_map

   function mark(x, y) result(c)
   !< The map's character for the point (x, y).
   real(real64), intent(in) :: x  !< Abscissa [pixels].
   real(real64), intent(in) :: y  !< Ordinate [pixels].
   character(len=1)         :: c  !< Mark.

   select case (test_frame_hit(x, y))
   case ('drag')
      c = '='
   case ('resize-top')
      c = '^'
   case ('resize-bottom')
      c = 'v'
   case ('resize-left')
      c = '<'
   case ('resize-right')
      c = '>'
   case ('resize-top-left', 'resize-bottom-right')
      c = '/'
   case ('resize-top-right', 'resize-bottom-left')
      c = '\'
   case default                                      ! the program's: which part of the bar, if any
      c = '.'
      if (in_part('menus', x, y)) c = 'M'
      if (in_part('minimize', x, y)) c = '_'
      if (in_part('maximize', x, y)) c = '#'
      if (in_part('close', x, y)) c = 'X'
   endselect
   endfunction mark

   function in_part(part, x, y) result(inside)
   !< The point (x, y) is in a part of the title bar.
   character(len=*), intent(in) :: part   !< Part.
   real(real64),     intent(in) :: x      !< Abscissa [pixels].
   real(real64),     intent(in) :: y      !< Ordinate [pixels].
   logical                      :: inside !< Inside.
   real(real64)                 :: r(4)   !< Its rectangle.
   logical                      :: found  !< Drawn.

   call test_frame_rect(part, r(1), r(2), r(3), r(4), found)
   inside = found .and. x >= r(1) .and. x < r(3) .and. y >= r(2) .and. y < r(4)
   endfunction in_part
endprogram tut07_window
