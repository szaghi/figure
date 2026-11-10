!< figure_test_tables, tables driven by synthetic input, headless: frozen header, sorting, hidden columns, row colours,
!< trees in tables.
program figure_test_tables
!< figure_test_tables, tables driven by synthetic input, headless: frozen header, sorting, hidden columns, row colours,
!< trees in tables.
!<
!< A 200-row table with its header frozen, scrolled by the wheel: the rows move, the header does not. Its order: the
!< first frame asks the default key (column 1, descending), a click on header 2 asks column 2 ascending, a second
!< click descending, and frames without a click ask nothing. A column declared hidden draws nothing until the program
!< shows it. A row colour and a cell colour drawn in the extent of their row and cell. A tree node spanning all
!< columns: its row is as wide as the table and a click in its last column chooses it. The column under the pointer.
!< Usage errors and wrong arguments refused with their status; no frame has a usage error otherwise.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, app_object, figure_last_error, ig_begin, ig_end,        &
                   ig_begin_table, ig_end_table, ig_item_rect, ig_set_next_window, ig_table_column_enabled,        &
                   ig_table_headers_row, ig_table_hovered_column, ig_table_next_column, ig_table_next_row,       &
                   ig_table_row_color, ig_table_setup_column, ig_table_sort, ig_text, ig_text_colored, ig_tree_node, &
                   ig_tree_pop, list_clipper_object
use figure_testing, only : test_click, test_drawn_extent, test_mouse_move, test_wheel

implicit none
integer(int32), parameter :: ROWS = 200_int32                          !< Rows of the long table.
real(real64),   parameter :: NAME_COLOR(4) = [0.20_real64, 0.60_real64, 0.95_real64, 1.0_real64] !< Column 1's text.
real(real64),   parameter :: NOTE_COLOR(4) = [0.95_real64, 0.75_real64, 0.10_real64, 1.0_real64] !< Column 3's text.
real(real64),   parameter :: ROW_COLOR(4) = [0.90_real64, 0.10_real64, 0.20_real64, 1.0_real64]  !< A row's colour.
real(real64),   parameter :: CELL_COLOR(4) = [0.10_real64, 0.80_real64, 0.30_real64, 1.0_real64] !< A cell's colour.
type(app_object)          :: app              !< Application.
type(list_clipper_object) :: clip             !< Rows in view.
logical                   :: ok(16)           !< Per-check outcome.
real(real64)              :: header(4)        !< Rectangle of the last header drawn [pixels].
real(real64)              :: header_y0        !< Top of the header before the wheel.
real(real64)              :: value_x          !< Centre of column 2 [pixels].
real(real64)              :: r(4)             !< A rectangle.
real(real64)              :: node(4)          !< The tree node's rectangle.
real(real64)              :: unit_cell(4)     !< The text in the tree table's last column.
real(real64)              :: row3(4)          !< The text of row 3 of the colour table.
real(real64)              :: row4(4, 2)       !< The texts of row 4 of the colour table, per column.
real(real64)              :: ext(4)           !< A drawn extent.
real(real64)              :: row_ext(4)       !< Extent of the row colour.
real(real64)              :: cell_ext(4)      !< Extent of the cell colour.
logical                   :: row_found        !< The row colour was drawn.
logical                   :: cell_found       !< The cell colour was drawn.
logical                   :: name_found       !< Column 1's text was drawn.
logical                   :: note_found       !< Column 3's text was drawn.
logical                   :: note_before      !< ... on some frame before it was shown.
logical                   :: note_after       !< ... after it was shown.
logical                   :: desc             !< Descending.
logical                   :: clicked          !< The tree node was clicked.
logical                   :: tree_open        !< The tree node is open.
logical                   :: header_still     !< The header kept its place while the rows scrolled.
integer(int32)            :: first_row        !< First row drawn this frame.
integer(int32)            :: col              !< Sort column.
integer(int32)            :: sorts            !< Frames on which a new order was asked.
integer(int32)            :: asked(2, 3)      !< The orders asked: column, descending (1/0); in order.
integer(int32)            :: clicks           !< Clicks on the tree node.
integer(int32)            :: hovered          !< Column under the pointer, in the colour table.
integer(int32)            :: hovered_away     !< ... with the pointer elsewhere.
integer(int32)            :: f                !< Frame.
integer(int32)            :: i                !< Row.
integer(int32)            :: s                !< Status of a frame.
integer(int32)            :: errors           !< Frames with a usage error.
integer(int32)            :: st(10)           !< Statuses of refused calls.
character(len=:), allocatable :: msg(:)       !< Their messages.

