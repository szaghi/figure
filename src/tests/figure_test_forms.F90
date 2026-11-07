!< figure_test_forms, the form widgets (fields, combo, tooltip, trees, ...) driven by synthetic input, headless.
program figure_test_forms
!< figure_test_forms, the form widgets (fields, combo, tooltip, trees, ...) driven by synthetic input, headless.
!<
!< Each field is clicked, its text selected (end, shift+home) and replaced by typing, then confirmed with enter; the checks read
!< the Fortran variables bound to the fields after the frames have consumed the input.
!<
!< Colour editing: a component field dragged; the swatch clicked opens the picker, and a click in its saturation-value
!< square near the top-left corner (white) picks a near-white colour, the alpha kept; an RGB colour keeps 3 components;
!< a colour of 2 components refused.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_button, ig_combo, ig_end, ig_input, ig_input_text, ig_item_rect,   &
                   ig_set_next_item_width, ig_set_next_window, ig_tooltip, ImGuiInputTextFlags_CharsNoBlank,   &
                   ig_begin_disabled, ig_begin_tab, ig_begin_tab_bar, ig_collapsing_header, ig_end_disabled,   &
                   ig_end_tab, ig_end_tab_bar, ig_pop_id, ig_push_id, ig_text, ig_begin_table, ig_end_table,   &
                   ig_table_headers_row, ig_table_next_column, ig_table_next_row, ig_table_set_column,       &
                   ig_table_setup_column, ig_set_next_item_open, ig_tree_node, ig_tree_pop
use figure, only : ig_color_edit, FIG_ERR_ARGUMENT, FIG_OK
use figure_testing, only : test_click, test_drag, test_item_center, test_key, test_mouse_move, test_popup_rect, test_type, &
                           test_window_rect

implicit none
integer(int32), parameter :: FRAMES = 400_int32 !< Frames run.
integer(int32), parameter :: TIP_FRAME = 230_int32 !< Frame on which the tooltip is looked for.
type(app_object)          :: app                !< Application.
logical                   :: test_passed(30)    !< Per-check outcome.
character(len=16)         :: grid_file          !< A text field.
character(len=4)          :: short              !< A text field of capacity 4.
character(len=12)         :: no_blank           !< A text field that refuses blanks.
character(len=8)          :: hinted             !< An empty field with a hint, never edited.
integer(int32)            :: levels             !< An integer field.
real(real64)              :: at(2, 4)           !< Centre of each field [pixels].
real(real64)              :: x0, y0, x1, y1     !< An item's rectangle.
real(real64)              :: narrow_width       !< Width of the field after ig_set_next_item_width(120).
integer(int32)            :: edits(4)           !< Frames on which each field reported an edit.
integer(int32)            :: hint_edits         !< Frames on which the hinted field reported an edit.
integer(int32)            :: frame              !< Frame counter.
character(len=3)          :: models(3)          !< Combo items.
integer(int32)            :: model              !< Index chosen in the combo.
integer(int32)            :: picks              !< Frames on which the combo reported a pick.
real(real64)              :: combo_at(2)        !< Centre of the combo.
real(real64)              :: help_at(2)         !< Centre of the button with a tooltip.
logical                   :: tip_before         !< The tooltip window existed before the pointer rested on the button.
logical                   :: tip_after          !< ... and after.
logical                   :: hdr_open(2)        !< 'Advanced' header open: before and after its click.
logical                   :: hdr_default        !< A default_open header is open on its first frame.
logical                   :: tab_sel(2, 2)      !< (tab, before/after the click): tabs 'Grid' and 'Files' selected.
real(real64)              :: hdr_at(2)          !< Centre of the 'Advanced' header.
real(real64)              :: tab_at(2)          !< Centre of the 'Files' tab.
real(real64)              :: row_at(2)          !< Centre of the field 'value' in id scope 2.
real(real64)              :: off_at(2)          !< Centre of the disabled button.
character(len=8)          :: row_value(2)       !< The same label in id scopes 1 and 2.
integer(int32)            :: off_presses        !< Presses of the disabled button.
logical                   :: is_open            !< 'Advanced' header open this frame.
logical                   :: basics_open        !< 'Basics' header open this frame.
logical                   :: sel(2)             !< Tabs selected this frame.
integer(int32)            :: r                  !< Row.
logical                   :: table_shown        !< ig_begin_table returned true on the last frame.
character(len=8)          :: faces(3)           !< Table column 1.
integer(int32)            :: conds(3)           !< Table column 2: a combo per row.
character(len=10)         :: values(3)          !< Table column 3: a text field per row.
character(len=8)          :: conditions(2)      !< Combo items.
real(real64)              :: cell(4, 3, 3)      !< (xmin, ymin, xmax, ymax) of the widget in each (column, row).
real(real64)              :: set_x0             !< Left of the text placed with ig_table_set_column(3).
real(real64)              :: value3_at(2)       !< Centre of the field of row 3.
real(real64)              :: body_rect(4)       !< Rectangle of the node 'Body 1' [pixels].
real(real64)              :: leaf_rect(4)       !< Rectangle of the leaf 'block 1' [pixels].
real(real64)              :: group_rect(4)      !< Rectangle of the node 'Group A' in the table's first column.
real(real64)              :: count_rect(4)      !< Rectangle of the text in the second column of its row.
logical                   :: body_open(3)       !< 'Body 1' open: at first, after the arrow, after the label click.
logical                   :: node_click         !< 'Body 1' reported a click this frame.
logical                   :: leaf_click         !< 'block 1' reported a click this frame.
integer(int32)            :: body_clicks        !< Clicks of 'Body 1' since frame 239.
integer(int32)            :: clicks_seen(2)     !< body_clicks after the arrow, after the label.
integer(int32)            :: leaf_clicks        !< Clicks of the leaf.
logical                   :: is_body            !< 'Body 1' open this frame.
logical                   :: is_body2           !< 'Body 2' open this frame.
logical                   :: body2_open(2)      !< 'Body 2': opened by the program, then closed by it.
logical                   :: is_group           !< 'Group A' open this frame.
integer(int32)            :: child_rows         !< Frames on which the child row of 'Group A' was drawn.
integer(int32)            :: tree_depth_ok      !< Frames on which the tree pops balanced (always, if it is right).
real(real64)              :: tint(4)            !< An RGBA colour edited.
real(real64)              :: tint_dragged(4)    !< ... after its red field was dragged.
real(real64)              :: rgb(3)             !< An RGB colour, not touched.
real(real64)              :: bad(2)             !< A colour of 2 components.
real(real64)              :: edit_rect(4)       !< The colour editor's rectangle.
real(real64)              :: popup(4)           !< The picker's rectangle.
logical                   :: popup_open(2)      !< The picker: open after the swatch's click, closed at the end.
integer(int32)            :: colour_changes     !< Frames on which the editor reported a change.
integer(int32)            :: s_colour(3)        !< Statuses of the colour editors.

