!< cb_context_menu, cookbook: act on a row with a right click; a tooltip with a table in it; links.
program cb_context_menu
!< cb_context_menu, cookbook: act on a row with a right click; a tooltip with a table in it; links.
!<
!< The patches of a grid, one row each. A right click on a row opens that row's menu (insert a row below it, duplicate
!< it, copy its name, delete it); a right click on the list's empty space opens the list's menu (add a row at the end).
!< The pointer resting on a row shows a tooltip with a table of the patch's values. A link below the list shows or hides
!< a line of help; another opens FIGURE's documentation in the browser.
!< `cb_context_menu --check` opens no window: it clicks headless and prints the rows after each action.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_begin_item_tooltip, ig_begin_popup_context, ig_begin_table, ig_em,     &
                   ig_end, ig_end_popup, ig_end_table, ig_end_tooltip, ig_menu_item, ig_pop_id, ig_push_id,           &
                   ig_same_line, ig_selectable, ig_separator, ig_set_clipboard, ig_set_next_window,                   &
                   ig_table_next_column, ig_table_next_row, ig_text, ig_text_disabled, ig_text_link, ig_text_link_url, &
                   ig_text_wrapped
use figure_testing, only : test_click, test_item_center, test_mouse_move, test_opened_url, test_popup_rect
implicit none
integer(int32), parameter     :: MAX_ROWS = 12_int32  !< Rows the list holds.
type(app_object)              :: app                  !< Application.
character(len=16)             :: names(MAX_ROWS)      !< Each patch's name.
character(len=12)             :: kinds(MAX_ROWS)      !< ... its boundary condition.
real(real64)                  :: values(MAX_ROWS)     !< ... its value.
integer(int32)                :: rows                 !< Rows in the list.
integer(int32)                :: added                !< Rows added so far (for their names).
integer(int32)                :: todo_row             !< The row a menu acts on.
character(len=12)             :: todo                 !< What a menu asked for ('': nothing).
integer(int32)                :: i                    !< Row.
integer(int32)                :: frame                !< Frame counter.
logical                       :: help                 !< The help line is shown.
logical                       :: check                !< --check: headless, scripted input.
logical                       :: tooltip              !< A row's tooltip was drawn this frame.
character(len=16)             :: arg                  !< First argument.
character(len=64)             :: label                !< A value written.
real(real64)                  :: row_at(2, MAX_ROWS)  !< Centre of each row.
real(real64)                  :: entry_at(2, 4)       !< Centre of each entry of the open row menu.
real(real64)                  :: link_at(2)           !< Centre of the help link.
real(real64)                  :: docs_at(2)           !< Centre of the documentation link.
!run cb_context_menu ./cb_context_menu --check
rows = 4_int32
names(1:4) = [character(len=16) :: 'inlet', 'outlet', 'wall', 'symmetry']
kinds(1:4) = [character(len=12) :: 'velocity', 'pressure', 'no-slip', 'symmetry']
values(1:4) = [12.5_real64, 101325.0_real64, 0.0_real64, 0.0_real64]
added = 0_int32
todo = ''
todo_row = 0_int32
help = .false.
row_at = 0.0_real64
entry_at = 0.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(520_int32, 400_int32)
else
   call app%init('FIGURE: context menus', 520_int32, 400_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   tooltip = .false.
   call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 300.0_real64)
   if (ig_begin('Patches')) then
      !region rows
      do i = 1_int32, rows
         call ig_push_id(i)                                ! each row's menu has its own id
         if (ig_selectable(trim(names(i)), .false.)) continue
         if (check) call test_item_center(row_at(1, i), row_at(2, i))
         if (ig_begin_popup_context('row')) then          ! a right click on the row just drawn
            call ig_text_disabled(trim(names(i)))
            call ig_separator()
            if (ig_menu_item('Insert below', enabled=rows < MAX_ROWS)) call ask('insert', i)
            call keep_entry(1)                             ! --check: where the entry is
            if (ig_menu_item('Duplicate', enabled=rows < MAX_ROWS)) call ask('duplicate', i)
            call keep_entry(2)
            if (ig_menu_item('Copy name')) call ig_set_clipboard(trim(names(i)))
            call keep_entry(3)
            if (ig_menu_item('Delete')) call ask('delete', i)
            call keep_entry(4)
            call ig_end_popup()
         endif
         !region tooltip
         if (ig_begin_item_tooltip()) then                ! the pointer rests on the row
            tooltip = .true.
            if (ig_begin_table('values', 2_int32)) then
               call cell('patch', trim(names(i)))
               call cell('condition', trim(kinds(i)))
               write(label, '(F0.1)') values(i)
               call cell('value', trim(label))
               call ig_end_table()
            endif
            call ig_end_tooltip()
         endif
         !endregion tooltip
         call ig_same_line(ig_em(8.0_real64))             ! the condition in a column of its own
         call ig_text_disabled(trim(kinds(i)))
         call ig_pop_id()
      enddo
      call apply()                                       ! the list changes after it is drawn, not while
      !endregion rows
      !region space
      if (ig_begin_popup_context('list', on='window')) then ! the window's empty space, not over a row
         if (ig_menu_item('Add a row', enabled=rows < MAX_ROWS)) call ask('add', rows)
         call keep_entry(1)
         call ig_end_popup()
      endif
      call apply()
      !endregion space
      !region links
      call ig_separator()
      if (ig_text_link('What is a patch?')) help = .not. help
      if (check) call test_item_center(link_at(1), link_at(2))
      if (help) call ig_text_wrapped('A patch is a set of faces of the grid that share one boundary condition.')
      call ig_text_link_url('Documentation', 'https://szaghi.github.io/figure/')
      if (check) call test_item_center(docs_at(1), docs_at(2))
      !endregion links
   endif
   call ig_end()
   if (check) then
      call script(frame)
      if (frame == 120_int32) exit
   endif