ok = .false.
sorts = 0_int32
asked = -1_int32
clicks = 0_int32
errors = 0_int32
header_y0 = -1.0_real64
header_still = .true.
note_before = .false.
note_after = .false.
hovered = -1_int32
hovered_away = -1_int32
value_x = 0.0_real64
st = -1_int32
allocate(character(len=160) :: msg(10))
msg = ''
call app%init_headless(900_int32, 700_int32)
do f = 1_int32, 70_int32
   if (.not. app%next_frame(s)) exit
   if (s /= FIG_OK) errors = errors + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 860.0_real64, 660.0_real64, always=.true.)
   if (ig_begin('Tables')) then
      ! a long table: header frozen, sortable, a hidden column
      if (ig_begin_table('long', 3_int32, height=200.0_real64, freeze_rows=1_int32, sortable=.true., &
                         hideable=.true.)) then
         call ig_table_setup_column('Name', default_sort=.true., descending=.true.)
         call ig_table_setup_column('Value', width=90.0_real64)
         call ig_table_setup_column('Note', hidden=.true.)
         call ig_table_headers_row()
         call ig_item_rect(header(1), header(2), header(3), header(4))
         if (ig_table_sort(col, desc)) then
            sorts = sorts + 1_int32
            if (sorts <= 3_int32) asked(:, sorts) = [col, merge(1_int32, 0_int32, desc)]
         endif
         if (f == 30_int32) call ig_table_column_enabled(3_int32, .true.)
         first_row = 0_int32
         call clip%begin(ROWS)
         do while (clip%step())
            first_row = max(first_row, clip%first) ! the first step is row 1, measured
            do i = clip%first, clip%last
               call ig_table_next_row()
               call ig_table_next_column()
               call ig_text_colored('row', NAME_COLOR)
               call ig_table_next_column()
               call ig_text('1.0')
               if (i == clip%first) then
                  call ig_item_rect(r(1), r(2), r(3), r(4))
                  value_x = 0.5_real64 * (r(1) + r(3))
               endif
               call ig_table_next_column()
               call ig_text_colored('note', NOTE_COLOR)
            enddo
         enddo
         call test_drawn_extent(NAME_COLOR, ext(1), ext(2), ext(3), ext(4), found=name_found)
         call test_drawn_extent(NOTE_COLOR, ext(1), ext(2), ext(3), ext(4), found=note_found)
         if (f < 30_int32 .and. note_found) note_before = .true.
         if (f > 32_int32 .and. note_found) note_after = .true.
         call ig_end_table()
      endif
      ! a hierarchy with values in columns
      if (ig_begin_table('tree', 3_int32)) then
         call ig_table_setup_column('Node')
         call ig_table_setup_column('Value')
         call ig_table_setup_column('Unit')
         call ig_table_headers_row()
         call ig_table_next_row()
         call ig_table_next_column()
         tree_open = ig_tree_node('Root', default_open=.true., span_all_columns=.true., clicked=clicked)
         call ig_item_rect(node(1), node(2), node(3), node(4))
         if (clicked) clicks = clicks + 1_int32
         call ig_table_next_column()
         call ig_text('1.5')
         call ig_table_next_column()
         call ig_text('m')
         call ig_item_rect(unit_cell(1), unit_cell(2), unit_cell(3), unit_cell(4))
         if (tree_open) then
            call ig_table_next_row()
            call ig_table_next_column()
            if (ig_tree_node('Leaf', leaf=.true., span_all_columns=.true.)) call ig_tree_pop()
            call ig_table_next_column()
            call ig_text('2.5')
            call ig_tree_pop()
         endif
         call ig_end_table()
      endif
      ! row and cell colours
      if (ig_begin_table('colours', 2_int32)) then
         if (f == 60_int32) then
            call ig_table_row_color(ROW_COLOR, stat=st(1))                ! no row begun
            msg(1) = figure_last_error()
            if (ig_table_sort(col, desc, stat=st(2))) continue            ! not sortable
            msg(2) = figure_last_error()
            call ig_table_column_enabled(1_int32, .false., stat=st(3))    ! not hideable
            msg(3) = figure_last_error()
         endif
         do i = 1_int32, 4_int32
            call ig_table_next_row()
            if (i == 3_int32) call ig_table_row_color(ROW_COLOR)
            if (i == 4_int32) call ig_table_row_color(CELL_COLOR, cell=2_int32)
            if (i == 4_int32 .and. f == 60_int32) then
               call ig_table_row_color(CELL_COLOR, cell=5_int32, stat=st(4))  ! no such column
               msg(4) = figure_last_error()
               call ig_table_row_color([0.5_real64, 0.5_real64], stat=st(5))  ! two components
               msg(5) = figure_last_error()
            endif
            call ig_table_next_column()
            call ig_text('cell')
            if (i == 3_int32) call ig_item_rect(row3(1), row3(2), row3(3), row3(4))
            if (i == 4_int32) call ig_item_rect(row4(1, 1), row4(2, 1), row4(3, 1), row4(4, 1))
            call ig_table_next_column()
            call ig_text('cell')
            if (i == 4_int32) call ig_item_rect(row4(1, 2), row4(2, 2), row4(3, 2), row4(4, 2))
         enddo
         if (f == 45_int32) hovered_away = ig_table_hovered_column()
         if (f == 55_int32) hovered = ig_table_hovered_column()
         call ig_end_table()
         call test_drawn_extent(ROW_COLOR, row_ext(1), row_ext(2), row_ext(3), row_ext(4), found=row_found)
         call test_drawn_extent(CELL_COLOR, cell_ext(1), cell_ext(2), cell_ext(3), cell_ext(4), found=cell_found)
      endif
      if (f == 60_int32) then
         if (ig_table_sort(col, desc, stat=st(6))) continue               ! outside a table
         msg(6) = figure_last_error()
         if (ig_begin_table('bad', 2_int32, freeze_rows=200_int32, stat=st(7))) call ig_end_table()
         msg(7) = figure_last_error()
         if (ig_begin_table('none', 0_int32, stat=st(10))) call ig_end_table()
         msg(10) = figure_last_error()
         if (ig_begin_table('half', 2_int32, sortable=.true.)) then
            call ig_table_setup_column('one', width=10.0_real64, stretch=1.0_real64, stat=st(8)) ! both
            msg(8) = figure_last_error()
            call ig_table_setup_column('one')
            if (ig_table_sort(col, desc, stat=st(9))) continue            ! column 2 not declared yet
            msg(9) = figure_last_error()
            call ig_table_setup_column('two')
            call ig_end_table()
         endif
      endif
   endif
   call ig_end()
   select case (f)
   case (3_int32)
      header_y0 = header(2)
      call test_mouse_move(value_x, header(2) + 100.0_real64) ! over the rows of the long table
   case (5_int32)
      call test_wheel(-5.0_real64)                            ! towards the user: the rows scroll up
   case (4_int32, 6_int32:11_int32)
      header_still = header_still .and. abs(header(2) - header_y0) < 0.5_real64
   case (12_int32)
      ok(1) = first_row > 1_int32                             ! the rows scrolled
      ok(2) = header_still .and. abs(header(2) - header_y0) < 0.5_real64 ! the header did not
      call test_click(value_x, 0.5_real64 * (header(2) + header(4))) ! header 2: ascending
   case (20_int32)
      call test_click(value_x, 0.5_real64 * (header(2) + header(4))) ! again: descending
   case (40_int32)
      call test_click(unit_cell(3) + 40.0_real64, 0.5_real64 * (node(2) + node(4))) ! the node's row, last column
   case (50_int32)
      call test_mouse_move(0.5_real64 * (row4(1, 2) + row4(3, 2)), 0.5_real64 * (row4(2, 2) + row4(4, 2)))
   endselect