grid_file = 'CC/cc'
short = ''
no_blank = ''
hinted = ''
levels = 1_int32
edits = 0_int32
hint_edits = 0_int32
narrow_width = 0.0_real64
hdr_open = .true.
hdr_default = .false.
tab_sel = .false.
row_value = ''
off_presses = 0_int32
faces = ['i-min', 'j-max', 'k-min']
conds = 1_int32
values = ''
conditions = ['wall    ', 'inflow  ']
table_shown = .false.
set_x0 = 0.0_real64
models = ['nul', 'spa', 'des']
model = 1_int32
picks = 0_int32
tip_before = .true.
tip_after = .false.
body_open = .true.
body_clicks = 0_int32
clicks_seen = -1_int32
leaf_clicks = 0_int32
node_click = .false.
body2_open = [.false., .true.]
child_rows = 0_int32
tree_depth_ok = 0_int32
call app%init_headless(1100_int32, 600_int32)
do frame = 1_int32, FRAMES
   if (.not. app%next_frame()) error stop 'figure_test_forms: next_frame returned false in headless mode'
   call ig_set_next_window(20.0_real64, 20.0_real64, 500.0_real64, 400.0_real64, always=.true.)
   if (ig_begin('Form')) then
      if (ig_input_text('grid file', grid_file)) edits(1) = edits(1) + 1_int32
      call test_item_center(at(1, 1), at(2, 1))
      if (ig_input_text('short', short)) edits(2) = edits(2) + 1_int32
      call test_item_center(at(1, 2), at(2, 2))
      if (ig_input_text('no blank', no_blank, flags=ImGuiInputTextFlags_CharsNoBlank)) edits(3) = edits(3) + 1_int32
      call test_item_center(at(1, 3), at(2, 3))
      if (ig_input('levels', levels)) edits(4) = edits(4) + 1_int32
      call test_item_center(at(1, 4), at(2, 4))
      if (ig_input_text('hinted', hinted, hint='root name')) hint_edits = hint_edits + 1_int32
      call ig_set_next_item_width(120.0_real64)
      if (ig_input_text('##narrow', hinted)) continue
      call ig_item_rect(x0, y0, x1, y1)
      narrow_width = x1 - x0
      if (ig_combo('turbulence', model, models)) picks = picks + 1_int32
      call test_item_center(combo_at(1), combo_at(2))
      if (ig_button('help')) continue
      call ig_tooltip('what this parameter does')
      call test_item_center(help_at(1), help_at(2))
   endif
   call ig_end()
   call ig_set_next_window(540.0_real64, 20.0_real64, 240.0_real64, 560.0_real64, always=.true.)
   if (ig_begin('Groups')) then
      is_open = ig_collapsing_header('Advanced')
      call test_item_center(hdr_at(1), hdr_at(2))
      if (is_open) call ig_text('hidden until opened')
      if (frame == 1_int32) hdr_default = ig_collapsing_header('Basics', default_open=.true.)
      if (frame > 1_int32) basics_open = ig_collapsing_header('Basics', default_open=.true.)
      sel = .false.
      if (ig_begin_tab_bar('sections')) then
         sel(1) = ig_begin_tab('Grid')
         if (sel(1)) then
            call ig_text('grid parameters')
            call ig_end_tab()
         endif
         sel(2) = ig_begin_tab('Files')
         call test_item_center(tab_at(1), tab_at(2))
         if (sel(2)) then
            call ig_text('file parameters')
            call ig_end_tab()
         endif
         call ig_end_tab_bar()
      endif
      do r = 1_int32, 2_int32                       ! the same label twice: told apart by the id scope
         call ig_push_id(r)
         if (ig_input_text('value', row_value(r))) continue
         if (r == 2_int32) call test_item_center(row_at(1), row_at(2))
         call ig_pop_id()
      enddo
      call ig_begin_disabled()
      if (ig_button('disabled')) off_presses = off_presses + 1_int32
      call test_item_center(off_at(1), off_at(2))
      call ig_end_disabled()
   endif
   call ig_end()
   call ig_set_next_window(20.0_real64, 430.0_real64, 500.0_real64, 160.0_real64, always=.true.)
   if (ig_begin('Table')) then
      table_shown = ig_begin_table('patches', 3_int32)
      if (table_shown) then
         call ig_table_setup_column('face', width=60.0_real64)
         call ig_table_setup_column('condition')
         call ig_table_setup_column('value')
         call ig_table_headers_row()
         do r = 1_int32, 3_int32
            call ig_push_id(r)                      ! one id scope per row: the widgets repeat their labels
            call ig_table_next_row()
            call ig_table_next_column()
            call ig_text(trim(faces(r)))
            call ig_item_rect(cell(1, 1, r), cell(2, 1, r), cell(3, 1, r), cell(4, 1, r))
            call ig_table_next_column()
            call ig_set_next_item_width(-1.0_real64)
            if (ig_combo('##condition', conds(r), conditions)) continue
            call ig_item_rect(cell(1, 2, r), cell(2, 2, r), cell(3, 2, r), cell(4, 2, r))
            call ig_table_next_column()
            call ig_set_next_item_width(-1.0_real64)
            if (ig_input_text('##value', values(r))) continue
            call ig_item_rect(cell(1, 3, r), cell(2, 3, r), cell(3, 3, r), cell(4, 3, r))
            if (r == 3_int32) call test_item_center(value3_at(1), value3_at(2))
            call ig_pop_id()
         enddo
         call ig_table_next_row()
         call ig_table_set_column(3_int32)          ! straight to the third cell
         call ig_text('set')
         call ig_item_rect(set_x0, y0, x1, y1)
         call ig_end_table()
      endif
   endif
   call ig_end()
   call ig_set_next_window(800.0_real64, 20.0_real64, 280.0_real64, 560.0_real64, always=.true.)
   if (ig_begin('Tree')) then
      is_body = ig_tree_node('Body 1, chimera blocks', clicked=node_click)
      call ig_item_rect(body_rect(1), body_rect(2), body_rect(3), body_rect(4))
      if (node_click) body_clicks = body_clicks + 1_int32
      if (is_body) then
         if (ig_tree_node('block 1', leaf=.true., clicked=leaf_click)) then
            call ig_item_rect(leaf_rect(1), leaf_rect(2), leaf_rect(3), leaf_rect(4))
            if (leaf_click) leaf_clicks = leaf_clicks + 1_int32
            call ig_tree_pop()
         endif
         call ig_tree_pop()
      endif
      if (frame == 1_int32) call ig_set_next_item_open(.true.)                ! opened by the program, once
      if (frame == 330_int32) call ig_set_next_item_open(.false., always=.true.) ! closed by the program
      is_body2 = ig_tree_node('Body 2')
      if (is_body2) then
         call ig_text('patch 1')
         call ig_tree_pop()
      endif
      if (frame == 2_int32) body2_open(1) = is_body2
      if (frame == 331_int32) body2_open(2) = is_body2
      if (ig_begin_table('blocks', 2_int32)) then
         call ig_table_next_row()
         call ig_table_next_column()
         is_group = ig_tree_node('Group A', span_full_width=.true.)
         call ig_item_rect(group_rect(1), group_rect(2), group_rect(3), group_rect(4))
         call ig_table_next_column()
         call ig_text('3 blocks')
         call ig_item_rect(count_rect(1), count_rect(2), count_rect(3), count_rect(4))
         if (is_group) then
            call ig_table_next_row()
            call ig_table_next_column()
            call ig_text('block 7')
            child_rows = child_rows + 1_int32
            call ig_tree_pop()
         endif
         call ig_end_table()
      endif
      if (ig_tree_node('Body 3', leaf=.true.)) call ig_tree_pop()
      tree_depth_ok = tree_depth_ok + 1_int32
   endif
   call ig_end()
   select case (frame)
   case (2_int32)
      call replace(1_int32, 'MESH/grid')
   case (20_int32)
      call replace(2_int32, 'abcdefg')                  ! longer than the capacity (4)
   case (38_int32)
      call replace(3_int32, 'a b c')                    ! blanks refused
   case (56_int32)
      call replace(4_int32, '42')
   case (74_int32)
      call test_click(combo_at(1), combo_at(2))        ! open the combo, then down + enter: the second item
   case (80_int32)
      call test_key('down')
      call test_key('enter')
   case (95_int32)
      call test_window_rect('##Tooltip_00', x0, y0, x1, y1, found=tip_before)
      call test_mouse_move(help_at(1), help_at(2))     ! rest on the button: the tooltip shows after the delay
   case (TIP_FRAME)
      call test_window_rect('##Tooltip_00', x0, y0, x1, y1, found=tip_after)
   case (239_int32)
      body_open(1) = is_body
      body_clicks = 0_int32
      call test_click(body_rect(1) + 6.0_real64, 0.5_real64 * (body_rect(2) + body_rect(4)))  ! the arrow
   case (260_int32)
      body_open(2) = is_body
      clicks_seen(1) = body_clicks
      call test_click(0.5_real64 * (body_rect(1) + body_rect(3)), 0.5_real64 * (body_rect(2) + body_rect(4))) ! label
   case (290_int32)
      body_open(3) = is_body
      clicks_seen(2) = body_clicks
      call test_click(leaf_rect(1) + 6.0_real64, 0.5_real64 * (leaf_rect(2) + leaf_rect(4)))  ! where an arrow would be
   case (360_int32)
      call test_click(group_rect(1) + 6.0_real64, 0.5_real64 * (group_rect(2) + group_rect(4))) ! the arrow, in a table
   case (140_int32)
      hdr_open(1) = is_open
      tab_sel(:, 1) = sel
      call test_click(hdr_at(1), hdr_at(2))
   case (146_int32)
      call test_click(tab_at(1), tab_at(2))           ! a tab: test_click lets the pointer rest on it first
   case (152_int32)
      call test_click(row_at(1), row_at(2))
      call test_type('two')
      call test_key('enter')
   case (166_int32)
      call test_click(off_at(1), off_at(2))
   case (200_int32)
      call test_click(value3_at(1), value3_at(2))
      call test_type('1.5')
      call test_key('enter')
   case (175_int32)
      hdr_open(2) = is_open
      tab_sel(:, 2) = sel
   endselect
