!< figure_test_select, multi-selection driven by synthetic input, headless: clicks, shift and ctrl clicks, select all,
!< escape, box-selection, a clipped list, a tree, a single-selection list, and the usage errors.
program figure_test_select
!< figure_test_select, multi-selection driven by synthetic input, headless: clicks, shift and ctrl clicks, select all,
!< escape, box-selection, a clipped list, a tree, a single-selection list, and the usage errors.
!<
!< A list of 40 lines in a child region of 8 lines' height, clipped (`list_clipper_object`, the range source kept):
!< a click on line 3 selects it alone; shift+click on 7 extends to 3..7; ctrl+click (cmd+click on macOS: the key
!< `shortcut`) on 10 adds it, on 5 removes it; ctrl+a selects all 40; escape clears; a click on 2, the wheel (line 2
!< out of view, kept drawn by the clipper), shift+click on a line in view: 2 to that line. A short list of 5 lines in
!< a tall child: a drag from the void below the last line up to line 2 box-selects 2..5. A tree of 4 nodes: click
!< node 2, shift+click node 4: 2..4. A single-selection list: ctrl+click two lines, the last one alone selected. The
!< refusals with their statuses and messages.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, app_object, figure_last_error, ig_begin, ig_begin_child, &
                   ig_begin_multi_select, ig_end, ig_end_child, ig_end_multi_select, ig_item_rect, ig_push_id,     &
                   ig_pop_id, ig_selectable, ig_set_next_window, ig_tree_node, ig_tree_pop, list_clipper_object,   &
                   selection_object
use figure_testing, only : test_click, test_key, test_mouse_button, test_mouse_move, test_next_frame, test_wheel

implicit none
integer(int32), parameter :: LONG = 40_int32  !< Lines of the clipped list.
type(app_object)          :: app              !< Application.
type(selection_object)    :: sel              !< The long list's selection.
type(selection_object)    :: box              !< The short list's.
type(selection_object)    :: tree             !< The tree's.
type(selection_object)    :: one              !< The single-selection list's.
type(list_clipper_object) :: clip             !< Lines in view.
logical                   :: ok(14)           !< Per-check outcome.
logical                   :: got(LONG, 8)     !< The long list's selection at each step's end.
real(real64)              :: line(4, LONG)    !< The long list's lines [pixels] (those drawn).
real(real64)              :: short(4, 5)      !< The short list's.
real(real64)              :: node(4, 4)       !< The tree's nodes.
real(real64)              :: single(4, 3)     !< The single list's lines.
real(real64)              :: void(2)          !< A point below the short list's last line.
logical                   :: clicked          !< A line was clicked.
character(len=160)        :: msg(5)           !< Messages of refused calls.
integer(int32)            :: st(5)            !< Their statuses.
integer(int32)            :: errors           !< Frames with a usage error.
integer(int32)            :: view(2)          !< The long list's lines in view (the clipper's last range).
integer(int32)            :: target           !< The line shift+clicked after the scroll.
integer(int32)            :: first_view       !< The first line in view then.
integer(int32), allocatable :: picked(:)      !< The long list's items selected, at the end.
integer(int32)            :: f                !< Frame.
integer(int32)            :: i                !< Line.
integer(int32)            :: s                !< Status of a frame.
character(len=12)         :: label            !< A line's label.