enddo
if (app%next_frame(s)) continue
if (s /= FIG_OK) errors = errors + 1_int32
call app%destroy()

ok(3) = all(asked(:, 1) == [1_int32, 1_int32])                ! the first frame: the default key, descending
ok(4) = all(asked(:, 2) == [2_int32, 0_int32])                ! a header click: column 2 ascending
ok(5) = all(asked(:, 3) == [2_int32, 1_int32]) .and. sorts == 3_int32 ! a second click: descending; nothing else
ok(6) = name_found .and. .not. note_before                    ! a hidden column draws nothing
ok(7) = note_after                                            ! ... until the program shows it
ok(8) = row_found .and. row_ext(2) >= row3(2) - 6.0_real64 .and. row_ext(4) <= row3(4) + 6.0_real64 .and. &
        row_ext(3) > row4(1, 2)                               ! the row colour: row 3, both columns
ok(9) = cell_found .and. cell_ext(1) > row4(3, 1) .and. cell_ext(2) >= row4(2, 2) - 6.0_real64 .and.       &
        cell_ext(4) <= row4(4, 2) + 6.0_real64                ! the cell colour: row 4, column 2 only
ok(10) = node(3) > unit_cell(3) + 40.0_real64                            ! the node's row spans every column
ok(11) = clicks == 1_int32                                    ! ... and a click in its last column chooses it
ok(12) = hovered == 2_int32 .and. hovered_away == 0_int32     ! the column under the pointer
ok(13) = all(st([1, 2, 3, 6, 9]) == int(FIG_ERR_STATE, int32)) .and.                                      &
         msg(1) == 'ig_table_row_color: no row is begun (call it after ig_table_next_row)' .and.         &
         msg(2) == 'ig_table_sort: the table is not sortable (ig_begin_table(..., sortable=.true.))' .and. &
         msg(3) == 'ig_table_column_enabled: the table is not hideable (ig_begin_table(..., hideable=.true.))' .and. &
         msg(6) == 'ig_table_sort: no table is open (call it between ig_begin_table and ig_end_table)' .and. &
         msg(9) == 'ig_table_sort: call it after every column is declared (ig_table_setup_column)'
