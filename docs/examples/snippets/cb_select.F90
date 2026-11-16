!< cb_select, cookbook: many blocks of a grid selected at once in a clipped list, as in a file manager; the selection's
!< total and a button acting on it.
program cb_select
!< cb_select, cookbook: many blocks of a grid selected at once in a clipped list, as in a file manager; the selection's
!< total and a button acting on it.
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure, only : app_object, ig_begin, ig_begin_child, ig_begin_multi_select, ig_button, ig_end, ig_end_child,    &
                   ig_end_multi_select, ig_same_line, ig_selectable, ig_set_next_window, ig_text, ig_text_disabled,  &
                   list_clipper_object, selection_object

implicit none
integer(int32), parameter :: BLOCKS = 2000_int32 !< Blocks of the grid.
type(app_object)          :: app                  !< Application.
type(selection_object)    :: sel                  !< The blocks selected.
type(list_clipper_object) :: clip                 !< Only the lines in view.
integer(int64)            :: cells(BLOCKS)        !< Cells of each block.
logical                   :: frozen(BLOCKS)       !< Blocks frozen by the button.
character(len=64)         :: line                 !< A formatted line.
integer(int32)            :: i                    !< Block.

cells = [(int(4096 + mod(i * 7919, 60000), int64), i = 1_int32, BLOCKS)]
frozen = .false.
call sel%resize(BLOCKS)
call app%init('FIGURE: selecting many items', 520_int32, 460_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 500.0_real64, 440.0_real64)
   if (ig_begin('Blocks')) then
      if (ig_begin_child('blocks', height=-60.0_real64, border=.true.)) then
         call ig_begin_multi_select(sel, box_select=.true., clear_on_escape=.true.)
         call clip%begin(BLOCKS, keep=sel%keep)           ! a shift+click extends from a line out of view
         do while (clip%step())
            do i = clip%first, clip%last
               write(line, '(A,I5,A,I7,A)') 'block ', i, ': ', cells(i), merge(' cells, frozen', ' cells        ', &
                                                                              frozen(i))
               if (ig_selectable(trim(line), sel%is_selected(i), index=i)) continue
            enddo
         enddo
         call ig_end_multi_select(sel)                    ! the clicks, keys and box are in sel
      endif
      call ig_end_child()
      write(line, '(I0,A,I0,A)') sel%selected_count(), ' blocks selected, ', sum(cells, mask=sel%flags()), ' cells'
      call ig_text(trim(line))
      if (ig_button('Freeze')) frozen(sel%indices()) = .true.  ! act on what is selected
      call ig_same_line()
      if (ig_button('Clear')) call sel%clear()
      call ig_same_line()
      call ig_text_disabled('shift, ctrl, ctrl+a, a drag in the void')
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_select