enddo
call colour_frames()
call app%destroy()

test_passed(1) = grid_file == 'MESH/grid' .and. edits(1) > 0_int32            ! typed text, written back
test_passed(2) = short == 'abcd'                                               ! cut at the capacity
test_passed(3) = no_blank == 'abc'                                             ! CharsNoBlank
test_passed(4) = levels == 42_int32 .and. edits(4) > 0_int32                   ! integer field
test_passed(5) = hinted == '' .and. hint_edits == 0_int32                      ! a hint is not a value
test_passed(6) = abs(narrow_width - 120.0_real64) < 0.5_real64                 ! ig_set_next_item_width
test_passed(7) = model == 2_int32 .and. picks == 1_int32                      ! combo: picked by keyboard, once
test_passed(8) = .not. tip_before                                             ! no tooltip before resting on it
test_passed(9) = tip_after                                                    ! the tooltip after resting on it
test_passed(10) = .not. hdr_open(1) .and. hdr_open(2)                         ! header: closed, opened by a click
test_passed(11) = hdr_default                                                 ! default_open: open at once
test_passed(12) = tab_sel(1, 1) .and. .not. tab_sel(2, 1)                     ! the first tab selected at first
test_passed(13) = tab_sel(2, 2) .and. .not. tab_sel(1, 2)                     ! the clicked tab selected after
test_passed(14) = row_value(1) == '' .and. row_value(2) == 'two'              ! id scopes: only row 2 edited
test_passed(15) = off_presses == 0_int32                                      ! a disabled button ignores clicks
test_passed(16) = table_shown                                                 ! the table is drawn
test_passed(17) = all(cell(1, 2, :) >= cell(3, 1, :)) .and. all(cell(1, 3, :) >= cell(3, 2, :)) .and. &
                  all(cell(2, :, 2) >= cell(4, :, 1)) .and. all(cell(2, :, 3) >= cell(4, :, 2)) ! cells left to right, rows down