ok(14) = all(st([4, 5, 7, 8, 10]) == int(FIG_ERR_ARGUMENT, int32)) .and.                                  &
         msg(10) == 'ig_begin_table: columns 0 is out of 1 to 511' .and.                                      &
         msg(4) == 'ig_table_row_color: column 5 is out of 1 to 2' .and.                                 &
         msg(5) == 'ig_table_row_color: rgba has 3 or 4 components' .and.                                &
         msg(7) == 'ig_begin_table: freeze_rows 200 is out of 0 to 127' .and.                            &
         msg(8) == 'ig_table_setup_column: give width or stretch, not both'
ok(15) = errors == 0_int32                                    ! no usage error kept for a frame
ok(16) = value_x > 0.0_real64 .and. header_y0 > 0.0_real64    ! the geometry was read

write(output_unit, '(A,*(L2))') 'figure_test_tables checks:', ok
if (.not. all(ok)) then
   write(output_unit, '(A,I0,A,6(I0,1X),A,I0,A,I0,A,2I3)') 'first row ', first_row, ', orders ', asked, &
      ', sorts ', sorts, ', clicks ', clicks, ', hovered ', hovered, hovered_away
   write(output_unit, '(A,4F8.1,A,4F8.1)') 'node ', node, ' unit ', unit_cell
   write(output_unit, '(A,4F8.1,A,4F8.1)') 'row ext ', row_ext, ' row3 ', row3
   write(output_unit, '(A,4F8.1,A,8F8.1)') 'cell ext ', cell_ext, ' row4 ', row4
   write(output_unit, '(A,10I3)') 'statuses ', st
   do i = 1_int32, 10_int32
      write(output_unit, '(A)') trim(msg(i))
   enddo
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1
endprogram figure_test_tables
