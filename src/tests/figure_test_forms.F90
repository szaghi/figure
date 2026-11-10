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
!<
!< Shortcuts (routed): two windows bind ctrl+s, only the focused one's fires; a 'global' chord fires whichever has
!< the focus; a text field being edited holds 'down' from its window and gives 'up' to its 'item' call; a chord with
!< `repeat` fires again while held, one without fires once; a button owning ctrl+r is pressed by it in its window
!< only; a call outside every window fires unless a focused window routes the same chord.
!<
!< Item status (`ig_last_item`): a text field typed into on three frames and left by a click elsewhere reports edited
!< on those three frames and deactivated_after_edit on one frame after them; a button hovered (at once, and after the
!< 'normal' delay), clicked once (no double click), clicked twice (one double click), right-clicked, held
!< (`ig_any_item_active`); a snapshot taken before a tooltip keeps the button's status after the tooltip and another
!< item are drawn; a combo's pick is an edit; a tree node's arrow toggles it open; a row scrolled out of a child
!< region is not visible.
!<
!< Scrolling and focus: in a 100-pixel child of 200 rows, `ig_scroll_here(0.5)` after row 150 puts it at the child's
!< centre on the next frame (not on the same one); in a clipped list of 1000 rows, a row not drawn is reached by
!< `ig_scroll_to_pos` and drawn at the centre on the next frame; `ig_set_scroll(y=0)` goes back to the top; a bad
!< ratio, axis or offset is refused; `ig_focus_here` makes the next field take typed keys without a click; a modal's
!< `ig_default_focus` button has the focus when the modal appears and enter presses it.
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_button, ig_combo, ig_end, ig_input, ig_input_text, ig_item_rect,   &
                   ig_set_next_item_width, ig_set_next_window, ig_tooltip, ImGuiInputTextFlags_CharsNoBlank,   &
                   ig_begin_disabled, ig_begin_tab, ig_begin_tab_bar, ig_collapsing_header, ig_end_disabled,   &
                   ig_end_tab, ig_end_tab_bar, ig_pop_id, ig_push_id, ig_text, ig_begin_table, ig_end_table,   &
                   ig_table_headers_row, ig_table_next_column, ig_table_next_row, ig_table_set_column,       &
                   ig_table_setup_column, ig_set_next_item_open, ig_tree_node, ig_tree_pop
use figure, only : ig_color_edit, ig_set_next_item_shortcut, ig_shortcut, FIG_ERR_ARGUMENT, FIG_OK
use figure, only : ig_any_item_active, ig_any_item_hovered, ig_begin_child, ig_end_child, ig_item_hovered, ig_last_item, &
                   item_status_object
use figure, only : ig_begin_popup_modal, ig_close_current_popup, ig_default_focus, ig_end_popup, ig_focus_here,   &
                   ig_get_scroll, ig_open_popup, ig_scroll_here, ig_scroll_to_pos, ig_selectable, ig_set_scroll, &
                   list_clipper_object
use figure_testing, only : test_click, test_drag, test_item_center, test_key, test_mouse_button, test_mouse_move, &
                           test_next_frame, test_popup_rect, test_type, test_wheel, test_window_rect