test_passed(18) = abs(set_x0 - cell(1, 3, 1)) < 1.0_real64                    ! ig_table_set_column(3): column 3
test_passed(19) = values(3) == '1.5' .and. values(1) == '' .and. values(2) == '' ! one row's field edited
test_passed(20) = .not. body_open(1) .and. body_open(2) .and. clicks_seen(1) == 0_int32 ! the arrow opens, no click
test_passed(21) = body_open(3) .and. clicks_seen(2) == 1_int32                 ! the label: a click, still open
test_passed(22) = leaf_clicks == 1_int32                                       ! a leaf has no arrow: a click there is a click
test_passed(23) = body2_open(1) .and. .not. body2_open(2)                      ! opened, then closed, by the program
test_passed(24) = child_rows > 0_int32 .and. child_rows < FRAMES - 360_int32   ! in a table: opened by its arrow
test_passed(25) = group_rect(3) <= count_rect(1) + 0.5_real64 .and. group_rect(1) < count_rect(1) ! in the first column
test_passed(26) = tree_depth_ok == FRAMES                                     ! the tree drawn on every frame
test_passed(27) = tint_dragged(1) > 0.2_real64 + 20.0_real64 / 255.0_real64 .and. &   ! red dragged up, the others kept
                  all(abs(tint_dragged(2:4) - [0.4_real64, 0.8_real64, 1.0_real64]) < 1.0e-6_real64)
