!< cb_markdown, cookbook: a help window from a Markdown file, its links reported to the program.
program cb_markdown
!< cb_markdown, cookbook: a help window from a Markdown file, its links reported to the program.
!<
!< `cb_markdown [FILE]` shows the solver's window, a few lines of Markdown (`ig_markdown`) whose link opens the help
!< beside it: FILE (default `cb_markdown.md`) read into a `markdown_view_object`, drawn with its table of contents and
!< its search (ctrl+f). A link to a heading of the page scrolls there; any other link is reported: the window's last
!< line shows it, nothing is opened. With `--test FILE`, headless: the page loaded, a search counted, a scroll to a
!< heading.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, FIG_OK, ig_begin, ig_end, ig_markdown, ig_set_next_window, ig_text, markdown_view_object

implicit none
type(app_object)              :: app        !< Application.
!region setup
type(markdown_view_object)    :: help       !< The help page.
character(len=:), allocatable :: url        !< A link clicked in this frame.
character(len=:), allocatable :: last       !< The link clicked last.
!endregion setup
logical                       :: shown      !< The help window is open.
character(len=512)            :: arg, file  !< Arguments.
integer(int32)                :: stat       !< Status of the load.
!run cb_markdown ./cb_markdown --test ../../../docs/examples/data/cb_markdown.md

call get_command_argument(1, arg)
if (trim(arg) == '--test') then
   call get_command_argument(2, file)
else
   file = arg
endif
if (len_trim(file) == 0) file = 'cb_markdown.md'
shown = trim(arg) == '--test' ! a window opens the help from its link
last = '(none)'
if (trim(arg) == '--test') then
   call app%init_headless(1000_int32, 600_int32)
else
   call app%init('FIGURE: help in Markdown', 1000_int32, 600_int32)
endif
!region setup
call help%init()
call help%load(trim(file), stat=stat)
if (stat /= FIG_OK) call help%set_text('# Help'//new_line('a')//new_line('a')//'The help file `'//trim(file)// &
                                       '` cannot be read.')
!endregion setup
if (trim(arg) == '--test') then
   call test()
else
   do while (app%next_frame())
      call draw()
   enddo
endif
call help%destroy()
call app%destroy()

contains
   subroutine draw()
   !< The solver's window, whose link opens the help, and the help window.
   call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 580.0_real64)
   if (ig_begin('Solver')) then
      !region inline
      if (ig_markdown('**Case** cylinder, *Re* = 100'//new_line('a')//new_line('a')//'Keys and units: [help](help)', &
                      url)) then
         if (url == 'help') shown = .true.                           ! the program's own link
      endif
      !endregion inline
   endif
   call ig_end()
   if (.not. shown) return
   call ig_set_next_window(320.0_real64, 10.0_real64, 670.0_real64, 580.0_real64)
   !region draw
   if (ig_begin('Help', open=shown)) then
      if (help%draw('page', url, height=-30.0_real64)) last = url ! nothing is opened: the program decides
      call ig_text('Last link: '//last)
   endif
   call ig_end()
   !endregion draw
   endsubroutine draw

   subroutine test()
   !< Headless: the page drawn, a search, a scroll to a heading.
   integer(int32) :: k !< Frame.

   do k = 1_int32, 3_int32
      if (.not. app%next_frame()) exit
      call draw()
   enddo
   !region test
   call help%find('pressure')
   do k = 1_int32, 3_int32
      if (.not. app%next_frame()) exit
      call draw()
   enddo
   write(output_unit, '(A,I0,A,I0)') "help: 'pressure' found ", help%matches(), ' times, current ', help%current_match()
   call help%find('')
   call help%scroll_to('Boundary conditions')
   do k = 1_int32, 30_int32
      if (.not. app%next_frame()) exit
      call draw()
   enddo
   write(output_unit, '(A)') 'help: scrolled to "Boundary conditions", last link: '//last
   !endregion test
   endsubroutine test
endprogram cb_markdown
