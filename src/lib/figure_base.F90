!< figure_base, error handling and string conversion shared by the FIGURE modules.
module figure_base
!< figure_base, error handling and string conversion shared by the FIGURE modules.
!<
!< Procedures that can fail take an optional `stat`: if present it receives `FIG_OK` or a `FIG_ERR_*` code and
!< `figure_last_error()` gives the message; if absent, a failure prints the message and stops (`error stop`).
!<
!< Usage checks: every drawing procedure asks `figure_draw_refused` first (a task, or no frame open), and every
!< begin/end and push/pop pair registers in the scope record of the frame (`figure_scope_open` after the begin,
!< `figure_scope_refused` before the end): see errors.md, "Pairing and frames".
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_f_pointer, c_int, c_null_char, c_ptr
use, intrinsic :: iso_fortran_env, only : error_unit, int32
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, fig_last_error, fig_set_last_error, fig_task_refuse, &
                            fig_draw_refuse, fig_scope_close, fig_scope_open

implicit none
private
public :: figure_check, figure_fail, figure_last_error, cstr, figure_refused
public :: FORMAT_INTEGER, FORMAT_REAL, format_ok, format_refused
public :: figure_draw_refused, figure_scope_open, figure_scope_refused
public :: SCOPE_WINDOW, SCOPE_CHILD, SCOPE_TAB_BAR, SCOPE_TAB, SCOPE_TABLE, SCOPE_TREE, SCOPE_MAIN_MENU_BAR, SCOPE_MENU_BAR
public :: SCOPE_MENU, SCOPE_POPUP, SCOPE_PLOT, SCOPE_SUBPLOTS, SCOPE_DOCK_LAYOUT, SCOPE_ID, SCOPE_DISABLED, SCOPE_FONT
public :: SCOPE_STYLE_COLOR, SCOPE_STYLE_VAR, SCOPE_GROUP, SCOPE_ALIGN, SCOPE_ITEM_WIDTH, SCOPE_TOOLTIP

