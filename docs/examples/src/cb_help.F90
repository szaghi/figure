!< cb_help, cookbook: a list of sections on the left, the section's parameters and a help panel on the right.
program cb_help
!< cb_help, cookbook: a list of sections on the left, the section's parameters and a help panel on the right.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_begin_child, ig_end, ig_end_child, ig_same_line, ig_selectable, &
                   ig_separator, ig_set_next_window, ig_text, ig_text_colored, ig_text_disabled, ig_text_wrapped

implicit none
character(len=*), parameter :: SECTIONS(3) = ['Files     ', 'Grid      ', 'Chimera   '] !< The list.
character(len=*), parameter :: HELP(3) = [character(len=160) ::                                                  &
   'Where the solver reads its grid and writes its results. Every name is a root: the block number and the '//   &
   'extension are appended.',                                                                                      &
   'How many grid levels, and how the blocks are distributed over the processes.',                                 &
   'The search of donor cells for the overlapping grids: tolerances and the number of iterations.']  !< Help texts.
type(app_object)          :: app      !< Application.
integer(int32)            :: current  !< Section shown.
integer(int32)            :: k        !< Counter.

current = 1_int32
call app%init('FIGURE: list and help', 760_int32, 380_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 740.0_real64, 360.0_real64)
   if (ig_begin('Input file')) then
      !region list
      if (ig_begin_child('sections', width=160.0_real64, border=.true.)) then
         do k = 1_int32, size(SECTIONS, kind=int32)
            if (ig_selectable(trim(SECTIONS(k)), k == current)) current = k  ! the program keeps the selection
         enddo
      endif
      call ig_end_child()
      call ig_same_line()
      if (ig_begin_child('section')) then                ! the rest of the window
         call ig_text(trim(SECTIONS(current)))
         call ig_separator()
         call ig_text('grid file')
         call ig_same_line(offset=160.0_real64)            ! the values in one column
         call ig_text_disabled('CC/cc (default)')
         call ig_text('levels')
         call ig_same_line(offset=160.0_real64)
         call ig_text_colored('[!!] 0: must be at least 1', [0.90_real64, 0.35_real64, 0.30_real64])
         call ig_separator()
         call ig_text_wrapped(trim(HELP(current)))         ! wraps at the region's width
      endif
      call ig_end_child()
      !endregion list
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_help
