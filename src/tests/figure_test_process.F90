!< figure_test_process, processes (captured and detached) and the log view, headless.
program figure_test_process
!< figure_test_process, processes (captured and detached) and the log view, headless.
!<
!< The children are this program itself, started again with `--child MODE`: the same on every system, no shell
!< needed. The checks a shell is needed for (a working directory) use `sh -c` on POSIX and `cmd /c` on Windows.
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_f_pointer, c_float, c_int, c_ptr
use, intrinsic :: iso_fortran_env, only : error_unit, int32, int64, output_unit, real64
use figure, only : app_object, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_OK, ig_begin, ig_end,         &
                   ig_get_style_var, ig_item_rect, ig_set_next_window, log_view_object, process_object
use figure_cimgui, only : igGetClipboardText, igGetTextLineHeightWithSpacing
use figure_testing, only : test_click, test_key, test_mouse_move, test_wheel

implicit none
interface
   subroutine c_exit(code) bind(C, name='exit')
   !< The C library's exit: the exit code, on every compiler.
   import :: c_int
   implicit none
   integer(c_int), value :: code !< Exit code.
   endsubroutine c_exit
endinterface
character(len=1), parameter :: LF = achar(10) !< Newline.
character(len=512)          :: self_path      !< This program.
character(len=64)           :: mode           !< Child mode.
logical                     :: test_passed(16) !< Per-check outcome.

call get_command_argument(0, self_path)
call get_command_argument(1, mode)
if (trim(mode) == '--child') then
   call child()
   call c_exit(0_c_int)
endif
test_passed = .false.
call lines_in_order(test_passed(1))
call partial_line(test_passed(2))
call exit_code(test_passed(3))
call killed(test_passed(4))
call bulk(test_passed(5))
call detached_survives(test_passed(6))
call detached_poll(test_passed(7))
call environment(test_passed(8))
call working_directory(test_passed(9))
call refused(test_passed(10))
call log_view(test_passed(11:16))