integer(int32), parameter :: FORMAT_INTEGER = 1_int32 !< A printf format of an integer value: d, i, u.
integer(int32), parameter :: FORMAT_REAL = 2_int32    !< A printf format of a real value: f, F, e, E, g, G, a, A.
! Kinds of scope in the record of the frame (native/figure_scope.cpp's kind_t: the same values).
integer(c_int), parameter :: SCOPE_WINDOW = 1_c_int         !< ig_begin, ig_begin_side_bar / ig_end (always paired).
integer(c_int), parameter :: SCOPE_CHILD = 2_c_int          !< ig_begin_child / ig_end_child (always paired).
integer(c_int), parameter :: SCOPE_TAB_BAR = 3_c_int        !< ig_begin_tab_bar / ig_end_tab_bar (after true).
integer(c_int), parameter :: SCOPE_TAB = 4_c_int            !< ig_begin_tab / ig_end_tab (after true).
integer(c_int), parameter :: SCOPE_TABLE = 5_c_int          !< ig_begin_table / ig_end_table (after true).
integer(c_int), parameter :: SCOPE_TREE = 6_c_int           !< ig_tree_node / ig_tree_pop (after true).
integer(c_int), parameter :: SCOPE_MAIN_MENU_BAR = 7_c_int  !< ig_begin_main_menu_bar / ig_end_main_menu_bar (after true).
integer(c_int), parameter :: SCOPE_MENU_BAR = 8_c_int       !< ig_begin_menu_bar / ig_end_menu_bar (after true).
integer(c_int), parameter :: SCOPE_MENU = 9_c_int           !< ig_begin_menu / ig_end_menu (after true).
integer(c_int), parameter :: SCOPE_POPUP = 10_c_int         !< ig_begin_popup, ig_begin_popup_context,
                                                             !< ig_begin_popup_modal / ig_end_popup (after true).
integer(c_int), parameter :: SCOPE_PLOT = 11_c_int          !< ip_begin_plot / ip_end_plot (after true).
integer(c_int), parameter :: SCOPE_SUBPLOTS = 12_c_int      !< ip_begin_subplots / ip_end_subplots (after true).
integer(c_int), parameter :: SCOPE_DOCK_LAYOUT = 13_c_int   !< ig_dock_layout_begin / ig_dock_layout_end (after true).
integer(c_int), parameter :: SCOPE_ID = 14_c_int            !< ig_push_id / ig_pop_id.
integer(c_int), parameter :: SCOPE_DISABLED = 15_c_int      !< ig_begin_disabled / ig_end_disabled.
integer(c_int), parameter :: SCOPE_FONT = 16_c_int          !< ig_push_font / ig_pop_font.
integer(c_int), parameter :: SCOPE_STYLE_COLOR = 17_c_int   !< ig_/ip_push_style_color / ig_/ip_pop_style_color.
integer(c_int), parameter :: SCOPE_STYLE_VAR = 18_c_int     !< ig_/ip_push_style_var / ig_/ip_pop_style_var.
integer(c_int), parameter :: SCOPE_GROUP = 19_c_int         !< ig_begin_group / ig_end_group (always paired).
integer(c_int), parameter :: SCOPE_ALIGN = 20_c_int         !< ig_align_begin / ig_align_end (always paired).
integer(c_int), parameter :: SCOPE_ITEM_WIDTH = 21_c_int    !< ig_push_item_width / ig_pop_item_width (always paired).
integer(c_int), parameter :: SCOPE_TOOLTIP = 22_c_int       !< ig_begin_tooltip, ig_begin_item_tooltip / ig_end_tooltip
                                                             !< (after true).

contains
   function figure_last_error() result(msg)
   !< Message of the last failed call.
   character(len=:), allocatable          :: msg    !< Message.
   character(kind=c_char), pointer        :: buf(:) !< Borrowed C buffer.
   type(c_ptr)                            :: p      !< C pointer to the message.
   integer(c_int)                         :: n      !< Message length [bytes].
   integer(int32)                         :: i      !< Counter.

   p = fig_last_error(n)
   allocate(character(len=max(n, 0_c_int)) :: msg)
   if (n <= 0_c_int .or. .not. c_associated(p)) return
   call c_f_pointer(p, buf, [n])
   do i = 1_int32, int(n, int32)
      msg(i:i) = buf(i)
   enddo
   endfunction figure_last_error

   subroutine figure_check(status, stat)
   !< Store `status` in `stat` if present, else stop on failure with the last error message.
   integer(c_int), intent(in)            :: status !< Status from the native layer.
   integer(int32), intent(out), optional :: stat   !< Status for the caller.

   if (present(stat)) then
      stat = int(status, int32)
   elseif (status /= FIG_OK) then
      write(error_unit, '(A)') 'FIGURE error: '//figure_last_error()
      error stop 1
   endif
   endsubroutine figure_check

   subroutine figure_fail(status, message, stat)
   !< Report a failure detected on the Fortran side: set the last error message, then act as `figure_check`.
   integer(c_int),   intent(in)            :: status  !< Failure status (a `FIG_ERR_*` code).
   character(len=*), intent(in)            :: message !< Message for `figure_last_error`.
   integer(int32),   intent(out), optional :: stat    !< Status for the caller.

   call fig_set_last_error(message, len(message, c_int))
   call figure_check(status, stat)
   endsubroutine figure_fail

   recursive function figure_refused(name, stat) result(refused)
   !< True when called from a task's worker thread: the drawing entry point `name` must return at once. The task's
   !< status becomes `FIG_ERR_STATE` with a message naming `name` (given by `t%result`), the task is asked to stop, and
   !< `stat`, if present, is `FIG_ERR_STATE`. False on the main thread (nothing changes).
   character(len=*), intent(in)            :: name    !< The entry point.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.

   refused = fig_task_refuse(name, len(name, c_int)) == 1_c_int
   if (refused .and. present(stat)) stat = int(FIG_ERR_STATE, int32)
   endfunction figure_refused

   recursive function figure_draw_refused(name, stat) result(refused)
   !< True when the drawing entry point `name` must return at once: called from a task (as `figure_refused`), or with
   !< no frame open (a usage error: `FIG_ERR_STATE`, `<name>: no frame open`). A usage error is returned in `stat`
   !< when present; without it, mode 'abort' stops the program here and the other modes keep it for the next
   !< `app%next_frame` (`app%set_checks`). False, `stat` untouched, inside a frame on the main thread.
   character(len=*), intent(in)            :: name    !< The entry point.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.
   integer(c_int)                          :: action  !< 0 go on, 1 refused, 2 stop.

   action = fig_draw_refuse(name, len(name, c_int), merge(1_c_int, 0_c_int, present(stat)))
   refused = action /= 0_c_int
   if (action == 2_c_int) call figure_check(FIG_ERR_STATE) ! 'abort': the message, then error stop
   if (refused .and. present(stat)) stat = int(FIG_ERR_STATE, int32)
   endfunction figure_draw_refused

   recursive subroutine figure_scope_open(kind, who, label, returned, aux)
   !< After a begin or a push: its scope in the record of the frame (a begin of the "end only after true" kind that
   !< returned false is remembered for the message of a wrong end, not opened).
   integer(c_int),   intent(in)           :: kind     !< SCOPE_*.
   character(len=*), intent(in)           :: who      !< The procedure (`ig_begin`).
   character(len=*), intent(in)           :: label    !< Its label or id (`''` when none).
   logical,          intent(in), optional :: returned !< What the begin returned (default true).
   integer(int32),   intent(in), optional :: aux      !< The dock id of a dock layout.
   integer(c_int)                         :: r        !< C copy of `returned`.
   integer(c_int)                         :: a        !< C copy of `aux`.

   r = 1_c_int
   if (present(returned)) r = merge(1_c_int, 0_c_int, returned)
   a = 0_c_int
   if (present(aux)) a = int(aux, c_int)
   call fig_scope_open(kind, who, len(who, c_int), label, len(label, c_int), r, a)
   endsubroutine figure_scope_open

   recursive function figure_scope_refused(kind, who, n, stat) result(refused)
   !< Before an end or a pop: true when it must return at once, because it is called from a task or with no frame open
   !< (as `figure_draw_refused`) or because it does not close the innermost open scope of the record (`FIG_ERR_STATE`,
   !< the message naming both calls); in mode 'recover' an end whose scope is open further down closes the scopes
   !< opened after it and goes on. A usage error is returned in `stat` when present; without it, mode 'abort' stops
   !< here and the other modes keep it for the next `app%next_frame`.
   integer(c_int),   intent(in)            :: kind    !< SCOPE_*.
   character(len=*), intent(in)            :: who     !< The procedure (`ig_end`).
   integer(int32),   intent(in),  optional :: n       !< Pops (style changes; default 1).
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.
   integer(c_int)                          :: k       !< Pops.
   integer(c_int)                          :: action  !< 0 go on, 1 refused, 2 stop.

   k = 1_c_int
   if (present(n)) k = int(n, c_int)
   action = fig_scope_close(kind, who, len(who, c_int), k, merge(1_c_int, 0_c_int, present(stat)))
   refused = action /= 0_c_int
   if (action == 2_c_int) call figure_check(FIG_ERR_STATE) ! 'abort': the message, then error stop
   if (refused .and. present(stat)) stat = int(FIG_ERR_STATE, int32)
   endfunction figure_scope_refused

   pure function format_ok(fmt, family, text) result(ok)
   !< True when `fmt` is a printf format for one value of `family` (`FORMAT_INTEGER` or `FORMAT_REAL`): exactly one
   !< conversion of the family (`d`, `i`, `u`; `f`, `F`, `e`, `E`, `g`, `G`, `a`, `A`), with optional flags (`-+ #0`),
   !< width and precision (digits), and any number of `%%` and other characters. Refused: no conversion or more than
   !< one, a conversion of the other family or of none (`%s`, `%c`, `%p`, `%x`, `%n`, ...), `*` for a width or a
   !< precision, length modifiers (`%ld`, `%Lf`), a `%` at the end. With `text=.true.`, a format with no conversion
   !< (text, `%%` included, or empty) is accepted too: C prints it as it is and ignores the value. Formats given to C's
   !< formatter unchecked are undefined behaviour when they do not match the value: a wrong label at best, a crash at
   !< worst.
   character(len=*), intent(in)           :: fmt    !< The format.
   integer(int32),   intent(in)           :: family !< FORMAT_INTEGER or FORMAT_REAL.
   logical,          intent(in), optional :: text   !< Accept a format without conversion (default false).
   logical                                :: ok     !< A format of the family.
   integer                      :: i, j   !< Positions.
   integer                      :: n      !< Conversions found.

   ok = .false.
   n = 0
   i = 1
   do while (i <= len(fmt))
      if (fmt(i:i) /= '%') then
         i = i + 1
         cycle
      endif
      j = i + 1
      if (j > len(fmt)) return                              ! a '%' at the end
      if (fmt(j:j) == '%') then                             ! '%%': a percent sign
         i = j + 1
         cycle
      endif
      do while (j <= len(fmt))                              ! flags
         if (index('-+ #0', fmt(j:j)) == 0) exit
         j = j + 1
      enddo
      do while (j <= len(fmt))                              ! width
         if (index('0123456789', fmt(j:j)) == 0) exit
         j = j + 1
      enddo
      if (j <= len(fmt)) then                               ! precision
         if (fmt(j:j) == '.') then
            j = j + 1
            do while (j <= len(fmt))
               if (index('0123456789', fmt(j:j)) == 0) exit
               j = j + 1
            enddo
         endif
      endif
      if (j > len(fmt)) return
      select case (family)
      case (FORMAT_INTEGER)
         if (index('diu', fmt(j:j)) == 0) return
      case (FORMAT_REAL)
         if (index('fFeEgGaA', fmt(j:j)) == 0) return
      case default
         return
      endselect
      n = n + 1
      i = j + 1
   enddo
   ok = n == 1
   if (present(text)) ok = ok .or. (text .and. n == 0)
   endfunction format_ok

   function format_refused(name, argument, fmt, family, stat, text) result(refused)
   !< True when `fmt` is not a printf format of `family` (`format_ok`): the failure is reported as `figure_fail` does,
   !< `FIG_ERR_ARGUMENT` with a message naming the procedure, the argument and the family expected (`stat` absent:
   !< `error stop` with it). False, `stat` untouched, for a good format.
   character(len=*), intent(in)            :: name     !< The procedure.
   character(len=*), intent(in)            :: argument !< The argument holding the format.
   character(len=*), intent(in)            :: fmt      !< The format.
   integer(int32),   intent(in)            :: family   !< FORMAT_INTEGER or FORMAT_REAL.
   integer(int32),   intent(out), optional :: stat     !< Status, on a refusal.
   logical,          intent(in),  optional :: text     !< Accept a format without conversion (`format_ok`).
   logical                                 :: refused  !< Refused: return.
   character(len=:), allocatable           :: or_text  !< The text alternative, when accepted.

   refused = .not. format_ok(fmt, family, text)
   if (.not. refused) return
   or_text = ''
   if (present(text)) then
      if (text) or_text = ' (or none: text, printed as it is)'
   endif
   if (family == FORMAT_INTEGER) then
      call figure_fail(FIG_ERR_ARGUMENT, name//': '//argument//" '"//fmt//"' is not a format of an integer: one "// &
                       'conversion %d, %i or %u expected, with optional flags, width and precision'//or_text, stat)
   else
      call figure_fail(FIG_ERR_ARGUMENT, name//': '//argument//" '"//fmt//"' is not a format of a real: one "//     &
                       'conversion %f, %e, %g or %a (or %F, %E, %G, %A) expected, with optional flags, width and '// &
                       'precision'//or_text, stat)
   endif
   endfunction format_refused

   pure function cstr(s) result(c)
   !< `s` NUL-terminated, for cimgui/cimplot (trailing blanks kept: labels are taken verbatim).
   character(len=*), intent(in)               :: s !< Fortran string.
   character(kind=c_char, len=:), allocatable :: c !< C string.

   c = s//c_null_char
   endfunction cstr
endmodule figure_base
