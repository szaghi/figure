!< cb_table_sort, cookbook: a sortable table with a fixed header, its rows drawn through a clipper.
program cb_table_sort
!< cb_table_sort, cookbook: a sortable table with a fixed header, its rows drawn through a clipper.
!<
!< The 200 blocks of a grid, one row each: block, body, cells, residual, and a patch column hidden at first (the
!< headers' context menu shows it). A click on a header sorts by that column, a second click the other way; the program
!< sorts a permutation of the row indices, the data stay where they are. The header stays in view while the rows
!< scroll. A block whose residual is above the tolerance has its row coloured and its residual marked with '!'.
!< `cb_table_sort --check` opens no window: it clicks the headers, turns the wheel, and prints what it sees.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_begin_table, ig_em, ig_end, ig_end_table, ig_item_rect,               &
                   ig_set_next_window, ig_table_headers_row, ig_table_next_column, ig_table_next_row,             &
                   ig_table_row_color, ig_table_setup_column, ig_table_sort, ig_text, ig_text_disabled,           &
                   list_clipper_object
use figure_testing, only : test_click, test_mouse_move, test_wheel
implicit none
integer(int32),   parameter :: ROWS = 200_int32                                  !< Blocks.
character(len=*), parameter :: BODY(3) = ['wing    ', 'fuselage', 'flap    ']  !< Bodies.
character(len=*), parameter :: PATCH(3) = ['wall    ', 'overset ', 'symmetry'] !< Patches.
real(real64),     parameter :: TOLERANCE = 1.0e-4_real64                          !< Residual tolerance.
real(real64),     parameter :: WARN(4) = [0.85_real64, 0.45_real64, 0.10_real64, 0.35_real64] !< A row above it.
type(app_object)            :: app             !< Application.
type(list_clipper_object)   :: clip            !< Only the rows in view.
character(len=8)            :: bodies(ROWS)    !< Each block's body.
character(len=8)            :: patches(ROWS)   !< ... its first patch.
integer(int32)              :: cells(ROWS)     !< ... its cells.
real(real64)                :: residual(ROWS)  !< ... its residual.
integer(int32)              :: order(ROWS)     !< The rows in the order shown: indices into the data.
integer(int32)              :: column          !< The sort column.
integer(int32)              :: i               !< Row shown.
integer(int32)              :: k               !< Block.
integer(int32)              :: frame           !< Frame counter.
logical                     :: descending      !< Largest first.
logical                     :: check           !< --check: headless, scripted input.
character(len=16)           :: arg             !< First argument.
character(len=32)           :: text            !< A value written.
real(real64)                :: header(4)       !< The headers row's rectangle (--check).
real(real64)                :: cells_x         !< Centre of the cells column (--check).
real(real64)                :: header_top      !< The header's top before the wheel (--check).
integer(int32)              :: first_shown     !< The first row in view (--check).
!run cb_table_sort ./cb_table_sort --check
do k = 1_int32, ROWS                                ! a grid: deterministic values
   bodies(k) = BODY(1_int32 + mod(k, 3_int32))
   patches(k) = PATCH(1_int32 + mod(7_int32 * k, 3_int32))
   cells(k) = 4096_int32 + 128_int32 * mod(37_int32 * k * k + 11_int32 * k, 900_int32)
   residual(k) = 10.0_real64**(-3.0_real64 - 0.1_real64 * real(mod(13_int32 * k, 40_int32), real64))
enddo
order = [(k, k = 1_int32, ROWS)]
column = 1_int32
descending = .false.
header = 0.0_real64
cells_x = 0.0_real64
header_top = 0.0_real64
first_shown = 0_int32
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(640_int32, 420_int32)
else
   call app%init('FIGURE: a sortable table', 640_int32, 420_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 400.0_real64)
   if (ig_begin('Blocks')) then
      !region table
      if (ig_begin_table('blocks', 5_int32, height=ig_em(18.0_real64), freeze_rows=1_int32, sortable=.true., &
                         hideable=.true.)) then
         call ig_table_setup_column('block', width=ig_em(4.0_real64), default_sort=.true.)
         call ig_table_setup_column('body', stretch=1.0_real64)
         call ig_table_setup_column('cells', width=ig_em(6.0_real64), descending=.true.) ! largest first
         call ig_table_setup_column('residual', width=ig_em(7.0_real64), descending=.true.)
         call ig_table_setup_column('patch', width=ig_em(6.0_real64), hidden=.true.)
         call ig_table_headers_row()                           ! frozen: it stays while the rows scroll
         if (check) call ig_item_rect(header(1), header(2), header(3), header(4))
         if (ig_table_sort(column, descending)) call sort_rows(column, descending) ! a new order asked
         first_shown = 0_int32
         call clip%begin(ROWS)
         do while (clip%step())
            first_shown = max(first_shown, clip%first)
            do i = clip%first, clip%last
               k = order(i)                                    ! the row shown i is block k
               call ig_table_next_row()
               if (residual(k) > TOLERANCE) call ig_table_row_color(WARN)
               call ig_table_next_column()
               write(text, '(I0)') k
               call ig_text(trim(text))
               call ig_table_next_column()
               call ig_text(trim(bodies(k)))
               call ig_table_next_column()
               write(text, '(I0)') cells(k)
               call ig_text(trim(text))
               if (check .and. i == clip%first) call keep_cells_x()
               call ig_table_next_column()
               write(text, '(ES9.2)') residual(k)
               if (residual(k) > TOLERANCE) then
                  call ig_text('! '//trim(adjustl(text)))      ! a mark with the colour, not the colour alone
               else
                  call ig_text_disabled(trim(adjustl(text)))
               endif
               call ig_table_next_column()
               call ig_text(trim(patches(k)))
            enddo
         enddo
         call ig_end_table()
      endif
      !endregion table
   endif
   call ig_end()
   if (check) then
      call script(frame)
      if (frame == 60_int32) exit
   endif
enddo
call app%destroy()
contains
   !region sort
   subroutine sort_rows(key, down)
   !< Sort the permutation `order` by column `key` (`down`: largest first); the data do not move. An insertion sort,
   !< stable: rows equal in `key` keep the order they had, so a second key is the column sorted before.
   integer(int32), intent(in) :: key  !< Column, 1-based (0: no order, the blocks' own).
   logical,        intent(in) :: down !< Descending.
   integer(int32)             :: a    !< Position.
   integer(int32)             :: b    !< Position.
   integer(int32)             :: moving !< The index being placed.

   if (key == 0_int32) then
      order = [(a, a = 1_int32, ROWS)]
      return
   endif
   do a = 2_int32, ROWS
      moving = order(a)
      b = a - 1_int32
      do while (b >= 1_int32)
         if (.not. before(moving, order(b), key, down)) exit
         order(b + 1_int32) = order(b)
         b = b - 1_int32
      enddo
      order(b + 1_int32) = moving
   enddo
   endsubroutine sort_rows

   logical function before(p, q, key, down)
   !< Block `p` goes before block `q` in the order of column `key`.
   integer(int32), intent(in) :: p    !< A block.
   integer(int32), intent(in) :: q    !< Another block.
   integer(int32), intent(in) :: key  !< Column.
   logical,        intent(in) :: down !< Descending.

   select case (key)
   case (1_int32)
      before = merge(p > q, p < q, down)
   case (2_int32)
      before = merge(bodies(p) > bodies(q), bodies(p) < bodies(q), down)
   case (3_int32)
      before = merge(cells(p) > cells(q), cells(p) < cells(q), down)
   case (4_int32)
      before = merge(residual(p) > residual(q), residual(p) < residual(q), down)
   case default
      before = merge(patches(p) > patches(q), patches(p) < patches(q), down)
   endselect
   endfunction before
   !endregion sort

   subroutine keep_cells_x()
   !< In --check: the centre of the cells column, from the cell just drawn.
   real(real64) :: r(4) !< The cell's text.
   call ig_item_rect(r(1), r(2), r(3), r(4))
   cells_x = 0.5_real64 * (r(1) + r(3))
   endsubroutine keep_cells_x

   subroutine report(what)
   !< In --check: what happened, the order asked and the first rows shown.
   character(len=*), intent(in) :: what !< The action.
   write(output_unit, '(A,I0,A,I0,A,L1,A,5(I0,:,", "))') 'frame ', frame, ': '//what//': column ', column, &
      ', descending ', descending, '; blocks ', order(1:5)
   endsubroutine report

   subroutine script(f)
   !< The input of --check, by frame.
   integer(int32), intent(in) :: f !< Frame.
   select case (f)
   case (5_int32)
      call report('first frame, the default order')
      call test_click(cells_x, 0.5_real64 * (header(2) + header(4)))  ! the header 'cells'
   case (13_int32)
      call report('click on cells')
      write(output_unit, '(A,I0,A,I0)') '   cells of the first row: ', cells(order(1)), ', the largest: ', maxval(cells)
      call test_click(cells_x, 0.5_real64 * (header(2) + header(4)))  ! again: the other way
   case (21_int32)
      call report('second click on cells')
      header_top = header(2)
      call test_mouse_move(cells_x, header(4) + 120.0_real64)         ! over the rows
   case (23_int32)
      call test_wheel(-6.0_real64)                                    ! scroll them
   case (40_int32)
      write(output_unit, '(A,I0,A,I0,A,L1)') 'frame ', f, ': the wheel scrolled to row ', first_shown, &
         ', the header in place: ', abs(header(2) - header_top) < 0.5_real64
   endselect
   endsubroutine script
endprogram cb_table_sort