implicit none
integer(int32), parameter :: FRAMES = 400_int32 !< Frames run.
integer(int32), parameter :: TIP_FRAME = 230_int32 !< Frame on which the tooltip is looked for.
type(app_object)          :: app                !< Application.
logical                   :: test_passed(60)    !< Per-check outcome.
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
integer(int32)            :: saves(3)           !< ctrl+s fired: in Left, in Right, outside every window.
integer(int32)            :: saves_at(3, 3)     !< `saves` after Left's focus, Right's focus, the background's.
integer(int32)            :: globals            !< f6 ('global', in Left) fired.
integer(int32)            :: tops               !< f9 (default scope, outside every window) fired.
integer(int32)            :: downs(3)           !< 'down' (in Left) fired: no item active, field edited, end.
integer(int32)            :: item_ups(2)        !< 'up' ('item', after the field): field edited, then not.
integer(int32)            :: repeats(2)         !< f7 held with repeat, f8 held without.
integer(int32)            :: runs(2)            !< The button owning ctrl+r pressed: Right focused, then Left.
integer(int32)            :: s_short(2)         !< Statuses: an unknown scope, 'item' for the next item.
integer(int32)            :: leave_frames       !< Frames on which the field reported deactivated_after_edit.
integer(int32)            :: leave_at           !< The last of them.
integer(int32)            :: edit_frames        !< Frames on which the field reported edited.
integer(int32)            :: last_edit          !< The last of them.
character(len=16)         :: committed          !< The field's text on the frame it was left.
integer(int32)            :: active_seen(2)     !< Frames on which the field was activated, deactivated.
logical                   :: hover_seen(2)      !< The button: hovered with the pointer away, just arrived.
integer(int32)            :: clicks(3)          !< Left clicks: one click, a double click; right clicks.
integer(int32)            :: dbl(2)             !< Double clicks reported: after one click, after two.
logical                   :: held(2)            !< ig_any_item_active: the button held, then released.
logical                   :: snap_ok            !< The snapshot taken before a tooltip kept the button's status.
integer(int32)            :: combo_edits        !< Frames on which the combo reported edited.
integer(int32)            :: toggles            !< Frames on which the tree node reported toggled_open.
logical                   :: row_visible(2, 2)  !< (row 1, row 30) of a child visible: before, after the wheel.
integer(int32)            :: s_hover(2)         !< Statuses of ig_item_hovered: 'normal', an unknown delay.
integer(int32)            :: picked             !< The combo's choice after the pick.
integer(int32)            :: normal_at          !< First frame the button was hovered with the 'normal' delay.
real(real64)              :: here_off(2)        !< Row 150's centre minus the child's centre: same frame, next frame.
logical                   :: here_vis(2)        !< Row 150 visible: on the frame of ig_scroll_here, on the next.
real(real64)              :: scroll_seen(4, 2)  !< ig_get_scroll (y, ymax, x, xmax): before, after the scroll.
real(real64)              :: pitch(2)           !< Row pitch: of the plain list (measured), of the clipper.
integer(int32)            :: clip_drawn(4)      !< Row 700 drawn on the frame of ig_scroll_to_pos, on the next; then
                                                !< row 300 (from a scrolled list), the same.
real(real64)              :: clip_off(2)        !< Row 700's, then 300's, centre minus the child's centre.
real(real64)              :: top_scroll         !< The plain list's scroll after ig_set_scroll(y=0).
integer(int32)            :: s_scroll(6)        !< Statuses: good here, good to_pos, bad ratio, bad axis, NaN,
                                                !< offset -2.
integer(int32)            :: s_focus            !< Status of a good ig_focus_here.
character(len=8)          :: fields(2)          !< Two fields: the second gets the focus from the program.
logical                   :: modal_focus(2)     !< In the modal: Delete focused, Keep focused (after it appears).
integer(int32)            :: modal_press(2)     !< Presses: Delete, Keep.

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
is_open = .false.
is_body = .false.
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
call shortcut_frames()
call item_frames()
call scroll_frames()
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
test_passed(31) = all(saves_at(1:2, 1) == [1_int32, 0_int32])                ! Left focused: only Left's ctrl+s
test_passed(32) = all(saves_at(1:2, 2) == [1_int32, 1_int32])                ! Right focused: only Right's
test_passed(33) = saves_at(3, 2) == 0_int32 .and. saves_at(3, 3) == 1_int32 .and. & ! outside every window: only
                  all(saves_at(1:2, 3) == [1_int32, 1_int32])                ! when no window routes it
test_passed(34) = globals == 1_int32                                         ! 'global' in Left, Right focused
test_passed(35) = tops == 1_int32                                            ! default outside windows: fires
test_passed(36) = all(downs == [1_int32, 1_int32, 1_int32])                  ! not while the field is edited
test_passed(37) = all(item_ups == [1_int32, 1_int32])                        ! 'item': only while edited
test_passed(38) = repeats(1) >= 3_int32 .and. repeats(2) == 1_int32          ! repeat, once without
test_passed(39) = all(runs == [0_int32, 1_int32])                            ! the button owns ctrl+r, focused
test_passed(40) = s_short(1) == FIG_ERR_ARGUMENT                             ! an unknown scope refused
test_passed(41) = s_short(2) == FIG_ERR_ARGUMENT                             ! 'item' refused for the next item
test_passed(42) = leave_frames == 1_int32 .and. leave_at > last_edit .and. committed == 'wig' ! left once, after
test_passed(43) = edit_frames == 3_int32                                     ! edited on each keystroke's frame
test_passed(44) = all(active_seen == [1_int32, 1_int32])                     ! activated once, deactivated once
test_passed(45) = .not. hover_seen(1) .and. hover_seen(2) .and. s_hover(1) == FIG_OK .and. & ! hovered at once,
                  normal_at >= 41_int32 + 24_int32 .and. normal_at < 41_int32 + 40_int32 ! and after the 'normal' delay
