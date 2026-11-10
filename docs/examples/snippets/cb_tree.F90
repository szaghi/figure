!< cb_tree, cookbook: a hierarchy of bodies and blocks with values in columns, and a node with thousands of children.
program cb_tree
!< cb_tree, cookbook: a hierarchy of bodies and blocks with values in columns, and a node with thousands of children.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_begin_child, ig_begin_table, ig_end, ig_end_child, ig_end_table,       &
                   ig_pop_id, ig_push_id, ig_separator, ig_set_next_window, ig_table_headers_row,                &
                   ig_table_next_column, ig_table_next_row, ig_table_setup_column, ig_text, ig_text_disabled,  &
                   ig_tree_node, ig_tree_pop, list_clipper_object

implicit none
integer(int32),   parameter :: BODIES = 3_int32                                       !< Bodies.
character(len=*), parameter :: BODY(BODIES) = ['wing    ', 'fuselage', 'flap    '] !< Their names.
integer(int32),   parameter :: FIRST(BODIES) = [1_int32, 4_int32, 6_int32]            !< First block of each body.
integer(int32),   parameter :: LAST(BODIES) = [3_int32, 5_int32, 6_int32]             !< Last block of each body.
integer(int32),   parameter :: CELLS(6) = [262144_int32, 131072_int32, 98304_int32, 524288_int32, 65536_int32, &
                                           32768_int32]                                 !< Cells of each block.
character(len=*), parameter :: PATCH(6) = ['wall    ', 'wall    ', 'overset ', 'wall    ', 'symmetry', 'wall    ']
integer(int32),   parameter :: BACKGROUND = 20000_int32                                 !< Blocks of the background grid.
type(app_object)            :: app      !< Application.
type(list_clipper_object)   :: clip     !< Only the rows in view.
integer(int32)              :: chosen   !< Block chosen (0: none).
integer(int32)              :: b        !< Body.
integer(int32)              :: k        !< Block.
logical                     :: clicked  !< A node's label was clicked.
logical                     :: open     !< A body's node is open.
character(len=48)           :: line     !< A formatted value.

chosen = 0_int32
call app%init('FIGURE: a tree with values in columns', 620_int32, 420_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 600.0_real64, 400.0_real64)
   if (ig_begin('Case')) then
      if (ig_begin_table('grids', 3_int32)) then
         call ig_table_setup_column('grid')
         call ig_table_setup_column('cells', width=90.0_real64)
         call ig_table_setup_column('first patch', width=110.0_real64)
         call ig_table_headers_row()
         do b = 1_int32, BODIES
            call ig_table_next_row()
            call ig_table_next_column()
            open = ig_tree_node(trim(BODY(b)), default_open=(b == 1_int32), span_all_columns=.true.)
            call ig_table_next_column()
            write(line, '(I0)') sum(CELLS(FIRST(b):LAST(b)))     ! the body's values, open or not
            call ig_text(trim(line))
            if (open) then
               do k = FIRST(b), LAST(b)                          ! the children: one row each
                  call ig_push_id(k)
                  call ig_table_next_row()
                  call ig_table_next_column()
                  write(line, '(A,I0)') 'block ', k
                  if (ig_tree_node(trim(line), leaf=.true., selected=(k == chosen), span_all_columns=.true., &
                                   clicked=clicked)) call ig_tree_pop()
                  if (clicked) chosen = k                         ! a click on the row chooses, the arrow expands
                  call ig_table_next_column()
                  write(line, '(I0)') CELLS(k)
                  call ig_text(trim(line))
                  call ig_table_next_column()
                  call ig_text(trim(PATCH(k)))
                  call ig_pop_id()
               enddo
               call ig_tree_pop()                                ! only after a true node
            endif
         enddo
         call ig_end_table()
      endif
      if (chosen > 0_int32) then
         write(line, '(A,I0,A,I0,A)') 'block ', chosen, ' chosen: ', CELLS(chosen), ' cells'
         call ig_text(trim(line))
      else
         call ig_text_disabled('click a block to choose it')
      endif
      call ig_separator()
      if (ig_tree_node('background, 20000 blocks')) then
         if (ig_begin_child('background', height=110.0_real64)) then
            call clip%begin(BACKGROUND)                           ! children of equal height: only those in view
            do while (clip%step())
               do k = clip%first, clip%last
                  write(line, '(A,I0)') 'block ', k
                  if (ig_tree_node(trim(line), leaf=.true.)) call ig_tree_pop()
               enddo
            enddo
         endif
         call ig_end_child()
         call ig_tree_pop()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_tree