test_passed(28) = popup_open(1) .and. .not. popup_open(2) .and. all(tint(1:3) > 0.9_real64) .and. & ! picked, the
                  abs(tint(4) - 1.0_real64) < 1.0e-6_real64                              ! alpha kept; closed
test_passed(29) = colour_changes > 0_int32 .and. all(s_colour(1:2) == FIG_OK) .and. &      ! an untouched colour keeps
                  all(rgb == [0.1_real64, 0.2_real64, 0.3_real64])                        ! its double precision bits
test_passed(30) = s_colour(3) == FIG_ERR_ARGUMENT                                         ! 2 components refused

write(output_unit, '(A,*(L2))') 'figure_test_forms checks:', test_passed
if (.not. all(test_passed)) then
   write(output_unit, '(A)') 'grid_file "'//trim(grid_file)//'", short "'//trim(short)//'", no_blank "'// &
                             trim(no_blank)//'"'
   write(output_unit, '(A,I0,A,F0.1,A,4(I0,1X))') 'levels ', levels, ', narrow width ', narrow_width, ', edits ', edits
   write(output_unit, '(A,2L2,A,L2,A,4L2,A,A,A,A,A,I0)') 'header', hdr_open, ', default', hdr_default, ', tabs', &
         tab_sel, ', rows "', trim(row_value(1)), '" "', trim(row_value(2)), '", disabled presses ', off_presses
   write(output_unit, '(A,3(1X,A),A,F0.1,A,F0.1)') 'table values', (trim(values(r)), r = 1_int32, 3_int32), &
         ', set at x ', set_x0, ', column 3 at x ', cell(1, 3, 1)
   write(output_unit, '(A,3L2,A,2(I0,1X),A,I0,A,2L2,A,I0,A,8(F0.1,1X))') 'tree: Body 1 open', body_open, &
         ', clicks', clicks_seen, ', leaf clicks ', leaf_clicks, ', Body 2', body2_open, ', child rows ', child_rows, &
         ', group/count rects ', group_rect, count_rect
   write(output_unit, '(A,I0,A,I0,A,2L2)') 'model ', model, ', picks ', picks, ', tooltip before/after', tip_before, &
                                          tip_after
   write(output_unit, '(A,4F7.3,A,4F7.3,A,2L2,A,4F7.1,A,I0,A,3I3)') 'colour dragged', tint_dragged, ', picked', tint, &
         ', picker open', popup_open, ', picker', popup, ', changes ', colour_changes, ', statuses', s_colour
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine colour_frames()
   !< The colour editors, in a window of their own, after the forms: drag the red field, then pick from the picker.
   integer(int32) :: f    !< Frame.
   real(real64)   :: h    !< The editor's height: a frame's, and the swatch's side.
   logical        :: open !< A popup is open.

   tint = [0.2_real64, 0.4_real64, 0.8_real64, 1.0_real64]
   tint_dragged = 0.0_real64
   rgb = [0.1_real64, 0.2_real64, 0.3_real64]
   bad = 0.0_real64
   popup_open = [.false., .true.]
   colour_changes = 0_int32
   edit_rect = 0.0_real64
   do f = 1_int32, 60_int32
      if (.not. app%next_frame()) exit
      call ig_set_next_window(800.0_real64, 20.0_real64, 280.0_real64, 200.0_real64, always=.true.)
      if (ig_begin('Colour')) then
         if (ig_color_edit('##tint', tint, stat=s_colour(1))) colour_changes = colour_changes + 1_int32
         call ig_item_rect(edit_rect(1), edit_rect(2), edit_rect(3), edit_rect(4))
         if (ig_color_edit('rgb', rgb, stat=s_colour(2))) colour_changes = colour_changes + 1_int32
         if (ig_color_edit('bad', bad, stat=s_colour(3))) colour_changes = colour_changes + 1_int32
      endif
      call ig_end()
      h = edit_rect(4) - edit_rect(2)
      select case (f)
      case (5_int32)  ! drag the red field (the first) 40 pixels right: about 40 steps of 1/255
         call test_drag(edit_rect(1) + 8.0_real64, edit_rect(2) + 0.5_real64 * h, edit_rect(1) + 48.0_real64, &
                        edit_rect(2) + 0.5_real64 * h)
      case (20_int32) ! click the swatch, the rightmost square (the label is hidden)
         tint_dragged = tint
         call test_click(edit_rect(3) - 0.5_real64 * h, edit_rect(2) + 0.5_real64 * h)
      case (30_int32) ! the picker is open: click its saturation-value square near the top-left corner (white)
         call test_popup_rect(popup(1), popup(2), popup(3), popup(4), popup_open(1))
         call test_click(popup(1) + 12.0_real64, popup(2) + 12.0_real64)
      case (45_int32) ! close it
         call test_key('escape')
      case (60_int32)
         call test_popup_rect(popup(1), popup(2), popup(3), popup(4), open)
         popup_open(2) = open
      endselect
   enddo
   endsubroutine colour_frames

   subroutine replace(k, text)
   !< Click field k, select its text, type `text`, confirm with enter. The text is selected with end, then shift+home,
   !< which every platform reads the same way (select-all is ctrl+a, but cmd+a on macOS).
   integer(int32),   intent(in) :: k    !< Field.
   character(len=*), intent(in) :: text !< New text.

   call test_click(at(1, k), at(2, k))
   call test_key('end')
   call test_key('shift', down=.true.)
   call test_key('home')
   call test_key('shift', down=.false.)
   call test_type(text)
   call test_key('enter')
   endsubroutine replace
endprogram figure_test_forms
