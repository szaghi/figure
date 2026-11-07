!< figure_process, programs started from the program (process_object) and a view of their output (log_view_object).
module figure_process
!< figure_process, programs started from the program (process_object) and a view of their output (log_view_object).
!<
!< A process runs in one of two modes.
!<
!< - **Captured** (the default): its standard output, and its standard error with `merge_stderr` (the default), are
!<   piped to the program. A native reader thread drains the pipe as the child writes and wakes the frame loop, so a
!<   child printing megabytes never blocks while the program is busy or its loop sleeps. `p%poll(lines)` gives the
!<   complete lines since the last poll. The child is killed when the object ends, at `app%destroy`, and when the
!<   program exits.
!< - **Detached** (`detached=.true.`, with `log_file`): its output goes to the file, and the child survives the
!<   program. `p%poll(lines)` follows the file.
!<
!< The arguments are passed as an array, without a shell: `['sh', '-c', 'a | b']` when a pipeline is wanted.
use, intrinsic :: iso_c_binding, only : c_bool, c_char, c_float, c_int, c_long_long, c_null_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure_base, only : cstr, figure_check, figure_fail, figure_refused
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, fig_process_info, fig_process_kill,            &
                            fig_process_pending, fig_process_release, fig_process_start, fig_process_take
use figure_cimgui, only : igBeginChild_Str, igBeginPopupContextWindow, igEndChild, igEndPopup, igGetCursorPosX,     &
                          igGetScrollMaxY, igGetScrollY, igGetTextLineHeightWithSpacing, igIsKeyChordPressed_Nil,  &
                          igIsKeyDown_Nil, igIsWindowFocused, igMenuItem_Bool, igPopID, igPushID_Int, igSameLine,  &
                          igSelectable_Bool, igSetClipboardText, igSetScrollHereY, igTextUnformatted, im_vec2
use figure_cimgui_enums, only : ImGuiChildFlags_Borders, ImGuiKey_C, ImGuiMod_Ctrl, ImGuiMod_Shift,                 &
                                ImGuiWindowFlags_HorizontalScrollbar
use figure_group, only : list_clipper_object

implicit none
private
public :: process_object, log_view_object

type :: process_object
   !< A program started from the program: `p%start(args)`, then `p%poll(lines)` every frame while `p%running()`.
   !< Not to be copied: the copy would own the same child.
   integer(c_int), private :: id = 0_c_int !< Native handle (0: none).
   contains
      procedure, pass(self) :: start => process_start         !< Start a program.
      procedure, pass(self) :: poll => process_poll           !< The complete lines since the last poll.
      procedure, pass(self) :: running => process_running     !< It runs (or output is still to be read).
      procedure, pass(self) :: exit_code => process_exit_code !< Its exit code (captured, ended).
      procedure, pass(self) :: killed => process_killed       !< It ended after `kill`.
      procedure, pass(self) :: pid => process_pid             !< Its process id.
      procedure, pass(self) :: kill => process_kill           !< Ask it to end.
      final                 :: process_final
endtype process_object

type :: log_line_object
   !< One line of a log view.
   character(len=:), allocatable :: text !< The line.
endtype log_line_object

