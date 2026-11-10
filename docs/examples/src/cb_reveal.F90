!< cb_reveal, cookbook: reveal an item picked elsewhere; focus the field of a dialog.
program cb_reveal
!< cb_reveal, cookbook: reveal an item picked elsewhere; focus the field of a dialog.
!<
!< A bar of picks stands for a 3-D view: a pick names a block of a grid. The Bodies list (30 rows, all drawn) and the
!< Blocks list (2000 rows, only those in view drawn by a list clipper) scroll so that the picked body and block are in
!< the middle of their lists, and select them. "Go to..." opens a dialog whose field has the keyboard focus at once:
!< the user types a block number and enter, no click.
!< `cb_reveal --check` opens no window: it picks and types headless and prints what each list shows.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_begin_child, ig_begin_popup_modal, ig_button, ig_close_current_popup, &
                   ig_end, ig_end_child, ig_end_popup, ig_focus_here, ig_input_text, ig_last_item, ig_open_popup, &
                   ig_same_line, ig_scroll_here, ig_scroll_to_pos, ig_selectable, ig_set_next_window, ig_text, &
                   ig_text_disabled, item_status_object, list_clipper_object
use figure_testing, only : test_click, test_item_center, test_key, test_type
implicit none
integer(int32), parameter :: BLOCKS = 2000_int32   !< Blocks of the grid.
integer(int32), parameter :: BODIES = 30_int32     !< Bodies: each owns a run of blocks.
type(app_object)          :: app                   !< Application.
type(list_clipper_object) :: clip                  !< Only the blocks in view.
type(item_status_object)  :: s                     !< Status of an item.
integer(int32)            :: block                 !< The block selected (0: none).
logical                   :: reveal                !< Scroll the lists to the selection on this frame.
logical                   :: focus_field           !< Give the dialog's field the focus on this frame.
character(len=8)          :: goto_text             !< The dialog's field.
character(len=32)         :: label                 !< A row's label.
character(len=16)         :: arg                   !< First argument.
logical                   :: check                 !< --check: headless, scripted input.
real(real64)              :: pick_at(2, 3)         !< Centre of each pick button.
real(real64)              :: goto_at(2)            !< Centre of the "Go to..." button.
real(real64)              :: shown(4)              !< The selected block's row (x, y, w, h), when drawn.
real(real64)              :: list(4)               !< The Blocks list's rectangle.
integer(int32)            :: picks(3)              !< The blocks of the pick buttons.
integer(int32)            :: frame                 !< Frame counter.
integer(int32)            :: i                     !< Row.
integer(int32)            :: ios                   !< Status of a read.
!run cb_reveal ./cb_reveal --check
picks = [17_int32, 1240_int32, 1873_int32]
block = 0_int32
reveal = .false.
focus_field = .false.
goto_text = ''
pick_at = 0.0_real64
goto_at = 0.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(760_int32, 330_int32)
else
   call app%init('FIGURE: reveal an item', 760_int32, 330_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 740.0_real64, 60.0_real64)
   if (ig_begin('View')) then                                ! stands for a 3-D view where the user picks a block
      do i = 1_int32, size(picks, kind=int32)
         write(label, '(A,I0)') 'pick block ', picks(i)
         if (ig_button(trim(label))) call select(picks(i))
         call test_item_center(pick_at(1, i), pick_at(2, i))
         call ig_same_line()
      enddo
      if (ig_button('Go to...')) then
         call ig_open_popup('Go to block')
         goto_text = ''
         focus_field = .true.
      endif
      call test_item_center(goto_at(1), goto_at(2))
      call goto_dialog()
   endif
   call ig_end()
   call ig_set_next_window(10.0_real64, 80.0_real64, 240.0_real64, 240.0_real64)
   if (ig_begin('Bodies')) then
      if (ig_begin_child('bodies')) then
         do i = 1_int32, BODIES
            write(label, '(A,I0)') 'body ', i
            !region here
            if (ig_selectable(trim(label), i == body_of(block))) call select(first_of(i))
            if (reveal .and. i == body_of(block)) call ig_scroll_here(0.5_real64) ! this row to the middle
            !endregion here
         enddo
      endif
      call ig_end_child()
   endif
   call ig_end()
   call ig_set_next_window(260.0_real64, 80.0_real64, 490.0_real64, 240.0_real64)
   shown = 0.0_real64
   if (ig_begin('Blocks')) then
      !region clipped
      if (ig_begin_child('blocks')) then
         call clip%begin(BLOCKS)
         do while (clip%step())                                ! the rows in view, not the selected one
            do i = clip%first, clip%last
               write(label, '(A,I0,A,I0)') 'block ', i, '   body ', body_of(i)
               if (ig_selectable(trim(label), i == block)) call select(i)
               if (i == block) call keep_row()
            enddo
         enddo
         if (reveal .and. block > 0_int32) &                 ! row `block` starts (block - 1) rows down
            call ig_scroll_to_pos((real(block, real64) - 0.5_real64) * clip%item_height, 0.5_real64)
      endif
      call ig_end_child()
      !endregion clipped
      s = ig_last_item()
      list = s%rect
   endif
   call ig_end()
   reveal = .false.
   if (check) then
      call script(frame)
      if (frame == 70_int32) exit
   endif