test_passed(46) = clicks(1) == 1_int32 .and. dbl(1) == 0_int32               ! one click: no double click
test_passed(47) = clicks(2) == 2_int32 .and. dbl(2) == 1_int32               ! two clicks: one double click
test_passed(48) = clicks(3) == 1_int32                                       ! right click: clicked(2) only
test_passed(49) = held(1) .and. .not. held(2)                                ! ig_any_item_active while held
test_passed(50) = snap_ok                                                    ! the snapshot outlives the tooltip
test_passed(51) = combo_edits == 1_int32 .and. picked == 2_int32 .and. toggles == 1_int32 ! combo pick, node arrow
test_passed(52) = row_visible(1, 1) .and. .not. row_visible(2, 1) .and. &    ! a row scrolled out of the child:
                  .not. row_visible(1, 2) .and. row_visible(2, 2)            ! not visible
test_passed(53) = s_hover(2) == FIG_ERR_ARGUMENT                             ! an unknown delay refused
test_passed(54) = .not. here_vis(1) .and. here_vis(2) .and. &               ! ig_scroll_here: one frame later, row
                  abs(here_off(2)) < 0.5_real64 * pitch(1)                  ! 150 at the child's centre
test_passed(55) = scroll_seen(1, 1) == 0.0_real64 .and. scroll_seen(1, 2) > 0.0_real64 .and. & ! ig_get_scroll: 0,
                  scroll_seen(1, 2) <= scroll_seen(2, 2) .and. scroll_seen(2, 1) == scroll_seen(2, 2) .and. & ! then
                  scroll_seen(2, 2) > 190.0_real64 * pitch(1) .and. all(scroll_seen(3:4, :) == 0.0_real64) ! moved
test_passed(56) = all(clip_drawn == [0_int32, 1_int32, 0_int32, 1_int32]) .and. & ! clipped rows reached by
                  all(abs(clip_off) < 0.5_real64 * pitch(2)) .and. pitch(2) > 0.0_real64 ! ig_scroll_to_pos
