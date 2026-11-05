!< cb_form, cookbook: an input-file editor: text fields, a drop-down list, tooltips, tabs and a table of rows.
program cb_form
!< cb_form, cookbook: an input-file editor: text fields, a drop-down list, tooltips, tabs and a table of rows.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_begin_disabled, ig_begin_tab, ig_begin_tab_bar, ig_begin_table, ig_button, &
                   ig_checkbox, ig_collapsing_header, ig_combo, ig_end, ig_end_disabled, ig_end_tab, ig_end_tab_bar, &
                   ig_end_table, ig_input, ig_input_text, ig_pop_id, ig_push_id, ig_separator, ig_set_next_item_width, &
                   ig_set_next_window, ig_table_headers_row, ig_table_next_column, ig_table_next_row,             &
                   ig_table_setup_column, ig_text, ig_tooltip, ImGuiInputTextFlags_CharsNoBlank

implicit none
integer(int32), parameter :: MAX_ROWS = 8_int32                    !< Rows of the table.
character(len=*), parameter :: FACES(6) = ['i-min', 'i-max', 'j-min', 'j-max', 'k-min', 'k-max'] !< Block faces.
character(len=*), parameter :: KINDS(3) = ['wall   ', 'inflow ', 'outflow']                       !< Conditions.
type(app_object)          :: app                                   !< Application.
character(len=64)         :: grid_file                             !< A file name.
character(len=64)         :: output_dir                            !< Another one.
integer(int32)            :: blocks                                !< An integer.
integer(int32)            :: scheme                                !< A choice.
logical                   :: restart                               !< Gates the next field.
character(len=64)         :: restart_file                          !< Used only with restart.
integer(int32)            :: nrows                                 !< Rows in use.
integer(int32)            :: face(MAX_ROWS)                        !< Table column: a face.
integer(int32)            :: cond(MAX_ROWS)                        !< Table column: a condition.
character(len=16)         :: block_id(MAX_ROWS)                    !< Table column: a block number, as text.
character(len=96)         :: line                                  !< Preview line.
integer(int32)            :: r                                     !< Row.

grid_file = 'CC/cc'
output_dir = ''
blocks = 1_int32
scheme = 2_int32
restart = .false.
restart_file = 'RST/sol'
nrows = 2_int32
face = 1_int32
cond = 1_int32
block_id = '1'
face(2) = 4_int32
cond(2) = 2_int32

call app%init('FIGURE: a form', 900_int32, 560_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 520.0_real64, 540.0_real64)
   if (ig_begin('overset.input')) then
      if (ig_begin_tab_bar('sections')) then
         !region fields
         if (ig_begin_tab('Files')) then
            if (ig_input_text('grid file', grid_file, flags=ImGuiInputTextFlags_CharsNoBlank)) continue
            call ig_tooltip('Root name of the grid files (no blanks)')
            if (ig_input_text('output directory', output_dir, hint='OUT/')) continue
            if (ig_input('blocks', blocks, step=1_int32)) blocks = max(blocks, 1_int32)
            if (ig_combo('scheme', scheme, ['centred 2nd', 'TVD        ', 'WENO 5     '])) continue
            if (ig_collapsing_header('Restart')) then
               if (ig_checkbox('restart from a solution', restart)) continue
               call ig_begin_disabled(.not. restart)     ! greyed out until the box is ticked
               if (ig_input_text('restart file', restart_file)) continue
               call ig_end_disabled()
            endif
            call ig_end_tab()
         endif
         !endregion fields
         !region table
         if (ig_begin_tab('Boundary conditions')) then
            if (ig_begin_table('patches', 3_int32)) then
               call ig_table_setup_column('face', width=90.0_real64)
               call ig_table_setup_column('condition')
               call ig_table_setup_column('block', width=70.0_real64)
               call ig_table_headers_row()
               do r = 1_int32, nrows
                  call ig_push_id(r)                     ! every row repeats the same widgets
                  call ig_table_next_row()
                  call ig_table_next_column()
                  call ig_set_next_item_width(-1.0_real64)
                  if (ig_combo('##face', face(r), FACES)) continue
                  call ig_table_next_column()
                  call ig_set_next_item_width(-1.0_real64)
                  if (ig_combo('##kind', cond(r), KINDS)) continue
                  call ig_table_next_column()
                  call ig_set_next_item_width(-1.0_real64)
                  if (ig_input_text('##block', block_id(r))) continue
                  call ig_pop_id()
               enddo
               call ig_end_table()
            endif
            if (ig_button('add a row') .and. nrows < MAX_ROWS) nrows = nrows + 1_int32
            call ig_end_tab()
         endif
         !endregion table
         call ig_end_tab_bar()
      endif
   endif
   call ig_end()
   call ig_set_next_window(540.0_real64, 10.0_real64, 350.0_real64, 540.0_real64)
   if (ig_begin('Preview')) then                        ! what the editor would write
      call ig_text('[file-set]')
      call ig_text(' grid file = '//trim(grid_file))
      if (len_trim(output_dir) > 0) call ig_text(' output directory = '//trim(output_dir))
      if (restart) call ig_text(' restart file = '//trim(restart_file))
      call ig_separator()
      call ig_text('[boundary-conditions-patches]')
      do r = 1_int32, nrows
         write(line, '(A,I0,A)') ' fullpatch ', r, ' = '//trim(FACES(face(r)))//', '//trim(KINDS(cond(r)))// &
                                ', block '//trim(block_id(r))
         call ig_text(trim(line))
      enddo
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_form