enddo
call app%destroy()
contains
   subroutine select(k)
   !< Select block `k` and reveal it (and its body) on the next frame.
   integer(int32), intent(in) :: k !< Block.
   block = k
   reveal = .true.
   endsubroutine select

   !region dialog
   subroutine goto_dialog()
   !< The "Go to block" dialog: its field has the focus when it opens; enter goes to the block typed.
   integer(int32) :: k !< The block typed.
   if (ig_begin_popup_modal('Go to block')) then
      call ig_text_disabled('a block from 1 to 2000, then enter')
      if (focus_field) call ig_focus_here()                ! once: the next item takes the keys
      focus_field = .false.
      if (ig_input_text('block', goto_text)) continue
      s = ig_last_item()
      if (s%deactivated_after_edit) then                   ! enter (or a click elsewhere)
         read(goto_text, *, iostat=ios) k
         if (ios == 0 .and. k >= 1_int32 .and. k <= BLOCKS) call select(k)
         call ig_close_current_popup()
      endif
      if (ig_button('Cancel')) call ig_close_current_popup()
      call ig_end_popup()
   endif
   endsubroutine goto_dialog
   !endregion dialog

   subroutine keep_row()
   !< In --check: the selected block's row as drawn.
   s = ig_last_item()
   shown = s%rect
   endsubroutine keep_row

   pure function body_of(k) result(b)
   !< The body that owns block `k` (0 for none).
   integer(int32), intent(in) :: k !< Block.
   integer(int32)             :: b !< Body.
   b = 0_int32
   if (k > 0_int32) b = (k - 1_int32) * BODIES / BLOCKS + 1_int32
   endfunction body_of

   pure function first_of(b) result(k)
   !< The first block of body `b`.
   integer(int32), intent(in) :: b !< Body.
   integer(int32)             :: k !< Block.
   k = ((b - 1_int32) * BLOCKS + BODIES - 1_int32) / BODIES + 1_int32
   endfunction first_of

   subroutine report()
   !< In --check: where the selected block's row is in the Blocks list.
   character(len=24) :: where !< Its place.
   if (shown(4) <= 0.0_real64) then
      where = 'not drawn'
   elseif (abs(shown(2) + 0.5_real64 * shown(4) - (list(2) + 0.5_real64 * list(4))) < shown(4)) then
      where = 'in the middle'
   else
      where = 'drawn, off the middle'
   endif
   write(output_unit, '(A,I0,A,I0,A,I0,A)') 'frame ', frame, ': block ', block, ' (body ', body_of(block), &
                                             '): '//trim(where)
   endsubroutine report

   subroutine script(f)
   !< The input of --check, by frame.
   integer(int32), intent(in) :: f !< Frame.
   select case (f)
   case (5_int32)                          ! a pick in the "3-D view": block 1240
      call test_click(pick_at(1, 2), pick_at(2, 2))
   case (8_int32, 9_int32, 10_int32)       ! 8: the button not yet released; 9: picked; 10: scrolled, a frame later
      call report()
   case (20_int32)                         ! block 1873
      call test_click(pick_at(1, 3), pick_at(2, 3))
   case (25_int32)
      call report()
   case (35_int32)                         ! "Go to...", then type at once: the field has the focus
      call test_click(goto_at(1), goto_at(2))
   case (40_int32)
      call test_type('333')
      call test_key('enter')
   case (50_int32)
      call report()
   endselect
   endsubroutine script
endprogram cb_reveal
