!< cb_scope_error, cookbook: find a misplaced end (the usage checks name the Fortran calls).
program cb_scope_error
!< cb_scope_error, cookbook: find a misplaced end (the usage checks name the Fortran calls).
use, intrinsic :: iso_fortran_env, only : int32, output_unit
use figure, only : app_object, figure_last_error, FIG_OK, ig_begin, ig_begin_table, ig_end, ig_end_table, &
                   ig_table_next_column, ig_table_next_row, ig_text, ig_tree_node, ig_tree_pop

implicit none
type(app_object) :: app  !< Application (headless).
integer(int32)   :: stat !< Status of a frame.
logical          :: ok   !< A frame drawn.

call app%init_headless(600_int32, 400_int32)
ok = app%next_frame()
call grid(pop=.false.)                         ! ig_tree_pop forgotten
ok = app%next_frame(stat=stat)                 ! mode 'report' (the default): the errors of the frame
if (stat /= FIG_OK) write(output_unit, '(A)') 'report:'//new_line('a')//figure_last_error()
call grid(pop=.true.)
ok = app%next_frame(stat=stat)
if (stat == FIG_OK) write(output_unit, '(A)') 'fixed: no usage error'
call app%set_checks('recover')                 ! repaired where it happens, shown in a notification
call grid(pop=.false.)
ok = app%next_frame(stat=stat)
write(output_unit, '(A,L1,A)') 'recover: stat == FIG_OK is ', stat == FIG_OK, ', the message:'// &
                               new_line('a')//figure_last_error()
call app%destroy()

contains
   subroutine grid(pop)
   !< A table of blocks, a tree in its first cell; `pop` false: the tree's end forgotten.
   logical, intent(in) :: pop !< Close the tree (the right code).

   if (ig_begin('Grid')) then
      if (ig_begin_table('blocks', 2_int32)) then
         call ig_table_next_row()
         call ig_table_next_column()
         if (ig_tree_node('Blocks', default_open=.true.)) then
            call ig_text('inlet')
            call ig_text('outlet')
            if (pop) call ig_tree_pop()        ! only after a true ig_tree_node
         endif
         call ig_table_next_column()
         call ig_text('2 blocks')
         call ig_end_table()
      endif
   endif
   call ig_end()
   endsubroutine grid
endprogram cb_scope_error
