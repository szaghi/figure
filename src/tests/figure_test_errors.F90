!< figure_test_errors, usage errors reported, not aborted: the scope record, frames and the three modes, headless.
program figure_test_errors
!< figure_test_errors, usage errors reported, not aborted: the scope record, frames and the three modes, headless.
!<
!< Mode 'report' (the default): for every begin/end and push/pop pair FIGURE wraps, a missing end, an extra end, an
!< end of the wrong kind and an end after a begin that returned false (where the pair's rule is "end only after a true
!< begin") each give `FIG_ERR_STATE` at the next `next_frame(stat)` with its message, and the frame after draws
!< normally. A widget before the first frame is refused (reported by the first `next_frame`; a call with its own
!< `stat` gets it there). Calls through the raw bindings that leave a Dear ImGui stack open are caught, inside a scope
!< and at the end of the frame. Mode 'recover': a missing inner end is repaired, the error is in `figure_last_error`
!< and in one notification (not one per frame), `next_frame` gives `FIG_OK` and the next frame draws normally. Mode
!< 'abort': a child process (this program, run again with an argument) stops at the wrong end, and at `next_frame`
!< for a scope left open, with the message on standard error. An unknown mode is refused. The cost of the record is
!< measured (a push/pop pair and a text, against the raw calls) and printed.
use, intrinsic :: iso_c_binding, only : c_bool, c_float, c_int, c_null_char, c_null_ptr
use, intrinsic :: iso_fortran_env, only : error_unit, int32, int64, output_unit, real64
use figure, only : app_object, figure_last_error, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, ImGuiWindowFlags_MenuBar, &
                   ig_begin, ig_begin_child, ig_begin_disabled, ig_begin_main_menu_bar, ig_begin_menu,            &
                   ig_begin_menu_bar, ig_begin_popup, ig_begin_tab, ig_begin_tab_bar, ig_begin_table, ig_button,  &
                   ig_dock_layout_begin, ig_dock_layout_end, ig_end, ig_end_child, ig_end_disabled,              &
                   ig_end_main_menu_bar, ig_end_menu, ig_end_menu_bar, ig_end_popup, ig_end_tab, ig_end_tab_bar,  &
                   ig_end_table, ig_item_rect, ig_open_popup, ig_pop_font, ig_pop_id, ig_pop_style_color,        &
                   ig_pop_style_var, ig_push_font, ig_push_id, ig_push_style_color, ig_push_style_var, ig_text,  &
                   ig_tree_node, ig_tree_pop, ip_begin_plot, ip_begin_subplots, ip_end_plot, ip_end_subplots, &
                   ig_align_begin, ig_align_end, ig_begin_group, ig_end_group, ig_pop_item_width, ig_push_item_width
use figure_cimgui, only : igBegin, igPopID, igPushID_Int, igSetNextWindowCollapsed, igTextUnformatted
use figure_cimgui_enums, only : ImGuiCond_Always

implicit none
integer(int32), parameter :: K_WINDOW = 1, K_CHILD = 2, K_TAB_BAR = 3, K_TAB = 4, K_TABLE = 5, K_TREE = 6,    &
                             K_MAIN_MENU_BAR = 7, K_MENU_BAR = 8, K_MENU = 9, K_POPUP = 10, K_PLOT = 11,        &
                             K_SUBPLOTS = 12, K_DOCK_LAYOUT = 13, K_ID = 14, K_DISABLED = 15, K_FONT = 16,     &
                             K_STYLE_COLOR = 17, K_STYLE_VAR = 18, K_GROUP = 19, K_ALIGN = 20, K_ITEM_WIDTH = 21, &
                             NKIND = 21 !< The pairs (FIGURE's record's kinds).
integer(int32), parameter :: F_MISSING = 1, F_EXTRA = 2, F_WRONG = 3, F_FALSE = 4 !< The faults.
character(len=*), parameter :: OPENER(NKIND) = [character(len=22) ::                                          &
   'ig_begin', 'ig_begin_child', 'ig_begin_tab_bar', 'ig_begin_tab', 'ig_begin_table', 'ig_tree_node',        &
   'ig_begin_main_menu_bar', 'ig_begin_menu_bar', 'ig_begin_menu', 'ig_begin_popup', 'ip_begin_plot',         &
   'ip_begin_subplots', 'ig_dock_layout_begin', 'ig_push_id', 'ig_begin_disabled', 'ig_push_font',            &
   'ig_push_style_color', 'ig_push_style_var', 'ig_begin_group', 'ig_align_begin', 'ig_push_item_width'] !< The begin
                                                                                                    !< of each pair.
character(len=*), parameter :: CLOSER(NKIND) = [character(len=20) ::                                          &
   'ig_end', 'ig_end_child', 'ig_end_tab_bar', 'ig_end_tab', 'ig_end_table', 'ig_tree_pop',                   &
   'ig_end_main_menu_bar', 'ig_end_menu_bar', 'ig_end_menu', 'ig_end_popup', 'ip_end_plot', 'ip_end_subplots', &
   'ig_dock_layout_end', 'ig_pop_id', 'ig_end_disabled', 'ig_pop_font', 'ig_pop_style_color',                &
   'ig_pop_style_var', 'ig_end_group', 'ig_align_end', 'ig_pop_item_width'] !< The end of each pair.
logical, parameter :: TRUE_ONLY(NKIND) = [.false., .false., .true., .true., .true., .true., .true., .true.,   &
                                          .true., .true., .true., .true., .true., .false., .false., .false.,   &
                                          .false., .false., .false., .false., .false.] !< "End only after a true
                                                                                       !< begin".
logical, parameter :: NESTS(NKIND) = [.true., .true., .true., .true., .true., .true., .true., .true., .true.,      &
                                      .true., .true., .true., .true., .true., .false., .false., .false., .false., &
                                      .true., .true., .true.]
                                      !< Containers and id scopes (an end closes the innermost); the others are pushes.
type(app_object)              :: app          !< Application (headless).
logical                       :: passed(NKIND, 4) !< Per pair and fault (true where not applicable).
logical                       :: test_passed(11) !< The other checks.
character(len=:), allocatable :: msg          !< A frame's report.
character(len=:), allocatable :: expect       !< What it must contain.
character(len=256)            :: arg          !< This program's argument (a child run).
integer(int32)                :: k            !< Kind.
integer(int32)                :: f            !< Fault.
integer(int32)                :: stat         !< Status.
integer(int32)                :: dock         !< Dock ids, a new one for each layout.
integer(int32)                :: notes(3)     !< Notifications kept, at three points.
character(len=:), allocatable :: list(:)      !< Their texts.
real(real64)                  :: rect(4)      !< An item's rectangle.

call get_command_argument(1, arg)
if (len_trim(arg) > 0) call child(trim(arg)) ! mode 'abort', run again by the parent: never returns

passed = .true.
test_passed = .false.
dock = 7000_int32
call app%init_headless(800_int32, 600_int32)

! 1. a widget before the first frame: refused; reported by the first next_frame (a call with a stat: there)
if (ig_button('early')) continue
call ig_push_style_color('Text', '#ff0000', stat=stat)
test_passed(1) = stat == FIG_ERR_STATE .and. figure_last_error() == 'ig_push_style_color: no frame open'
msg = report()
test_passed(1) = test_passed(1) .and. msg == 'ig_button: no frame open'
if (.not. test_passed(1)) write(error_unit, '(A)') 'before the first frame: "'//msg//'"'

! 2. every pair, every fault: its message at the next next_frame, then a clean frame (a collapsed window drawn once
! before: a new window draws its content in its first frame, collapsed or not)
call igSetNextWindowCollapsed(.true._c_bool, ImGuiCond_Always)
if (ig_begin('Collapsed', flags=ImGuiWindowFlags_MenuBar)) continue
call ig_end()
msg = report()
do k = 1_int32, NKIND
   do f = F_MISSING, F_FALSE
      if (f == F_WRONG .and. .not. NESTS(k)) cycle      ! pushes do not nest: no wrong kind
      if (f == F_FALSE .and. .not. TRUE_ONLY(k)) cycle  ! always paired: no "after a false begin"
      if (f == F_FALSE .and. k == K_MAIN_MENU_BAR) cycle ! its begin is true in every frame FIGURE draws
      call fault(k, f, expect)
      msg = report()
      passed(k, f) = index(msg, expect) > 0
      msg = report() ! nothing in the frame after
      passed(k, f) = passed(k, f) .and. msg == ''
      if (.not. passed(k, f)) write(error_unit, '(A,I0,A,I0,A)') 'kind ', k, ', fault ', f, ': expected "'// &
                                                                 expect//'", got "'//figure_last_error()//'"'
   enddo
enddo
write(output_unit, '(A,I0,A,I0,A)') 'pairs and faults: ', count(passed), ' of ', size(passed), &
                                     ' right (the cells that do not apply count as right)'

! 3. raw calls that leave a Dear ImGui stack open: inside a scope, at the end of the frame
if (ig_begin('Raw')) continue
call igPushID_Int(7_c_int)
call ig_end()
msg = report()
test_passed(2) = index(msg, "ig_end: Dear ImGui holds ids 2 (1 expected) inside ig_begin('Raw')") > 0 .and. &
                 index(msg, 'a call outside FIGURE') > 0
if (igBegin('RawLeft'//c_null_char, c_null_ptr, 0_c_int)) continue
msg = report()
test_passed(2) = test_passed(2) .and. index(msg, 'app%next_frame: Dear ImGui holds windows 2 (1 expected)') > 0
test_passed(2) = test_passed(2) .and. report() == ''
if (.not. test_passed(2)) write(error_unit, '(A)') 'raw calls: "'//msg//'"'

! 4. errors listed one per line, every one named
if (ig_begin('Two')) continue
call ig_pop_id()
call ig_end_table()
call ig_end()
msg = report()
test_passed(3) = msg == 'ig_pop_id: no ig_push_id is open; the open scope is ig_begin(''Two'') (closed by ig_end)'// &
                 new_line('a')//'ig_end_table: no ig_begin_table is open; the open scope is ig_begin(''Two'') '//  &
                 '(closed by ig_end)'
if (.not. test_passed(3)) write(error_unit, '(A)') 'two errors: "'//msg//'"'

! 4b. what is right is not reported: a font pushed in a tree node and popped after it, a colour pushed before a window
! and popped inside it, one pushed inside and popped after it
if (ig_begin('Right')) then
   if (ig_tree_node('n', leaf=.true.)) then
      call ig_push_font('', 18.0_real64)
      call ig_tree_pop()
   endif
   call ig_pop_font()
   call ig_push_style_color('Text', '#00ff00')
endif
call ig_end()
call ig_pop_style_color()
call ig_push_style_color('WindowBg', '#202020')
if (ig_begin('Right')) call ig_pop_style_color()
call ig_end()
msg = report()
test_passed(10) = msg == ''
if (.not. test_passed(10)) write(error_unit, '(A)') 'right code reported: "'//msg//'"'

! 5. 'recover': the inner scope closed by the outer end, the error notified once, the next frames clean
call app%set_checks('recover')
call app%notifications(list)
notes(1) = size(list, kind=int32)
call recover_frame()
msg = report()
test_passed(4) = msg == '' .and. index(figure_last_error(), &
                 "ig_end: the open scope is ig_tree_node('inner') (close it with ig_tree_pop before ig_end)") > 0
call recover_frame()                                  ! the same error again: no second notification
msg = report()
call app%notifications(list)
notes(2) = size(list, kind=int32)
test_passed(4) = test_passed(4) .and. msg == '' .and. notes(2) == notes(1) + 1_int32
if (test_passed(4)) test_passed(4) = index(list(notes(2)), "ig_tree_node('inner')") > 0 .and. & ! repaired at the
                                     index(list(notes(2)), 'still open') == 0               ! end: none left open
if (ig_begin('Recovered')) then                       ! the frame after draws normally
   if (ig_button('fine')) continue
   call ig_item_rect(rect(1), rect(2), rect(3), rect(4))
endif
call ig_end()
msg = report()
call app%notifications(list)
notes(3) = size(list, kind=int32)
test_passed(5) = msg == '' .and. rect(3) > rect(1) .and. rect(4) > rect(2) .and. notes(3) == notes(2) .and. &
                 figure_last_error() /= ''
if (.not. all(test_passed(4:5))) write(error_unit, '(A,3I4)') 'recover: notifications ', notes
! 5b. 'recover' closes the missing ends, not the style changes pushed after the scope it ends (they are the frame's)
if (ig_begin('Kept')) then
   if (ig_tree_node('t', leaf=.true.)) call ig_push_style_color('Text', '#ff00ff')
endif
call ig_end()
call ig_pop_style_color()
msg = report()
test_passed(11) = msg == '' .and. index(figure_last_error(), 'ig_pop_style_color') == 0 .and. &
                  index(figure_last_error(), "ig_end: the open scope is ig_tree_node('t')") > 0
if (.not. test_passed(11)) write(error_unit, '(A)') 'recover kept styles: "'//figure_last_error()//'"'
call app%set_checks('report')

! 6. an unknown mode
call app%set_checks('ignore', stat=stat)
test_passed(6) = stat == FIG_ERR_ARGUMENT .and. index(figure_last_error(), "not 'ignore'") > 0

! 7. 'abort': a child stops at the wrong end, another at next_frame for a scope left open, each with its message
test_passed(7) = abort_child('end', "FIGURE error: ig_end: no ig_begin or ig_begin_side_bar is open")
test_passed(8) = abort_child('open', "FIGURE error: app%next_frame: ig_begin('Left') is still open (close it with ig_end)")

! 8. the cost of the record (printed; a bound far above any machine: the check is that it stays small)
test_passed(9) = cost()

call app%destroy()
if (all(passed) .and. all(test_passed)) then
   write(output_unit, '(A)') 'figure_test_errors: all tests passed'
else
   write(error_unit, '(A,11L2)') 'figure_test_errors: failed, checks ', test_passed
   error stop 1
endif

contains
   function report() result(text)
   !< Close the frame, open the next: '' when it had no usage error, else the messages.
   character(len=:), allocatable :: text !< The report.
   integer(int32)                :: s    !< Status.

   if (.not. app%next_frame(s)) error stop 'figure_test_errors: the loop ended'
   text = ''
   if (s /= FIG_OK) text = figure_last_error()
   endfunction report

   subroutine host_begin(kind)
   !< What scope `kind` lives in: a window (with a menu bar) for the containers of a window, a tab bar for a tab, a
   !< menu bar for a menu; nothing for a window, the main menu bar, a dock layout and the pushes.
   integer(int32), intent(in) :: kind !< Kind.

   select case (kind)
   case (K_WINDOW, K_MAIN_MENU_BAR, K_DOCK_LAYOUT, K_DISABLED, K_FONT, K_STYLE_COLOR, K_STYLE_VAR)
   case default
      if (ig_begin('Host', flags=ImGuiWindowFlags_MenuBar)) continue
      if (kind == K_TAB) then
         if (.not. ig_begin_tab_bar('bar')) error stop 'figure_test_errors: no tab bar'
      elseif (kind == K_MENU) then
         if (.not. ig_begin_menu_bar()) error stop 'figure_test_errors: no menu bar'
      endif
   endselect
   endsubroutine host_begin

   subroutine host_end(kind)
   !< Close what `host_begin` opened.
   integer(int32), intent(in) :: kind !< Kind.

   select case (kind)
   case (K_WINDOW, K_MAIN_MENU_BAR, K_DOCK_LAYOUT, K_DISABLED, K_FONT, K_STYLE_COLOR, K_STYLE_VAR)
   case default
      if (kind == K_TAB) call ig_end_tab_bar()
      if (kind == K_MENU) call ig_end_menu_bar()
      call ig_end()
   endselect
   endsubroutine host_end

   function open_scope(kind, label) result(opened)
   !< Begin a scope of `kind` (true when the begin returned true; the pushes always open).
   integer(int32),   intent(in) :: kind   !< Kind.
   character(len=*), intent(in) :: label  !< Its label.
   logical                      :: opened !< Opened.

   opened = .true.
   select case (kind)
   case (K_WINDOW)
      if (ig_begin(label)) continue
   case (K_CHILD)
      if (ig_begin_child(label, 100.0_real64, 50.0_real64)) continue
   case (K_TAB_BAR)
      opened = ig_begin_tab_bar(label)
   case (K_TAB)
      opened = ig_begin_tab(label)
   case (K_TABLE)
      opened = ig_begin_table(label, 2_int32)
   case (K_TREE)
      opened = ig_tree_node(label, leaf=.true.)
   case (K_MAIN_MENU_BAR)
      opened = ig_begin_main_menu_bar()
   case (K_MENU_BAR)
      opened = ig_begin_menu_bar()
   case (K_MENU)
      call ig_open_popup(label)
      opened = ig_begin_menu(label)
   case (K_POPUP)
      call ig_open_popup(label)
      opened = ig_begin_popup(label)
   case (K_PLOT)
      opened = ip_begin_plot(label, 200.0_real64, 150.0_real64)
   case (K_SUBPLOTS)
      opened = ip_begin_subplots(label, 1_int32, 1_int32, 200.0_real64, 150.0_real64)
   case (K_DOCK_LAYOUT)
      dock = dock + 1_int32
      opened = ig_dock_layout_begin(dock)
   case (K_ID)
      call ig_push_id(label)
   case (K_DISABLED)
      call ig_begin_disabled()
   case (K_FONT)
      call ig_push_font('', 20.0_real64)
   case (K_STYLE_COLOR)
      call ig_push_style_color('Text', '#ff0000')
   case (K_STYLE_VAR)
      call ig_push_style_var('Alpha', 0.9_real64)
   case (K_GROUP)
      call ig_begin_group()
   case (K_ALIGN)
      call ig_align_begin(label, 'right')
   case (K_ITEM_WIDTH)
      call ig_push_item_width(120.0_real64)
   endselect
   if (.not. opened) error stop 'figure_test_errors: a begin returned false: '//OPENER(kind)
   endfunction open_scope

   subroutine close_scope(kind)
   !< End a scope of `kind`.
   integer(int32), intent(in) :: kind !< Kind.

   select case (kind)
   case (K_WINDOW)
      call ig_end()
   case (K_CHILD)
      call ig_end_child()
   case (K_TAB_BAR)
      call ig_end_tab_bar()
   case (K_TAB)
      call ig_end_tab()
   case (K_TABLE)
      call ig_end_table()
   case (K_TREE)
      call ig_tree_pop()
   case (K_MAIN_MENU_BAR)
      call ig_end_main_menu_bar()
   case (K_MENU_BAR)
      call ig_end_menu_bar()
   case (K_MENU)
      call ig_end_menu()
   case (K_POPUP)
      call ig_end_popup()
   case (K_PLOT)
      call ip_end_plot()
   case (K_SUBPLOTS)
      call ip_end_subplots()
   case (K_DOCK_LAYOUT)
      call ig_dock_layout_end(dock)
   case (K_ID)
      call ig_pop_id()
   case (K_DISABLED)
      call ig_end_disabled()
   case (K_FONT)
      call ig_pop_font()
   case (K_STYLE_COLOR)
      call ig_pop_style_color()
   case (K_STYLE_VAR)
      call ig_pop_style_var()
   case (K_GROUP)
      call ig_end_group()
   case (K_ALIGN)
      call ig_align_end()
   case (K_ITEM_WIDTH)
      call ig_pop_item_width()
   endselect
   endsubroutine close_scope

   subroutine fault(kind, which, expected)
   !< Draw one frame with fault `which` on pair `kind`; `expected`: what the report must contain.
   integer(int32),                intent(in)  :: kind     !< Kind.
   integer(int32),                intent(in)  :: which    !< Fault.
   character(len=:), allocatable, intent(out) :: expected !< Part of the message.
   character(len=:), allocatable              :: label    !< The scope's label, as the record prints it.
   character(len=:), allocatable              :: hosted   !< The end of the scope it lives in.

   label = "('s"//trim(OPENER(kind))//"')"
   if (kind == K_MAIN_MENU_BAR .or. kind == K_MENU_BAR .or. kind == K_DISABLED) label = '()'
   if (kind == K_FONT .or. kind == K_GROUP .or. kind == K_ITEM_WIDTH) label = '()'
   if (kind == K_DOCK_LAYOUT) label = '('//itoa(dock + 1_int32)//')' ! the dock id of the next layout
   if (kind == K_STYLE_COLOR) label = "('Text')"
   if (kind == K_STYLE_VAR) label = "('Alpha')"
   select case (kind)
   case (K_WINDOW, K_MAIN_MENU_BAR, K_DOCK_LAYOUT, K_DISABLED, K_FONT, K_STYLE_COLOR, K_STYLE_VAR)
      hosted = ''
   case (K_TAB)
      hosted = 'ig_end_tab_bar'
   case (K_MENU)
      hosted = 'ig_end_menu_bar'
   case default
      hosted = 'ig_end'
   endselect
   select case (which)
   case (F_MISSING) ! the scope's end forgotten: the end of what holds it finds it open, or the frame's end does
      call host_begin(kind)
      if (open_scope(kind, 's'//trim(OPENER(kind)))) continue
      call host_end(kind)
      if (hosted == '') then
         expected = 'app%next_frame: '//trim(OPENER(kind))//label//' is still open (close it with '// &
                    trim(CLOSER(kind))//')'
      else
         expected = hosted//': the open scope is '//trim(OPENER(kind))//label//' (close it with '// &
                    trim(CLOSER(kind))//' before '//hosted//')'
      endif
   case (F_EXTRA) ! an end with nothing of its kind open
      call host_begin(kind)
      call close_scope(kind)
      call host_end(kind)
      expected = trim(CLOSER(kind))//': no '//trim(OPENER(kind))
   case (F_WRONG) ! the end of another kind while this one is open
      call host_begin(kind)
      if (open_scope(kind, 's'//trim(OPENER(kind)))) continue
      if (kind == K_ID) then
         call ig_tree_pop()
         expected = 'ig_tree_pop: no ig_tree_node is open; the open scope is ig_push_id'//label//' (closed by ig_pop_id)'
      else
         call ig_pop_id()
         expected = 'ig_pop_id: no ig_push_id is open; the open scope is '//trim(OPENER(kind))//label// &
                    ' (closed by '//trim(CLOSER(kind))//')'
      endif
      call close_scope(kind) ! the right end after the refused one: the frame closes cleanly
      call host_end(kind)
   case (F_FALSE) ! the end called although the begin returned false
      if (kind == K_DOCK_LAYOUT) label = '('//itoa(dock)//')' ! laid out already: false
      if (kind /= K_DOCK_LAYOUT) label = "('f')"
      if (kind == K_MENU_BAR) label = '()'
      call false_begin(kind)
      expected = trim(CLOSER(kind))//': '//trim(OPENER(kind))//label//' returned false (end only after a true begin)'
   endselect
   endsubroutine fault

   subroutine false_begin(kind)
   !< A begin of `kind` that returns false, then its end (the fault).
   integer(int32), intent(in) :: kind !< Kind.
   logical                    :: got  !< The begin's result.

   got = .true.
   select case (kind)
   case (K_TAB_BAR, K_TABLE, K_PLOT, K_SUBPLOTS, K_MENU_BAR) ! inside a collapsed window: false
      call igSetNextWindowCollapsed(.true._c_bool, ImGuiCond_Always)
      if (ig_begin('Collapsed', flags=ImGuiWindowFlags_MenuBar)) continue
      select case (kind)
      case (K_TAB_BAR)
         got = ig_begin_tab_bar('f')
      case (K_TABLE)
         got = ig_begin_table('f', 2_int32)
      case (K_PLOT)
         got = ip_begin_plot('f')
      case (K_SUBPLOTS)
         got = ip_begin_subplots('f', 1_int32, 1_int32)
      case (K_MENU_BAR)
         got = ig_begin_menu_bar()
      endselect
      call close_scope(kind)
      call ig_end()
   case (K_TAB) ! the second tab of a bar is not the selected one
      call host_begin(kind)
      if (ig_begin_tab('first')) call ig_end_tab()
      got = ig_begin_tab('f')
      call close_scope(kind)
      call host_end(kind)
   case (K_TREE) ! a closed node
      call host_begin(kind)
      got = ig_tree_node('f')
      call close_scope(kind)
      call host_end(kind)
   case (K_MENU) ! a menu not opened
      call host_begin(kind)
      got = ig_begin_menu('f')
      call close_scope(kind)
      call host_end(kind)
   case (K_POPUP) ! a popup not opened
      call host_begin(kind)
      got = ig_begin_popup('f')
      call close_scope(kind)
      call host_end(kind)
   case (K_DOCK_LAYOUT) ! laid out already
      got = ig_dock_layout_begin(dock)
      call close_scope(kind)
   endselect
   if (got) error stop 'figure_test_errors: a begin returned true: '//OPENER(kind)
   endsubroutine false_begin

   subroutine recover_frame()
   !< A frame with a missing inner end ('recover' repairs it) and the clean part of the UI.
   if (ig_begin('Recovered')) then
      if (ig_tree_node('inner', leaf=.true.)) call ig_text('a leaf')
   endif
   call ig_end() ! the tree is still open: closed first in 'recover'
   endsubroutine recover_frame

   function abort_child(what, expected) result(ok)
   !< Run this program again as a child in mode 'abort' (`what`: 'end' or 'open'): it must fail, and its standard
   !< error must hold `expected`.
   character(len=*), intent(in) :: what     !< The child's fault.
   character(len=*), intent(in) :: expected !< Its message.
   logical                      :: ok       !< It stopped with the message.
   character(len=1024)          :: me       !< This program.
   character(len=1024)          :: line     !< A line of the child's standard error.
   character(len=*), parameter  :: LOG = 'figure_test_errors_child.txt' !< The child's standard error.
   integer(int32)               :: code     !< The child's exit status.
   integer(int32)               :: u        !< Unit.
   integer(int32)               :: ios      !< I/O status.

   ok = .false.
   call get_command_argument(0, me)
   call execute_command_line('"'//trim(me)//'" '//what//' 2> '//LOG, exitstat=code)
   if (code == 0) return
   open(newunit=u, file=LOG, status='old', action='read', iostat=ios)
   if (ios /= 0) return
   do
      read(u, '(A)', iostat=ios) line
      if (ios /= 0) exit
      if (index(line, expected) > 0) ok = .true.
      if (what == 'end' .and. index(line, 'after the end') > 0) exit ! not stopped at the wrong end
   enddo
   if (ios == 0) ok = .false.
   close(u, status='delete')
   if (.not. ok) write(error_unit, '(A)') 'abort child '//what//': no "'//expected//'"'
   endfunction abort_child

   subroutine child(what)
   !< The child run: mode 'abort', then the fault `what`; it must never come back.
   character(len=*), intent(in) :: what !< 'end' (an end without begin) or 'open' (a window left open).

   call app%init_headless(400_int32, 300_int32)
   call app%set_checks('abort')
   if (.not. app%next_frame()) error stop 2
   select case (what)
   case ('end')
      call ig_end()
   case ('open')
      if (ig_begin('Left')) continue
   endselect
   write(error_unit, '(A)') 'figure_test_errors: after the '//what ! 'end': never reached in mode 'abort'
   if (app%next_frame()) continue
   write(output_unit, '(A)') 'figure_test_errors: the child was not stopped'
   stop 0 ! the parent sees success: a failure of the check
   endsubroutine child

   pure function itoa(i) result(text)
   !< `i` printed.
   integer(int32), intent(in)    :: i    !< Number.
   character(len=:), allocatable :: text !< Its digits.
   character(len=12)             :: buf  !< Buffer.

   write(buf, '(I0)') i
   text = trim(buf)
   endfunction itoa

   function cost() result(ok)
   !< The cost of the record per pair (ig_push_id/ig_pop_id against igPushID_Int/igPopID) and of the checks of a widget
   !< (ig_text against igTextUnformatted), in one frame; printed. True when the record costs less than 20 us a pair.
   logical                     :: ok       !< Small enough.
   integer(int32), parameter   :: N = 100000_int32 !< Pairs.
   integer(int32), parameter   :: M = 20000_int32  !< Texts.
   integer(int64)              :: t(5)     !< Clock ticks.
   integer(int64)              :: rate     !< Ticks per second.
   integer(int32)              :: i        !< Counter.
   real(real64)                :: pair(2)  !< ns per pair: FIGURE, raw.
   real(real64)                :: text(2)  !< ns per text: FIGURE, raw.

   if (ig_begin('Cost')) continue
   call system_clock(t(1), rate)
   do i = 1_int32, N
      call ig_push_id(i)
      call ig_pop_id()
   enddo
   call system_clock(t(2))
   do i = 1_int32, N
      call igPushID_Int(int(i, c_int))
      call igPopID()
   enddo
   call system_clock(t(3))
   do i = 1_int32, M
      call ig_text('x')
   enddo
   call system_clock(t(4))
   do i = 1_int32, M
      call igTextUnformatted('x'//c_null_char, c_null_ptr)
   enddo
   call system_clock(t(5))
   call ig_end()
   msg = report()
   pair = [real(t(2) - t(1), real64), real(t(3) - t(2), real64)] * 1.0e9_real64 / real(rate, real64) / real(N, real64)
   text = [real(t(4) - t(3), real64), real(t(5) - t(4), real64)] * 1.0e9_real64 / real(rate, real64) / real(M, real64)
   write(output_unit, '(A,F8.1,A,F8.1,A)') 'cost: ig_push_id + ig_pop_id ', pair(1), ' ns, raw ', pair(2), ' ns'
   write(output_unit, '(A,F8.1,A,F8.1,A)') 'cost: ig_text ', text(1), ' ns, raw igTextUnformatted ', text(2), ' ns'
   ok = msg == '' .and. pair(1) - pair(2) < 20000.0_real64
   endfunction cost
endprogram figure_test_errors