enddo
call app%destroy()
contains
   subroutine ask(what, row)
   !< Remember what a menu asked for, done by `apply` after the rows are drawn.
   character(len=*), intent(in) :: what !< 'insert', 'duplicate', 'delete' or 'add'.
   integer(int32),   intent(in) :: row  !< The row it acts on.
   todo = what
   todo_row = row
   endsubroutine ask

   subroutine apply()
   !< Do what a menu asked for in this frame.
   select case (todo)
   case ('insert', 'add')
      call insert(todo_row + 1_int32, 'new')
   case ('duplicate')
      call insert(todo_row + 1_int32, names(todo_row))
   case ('delete')
      call delete(todo_row)
   endselect
   todo = ''
   endsubroutine apply

   subroutine insert(at, name)
   !< A row at position `at` (the others move down): `name`, the condition and value of the row above it.
   integer(int32),   intent(in) :: at   !< Position of the new row.
   character(len=*), intent(in) :: name !< Its name ('new': a numbered new name).
   integer(int32)               :: k    !< Row.
   if (rows >= MAX_ROWS) return
   do k = rows, at, -1_int32
      names(k + 1_int32) = names(k)
      kinds(k + 1_int32) = kinds(k)
      values(k + 1_int32) = values(k)
   enddo
   if (name == 'new') then
      added = added + 1_int32
      write(names(at), '(A,I0)') 'patch-', added
      kinds(at) = 'no-slip'
      values(at) = 0.0_real64
   else
      names(at) = trim(name)//'-copy'
      kinds(at) = kinds(at - 1_int32)
      values(at) = values(at - 1_int32)
   endif
   rows = rows + 1_int32
   endsubroutine insert

   subroutine delete(at)
   !< Remove row `at` (the others move up).
   integer(int32), intent(in) :: at !< Position.
   integer(int32)             :: k  !< Row.
   do k = at, rows - 1_int32
      names(k) = names(k + 1_int32)
      kinds(k) = kinds(k + 1_int32)
      values(k) = values(k + 1_int32)
   enddo
   rows = rows - 1_int32
   endsubroutine delete

   subroutine cell(name, text)
   !< A row of the tooltip's table: a name and a value.
   character(len=*), intent(in) :: name !< First column.
   character(len=*), intent(in) :: text !< Second column.
   call ig_table_next_row()
   call ig_table_next_column()
   call ig_text_disabled(name)
   call ig_table_next_column()
   call ig_text(text)
   endsubroutine cell

   subroutine keep_entry(k)
   !< In --check: the centre of the open menu's entry `k`.
   integer(int32), intent(in) :: k !< Entry.
   if (check) call test_item_center(entry_at(1, k), entry_at(2, k))
   endsubroutine keep_entry

   subroutine report(what)
   !< In --check: what happened, then the rows.
   character(len=*), intent(in) :: what !< The action.
   integer(int32)               :: k    !< Row.
   write(output_unit, '(A,I0,A)', advance='no') 'frame ', frame, ': '//what//': '
   write(output_unit, '(*(A,:,", "))') (trim(names(k)), k = 1_int32, rows)
   endsubroutine report

   subroutine script(f)
   !< The input of --check, by frame.
   integer(int32), intent(in) :: f    !< Frame.
   real(real64)               :: r(4) !< The open menu's rectangle.
   logical                    :: open !< A menu is open.
   select case (f)
   case (5_int32)                                   ! a right click on 'outlet'
      call test_click(row_at(1, 2), row_at(2, 2), button='right')
   case (12_int32)
      call test_popup_rect(r(1), r(2), r(3), r(4), open)
      write(output_unit, '(A,I0,A,L1)') 'frame ', f, ': right click on outlet, its menu open: ', open
      call test_click(entry_at(1, 2), entry_at(2, 2))  ! Duplicate
   case (20_int32)
      call report('Duplicate')
      call test_click(row_at(1, 1), row_at(2, 1), button='right')
   case (28_int32)
      call test_click(entry_at(1, 4), entry_at(2, 4))  ! Delete 'inlet'
   case (36_int32)
      call report('Delete on inlet')
      call test_click(150.0_real64, 220.0_real64, button='right') ! below the rows: the list's menu
   case (44_int32)
      call test_popup_rect(r(1), r(2), r(3), r(4), open)
      write(output_unit, '(A,I0,A,L1)') 'frame ', f, ': right click below the rows, the list''s menu open: ', open
      call test_click(entry_at(1, 1), entry_at(2, 1))  ! Add a row
   case (52_int32)
      call report('Add a row')
      call test_mouse_move(row_at(1, 1), row_at(2, 1))  ! rest on the first row
   case (53_int32, 60_int32, 75_int32)
      write(output_unit, '(A,I0,A,L1)') 'frame ', f, ': pointer on '//trim(names(1))//', tooltip shown: ', tooltip
   case (80_int32)
      call test_click(link_at(1), link_at(2))
   case (88_int32)
      write(output_unit, '(A,I0,A,L1)') 'frame ', f, ': help link clicked, help shown: ', help
      call test_click(docs_at(1), docs_at(2))
   case (96_int32)
      write(output_unit, '(A,I0,A)') 'frame ', f, ': documentation link clicked, opened: '//test_opened_url()
   endselect
   endsubroutine script
endprogram cb_context_menu