ok = .false.
view = 0_int32
target = 2_int32
first_view = 0_int32
got = .false.
line = 0.0_real64
errors = 0_int32
st = -1_int32
msg = ''
call sel%resize(LONG)
call box%resize(5_int32)
call tree%resize(4_int32)
call one%resize(3_int32)
call app%init_headless(900_int32, 800_int32)
do f = 1_int32, 200_int32
   if (.not. app%next_frame(s)) exit
   if (s /= FIG_OK) errors = errors + 1_int32
   call ig_set_next_window(0.0_real64, 0.0_real64, 900.0_real64, 800.0_real64, always=.true.)
   if (ig_begin('Lists')) then
      if (ig_begin_child('long', width=300.0_real64, height=8.0_real64 * 23.0_real64)) then
         call ig_begin_multi_select(sel, clear_on_escape=.true.)
         call clip%begin(LONG, keep=sel%keep)
         do while (clip%step())
            view = [clip%first, clip%last]              ! the last range stepped: the lines in view
            do i = clip%first, clip%last
               write(label, '(A,I0)') 'line ', i
               if (ig_selectable(trim(label), sel%is_selected(i), index=i)) continue
               call ig_item_rect(line(1, i), line(2, i), line(3, i), line(4, i))
            enddo
         enddo
         call ig_end_multi_select(sel)
      endif
      call ig_end_child()
      if (ig_begin_child('short', width=300.0_real64, height=200.0_real64)) then
         call ig_begin_multi_select(box, box_select=.true.)
         do i = 1_int32, 5_int32
            write(label, '(A,I0)') 'item ', i
            if (ig_selectable(trim(label), box%is_selected(i), index=i)) continue
            call ig_item_rect(short(1, i), short(2, i), short(3, i), short(4, i))
         enddo
         call ig_end_multi_select(box)
         void = [0.5_real64 * (short(1, 5) + short(3, 5)), short(4, 5) + 60.0_real64]
      endif
      call ig_end_child()
      call ig_begin_multi_select(tree)
      do i = 1_int32, 4_int32
         write(label, '(A,I0)') 'node ', i
         if (ig_tree_node(trim(label), leaf=.true., selected=tree%is_selected(i), index=i)) call ig_tree_pop()
         call ig_item_rect(node(1, i), node(2, i), node(3, i), node(4, i))
      enddo
      call ig_end_multi_select(tree)
      call ig_begin_multi_select(one, single=.true.)
      do i = 1_int32, 3_int32
         call ig_push_id(i)
         if (ig_selectable('one of three', one%is_selected(i), index=i)) continue
         call ig_item_rect(single(1, i), single(2, i), single(3, i), single(4, i))
         call ig_pop_id()
      enddo
      call ig_end_multi_select(one)
      if (f == 190_int32) then
         if (ig_selectable('loose', .false., index=1_int32, stat=st(1))) continue ! no selection open
         msg(1) = figure_last_error()
         call ig_begin_multi_select(one)
         if (ig_selectable('far', .false., index=4_int32, stat=st(2))) continue   ! out of 1..3
         msg(2) = figure_last_error()
         call ig_begin_multi_select(box, stat=st(3))                               ! inside another
         msg(3) = figure_last_error()
         call ig_end_multi_select(one)
         call ig_end_multi_select(one, stat=st(4))                                  ! none open
         msg(4) = figure_last_error()
         if (ig_tree_node('loose', index=1_int32, stat=st(5))) call ig_tree_pop()   ! no selection open
         msg(5) = figure_last_error()
      endif
   endif
   call ig_end()
   select case (f)
   case (5_int32)
      call click_on(line(:, 3))
   case (15_int32)
      got(:, 1) = sel%flags()
      call test_key('shift', down=.true.)
      call click_on(line(:, 7))
      call test_key('shift', down=.false.)
   case (25_int32)
      got(:, 2) = sel%flags()
      call test_key('shortcut', down=.true.)
      call click_on(line(:, 10))
      call test_key('shortcut', down=.false.)
   case (35_int32)
      got(:, 3) = sel%flags()
      call test_key('shortcut', down=.true.)
      call click_on(line(:, 5))
      call test_key('shortcut', down=.false.)
   case (45_int32)
      got(:, 4) = sel%flags()
      call test_key('shortcut', down=.true.)
      call test_key('a')
      call test_key('shortcut', down=.false.)
   case (55_int32)
      got(:, 5) = sel%flags()
      call test_key('escape')
   case (65_int32)
      got(:, 6) = sel%flags()
      call click_on(line(:, 2))
   case (75_int32)
      call test_wheel(-4.0_real64)                         ! line 2 scrolls out of view
   case (85_int32)
      target = view(2) - 1_int32                          ! a line in view, well inside it
      first_view = view(1)
      call test_key('shift', down=.true.)
      call click_on(line(:, target))
      call test_key('shift', down=.false.)
   case (95_int32)
      got(:, 7) = sel%flags()
      ! box-selection: from the void below item 5 up to item 2
      call test_mouse_move(void(1), void(2))
      call test_next_frame()
      call test_next_frame()
      call test_mouse_button(.true.)
      call test_next_frame()
      call test_mouse_move(void(1), void(2) - 40.0_real64)
      call test_next_frame()
      call test_mouse_move(void(1), 0.5_real64 * (short(2, 2) + short(4, 2)))
      call test_next_frame()
      call test_next_frame()
      call test_mouse_button(.false.)
   case (115_int32)
      call click_on(node(:, 2))
   case (125_int32)
      call test_key('shift', down=.true.)
      call click_on(node(:, 4))
      call test_key('shift', down=.false.)
   case (135_int32)
      call test_key('shortcut', down=.true.)
      call click_on(single(:, 1))
      call test_next_frame()
      call click_on(single(:, 3))
      call test_key('shortcut', down=.false.)
   endselect