test_passed(57) = top_scroll == 0.0_real64                                   ! ig_set_scroll(y=0)
test_passed(58) = all(s_scroll(1:2) == FIG_OK) .and. all(s_scroll(3:6) == FIG_ERR_ARGUMENT) .and. s_focus == FIG_OK
test_passed(59) = fields(1) == 'one' .and. fields(2) == 'abc'                ! typed keys go to the focused field
test_passed(60) = .not. modal_focus(1) .and. modal_focus(2) .and. &          ! a modal's default focus: Keep, and
                  all(modal_press == [0_int32, 1_int32])                     ! enter presses it

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
   write(output_unit, '(A,9(I0,1X),A,I0,A,I0,A,3(I0,1X),A,2(I0,1X),A,2(I0,1X),A,2(I0,1X),A,2(I0,1X))') &
         'shortcuts: saves', saves_at, ', globals ', globals, ', tops ', tops, ', downs ', downs, ', item ups ', &
         item_ups, ', repeats ', repeats, ', runs ', runs, ', statuses ', s_short
   write(output_unit, '(A,4(I0,1X),A,2(I0,1X),A,2L2,1X,I0,A,3(I0,1X),A,2(I0,1X),A,2L2,A,L2,A,3(I0,1X),A,4L2,A,2(I0,1X))') &
         'items: leave/at/edits/last ', leave_frames, leave_at, edit_frames, last_edit, ', act/deact ', active_seen, &
         ', hover', hover_seen, normal_at, ', clicks ', clicks, ', dbl ', dbl, ', held', held, ', snap', snap_ok, &
         ', combo/picked/toggles ', combo_edits, picked, toggles, ', rows', row_visible, ', hover stats ', s_hover
   write(output_unit, '(A)') 'committed "'//trim(committed)//'"'
   write(output_unit, '(A,2L2,A,2F8.2,A,8F8.1,A,2F7.2,A,4(I0,1X),A,2F8.2,A,F7.1,A,6(I0,1X),I0)') 'scroll: here vis', &
         here_vis, ', off', here_off, ', get', scroll_seen, ', pitch', pitch, ', clip drawn ', clip_drawn, ', off ', &
         clip_off, ', top ', top_scroll, ', stats ', s_scroll, s_focus
   write(output_unit, '(A,2L2,A,2(I0,1X))') 'focus: fields "'//trim(fields(1))//'" "'//trim(fields(2))// &
         '", modal focus', modal_focus, ', presses ', modal_press
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

   subroutine shortcut_frames()
   !< Two windows, Left and Right, both binding ctrl+s; Left also has a text field, 'down', 'up' for the field
   !< ('item'), f6 ('global'), f7 (repeat), f8, and a button owning ctrl+r; f9 and ctrl+s outside every window.
   character(len=16) :: note     !< Left's text field.
   real(real64)      :: field(2) !< Centre of the field.
   integer(int32)    :: f        !< Frame.

   note = 'x'
   field = 0.0_real64
   saves = 0_int32
   saves_at = -1_int32
   globals = 0_int32
   tops = 0_int32
   downs = 0_int32
   item_ups = 0_int32
   repeats = 0_int32
   runs = 0_int32
   s_short = FIG_OK
   do f = 1_int32, 170_int32
      if (.not. app%next_frame()) exit
      call ig_set_next_window(20.0_real64, 20.0_real64, 300.0_real64, 200.0_real64, always=.true.)
      if (ig_begin('Left')) then
         if (ig_input_text('note', note)) continue
         call test_item_center(field(1), field(2))
         if (ig_shortcut('up', scope='item')) item_ups(1) = item_ups(1) + 1_int32
         if (ig_shortcut('ctrl+s')) saves(1) = saves(1) + 1_int32
         if (ig_shortcut('down')) downs(1) = downs(1) + 1_int32
         if (ig_shortcut('f6', scope='global')) globals = globals + 1_int32
         if (ig_shortcut('f7', repeat=.true.)) repeats(1) = repeats(1) + 1_int32
         if (ig_shortcut('f8')) repeats(2) = repeats(2) + 1_int32
         call ig_set_next_item_shortcut('ctrl+r')
         if (ig_button('Run')) runs(2) = runs(2) + 1_int32
         if (f == 2_int32) then
            if (ig_shortcut('f8', scope='window', stat=s_short(1))) continue
            call ig_set_next_item_shortcut('ctrl+r', scope='item', stat=s_short(2))
         endif
      endif
      call ig_end()
      call ig_set_next_window(400.0_real64, 20.0_real64, 300.0_real64, 200.0_real64, always=.true.)
      if (ig_begin('Right')) then
         call ig_text('right')
         if (ig_shortcut('ctrl+s')) saves(2) = saves(2) + 1_int32
      endif
      call ig_end()
      if (ig_shortcut('ctrl+s')) saves(3) = saves(3) + 1_int32 ! outside every window
      if (ig_shortcut('f9')) tops = tops + 1_int32
      select case (f)
      case (5_int32, 50_int32, 90_int32) ! focus Left by its title bar
         call test_click(170.0_real64, 28.0_real64)
      case (22_int32)                    ! focus Right
         call test_click(550.0_real64, 28.0_real64)
      case (12_int32, 30_int32, 158_int32)
         call ctrl('s')
      case (20_int32, 38_int32, 166_int32)
         saves_at(:, merge(1_int32, merge(2_int32, 3_int32, f == 38_int32), f == 20_int32)) = saves
      case (40_int32)                    ! Right focused: Left's 'global' f6, the top-level f9, Left's button's ctrl+r
         call test_key('f6')
         call test_key('f9')
      case (44_int32)
         call ctrl('r')
         runs(1) = runs(2)
      case (48_int32)
         runs(1) = runs(2) - runs(1)     ! presses while Right had the focus
         runs(2) = 0_int32
      case (56_int32)                    ! Left focused: its button
         call ctrl('r')
      case (60_int32)                    ! Left focused, nothing edited: 'down' fires
         call test_key('down')
      case (66_int32)                    ! edit the field
         call test_click(field(1), field(2))
      case (72_int32)                    ! 'up' goes to the field's 'item' call
         call test_key('up')
      case (76_int32)
         item_ups(2) = item_ups(1)
         downs(2) = downs(1)
      case (78_int32)                    ! 'down' is the field's: Left's call does not fire
         call test_key('down')
      case (84_int32)
         downs(2) = downs(1) - downs(2) + 1_int32 ! 1 when it did not fire
         call test_key('escape')
      case (95_int32)                    ! the field no longer edited: 'item' does not fire
         call test_key('up')
      case (100_int32)                   ! hold f7 (repeat) and f8 (once) for 40 frames
         call test_key('f7', down=.true.)
         call test_key('f8', down=.true.)
      case (140_int32)
         call test_key('f7', down=.false.)
         call test_key('f8', down=.false.)
         downs(3) = downs(1)
      case (150_int32)                   ! the background: no window has the focus
         call test_click(900.0_real64, 500.0_real64)
      endselect
   enddo
   item_ups(2) = item_ups(1) - item_ups(2) + 1_int32 ! 1 when the second 'up' did not fire
   endsubroutine shortcut_frames

   subroutine ctrl(key)
   !< Press the platform's shortcut key with `key` (ctrl+key; cmd+key on macOS).
   character(len=*), intent(in) :: key !< Key name.

   call test_key('shortcut', down=.true.)
   call test_key(key)
   call test_key('shortcut', down=.false.)
   endsubroutine ctrl

   subroutine item_frames()
   !< One window, Items: a text field typed into and left, a button hovered, clicked, double-clicked, right-clicked
   !< and held, a button with a tooltip whose snapshot is taken before the tooltip, a combo picked, a tree node opened
   !< by its arrow, and a child region of 30 rows scrolled by the wheel.
   character(len=16)        :: mesh       !< The text field.
   integer(int32)           :: model      !< The combo's choice.
   type(item_status_object) :: s          !< Status of an item.
   type(item_status_object) :: snap       !< The help button's status, before its tooltip.
   type(item_status_object) :: after      !< The last item's status after the tooltip and a text.
   real(real64)             :: field(2)   !< Centre of the field.
   real(real64)             :: button(2)  !< Centre of the button 'open'.
   real(real64)             :: help(2)    !< Centre of the button 'help'.
   real(real64)             :: combo(2)   !< Centre of the combo.
   real(real64)             :: node(4)    !< The tree node's rectangle (x, y, w, h).
   real(real64)             :: list(2)    !< Centre of the child region.
   real(real64)             :: help_rect(4) !< The help button's rectangle by ig_item_rect (xmin, ymin, xmax, ymax).
   real(real64)             :: x0, y0, x1, y1 !< A window's rectangle.
   logical                  :: open       !< The tree node is open.
   logical                  :: tip        !< The tooltip is shown.
   integer(int32)           :: f          !< Frame.
   integer(int32)           :: r          !< Row.

   mesh = ''
   committed = ''
   model = 1_int32
   field = 0.0_real64
   button = 0.0_real64
   help = 0.0_real64
   combo = 0.0_real64
   node = 0.0_real64
   list = 0.0_real64
   leave_frames = 0_int32
   edit_frames = 0_int32
   last_edit = 0_int32
   leave_at = 0_int32
   active_seen = 0_int32
   hover_seen = .true.
   dbl = 0_int32
   clicks = 0_int32
   held = .true.
   snap_ok = .false.
   combo_edits = 0_int32
   toggles = 0_int32
   row_visible = .false.
   s_hover = FIG_OK
   normal_at = 0_int32
   do f = 1_int32, 300_int32
      if (.not. app%next_frame()) exit
      call ig_set_next_window(20.0_real64, 20.0_real64, 500.0_real64, 420.0_real64, always=.true.)
      if (ig_begin('Items')) then
         if (ig_input_text('mesh', mesh)) continue
         s = ig_last_item()                                   ! right after the field
         field = s%rect(1:2) + 0.5_real64 * s%rect(3:4)
         if (s%edited) then
            edit_frames = edit_frames + 1_int32
            last_edit = f
         endif
         if (s%activated) active_seen(1) = active_seen(1) + 1_int32
         if (s%deactivated) active_seen(2) = active_seen(2) + 1_int32
         if (s%deactivated_after_edit) then
            leave_frames = leave_frames + 1_int32
            leave_at = f
            committed = mesh
         endif
         if (ig_button('open')) continue
         s = ig_last_item()
         button = s%rect(1:2) + 0.5_real64 * s%rect(3:4)
         select case (f)
         case (36_int32)                                      ! the pointer away from every item
            hover_seen(1) = s%hovered .or. ig_item_hovered() .or. ig_any_item_hovered()
         case (43_int32)                                      ! the pointer on the button, just arrived
            hover_seen(2) = s%hovered .and. ig_item_hovered() .and. ig_any_item_hovered() .and. &
                            .not. ig_item_hovered(delay='normal')
         endselect
         if (f > 43_int32 .and. f < 90_int32) then            ! resting there: 'normal' after 0.40 s (24 frames)
            if (ig_item_hovered(delay='normal', stat=s_hover(1)) .and. normal_at == 0_int32) normal_at = f
         endif
         if (f >= 90_int32 .and. f < 120_int32) then          ! one click
            if (s%clicked(1)) clicks(1) = clicks(1) + 1_int32
            if (s%double_clicked(1)) dbl(1) = dbl(1) + 1_int32
         elseif (f >= 120_int32 .and. f < 145_int32) then     ! two clicks: a double click
            if (s%clicked(1)) clicks(2) = clicks(2) + 1_int32
            if (s%double_clicked(1)) dbl(2) = dbl(2) + 1_int32
         elseif (f >= 145_int32 .and. f < 165_int32) then     ! a right click
            if (s%clicked(2)) clicks(3) = clicks(3) + 1_int32
            if (s%clicked(1) .or. s%double_clicked(2)) clicks(3) = clicks(3) + 10_int32
         endif
         if (ig_button('help')) continue
         snap = ig_last_item()                                ! before the tooltip
         call ig_item_rect(help_rect(1), help_rect(2), help_rect(3), help_rect(4))
         help = snap%rect(1:2) + 0.5_real64 * snap%rect(3:4)
         call ig_tooltip('opens the case')
         call ig_text('after the tooltip')
         after = ig_last_item()
         if (f == 230_int32) then
            call test_window_rect('##Tooltip_00', x0, y0, x1, y1, found=tip)
            snap_ok = tip .and. snap%hovered .and. abs(snap%rect(1) - help_rect(1)) < 0.01_real64 .and. &
                      abs(snap%rect(3) - (help_rect(3) - help_rect(1))) < 0.01_real64 .and. &
                      .not. after%hovered .and. abs(after%rect(2) - snap%rect(2)) > 1.0_real64
         endif
         if (ig_combo('model', model, ['nul', 'spa', 'des'])) continue
         s = ig_last_item()
         combo = s%rect(1:2) + 0.5_real64 * s%rect(3:4)
         if (s%edited) combo_edits = combo_edits + 1_int32
         open = ig_tree_node('blocks')
         s = ig_last_item()
         node = s%rect
         if (s%toggled_open) toggles = toggles + 1_int32
         if (open) call ig_tree_pop()
         if (ig_begin_child('list', height=100.0_real64, border=.true.)) then
            do r = 1_int32, 30_int32
               call ig_text('row '//achar(48 + r / 10)//achar(48 + mod(r, 10)))
               s = ig_last_item()
               if (f == 260_int32 .and. r == 1_int32) row_visible(1, 1) = s%visible  ! before the wheel
               if (f == 260_int32 .and. r == 30_int32) row_visible(2, 1) = s%visible
               if (f == 295_int32 .and. r == 1_int32) row_visible(1, 2) = s%visible  ! after it
               if (f == 295_int32 .and. r == 30_int32) row_visible(2, 2) = s%visible
            enddo
         endif
         call ig_end_child()
         s = ig_last_item()
         list = s%rect(1:2) + 0.5_real64 * s%rect(3:4)
      endif
      call ig_end()
      if (f == 172_int32) held(1) = ig_any_item_active()     ! the button held
      if (f == 180_int32) held(2) = ig_any_item_active()     ! released
      select case (f)
      case (5_int32)                                          ! click into the field, type three keys on three frames
         call test_click(field(1), field(2))
      case (12_int32)
         call test_type('w')
         call test_next_frame()
         call test_type('i')
         call test_next_frame()
         call test_type('g')
      case (25_int32)                                         ! leave the field: a click on the empty window
         call test_click(450.0_real64, 410.0_real64)
      case (40_int32)
         call test_mouse_move(button(1), button(2))
      case (90_int32)
         call test_click(button(1), button(2))
      case (120_int32)
         call test_click(button(1), button(2))
         call test_click(button(1), button(2))
      case (145_int32)
         call test_click(button(1), button(2), button='right')
      case (165_int32)
         call test_mouse_move(button(1), button(2))
         call test_next_frame()
         call test_mouse_button(.true.)
      case (176_int32)
         call test_mouse_button(.false.)
      case (185_int32)
         call test_mouse_move(help(1), help(2))
      case (235_int32)                                        ! pick the second model
         call test_click(combo(1), combo(2))
      case (242_int32)
         call test_key('down')
         call test_key('enter')
      case (255_int32)                                        ! open the node by its arrow
         call test_click(node(1) + 6.0_real64, node(2) + 0.5_real64 * node(4))
      case (270_int32)                                        ! scroll the list to its end
         call test_mouse_move(list(1), list(2))
         call test_next_frame()
         call test_wheel(-20.0_real64)
      case (285_int32)
         if (ig_item_hovered(delay='later', stat=s_hover(2))) continue
      endselect
   enddo
   picked = model
   endsubroutine item_frames

   subroutine scroll_frames()
   !< One window, Scroll: a child of 200 rows scrolled by `ig_scroll_here` and `ig_set_scroll`, a child of 1000
   !< clipped rows scrolled by `ig_scroll_to_pos`, two fields (the second focused by `ig_focus_here`), and a modal
   !< whose second button is its default focus.
   type(item_status_object)  :: s           !< Status of an item.
   type(list_clipper_object) :: clip        !< The clipped list.
   real(real64)              :: row(4)      !< Row 150's (or 700's) rectangle this frame.
   real(real64)              :: prev(4)     !< Row 1's rectangle (for the pitch).
   real(real64)              :: dummy(2)    !< ig_get_scroll's values not kept.
   character(len=12)         :: label       !< A row's label.
   logical                   :: drawn       !< Row 700 drawn this frame.
   logical                   :: shown       !< The modal is open.
   integer(int32)            :: f           !< Frame.
   integer(int32)            :: r           !< Row.
   integer(int32)            :: goal        !< The clipped row to reach.

   here_off = huge(1.0_real64)
   here_vis = .true.
   scroll_seen = -1.0_real64
   pitch = 0.0_real64
   clip_drawn = -1_int32
   clip_off = huge(1.0_real64)
   goal = 700_int32
   top_scroll = -1.0_real64
   s_scroll = -1_int32
   s_focus = -1_int32
   fields = ['one', '   ']
   modal_focus = [.true., .false.]
   modal_press = 0_int32
   do f = 1_int32, 90_int32
      if (.not. app%next_frame()) exit
      call ig_set_next_window(20.0_real64, 20.0_real64, 500.0_real64, 520.0_real64, always=.true.)
      if (ig_begin('Scroll')) then
         row = 0.0_real64
         prev = 0.0_real64
         if (ig_begin_child('rows', height=100.0_real64, border=.true.)) then
            if (f == 4_int32) call ig_get_scroll(scroll_seen(1, 1), scroll_seen(2, 1), scroll_seen(3, 1), &
                                                 scroll_seen(4, 1))
            if (f == 6_int32) call ig_get_scroll(scroll_seen(1, 2), scroll_seen(2, 2), scroll_seen(3, 2), &
                                                 scroll_seen(4, 2))
            if (f == 32_int32) call ig_get_scroll(top_scroll, dummy(1))
            do r = 1_int32, 200_int32
               write(label, '(A,I3.3)') 'item ', r
               if (ig_selectable(trim(label), r == 150_int32)) continue
               s = ig_last_item()
               if (r == 1_int32) prev = s%rect
               if (r == 2_int32) pitch(1) = s%rect(2) - prev(2)
               if (r == 150_int32) then
                  row = s%rect
                  if (f == 5_int32) here_vis(1) = s%visible
                  if (f == 6_int32) here_vis(2) = s%visible
                  if (f == 5_int32) call ig_scroll_here(0.5_real64, stat=s_scroll(1)) ! centre row 150
               endif
            enddo
            if (f == 30_int32) call ig_set_scroll(y=0.0_real64)                    ! back to the top
            if (f == 8_int32) then                                                ! refused arguments
               call ig_scroll_here(1.5_real64, stat=s_scroll(3))
               call ig_scroll_to_pos(0.0_real64, axis='z', stat=s_scroll(4))
               call ig_scroll_here(ieee_value(1.0_real64, ieee_quiet_nan), stat=s_scroll(5))
               call ig_focus_here(-2_int32, stat=s_scroll(6))
            endif
         endif
         call ig_end_child()
         s = ig_last_item()
         if (f == 5_int32 .or. f == 6_int32) here_off(f - 4_int32) = (row(2) + 0.5_real64 * row(4)) - &
                                                                    (s%rect(2) + 0.5_real64 * s%rect(4))
         drawn = .false.
         row = 0.0_real64
         if (ig_begin_child('clipped', height=100.0_real64, border=.true.)) then
            call clip%begin(1000_int32)
            do while (clip%step())
               do r = clip%first, clip%last
                  write(label, '(A,I4.4)') 'line ', r
                  call ig_text(trim(label))
                  if (r == goal) then
                     drawn = .true.
                     s = ig_last_item()
                     row = s%rect
                  endif
               enddo
            enddo
            pitch(2) = clip%item_height
            if (f == 20_int32 .or. f == 24_int32) &                               ! a row not drawn now
               call ig_scroll_to_pos((real(goal, real64) - 0.5_real64) * clip%item_height, 0.5_real64, stat=s_scroll(2))
         endif
         call ig_end_child()
         s = ig_last_item()
         select case (f)
         case (20_int32)                                                          ! row 700: asked, not drawn
            clip_drawn(1) = merge(1_int32, 0_int32, drawn)
         case (21_int32)                                                          ! drawn, at the centre
            clip_drawn(2) = merge(1_int32, 0_int32, drawn)
            clip_off(1) = (row(2) + 0.5_real64 * row(4)) - (s%rect(2) + 0.5_real64 * s%rect(4))
         case (22_int32)
            goal = 300_int32                                                      ! now from a scrolled list
         case (24_int32)
            clip_drawn(3) = merge(1_int32, 0_int32, drawn)
         case (25_int32)
            clip_drawn(4) = merge(1_int32, 0_int32, drawn)
            clip_off(2) = (row(2) + 0.5_real64 * row(4)) - (s%rect(2) + 0.5_real64 * s%rect(4))
         endselect
         if (ig_input_text('first', fields(1))) continue
         if (f == 40_int32) call ig_focus_here(stat=s_focus)                      ! the next field: 'second'
         if (ig_input_text('second', fields(2))) continue
         if (f == 60_int32) call ig_open_popup('Confirm')
         shown = ig_begin_popup_modal('Confirm')
         if (shown) then
            call ig_text('delete the case?')
            if (ig_button('Delete')) then
               modal_press(1) = modal_press(1) + 1_int32
               call ig_close_current_popup()
            endif
            s = ig_last_item()
            if (f == 64_int32) modal_focus(1) = s%focused
            if (ig_button('Keep')) then
               modal_press(2) = modal_press(2) + 1_int32
               call ig_close_current_popup()
            endif
            call ig_default_focus()                                               ! the safe choice
            s = ig_last_item()
            if (f == 64_int32) modal_focus(2) = s%focused
            call ig_end_popup()
         endif
      endif
      call ig_end()
      select case (f)
      case (44_int32)                                         ! no click: the keys go to 'second'
         call test_type('abc')
      case (66_int32)
         call test_key('enter')
      endselect
   enddo
   endsubroutine scroll_frames

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