type :: log_view_object
   !< Lines of text kept in a ring buffer (`set_cap`, default 10000 lines: the oldest go first) and drawn in a region
   !< of their own, only those in view. The view follows the end while it is scrolled to the bottom; a click chooses a
   !< line, shift+click extends the choice, ctrl+c (cmd+c on macOS) or the right-click menu copies it.
   type(log_line_object), allocatable, private :: ring(:)              !< The lines, from position `head`.
   integer(int32),                     private :: cap = 10000_int32    !< Lines kept at most.
   integer(int32),                     private :: head = 1_int32       !< Position of the oldest line in `ring`.
   integer(int32),                     private :: n = 0_int32          !< Lines kept.
   integer(int64),                     private :: total = 0_int64      !< Lines ever added (the newest's number).
   integer(int64),                     private :: sel(2) = 0_int64     !< First and last chosen line (numbers; 0: none).
   logical,                            private :: follow = .true.      !< The view follows the end.
   integer(int32),                     private :: view(2) = [1, 0]     !< Kept lines in view on the last draw.
   contains
      procedure, pass(self), private :: add_line, add_lines
      generic                        :: add => add_line, add_lines     !< Add one line or several.
      procedure, pass(self)          :: clear => log_clear             !< Remove every line.
      procedure, pass(self)          :: set_cap => log_set_cap         !< The number of lines kept.
      procedure, pass(self)          :: count => log_count             !< Lines kept.
      procedure, pass(self)          :: line => log_line               !< A kept line.
      procedure, pass(self)          :: draw => log_draw               !< Draw the view.
      procedure, pass(self)          :: following => log_following     !< The view follows the end.
      procedure, pass(self)          :: in_view => log_in_view         !< The lines in view on the last draw.
      procedure, pass(self)          :: copy => log_copy               !< The chosen lines, joined by newlines.
endtype log_view_object

contains
   ! ---- process_object ------------------------------------------------------------------------------------------------
   subroutine process_start(self, args, cwd, env, merge_stderr, detached, log_file, stat)
   !< Start the program `args(1)` with the arguments `args(2:)` (each trimmed of trailing blanks; no shell). `cwd`: its
   !< working directory (default: the program's). `env`: `NAME=value` entries added to (or replacing in) the program's
   !< environment. `merge_stderr` (default true): standard error goes with standard output (false: captured, it goes
   !< to the program's own standard error; detached, it is discarded). `detached` (default false) needs `log_file`,
   !< which is created or truncated. Statuses: `FIG_ERR_STATE` while this object's previous process still runs,
   !< `FIG_ERR_ARGUMENT` for an empty `args`, an entry of `env` without `=`, `detached` without `log_file` (or
   !< `log_file` without `detached`), `FIG_ERR_FAILED` when the program cannot be started (not found, not executable)
   !< or the log file cannot be written. The same in every mode (in remote mode the program runs on the server).
   class(process_object), intent(inout)         :: self         !< Process.
   character(len=*),      intent(in)            :: args(:)      !< Program and arguments.
   character(len=*),      intent(in),  optional :: cwd          !< Working directory.
   character(len=*),      intent(in),  optional :: env(:)       !< `NAME=value` entries.
   logical,               intent(in),  optional :: merge_stderr !< Standard error with the output (default true).
   logical,               intent(in),  optional :: detached     !< Detached (default false).
   character(len=*),      intent(in),  optional :: log_file     !< Detached: the file of its output.
   integer(int32),        intent(out), optional :: stat         !< Status.
   character(kind=c_char, len=:), allocatable   :: packed_args  !< Arguments, packed.
   character(kind=c_char, len=:), allocatable   :: packed_env   !< Environment, packed.
   integer(c_int),                allocatable   :: arg_lens(:)  !< Their lengths [bytes].
   integer(c_int),                allocatable   :: env_lens(:)  !< Their lengths [bytes].
   character(len=:),              allocatable   :: dir          !< Working directory.
   character(len=:),              allocatable   :: log          !< Log file.
   integer(c_int)                               :: merge        !< C copy of merge_stderr.
   integer(c_int)                               :: det          !< C copy of detached.
   integer(c_int)                               :: new_id       !< New handle.
   integer(c_int)                               :: status       !< Native status.

   if (self%id /= 0_c_int) then
      if (self%running()) then
         call figure_fail(FIG_ERR_STATE, 'process_object%start: its process still runs: kill it or wait for its end', &
                          stat)
         return
      endif
      call fig_process_release(self%id)
      self%id = 0_c_int
   endif
   if (size(args) < 1) then
      call figure_fail(FIG_ERR_ARGUMENT, 'process_object%start: args is empty: the program is args(1)', stat)
      return
   endif
   call pack_strings(args, packed_args, arg_lens)
   if (present(env)) then
      call pack_strings(env, packed_env, env_lens)
   else
      allocate(character(kind=c_char, len=1) :: packed_env)
      allocate(env_lens(1))
      env_lens = 0_c_int
   endif
   dir = ''
   if (present(cwd)) dir = trim(cwd)
   log = ''
   if (present(log_file)) log = trim(log_file)
   merge = 1_c_int
   if (present(merge_stderr)) then
      if (.not. merge_stderr) merge = 0_c_int
   endif
   det = 0_c_int
   if (present(detached)) then
      if (detached) det = 1_c_int
   endif
   status = fig_process_start(new_id, packed_args, arg_lens, size(args, kind=c_int), dir, len(dir, c_int),  &
                              packed_env, env_lens, merge_env(env), merge, det, log, len(log, c_int))
   if (status == FIG_OK) self%id = new_id
   call figure_check(status, stat)
   contains
      pure function merge_env(e) result(m)
      !< Entries of `env` (0 when absent).
      character(len=*), intent(in), optional :: e(:) !< Entries.
      integer(c_int)                         :: m    !< Count.

      m = 0_c_int
      if (present(e)) m = size(e, kind=c_int)
      endfunction merge_env
   endsubroutine process_start

   subroutine process_poll(self, lines, stat)
   !< The complete lines printed since the last poll, oldest first, without their newline (a carriage return is
   !< dropped); a last line without a newline is kept until it is completed, or given once the process has ended.
   !< `lines` has no element when there is nothing new; its length is the longest line's (shorter ones are padded with
   !< blanks: `trim` them). Detached: the lines appended to `log_file`. Status: `FIG_ERR_STATE` before `start`.
   class(process_object),         intent(inout)         :: self     !< Process.
   character(len=:), allocatable, intent(out)           :: lines(:) !< The new lines.
   integer(int32),                intent(out), optional :: stat     !< Status.
   character(kind=c_char, len=:), allocatable           :: buf      !< The bytes taken.
   integer(c_long_long)                                 :: length   !< Bytes ready.
   integer(c_long_long)                                 :: got      !< Bytes taken.
   integer(c_int)                                       :: running  !< 1 while it runs.
   integer(c_int)                                       :: status   !< Native status.

   if (self%id == 0_c_int) then
      allocate(character(len=0) :: lines(0))
      call figure_fail(FIG_ERR_STATE, 'process_object%poll: no process started', stat)
      return
   endif
   status = fig_process_pending(self%id, length, running)
   got = 0_c_long_long
   if (status == FIG_OK .and. length > 0_c_long_long) then
      allocate(character(kind=c_char, len=length) :: buf)
      status = fig_process_take(self%id, buf, length, got)
   endif
   if (got > 0_c_long_long) then
      call split_lines(buf(1:got), lines)
   else
      allocate(character(len=0) :: lines(0))
   endif
   call figure_check(status, stat)
   endsubroutine process_poll

   function process_running(self) result(running)
   !< True while the process runs; a captured one counts as running until its output has all been read by FIGURE
   !< (then a last `poll` gives the rest). False before `start`.
   class(process_object), intent(in) :: self    !< Process.
   logical                           :: running !< It runs.
   integer(c_int)                    :: r, e, c, k, d !< Native state.
   integer(c_long_long)              :: p       !< Pid.

   running = .false.
   if (self%id == 0_c_int) return
   if (fig_process_info(self%id, r, e, c, k, p, d) == FIG_OK) running = r == 1_c_int
   endfunction process_running

   function process_exit_code(self, stat) result(code)
   !< The exit code of a captured process that has ended (after a kill: the negative signal number on POSIX, 1 on
   !< Windows). `FIG_ERR_STATE` (and -1) before `start`, while it runs, and for a detached process (its exit code is
   !< not known: the program's own log tells how it ended).
   class(process_object), intent(in)            :: self   !< Process.
   integer(int32),        intent(out), optional :: stat   !< Status.
   integer(int32)                               :: code   !< Exit code.
   integer(c_int)                               :: r, e, c, k, d !< Native state.
   integer(c_long_long)                         :: p      !< Pid.

   code = -1_int32
   if (self%id == 0_c_int) then
      call figure_fail(FIG_ERR_STATE, 'process_object%exit_code: no process started', stat)
      return
   endif
   call figure_check(fig_process_info(self%id, r, e, c, k, p, d), stat)
   if (d == 1_c_int) then
      call figure_fail(FIG_ERR_STATE, 'process_object%exit_code: the exit code of a detached process is not known', &
                       stat)
   elseif (e == 0_c_int) then
      call figure_fail(FIG_ERR_STATE, 'process_object%exit_code: the process still runs', stat)
   else
      code = int(c, int32)
   endif
   endfunction process_exit_code

   function process_killed(self) result(killed)
   !< True when the process ended after `kill` (false before `start`, while it runs, or when it ended by itself
   !< before the kill).
   class(process_object), intent(in) :: self   !< Process.
   logical                           :: killed !< It was killed.
   integer(c_int)                    :: r, e, c, k, d !< Native state.
   integer(c_long_long)              :: p      !< Pid.

   killed = .false.
   if (self%id == 0_c_int) return
   if (fig_process_info(self%id, r, e, c, k, p, d) == FIG_OK) killed = k == 1_c_int .and. e == 1_c_int
   endfunction process_killed

   function process_pid(self) result(pid)
   !< The process id given by the system (0 before `start`).
   class(process_object), intent(in) :: self !< Process.
   integer(int64)                    :: pid  !< Process id.
   integer(c_int)                    :: r, e, c, k, d !< Native state.
   integer(c_long_long)              :: p    !< Pid.

   pid = 0_int64
   if (self%id == 0_c_int) return
   if (fig_process_info(self%id, r, e, c, k, p, d) == FIG_OK) pid = int(p, int64)
   endfunction process_pid

   subroutine process_kill(self, force, stat)
   !< Ask the process to end: SIGTERM on POSIX (with `force`, SIGKILL); on Windows a close request to its windows or
   !< console (a console program may ignore it: use `force`, TerminateProcess). Only the started program is stopped,
   !< not the programs it started itself. An ended process: nothing happens. `FIG_ERR_STATE` before `start`,
   !< `FIG_ERR_FAILED` when the system refuses.
   class(process_object), intent(inout)         :: self  !< Process.
   logical,               intent(in),  optional :: force !< At once (default false).
   integer(int32),        intent(out), optional :: stat  !< Status.
   integer(c_int)                               :: f     !< C copy of force.

   if (self%id == 0_c_int) then
      call figure_fail(FIG_ERR_STATE, 'process_object%kill: no process started', stat)
      return
   endif
   f = 0_c_int
   if (present(force)) then
      if (force) f = 1_c_int
   endif
   call figure_check(fig_process_kill(self%id, f), stat)
   endsubroutine process_kill

   subroutine process_final(self)
   !< The object ends: a captured process still running is killed; a detached one goes on.
   type(process_object), intent(inout) :: self !< Process.

   if (self%id /= 0_c_int) call fig_process_release(self%id)
   self%id = 0_c_int
   endsubroutine process_final

   pure subroutine pack_strings(s, packed, lens)
   !< The strings of `s`, trimmed, one after the other, and their lengths.
   character(len=*),                           intent(in)  :: s(:)    !< Strings.
   character(kind=c_char, len=:), allocatable, intent(out) :: packed  !< Packed.
   integer(c_int),                allocatable, intent(out) :: lens(:) !< Lengths [bytes].
   integer(int32)                                          :: i       !< Counter.

   allocate(lens(max(size(s), 1)))
   lens = 0_c_int
   packed = ''
   do i = 1_int32, size(s, kind=int32)
      lens(i) = len_trim(s(i), c_int)
      packed = packed//trim(s(i))
   enddo
   if (len(packed) == 0) packed = ' ' ! a buffer to point to
   endsubroutine pack_strings

   pure subroutine split_lines(buf, lines)
   !< `buf` cut at each LF (carriage returns dropped); a last piece without LF is a line too.
   character(len=*),              intent(in)  :: buf      !< Bytes.
   character(len=:), allocatable, intent(out) :: lines(:) !< Lines.
   integer(int32)                             :: count    !< Lines.
   integer(int32)                             :: longest  !< Longest line [bytes].
   integer(int32)                             :: i, k, s, l !< Counters, start, length.
   character(len=1), parameter                :: LF = achar(10), CR = achar(13)

   count = 0_int32
   longest = 0_int32
   l = 0_int32
   do i = 1_int32, len(buf, int32)
      if (buf(i:i) == LF) then
         count = count + 1_int32
         longest = max(longest, l)
         l = 0_int32
      elseif (buf(i:i) /= CR) then
         l = l + 1_int32
      endif
   enddo
   if (l > 0_int32 .or. (len(buf) > 0 .and. buf(len(buf):len(buf)) /= LF)) then
      count = count + 1_int32
      longest = max(longest, l)
   endif
   allocate(character(len=longest) :: lines(count))
   lines = ''
   k = 1_int32
   s = 0_int32
   do i = 1_int32, len(buf, int32)
      if (buf(i:i) == LF) then
         k = k + 1_int32
         s = 0_int32
      elseif (buf(i:i) /= CR) then
         s = s + 1_int32
         lines(k)(s:s) = buf(i:i)
      endif
   enddo
   endsubroutine split_lines

   ! ---- log_view_object -----------------------------------------------------------------------------------------------
   subroutine add_line(self, line)
   !< Add a line (trailing blanks removed); with the buffer full, the oldest line goes.
   class(log_view_object), intent(inout) :: self !< Log.
   character(len=*),       intent(in)    :: line !< Line.
   integer(int32)                        :: at   !< Its position in the ring.

   if (.not. allocated(self%ring)) allocate(self%ring(self%cap))
   if (self%n < self%cap) then
      self%n = self%n + 1_int32
   else
      self%head = modulo(self%head, self%cap) + 1_int32
   endif
   at = modulo(self%head - 1_int32 + self%n - 1_int32, self%cap) + 1_int32
   self%ring(at)%text = trim(line)
   self%total = self%total + 1_int64
   endsubroutine add_line

   subroutine add_lines(self, lines)
   !< Add lines, oldest first (as `p%poll` gives them).
   class(log_view_object), intent(inout) :: self     !< Log.
   character(len=*),       intent(in)    :: lines(:) !< Lines.
   integer(int32)                        :: i        !< Counter.

   do i = 1_int32, size(lines, kind=int32)
      call self%add_line(lines(i))
   enddo
   endsubroutine add_lines

   subroutine log_clear(self)
   !< Remove every line (and the choice); the cap stays.
   class(log_view_object), intent(inout) :: self !< Log.

   if (allocated(self%ring)) deallocate(self%ring)
   self%head = 1_int32
   self%n = 0_int32
   self%sel = 0_int64
   self%follow = .true.
   endsubroutine log_clear

   subroutine log_set_cap(self, cap, stat)
   !< Keep at most `cap` lines (at least 1): the newest stay. Status: `FIG_ERR_ARGUMENT` for `cap` < 1.
   class(log_view_object), intent(inout)         :: self   !< Log.
   integer(int32),         intent(in)            :: cap    !< Lines kept at most.
   integer(int32),         intent(out), optional :: stat   !< Status.
   type(log_line_object),  allocatable           :: old(:) !< The lines kept, oldest first.
   integer(int32)                                :: keep   !< Lines kept.
   integer(int32)                                :: i      !< Counter.

   if (cap < 1_int32) then
      call figure_fail(FIG_ERR_ARGUMENT, 'log_view_object%set_cap: the cap must be at least 1', stat)
      return
   endif
   keep = min(self%n, cap)
   allocate(old(keep))
   do i = 1_int32, keep
      old(i)%text = self%line(self%n - keep + i)
   enddo
   if (allocated(self%ring)) deallocate(self%ring)
   allocate(self%ring(cap))
   self%cap = cap
   self%head = 1_int32
   self%n = keep
   do i = 1_int32, keep
      call move_alloc(old(i)%text, self%ring(i)%text)
   enddo
   if (present(stat)) stat = FIG_OK
   endsubroutine log_set_cap

   pure function log_count(self) result(n)
   !< The number of lines kept.
   class(log_view_object), intent(in) :: self !< Log.
   integer(int32)                     :: n    !< Lines.

   n = self%n
   endfunction log_count

   pure function log_line(self, i) result(text)
   !< Kept line `i`, from 1 (the oldest kept) to `count()`; '' out of range.
   class(log_view_object), intent(in) :: self !< Log.
   integer(int32),         intent(in) :: i    !< Line.
   character(len=:), allocatable      :: text !< Its text.

   text = ''
   if (i < 1_int32 .or. i > self%n) return
   text = self%ring(modulo(self%head - 1_int32 + i - 1_int32, self%cap) + 1_int32)%text
   endfunction log_line

   pure function log_following(self) result(follow)
   !< True while the view follows the end (it was scrolled to the bottom on the last draw): new lines scroll it.
   class(log_view_object), intent(in) :: self   !< Log.
   logical                            :: follow !< It follows.

   follow = self%follow
   endfunction log_following

   pure subroutine log_in_view(self, first, last)
   !< The kept lines drawn on the last `draw` (`last` < `first` when none).
   class(log_view_object), intent(in)  :: self  !< Log.
   integer(int32),         intent(out) :: first !< First line in view.
   integer(int32),         intent(out) :: last  !< Last line in view.

   first = self%view(1)
   last = self%view(2)
   endsubroutine log_in_view

   function log_copy(self, all) result(text)
   !< The chosen lines (with `all`, every kept line), joined by newlines; '' when none is chosen.
   class(log_view_object), intent(in)           :: self !< Log.
   logical,                intent(in), optional :: all  !< Every line.
   character(len=:), allocatable                :: text !< Text.
   integer(int64)                               :: a, b !< Numbers of the first and last line.
   integer(int32)                               :: i    !< Counter.
   logical                                      :: every !< Every line.

   text = ''
   every = .false.
   if (present(all)) every = all
   if (every) then
      a = self%total - self%n + 1_int64
      b = self%total
   else
      if (self%sel(1) <= 0_int64) return
      a = min(self%sel(1), self%sel(2))
      b = max(self%sel(1), self%sel(2))
   endif
   do i = 1_int32, self%n
      if (self%total - self%n + i < a .or. self%total - self%n + i > b) cycle
      if (len(text) > 0) text = text//achar(10)
      text = text//self%line(i)
   enddo
   endfunction log_copy

   subroutine log_draw(self, id, height)
   !< Draw the lines in a region of their own (`id`, not shown) as wide as the space left and `height` [pixels] high
   !< (absent or 0: the rest of the window; negative: leave that much below). Only the lines in view are drawn. The
   !< view follows the end while it is scrolled to the bottom; scrolled up, it stays where it is.
   class(log_view_object), intent(inout)        :: self    !< Log.
   character(len=*),       intent(in)           :: id      !< Id of the region.
   real(real64),           intent(in), optional :: height  !< Height [pixels].
   type(list_clipper_object)                    :: clip    !< Only the lines in view.
   real(c_float)                                :: h       !< Height.
   real(c_float)                                :: x       !< Left of a line.
   logical                                      :: at_end  !< Scrolled to the bottom (last frame's layout).
   integer(int32)                               :: i       !< Line.
   integer(int64)                               :: num     !< Its number.
   logical                                      :: chosen  !< It is chosen.
   integer(int32)                               :: widest  !< Lines in the largest range of the clipper.

   if (figure_refused('log_view_object%draw')) return ! a task does not draw
   h = 0.0_c_float
   if (present(height)) h = real(height, c_float)
   if (igBeginChild_Str(cstr(id), im_vec2(0.0_c_float, h), ImGuiChildFlags_Borders,                                 &
                        ImGuiWindowFlags_HorizontalScrollbar)) then
      at_end = igGetScrollY() >= igGetScrollMaxY() - 1.0_c_float
      self%view = [1_int32, 0_int32]
      widest = 0_int32
      call clip%begin(self%n, real(igGetTextLineHeightWithSpacing(), real64))
      do while (clip%step())
         if (clip%last - clip%first + 1_int32 > widest) then
            widest = clip%last - clip%first + 1_int32
            self%view = [clip%first, clip%last]
         endif
         do i = clip%first, clip%last
            num = self%total - self%n + i
            chosen = self%sel(1) > 0_int64 .and. num >= min(self%sel(1), self%sel(2)) .and. &
                     num <= max(self%sel(1), self%sel(2))
            call igPushID_Int(int(modulo(num, 1073741824_int64), c_int))
            x = igGetCursorPosX()
            if (igSelectable_Bool(cstr('##line'), logical(chosen, c_bool), 0_c_int, im_vec2(0.0_c_float, 0.0_c_float))) &
               then
               if (logical(igIsKeyDown_Nil(ImGuiMod_Shift)) .and. self%sel(1) > 0_int64) then
                  self%sel(2) = num
               else
                  self%sel = num
               endif
            endif
            call igSameLine(x, 0.0_c_float)
            call igTextUnformatted(cstr(self%line(i)), c_null_ptr)
            call igPopID()
         enddo
      enddo
      if (at_end) call igSetScrollHereY(1.0_c_float) ! following: the newest line at the bottom
      self%follow = at_end
      if (logical(igIsWindowFocused(0_c_int)) .and. logical(igIsKeyChordPressed_Nil(ior(ImGuiMod_Ctrl, ImGuiKey_C)))) &
         call clipboard(self%copy())
      if (igBeginPopupContextWindow(c_null_ptr, 0_c_int)) then
         if (igMenuItem_Bool(cstr('Copy'), c_null_ptr, .false._c_bool, logical(self%sel(1) > 0_int64, c_bool))) &
            call clipboard(self%copy())
         if (igMenuItem_Bool(cstr('Copy all'), c_null_ptr, .false._c_bool, logical(self%n > 0_int32, c_bool))) &
            call clipboard(self%copy(all=.true.))
         call igEndPopup()
      endif
   endif
   call igEndChild()
   contains
      subroutine clipboard(text)
      !< Put `text` on the clipboard.
      character(len=*), intent(in) :: text !< Text.

      if (len(text) > 0) call igSetClipboardText(cstr(text))
      endsubroutine clipboard
   endsubroutine log_draw
endmodule figure_process