enddo
if (app%next_frame(s)) continue
if (s /= FIG_OK) errors = errors + 1_int32
call app%destroy()

ok(1) = count(got(:, 1)) == 1 .and. got(3, 1)                                ! a click: line 3 alone
ok(2) = count(got(:, 2)) == 5 .and. all(got(3:7, 2))                         ! shift+click: 3..7
ok(3) = count(got(:, 3)) == 6 .and. got(10, 3)                               ! ctrl+click: 10 added
ok(4) = count(got(:, 4)) == 5 .and. .not. got(5, 4)                          ! ctrl+click: 5 removed
ok(5) = all(got(:, 5))                                                       ! ctrl+a: all
ok(6) = .not. any(got(:, 6))                                                 ! escape: none
ok(7) = first_view > 2_int32 .and. count(got(:, 7)) == target - 1 .and. all(got(2:target, 7)) ! past the clipped source
ok(8) = all(box%flags() .eqv. [.false., .true., .true., .true., .true.])     ! box-selection: 2..5
ok(9) = all(tree%flags() .eqv. [.false., .true., .true., .true.])            ! a tree: 2..4
ok(10) = all(one%flags() .eqv. [.false., .false., .true.])                   ! single: the last one alone
picked = sel%indices()
if (size(picked) == target - 1 .and. target >= 2_int32) then                ! sizes first: no short circuit
   ok(11) = sel%selected_count() == target - 1_int32 .and. all(picked == [(i, i = 2, target)]) ! the queries
endif
ok(12) = all(st([1, 3, 4, 5]) == int(FIG_ERR_STATE, int32)) .and.                                                &
         msg(1) == 'ig_selectable: index is given, but no multi-selection is open (ig_begin_multi_select)' .and.  &
         msg(3) == 'ig_begin_multi_select: a multi-selection is open (Dear ImGui allows one at a time)' .and.     &
         msg(4)(1:20) == 'ig_end_multi_select:' .and.                                                            &
         msg(5) == 'ig_tree_node: index is given, but no multi-selection is open (ig_begin_multi_select)'
ok(13) = st(2) == int(FIG_ERR_ARGUMENT, int32) .and. msg(2) == 'ig_selectable: index 4 is out of 1 to 3'
ok(14) = errors == 0_int32

write(output_unit, '(A,*(L2))') 'figure_test_select checks:', ok
if (.not. all(ok)) then
   do i = 1_int32, 7_int32
      write(output_unit, '(A,I0,1X,40L1)') 'step ', i, got(:, i)
   enddo
   write(output_unit, '(A,3I4)') 'view, target ', first_view, view(2), target
   write(output_unit, '(A,5L1,1X,4L1,1X,3L1)') 'box tree one ', box%flags(), tree%flags(), one%flags()
   write(output_unit, '(A,5I3)') 'statuses ', st
   do i = 1_int32, 5_int32
      write(output_unit, '(A)') trim(msg(i))
   enddo
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1
contains
   subroutine click_on(r)
   !< Queue a click at the centre of rectangle `r` [pixels].
   real(real64), intent(in) :: r(4) !< Rectangle: left, top, right, bottom.

   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
   endsubroutine click_on
endprogram figure_test_select
