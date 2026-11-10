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