write(output_unit, '(A,*(L2))') 'figure_test_process checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   ! ---- the child -----------------------------------------------------------------------------------------------------
   subroutine child()
   !< What this program does when started with `--child MODE [ARG]`.
   character(len=256) :: arg   !< Argument of the mode.
   character(len=256) :: value !< An environment variable.
   integer(int32)     :: i, n  !< Counters.
   logical            :: there !< A file exists.

   call get_command_argument(2, mode)
   call get_command_argument(3, arg)
   select case (trim(mode))
   case ('lines')                                     ! N numbered lines
      read(arg, *) n
      do i = 1_int32, n
         write(output_unit, '(A,I0)') 'line ', i
      enddo
   case ('partial')                                   ! a line, a partial line; on GO its end and a last partial one
      write(output_unit, '(A)') 'first'
      write(output_unit, '(A)', advance='no') 'abc'
      flush(output_unit)
      do i = 1_int32, 1000_int32
         inquire(file=trim(arg), exist=there)
         if (there) exit
         call pause(0.01_real64)
      enddo
      write(output_unit, '(A)') 'def'
      write(output_unit, '(A)', advance='no') 'tail'
   case ('exit')                                      ! a line, then the exit code given
      read(arg, *) n
      write(output_unit, '(A)') 'bye'
      flush(output_unit)
      call c_exit(int(n, c_int))
   case ('forever')                                   ! a line every 20 ms, until killed
      do
         write(output_unit, '(A)') 'tick'
         flush(output_unit)
         call pause(0.02_real64)
      enddo
   case ('bulk')                                      ! 1 MiB: 16384 lines of 63 bytes and a newline
      do i = 1_int32, 16384_int32
         write(output_unit, '(A)') repeat('x', 63)
      enddo
   case ('env')                                       ! an environment variable
      call get_environment_variable(trim(arg), value)
      write(output_unit, '(A)') trim(value)
   case ('late')                                      ! a line after 0.5 s (detached: after its parent object ended)
      call pause(0.5_real64)
      write(output_unit, '(A)') 'survived'
   endselect
   flush(output_unit)
   endsubroutine child

   subroutine pause(seconds)
   !< Wait `seconds` (by the clock: Fortran has no sleep).
   real(real64), intent(in) :: seconds !< Time [s].
   integer(int64)           :: t0, t, rate !< Clock.

   call system_clock(t0, rate)
   do
      call system_clock(t)
      if (real(t - t0, real64) / real(rate, real64) >= seconds) exit
   enddo
   endsubroutine pause

   subroutine wait_end(p, seconds, all_lines)
   !< Wait for the end of `p` (at most `seconds`), polling it all along when `all_lines` is present.
   type(process_object),                    intent(inout) :: p            !< Process.
   real(real64),                            intent(in)    :: seconds      !< Time out [s].
   character(len=:), allocatable, optional, intent(inout) :: all_lines(:) !< Every line polled.
   character(len=:), allocatable                          :: lines(:)     !< New lines.
   integer(int64)                                         :: t0, t, rate  !< Clock.

   call system_clock(t0, rate)
   do
      if (present(all_lines)) then
         call p%poll(lines)
         call append(all_lines, lines)
      endif
      if (.not. p%running()) exit
      call system_clock(t)
      if (real(t - t0, real64) / real(rate, real64) > seconds) exit
      call pause(0.005_real64)
   enddo
   if (present(all_lines)) then                       ! the rest
      call p%poll(lines)
      call append(all_lines, lines)
   endif
   endsubroutine wait_end

   subroutine append(all_lines, lines)
   !< `all_lines` followed by `lines`.
   character(len=:), allocatable, intent(inout) :: all_lines(:) !< Lines so far.
   character(len=*),              intent(in)    :: lines(:)     !< New lines.
   character(len=:), allocatable                :: both(:)      !< Joined.
   integer(int32)                               :: l            !< Length.

   if (size(lines) == 0) return
   l = max(len(all_lines), len(lines))
   allocate(character(len=l) :: both(size(all_lines) + size(lines)))
   both(1:size(all_lines)) = all_lines
   both(size(all_lines) + 1:) = lines
   call move_alloc(both, all_lines)
   endsubroutine append

   ! ---- the checks ----------------------------------------------------------------------------------------------------
   subroutine lines_in_order(ok)
   !< 200 lines arrive in order, and the exit code is 0.
   logical, intent(out)          :: ok       !< Outcome.
   type(process_object)          :: p        !< Process.
   character(len=:), allocatable :: lines(:) !< Lines read.
   character(len=16)             :: expect   !< Expected line.
   integer(int32)                :: i        !< Counter.

   allocate(character(len=0) :: lines(0))
   call p%start([character(len=512) :: self_path, '--child', 'lines', '200'])
   call wait_end(p, 20.0_real64, lines)
   ok = size(lines) == 200 .and. p%exit_code() == 0_int32 .and. .not. p%running() .and. .not. p%killed()
   do i = 1_int32, min(200_int32, size(lines, kind=int32))
      write(expect, '(A,I0)') 'line ', i
      ok = ok .and. trim(lines(i)) == trim(expect)
   enddo
   if (.not. ok) write(error_unit, '(A,I0)') 'lines in order: lines read ', size(lines)
   endsubroutine lines_in_order

   subroutine partial_line(ok)
   !< A partial line is kept until its newline; the last one, without a newline, is given at the end.
   logical, intent(out)          :: ok        !< Outcome.
   type(process_object)          :: p         !< Process.
   character(len=:), allocatable :: lines(:)  !< Lines read.
   character(len=:), allocatable :: early(:)  !< Lines read before GO.
   character(len=*), parameter   :: GO = 'figure_test_process.go' !< The child's signal to go on.
   integer(int32)                :: i, u      !< Counter, unit.
   logical                       :: there     !< The signal file exists.

   inquire(file=GO, exist=there)
   if (there) then
      open(newunit=u, file=GO)
      close(u, status='delete')
   endif
   allocate(character(len=0) :: lines(0), early(0))
   call p%start([character(len=512) :: self_path, '--child', 'partial', GO])
   do i = 1_int32, 2000_int32                         ! 'first' arrives, 'abc' does not: it has no newline yet
      call p%poll(lines)
      call append(early, lines)
      if (size(early) > 0) exit
      call pause(0.005_real64)
   enddo
   call pause(0.2_real64)
   call p%poll(lines)
   call append(early, lines)
   open(newunit=u, file=GO)
   close(u)
   deallocate(lines)
   allocate(character(len=0) :: lines(0))
   call wait_end(p, 20.0_real64, lines)
   open(newunit=u, file=GO)
   close(u, status='delete')
   ok = size(early) == 1
   if (ok) ok = trim(early(1)) == 'first'
   ok = ok .and. size(lines) == 2
   if (ok) ok = trim(lines(1)) == 'abcdef' .and. trim(lines(2)) == 'tail'
   if (.not. ok) write(error_unit, '(A,2(I0,1X))') 'partial line: lines before and after GO ', size(early), size(lines)
   endsubroutine partial_line

   subroutine exit_code(ok)
   !< The exit code is read; asked while running it is refused.
   logical, intent(out)          :: ok       !< Outcome.
   type(process_object)          :: p        !< Process.
   character(len=:), allocatable :: lines(:) !< Lines read.
   integer(int32)                :: stat     !< Status.
   integer(int32)                :: code     !< Exit code.

   allocate(character(len=0) :: lines(0))
   call p%start([character(len=512) :: self_path, '--child', 'exit', '3'])
   call wait_end(p, 20.0_real64, lines)
   code = p%exit_code(stat)
   ok = code == 3_int32 .and. stat == FIG_OK .and. size(lines) == 1 .and. p%pid() > 0_int64
   if (.not. ok) write(error_unit, '(A,I0,1X,I0)') 'exit code: code and stat ', code, stat
   endsubroutine exit_code

   subroutine killed(ok)
   !< A kill is reported, the exit code read while it ran is refused, a start while it runs is refused.
   logical, intent(out)          :: ok       !< Outcome.
   type(process_object)          :: p        !< Process.
   character(len=:), allocatable :: lines(:) !< Lines read.
   integer(int32)                :: i        !< Counter.
   integer(int32)                :: stat(3)  !< Statuses.
   integer(int32)                :: code     !< Exit code.

   call p%start([character(len=512) :: self_path, '--child', 'forever'])
   do i = 1_int32, 2000_int32                         ! running: it prints
      call p%poll(lines)
      if (size(lines) > 0) exit
      call pause(0.005_real64)
   enddo
   code = p%exit_code(stat(1))
   call p%start([character(len=512) :: self_path, '--child', 'lines', '1'], stat=stat(2))
   call p%kill(force=.true., stat=stat(3))
   call wait_end(p, 20.0_real64)
   ok = all(stat == [FIG_ERR_STATE, FIG_ERR_STATE, FIG_OK]) .and. .not. p%running() .and. p%killed()
   if (.not. ok) write(error_unit, '(A,3(I0,1X),L2)') 'killed: statuses, killed ', stat, p%killed()
   endsubroutine killed

   subroutine bulk(ok)
   !< 1 MiB printed while the program does not poll is read in full: the child ends without the program's help.
   logical, intent(out)          :: ok       !< Outcome.
   type(process_object)          :: p        !< Process.
   character(len=:), allocatable :: lines(:) !< Lines read.
   integer(int64)                :: bytes    !< Bytes read.
   integer(int32)                :: i        !< Counter.

   call p%start([character(len=512) :: self_path, '--child', 'bulk'])
   call wait_end(p, 30.0_real64)                       ! no poll meanwhile
   ok = .not. p%running()
   call p%poll(lines)
   bytes = 0_int64
   do i = 1_int32, size(lines, kind=int32)
      bytes = bytes + len_trim(lines(i), int64) + 1_int64
   enddo
   ok = ok .and. size(lines) == 16384 .and. bytes == 1048576_int64 .and. p%exit_code() == 0_int32
   if (.not. ok) write(error_unit, '(A,I0,1X,I0)') 'bulk: lines and bytes read ', size(lines), bytes
   endsubroutine bulk

   subroutine detached_survives(ok)
   !< A detached child outlives its object (released at the end of the block) and writes its log file.
   logical, intent(out)          :: ok   !< Outcome.
   character(len=*), parameter   :: LOG = 'figure_test_process.late.log' !< Its log.
   character(len=64)             :: text !< The log's line.
   integer(int64)                :: pid  !< Its process id.
   integer(int32)                :: i, u, ios !< Counter, unit, I/O status.

   pid = 0_int64
   block
      type(process_object) :: p !< Ends with the block.

      call p%start([character(len=512) :: self_path, '--child', 'late'], detached=.true., log_file=LOG)
      pid = p%pid()
   endblock
   text = ''
   do i = 1_int32, 1000_int32                          ! at most 10 s
      call pause(0.01_real64)
      open(newunit=u, file=LOG, status='old', action='read', iostat=ios)
      if (ios /= 0) cycle
      read(u, '(A)', iostat=ios) text
      close(u)
      if (trim(text) == 'survived') exit
   enddo
   open(newunit=u, file=LOG, iostat=ios)
   if (ios == 0) close(u, status='delete')
   ok = trim(text) == 'survived' .and. pid > 0_int64
   if (.not. ok) write(error_unit, '(A,A,A,I0)') 'detached survives: log "', trim(text), '", pid ', pid
   endsubroutine detached_survives

   subroutine detached_poll(ok)
   !< A detached process is followed through its log file; its exit code is refused.
   logical, intent(out)          :: ok       !< Outcome.
   character(len=*), parameter   :: LOG = 'figure_test_process.lines.log' !< Its log.
   type(process_object)          :: p        !< Process.
   character(len=:), allocatable :: lines(:) !< Lines read.
   integer(int32)                :: stat     !< Status.
   integer(int32)                :: code     !< Exit code.
   integer(int32)                :: u, ios   !< Unit, I/O status.

   allocate(character(len=0) :: lines(0))
   call p%start([character(len=512) :: self_path, '--child', 'lines', '5'], detached=.true., log_file=LOG)
   call wait_end(p, 20.0_real64, lines)
   code = p%exit_code(stat)
   open(newunit=u, file=LOG, iostat=ios)
   if (ios == 0) close(u, status='delete')
   ok = size(lines) == 5 .and. stat == FIG_ERR_STATE
   if (ok) ok = trim(lines(1)) == 'line 1' .and. trim(lines(5)) == 'line 5'
   if (.not. ok) write(error_unit, '(A,I0,1X,I0)') 'detached poll: lines, stat ', size(lines), stat
   endsubroutine detached_poll

   subroutine environment(ok)
   !< An environment entry reaches the child.
   logical, intent(out)          :: ok       !< Outcome.
   type(process_object)          :: p        !< Process.
   character(len=:), allocatable :: lines(:) !< Lines read.

   allocate(character(len=0) :: lines(0))
   call p%start([character(len=512) :: self_path, '--child', 'env', 'FIGURE_TEST_VALUE'], &
                env=['FIGURE_TEST_VALUE=chimera 7'])
   call wait_end(p, 20.0_real64, lines)
   ok = size(lines) == 1
   if (ok) ok = trim(lines(1)) == 'chimera 7'
   if (.not. ok) write(error_unit, '(A,I0)') 'environment: lines ', size(lines)
   endsubroutine environment

   subroutine working_directory(ok)
   !< The child runs in the directory given (through the system's shell: sh -c, or cmd /c on Windows).
   logical, intent(out)          :: ok       !< Outcome.
   type(process_object)          :: p        !< Process.
   character(len=:), allocatable :: lines(:) !< Lines read.

   allocate(character(len=0) :: lines(0))
#ifdef _WIN32
   call p%start([character(len=64) :: 'cmd', '/c', 'if exist figure_test_process.F90 echo yes'], cwd='src/tests')
#else
   call p%start([character(len=64) :: 'sh', '-c', 'test -f figure_test_process.F90 && echo yes'], cwd='src/tests')
#endif
   call wait_end(p, 20.0_real64, lines)
   ok = size(lines) == 1
   if (ok) ok = trim(lines(1)) == 'yes'
   if (.not. ok) write(error_unit, '(A,I0)') 'working directory: lines ', size(lines)
   endsubroutine working_directory

   subroutine refused(ok)
   !< Wrong uses are refused with their status: no program, a missing program, detached without a log file, a poll
   !< before start.
   logical, intent(out)          :: ok       !< Outcome.
   type(process_object)          :: p        !< Process.
   character(len=:), allocatable :: lines(:) !< Lines read.
   character(len=8), allocatable :: none(:)  !< No arguments.
   integer(int32)                :: stat(5)  !< Statuses.

   allocate(none(0))
   call p%poll(lines, stat=stat(1))
   call p%start(none, stat=stat(2))
   call p%start(['figure-no-such-program'], stat=stat(3))
   call p%start([character(len=512) :: self_path, '--child', 'lines', '1'], detached=.true., stat=stat(4))
   call p%start([character(len=512) :: self_path, '--child', 'lines', '1'], env=['NO_EQUALS'], stat=stat(5))
   ok = all(stat == [FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT])
   if (.not. ok) write(error_unit, '(A,5(I0,1X))') 'refused: statuses ', stat
   endsubroutine refused

   subroutine log_view(ok)
   !< The log view: its cap; following the end at the bottom, staying put when scrolled up; a range of lines chosen
   !< by click and shift+click, copied with ctrl+c.
   logical, intent(out)           :: ok(6)     !< Outcomes.
   type(app_object)               :: app       !< Application.
   type(log_view_object)          :: log       !< A log that grows.
   type(log_view_object)          :: pick      !< A log of four lines.
   type(log_view_object)          :: capped    !< A log with a small cap.
   character(len=16)              :: text      !< A line.
   real(real64)                   :: rect(4)   !< The pick region's rectangle [pixels].
   real(real64)                   :: log_at(2) !< Centre of the growing log's region.
   real(real64)                   :: pad(2)    !< Window padding [pixels].
   real(real64)                   :: pitch     !< Row pitch [pixels].
   integer(int32)                 :: frame, i, n, first, last !< Counters, lines in view.
   integer(int32)                 :: seen(2, 3) !< (first/last in view, at three moments).
   logical                        :: follow(3) !< Following, at three moments.
   character(len=:), allocatable  :: clip      !< The clipboard.

   call capped%set_cap(50_int32)
   do i = 1_int32, 120_int32
      write(text, '(A,I0)') 'line ', i
      call capped%add(trim(text))
   enddo
   ok(1) = capped%count() == 50_int32 .and. capped%line(1) == 'line 71' .and. capped%line(50) == 'line 120'
   call capped%set_cap(10_int32)
   ok(1) = ok(1) .and. capped%count() == 10_int32 .and. capped%line(1) == 'line 111'
   call pick%add(['alpha', 'beta ', 'gamma', 'delta'])
   seen = 0_int32
   follow = .false.
   pitch = 0.0_real64
   call app%init_headless(640_int32, 480_int32)
   call ig_get_style_var('WindowPadding', pad, n)
   do frame = 1_int32, 120_int32
      if (.not. app%next_frame()) exit
      if (frame <= 60_int32 .or. frame > 90_int32) then ! lines arrive, except while the view is scrolled up
         write(text, '(A,I0)') 'step ', frame
         call log%add(trim(text))
      endif
      call ig_set_next_window(10.0_real64, 10.0_real64, 600.0_real64, 440.0_real64, always=.true.)
      if (ig_begin('Logs')) then
         pitch = real(igGetTextLineHeightWithSpacing(), real64)
         call log%draw('log', height=120.0_real64)
         call ig_item_rect(rect(1), rect(2), rect(3), rect(4))
         log_at = [0.5_real64 * (rect(1) + rect(3)), 0.5_real64 * (rect(2) + rect(4))]
         call pick%draw('pick', height=150.0_real64)
         call ig_item_rect(rect(1), rect(2), rect(3), rect(4))
      endif
      call ig_end()
      select case (frame)
      case (60_int32)                                ! following: the newest line in view
         call log%in_view(first, last)
         seen(:, 1) = [first, last]
         follow(1) = log%following()
         call test_mouse_move(log_at(1), log_at(2))
         call test_wheel(3.0_real64)                 ! scroll up
      case (80_int32)
         call log%in_view(first, last)
         seen(:, 2) = [first, last]
         follow(2) = log%following()
      case (100_int32)                               ! scrolled up: new lines do not move the view
         call log%in_view(first, last)
         seen(:, 3) = [first, last]
         follow(3) = log%following()
         call test_click(rect(1) + 40.0_real64, rect(2) + pad(2) + 1.5_real64 * pitch)  ! 'beta'
      case (106_int32)
         call test_key('shift', down=.true.)
         call test_click(rect(1) + 40.0_real64, rect(2) + pad(2) + 2.5_real64 * pitch)  ! shift: up to 'gamma'
         call test_key('shift', down=.false.)
      case (112_int32)
         call test_key('ctrl', down=.true.)
         call test_key('c')
         call test_key('ctrl', down=.false.)
      endselect
   enddo
   clip = clipboard()
   call app%destroy()
   ok(2) = follow(1) .and. seen(2, 1) >= 59_int32 .and. log%count() == 90_int32      ! following the end
   ok(3) = .not. follow(2) .and. seen(2, 2) < 59_int32                                 ! scrolled up
   ok(4) = .not. follow(3) .and. seen(1, 3) == seen(1, 2) .and. seen(2, 3) == seen(2, 2) ! lines added: no move
   ok(5) = pick%copy() == 'beta'//LF//'gamma' .and. pick%copy(all=.true.) == 'alpha'//LF//'beta'//LF//'gamma'//LF// &
           'delta'                                                                   ! the chosen range
   ok(6) = clip == 'beta'//LF//'gamma'                                                 ! ctrl+c copied it
   if (.not. all(ok)) then
      write(error_unit, '(A,6(I0,1X),A,3L2)') 'log view: in view ', seen, ', following ', follow
      write(error_unit, '(A,A,A,A,A)') 'log view: chosen "', pick%copy(), '", clipboard "', clip, '"'
   endif
   endsubroutine log_view

   function clipboard() result(text)
   !< Dear ImGui's clipboard (in headless mode its own).
   character(len=:), allocatable   :: text !< Text.
   type(c_ptr)                     :: p    !< C string.
   character(kind=c_char), pointer :: s(:) !< Its characters.
   integer(int32)                  :: i    !< Counter.

   text = ''
   p = igGetClipboardText()
   if (.not. c_associated(p)) return
   call c_f_pointer(p, s, [1048576])
   do i = 1_int32, 1048576_int32
      if (s(i) == achar(0)) exit
      text = text//s(i)
   enddo
   endfunction clipboard
endprogram figure_test_process
