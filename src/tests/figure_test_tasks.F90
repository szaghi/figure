!< figure_test_tasks_work, the work procedures of figure_test_tasks (module procedures: they run on other threads).
module figure_test_tasks_work
!< figure_test_tasks_work, the work procedures of figure_test_tasks (module procedures: they run on other threads).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_color_edit, ig_end, ig_input, ig_push_style_color, &
                   ig_same_line, ig_separator, ig_slider, ig_text, ip_begin_plot, ip_colormap_legend, ip_line, &
                   ip_setup_axes, list_clipper_object, task_handle_object

implicit none
private
public :: sum_job, sum_work, forever_work, draw_work, drop_work, fail_work, pause, ended_by_object
public :: wake_job, waker_work, WAKE_BY_REQUEST, WAKE_BY_WAKE, WAKE_BY_QUIT

type :: sum_job
   !< A sum of the integers first..last, in 10 chunks, with a pause after each [s].
   integer(int64) :: first = 1_int64   !< First integer.
   integer(int64) :: last = 0_int64    !< Last integer.
   integer(int64) :: total = 0_int64   !< The sum.
   real(real64)   :: seconds = 0.0_real64 !< Pause after each chunk [s].
   integer(int32) :: chunks = 0_int32  !< Chunks done.
   logical        :: drawn(3) = .true. !< Drawing calls that returned true (they must not).
   logical        :: widgets(6) = .true. !< Widgets called from the task that returned true (they must not).
   integer(int32) :: stats(6) = -1_int32 !< Statuses of the widgets and style calls made from the task.
   integer(int32) :: stat = -1_int32   !< Status of a call that must refuse.
endtype sum_job

type :: wake_job
   !< A call from a task to the application at a given time (`at`), then a hold until cancelled (or `hold` seconds).
   integer(int32) :: action = 0_int32    !< WAKE_BY_REQUEST, WAKE_BY_WAKE or WAKE_BY_QUIT.
   integer(int32) :: n = 1_int32         !< Frames requested (WAKE_BY_REQUEST).
   integer(int64) :: at = 0_int64        !< When to call (system_clock count).
   real(real64)   :: hold = 0.0_real64   !< Time alive after the call, unless cancelled [s].
   integer(int64) :: called = -1_int64   !< When it called (system_clock count).
endtype wake_job

integer(int32), parameter :: WAKE_BY_REQUEST = 1_int32 !< app%request_frames(n).
integer(int32), parameter :: WAKE_BY_WAKE = 2_int32    !< app%wake().
integer(int32), parameter :: WAKE_BY_QUIT = 3_int32    !< app%quit().

logical :: ended_by_object = .false. !< forever_work saw the cancel of its object's end.

contains
   recursive subroutine pause(seconds)
   !< Wait `seconds` (by the clock).
   real(real64), intent(in) :: seconds     !< Time [s].
   integer(int64)           :: t0, t, rate !< Clock.

   call system_clock(t0, rate)
   do
      call system_clock(t)
      if (real(t - t0, real64) / real(rate, real64) >= seconds) exit
   enddo
   endsubroutine pause

   recursive subroutine sum_work(h, data)
   !< The sum, in 10 chunks, reporting each; stops at a cancel.
   type(task_handle_object), intent(inout) :: h    !< Handle.
   class(*),                 intent(inout) :: data !< A sum_job.
   integer(int64)                          :: k, a, b, i, n !< Chunk, its range, counter, length.
   character(len=32)                       :: msg  !< Message.

   select type (data)
   type is (sum_job)
      n = data%last - data%first + 1_int64
      do k = 1_int64, 10_int64
         if (h%cancelled()) return
         a = data%first + (k - 1_int64) * n / 10_int64
         b = data%first + k * n / 10_int64 - 1_int64
         do i = a, b
            data%total = data%total + i
         enddo
         data%chunks = data%chunks + 1_int32
         write(msg, '(A,I0,A)') 'chunk ', k, ' of 10'
         call h%report(real(k, real64) / 10.0_real64, trim(msg))
         call pause(data%seconds)
      enddo
   endselect
   endsubroutine sum_work

   recursive subroutine forever_work(h, data)
   !< Counts until cancelled.
   type(task_handle_object), intent(inout) :: h    !< Handle.
   class(*),                 intent(inout) :: data !< A sum_job.

   select type (data)
   type is (sum_job)
      do
         if (h%cancelled()) exit
         data%chunks = data%chunks + 1_int32
         call h%report(0.5_real64)
         call pause(0.001_real64)
      enddo
      ended_by_object = .true.
   endselect
   endsubroutine forever_work

   recursive subroutine draw_work(h, data)
   !< Breaks the threading rule: calls drawing procedures, which must refuse: containers, then widgets, plot items,
   !< a legend, a colour editor, a list clipper and a style colour outside any container; the application's style.
   type(task_handle_object), intent(inout) :: h       !< Handle.
   class(*),                 intent(inout) :: data    !< A sum_job.
   type(app_object)                        :: app     !< An application object (not initialized here).
   type(list_clipper_object)               :: clip    !< A clipper (not begun).
   integer(int32)                          :: ival    !< A slider's value.
   real(real64)                            :: rval    !< A field's value.
   real(real64)                            :: rgba(4) !< A colour.
   logical                                 :: flag    !< A check box's value.

   select type (data)
   type is (sum_job)
      data%drawn(1) = ig_begin('from a task')
      call ig_end()
      data%drawn(2) = ip_begin_plot('##from a task')
      data%drawn(3) = app%next_frame()
      data%chunks = merge(1_int32, 0_int32, h%cancelled())  ! the refusal asked the task to stop
      ! widgets outside any container: each refuses too (nothing is drawn, nothing changes, no crash)
      ival = 3_int32
      rval = 0.5_real64
      flag = .false.
      rgba = [0.1_real64, 0.2_real64, 0.3_real64, 1.0_real64]
      call ig_text('from a task')
      call ig_same_line()
      call ig_separator()
      data%widgets(1) = ig_button('task button')
      data%widgets(2) = ig_slider('task slider', ival, 0_int32, 10_int32)
      data%widgets(3) = ig_input('task input', rval)
      data%widgets(4) = ig_checkbox('task box', flag)
      data%widgets(5) = ig_color_edit('task colour', rgba, stat=data%stats(1))
      call clip%begin(100_int32)
      data%widgets(6) = clip%step()
      call ip_setup_axes('x', 'y')
      call ip_line('task line', [0.0_real64, 1.0_real64], [0.0_real64, 1.0_real64], stat=data%stats(2))
      call ip_colormap_legend('task legend', 0_int32, 0.0_real64, 1.0_real64, stat=data%stats(3))
      call ig_push_style_color('Text', '#ff0000', stat=data%stats(4))
      call app%set_style('paper', stat=data%stats(5))                ! the application's style calls too
      call app%set_font('plex-mono', stat=data%stats(6))
      data%widgets = data%widgets .or. ival /= 3_int32 .or. rval /= 0.5_real64 .or. flag
   endselect
   endsubroutine draw_work

   recursive subroutine drop_work(h, data)
   !< Breaks the threading rule: asks for the frame's drops, which must refuse with FIG_ERR_STATE.
   type(task_handle_object), intent(inout) :: h        !< Handle.
   class(*),                 intent(inout) :: data     !< A sum_job.
   type(app_object)                        :: app      !< An application object (not initialized here).
   character(len=:), allocatable           :: paths(:) !< Paths dropped.

   select type (data)
   type is (sum_job)
      data%drawn(1) = app%dropped(paths, stat=data%stat)
      data%drawn(2) = size(paths) > 0
      data%chunks = merge(1_int32, 0_int32, h%cancelled())  ! the refusal asked the task to stop
   endselect
   endsubroutine drop_work

   recursive subroutine waker_work(h, data)
   !< At the job's time, calls the application (request_frames, wake or quit) and records when; then stays alive (so
   !< that its end, which wakes the loop too, comes later) until cancelled or for the job's hold.
   type(task_handle_object), intent(inout) :: h       !< Handle.
   class(*),                 intent(inout) :: data    !< A wake_job.
   type(app_object)                        :: app     !< The application (its calls act on the one loop).
   integer(int64)                          :: t, rate !< Clock.

   select type (data)
   type is (wake_job)
      do
         call system_clock(t, rate)
         if (t >= data%at) exit
      enddo
      call system_clock(data%called)
      select case (data%action)
      case (WAKE_BY_REQUEST)
         call app%request_frames(data%n)
      case (WAKE_BY_WAKE)
         call app%wake()
      case (WAKE_BY_QUIT)
         call app%quit()
      endselect
      do
         if (h%cancelled()) exit
         call system_clock(t)
         if (real(t - data%called, real64) / real(rate, real64) >= data%hold) exit
         call pause(0.001_real64)
      enddo
   endselect
   endsubroutine waker_work

   recursive subroutine fail_work(h, data)
   !< Reports a failure.
   type(task_handle_object), intent(inout) :: h    !< Handle.
   class(*),                 intent(inout) :: data !< Any.

   call h%report(0.25_real64, 'reading grid.h5')
   call h%fail('cannot read grid.h5: no such file')
   select type (data)
   type is (sum_job)
      data%chunks = 1_int32
   endselect
   endsubroutine fail_work
endmodule figure_test_tasks_work

!< figure_test_tasks, background tasks: progress, result, cancel, the threading rule, several at once, headless.
program figure_test_tasks
!< figure_test_tasks, background tasks: progress, result, cancel, the threading rule, several at once, headless.
use, intrinsic :: iso_fortran_env, only : error_unit, int32, int64, output_unit, real64
use figure, only : app_object, FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK, figure_last_error, task_object
use figure_test_tasks_work, only : draw_work, drop_work, ended_by_object, fail_work, forever_work, pause, sum_job, &
                                  sum_work, wake_job, waker_work, WAKE_BY_QUIT, WAKE_BY_REQUEST, WAKE_BY_WAKE

implicit none
type(app_object)              :: app             !< Application.
logical                       :: test_passed(15) !< Per-check outcome.
integer(int32)                :: port            !< Remote mode's port.

call app%init_headless(400_int32, 300_int32)
test_passed = .false.
call known_sum(test_passed(1:2))
call cancelled(test_passed(3))
call drawing_refused(test_passed(4))
call eight_at_once(test_passed(5))
call failing(test_passed(6))
call refused_while_running(test_passed(7))
call object_end(test_passed(8))
call progress_before(test_passed(9))
call drop_refused(test_passed(10))
call app%destroy()
! the waits of a lazy loop, which headless mode never makes: remote mode, no browser connected (a frame begins after
! input, a wake-up or max_wait)
call app%init_remote(port=0_int32, port_used=port, quiet=.true.)
call woken_by_task(WAKE_BY_REQUEST, test_passed(11))
call woken_by_task(WAKE_BY_WAKE, test_passed(12))
call largest_request_kept(test_passed(13))
call woken_by_main(test_passed(14))
call woken_by_task(WAKE_BY_QUIT, test_passed(15))
call app%destroy()

write(output_unit, '(A,*(L2))') 'figure_test_tasks checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function frames_until_done(t, limit) result(frames)
   !< Frames drawn until `t` is done (at most `limit` seconds).
   type(task_object), intent(in)  :: t      !< Task.
   real(real64),      intent(in)  :: limit  !< Time out [s].
   integer(int32)                 :: frames !< Frames.
   integer(int64)                 :: t0, tn, rate !< Clock.

   frames = 0_int32
   call system_clock(t0, rate)
   do while (.not. t%done())
      if (.not. app%next_frame()) exit
      frames = frames + 1_int32
      call system_clock(tn)
      if (real(tn - t0, real64) / real(rate, real64) > limit) exit
   enddo
   endfunction frames_until_done

   subroutine known_sum(ok)
   !< 1..10^7 summed in a task: the right result, its progress seen in order with its message, and the frame count
   !< growing while it runs (the loop is not blocked).
   logical, intent(out)          :: ok(2)    !< Outcomes.
   type(task_object)             :: t        !< Task.
   class(*), allocatable         :: data     !< Result.
   character(len=:), allocatable :: msg      !< Progress message.
   real(real64)                  :: f, last  !< Progress.
   integer(int32)                :: frames   !< Frames while it ran.
   integer(int32)                :: stat     !< Status.
   logical                       :: in_order !< Progress never went back.

   call t%start(sum_work, sum_job(first=1_int64, last=10000000_int64, seconds=0.03_real64))
   in_order = .true.
   last = -1.0_real64
   frames = 0_int32
   do while (.not. t%done())
      if (.not. app%next_frame()) exit
      frames = frames + 1_int32
      call t%progress(f, msg)
      if (f < last) in_order = .false.
      last = f
      if (frames > 10000000_int32) exit
   enddo
   call t%progress(f, msg)
   call t%result(data, stat)
   ok = .false.
   select type (data)
   type is (sum_job)
      ok(1) = data%total == 50000005000000_int64 .and. data%chunks == 10_int32 .and. stat == FIG_OK
      if (.not. ok(1)) write(error_unit, '(A,I0,1X,I0)') 'known sum: ', data%total, data%chunks
   endselect
   ok(1) = ok(1) .and. in_order .and. f == 1.0_real64 .and. msg == 'chunk 10 of 10' .and. .not. t%done()
   ok(2) = frames >= 10_int32                                  ! 0.3 s of pauses: many frames meanwhile
   if (.not. all(ok)) write(error_unit, '(A,I0,A,F5.2,A,A,A,L2)') 'known sum: frames ', frames, ', progress ', f, &
                                                                 ', "', msg, '", in order', in_order
   endsubroutine known_sum

   subroutine cancelled(ok)
   !< A task that never ends by itself stops at its next safe point after a cancel; not a failure.
   logical, intent(out)  :: ok     !< Outcome.
   type(task_object)     :: t      !< Task.
   class(*), allocatable :: data   !< Result.
   integer(int32)        :: frames !< Frames.
   integer(int32)        :: stat   !< Status.

   call t%start(forever_work, sum_job())
   call pause(0.05_real64)
   ok = t%running()
   call t%cancel()
   frames = frames_until_done(t, 10.0_real64)
   call t%result(data, stat)
   select type (data)
   type is (sum_job)
      ok = ok .and. data%chunks > 0_int32 .and. stat == FIG_OK
   class default
      ok = .false.
   endselect
   if (.not. ok) write(error_unit, '(A,I0,1X,I0)') 'cancelled: frames, stat ', frames, stat
   endsubroutine cancelled

   subroutine drawing_refused(ok)
   !< Drawing calls from a task return at once, containers and widgets outside any container alike (false, values
   !< unchanged, statuses FIG_ERR_STATE); the task's status is FIG_ERR_STATE, named in the message of the first.
   logical, intent(out)          :: ok     !< Outcome.
   type(task_object)             :: t      !< Task.
   class(*), allocatable         :: data   !< Result.
   character(len=:), allocatable :: msg    !< Message.
   integer(int32)                :: frames !< Frames.
   integer(int32)                :: stat   !< Status.

   call t%start(draw_work, sum_job())
   frames = frames_until_done(t, 10.0_real64)
   call t%result(data, stat)
   msg = figure_last_error()
   ok = stat == FIG_ERR_STATE .and. index(msg, 'ig_begin') > 0
   select type (data)
   type is (sum_job)
      ok = ok .and. .not. any(data%drawn) .and. data%chunks == 1_int32 .and. .not. any(data%widgets) .and. &
           all(data%stats == FIG_ERR_STATE)
      if (.not. ok) write(error_unit, '(A,6L2,A,6(I0,1X))') 'drawing refused: widgets ', data%widgets, ', statuses ', &
                                                           data%stats
   class default
      ok = .false.
   endselect
   if (.not. ok) write(error_unit, '(A,I0,A,A)') 'drawing refused: stat ', stat, ', ', msg
   endsubroutine drawing_refused

   subroutine drop_refused(ok)
   !< app%dropped from a task refuses: its stat and the task's status are FIG_ERR_STATE, named in the message; it
   !< reports no drop. On the main thread, the same call is FIG_OK.
   logical, intent(out)          :: ok     !< Outcome.
   type(task_object)             :: t      !< Task.
   class(*), allocatable         :: data   !< Result.
   character(len=:), allocatable :: msg    !< Message.
   character(len=:), allocatable :: paths(:) !< Paths dropped, main thread.
   integer(int32)                :: frames !< Frames.
   integer(int32)                :: stat   !< Status.
   logical                       :: main   !< The main thread sees the drop.

   call t%start(drop_work, sum_job())
   frames = frames_until_done(t, 10.0_real64)
   call t%result(data, stat)
   msg = figure_last_error()
   ok = stat == FIG_ERR_STATE .and. index(msg, 'app%dropped') > 0
   select type (data)
   type is (sum_job)
      ok = ok .and. .not. any(data%drawn(1:2)) .and. data%stat == FIG_ERR_STATE .and. data%chunks == 1_int32
   class default
      ok = .false.
   endselect
   main = app%dropped(paths, stat=stat)
   ok = ok .and. stat == FIG_OK .and. .not. main
   if (.not. ok) write(error_unit, '(A,I0,A,A)') 'drop refused: stat ', stat, ', ', msg
   endsubroutine drop_refused

   subroutine eight_at_once(ok)
   !< Eight tasks at once, each summing its own range: all finish with the right sums.
   logical, intent(out)  :: ok      !< Outcome.
   type(task_object)     :: t(8)    !< Tasks.
   class(*), allocatable :: data    !< A result.
   integer(int32)        :: k       !< Task.
   integer(int32)        :: frames  !< Frames.
   integer(int64)        :: a, b    !< A range.
   integer(int32)        :: stat    !< Status.

   do k = 1_int32, 8_int32
      a = int(k - 1_int32, int64) * 1000000_int64 + 1_int64
      call t(k)%start(sum_work, sum_job(first=a, last=a + 999999_int64, seconds=0.002_real64))
   enddo
   frames = 0_int32
   do while (any([(t(k)%running(), k = 1_int32, 8_int32)]))
      if (.not. app%next_frame()) exit
      frames = frames + 1_int32
   enddo
   ok = .true.
   do k = 1_int32, 8_int32
      call t(k)%result(data, stat)
      a = int(k - 1_int32, int64) * 1000000_int64 + 1_int64
      b = a + 999999_int64
      select type (data)
      type is (sum_job)
         ok = ok .and. data%total == (a + b) * 1000000_int64 / 2_int64 .and. stat == FIG_OK
      class default
         ok = .false.
      endselect
   enddo
   if (.not. ok) write(error_unit, '(A,I0)') 'eight at once: frames ', frames
   endsubroutine eight_at_once

   subroutine failing(ok)
   !< A task that reports a failure: FIG_ERR_FAILED and its message; its data as it left it.
   logical, intent(out)          :: ok     !< Outcome.
   type(task_object)             :: t      !< Task.
   class(*), allocatable         :: data   !< Result.
   character(len=:), allocatable :: msg    !< Message.
   integer(int32)                :: frames !< Frames.
   integer(int32)                :: stat   !< Status.

   call t%start(fail_work, sum_job())
   frames = frames_until_done(t, 10.0_real64)
   call t%result(data, stat)
   msg = figure_last_error()
   ok = stat == FIG_ERR_FAILED .and. msg == 'cannot read grid.h5: no such file'
   select type (data)
   type is (sum_job)
      ok = ok .and. data%chunks == 1_int32
   class default
      ok = .false.
   endselect
   if (.not. ok) write(error_unit, '(A,I0,A,A)') 'failing: stat ', stat, ', ', msg
   endsubroutine failing

   subroutine refused_while_running(ok)
   !< start and result are refused while the task runs; cancel and result before start are refused.
   logical, intent(out)  :: ok      !< Outcome.
   type(task_object)     :: t, idle !< Tasks.
   class(*), allocatable :: data    !< Result.
   integer(int32)        :: stat(4) !< Statuses.
   integer(int32)        :: frames  !< Frames.

   call idle%cancel(stat(1))
   call idle%result(data, stat(2))
   call t%start(forever_work, sum_job())
   call t%start(forever_work, sum_job(), stat(3))
   call t%result(data, stat(4))
   call t%cancel()
   frames = frames_until_done(t, 10.0_real64)
   ok = all(stat == FIG_ERR_STATE) .and. t%done()
   if (.not. ok) write(error_unit, '(A,4(I0,1X))') 'refused while running: ', stat
   endsubroutine refused_while_running

   subroutine object_end(ok)
   !< A task object that ends while its task runs asks it to stop and waits for it.
   logical, intent(out) :: ok !< Outcome.

   ended_by_object = .false.
   block
      type(task_object) :: t !< Ends with the block.

      call t%start(forever_work, sum_job())
      call pause(0.02_real64)
   endblock
   ok = ended_by_object
   if (.not. ok) write(error_unit, '(A)') 'object end: the task did not see its cancel'
   endsubroutine object_end

   subroutine settle()
   !< Lazy redraw off for a few frames: the frames still to draw run out, so that the next lazy frame waits.
   integer(int32) :: k !< Frame.

   call app%set_lazy(.false.)
   do k = 1_int32, 6_int32
      if (.not. app%next_frame()) exit
   enddo
   endsubroutine settle

   subroutine woken_by_task(action, ok)
   !< A lazy loop with max_wait 10 s, idle: a task's request_frames, wake or quit starts the next frame (ends the loop,
   !< for quit) in under 1 s (0.1 s on a desktop; CI runners are slower), against 10 s unwoken. The task stays alive
   !< meanwhile: its end, which wakes the loop too, comes 2 s later.
   integer(int32), intent(in)  :: action  !< WAKE_BY_*.
   logical,        intent(out) :: ok      !< Outcome.
   type(task_object)           :: t       !< Task.
   class(*), allocatable       :: data    !< Result.
   integer(int64)              :: t0, t1, rate !< Clock.
   integer(int32)              :: frames  !< Frames.
   integer(int32)              :: stat    !< Status.
   real(real64)                :: latency !< From the task's call to the frame [s].
   logical                     :: running !< next_frame's result.
   character(len=*), parameter :: names(3) = ['request_frames', 'wake          ', 'quit          '] !< Calls.

   call settle()
   call app%set_lazy(.true., max_wait=10.0_real64)
   call system_clock(t0, rate)
   call t%start(waker_work, wake_job(action=action, n=2_int32, at=t0 + rate / 5_int64, hold=2.0_real64))
   running = app%next_frame()
   call system_clock(t1)
   call t%cancel()
   frames = frames_until_done(t, 10.0_real64)
   call t%result(data, stat)
   ok = .false.
   latency = -1.0_real64
   select type (data)
   type is (wake_job)
      latency = real(t1 - data%called, real64) / real(rate, real64)
      ok = data%called > 0_int64 .and. latency >= 0.0_real64 .and. latency < 1.0_real64 .and. stat == FIG_OK
   endselect
   ok = ok .and. (running .neqv. action == WAKE_BY_QUIT)
   if (.not. ok) write(error_unit, '(A,A,A,F8.4,A,L1)') 'woken by a task''s ', trim(names(action)), ': latency ', &
                                                       latency, ' s, next_frame ', running
   endsubroutine woken_by_task

   subroutine largest_request_kept(ok)
   !< Eight tasks call request_frames(10 k), k = 1..8, at the same instant: the loop draws at least 80 frames before it
   !< waits again (max_wait 1 s): concurrent requests keep the largest, and the event of the wake-up does not lower it.
   logical, intent(out)  :: ok      !< Outcome.
   type(task_object)     :: t(8)    !< Tasks.
   integer(int64)        :: t0, ta, tb, rate !< Clock.
   integer(int32)        :: k       !< Task.
   integer(int32)        :: frames  !< Frames drawn before the loop waited.

   call settle()
   call app%set_lazy(.true., max_wait=1.0_real64)
   call system_clock(t0, rate)
   do k = 1_int32, 8_int32
      call t(k)%start(waker_work, wake_job(action=WAKE_BY_REQUEST, n=10_int32 * k, at=t0 + rate / 5_int64))
   enddo
   do while (any([(t(k)%running(), k = 1_int32, 8_int32)]))
      call pause(0.005_real64)
   enddo
   frames = 0_int32
   do while (frames < 1000_int32)
      call system_clock(ta)
      if (.not. app%next_frame()) exit
      call system_clock(tb)
      if (real(tb - ta, real64) / real(rate, real64) > 0.5_real64) exit ! a wait: the frames requested ran out
      frames = frames + 1_int32
   enddo
   ok = frames >= 80_int32 .and. frames <= 90_int32
   if (.not. ok) write(error_unit, '(A,I0,A)') 'largest request kept: ', frames, ' frames before the wait (80 expected)'
   endsubroutine largest_request_kept

   subroutine woken_by_main(ok)
   !< app%wake from the loop's own thread: the next frame does not wait (max_wait 10 s).
   logical, intent(out) :: ok      !< Outcome.
   integer(int64)       :: t0, t1, rate !< Clock.
   real(real64)         :: elapsed !< next_frame's time [s].

   call settle()
   call app%set_lazy(.true., max_wait=10.0_real64)
   call app%wake()
   call system_clock(t0, rate)
   ok = app%next_frame()
   call system_clock(t1)
   elapsed = real(t1 - t0, real64) / real(rate, real64)
   ok = ok .and. elapsed < 1.0_real64 ! a frame's own cost, not a 10 s wait (0.125 s seen on a macOS runner)
   if (.not. ok) write(error_unit, '(A,F8.4,A)') 'woken by the main thread: next_frame took ', elapsed, ' s'
   endsubroutine woken_by_main

   subroutine progress_before(ok)
   !< Before start: no progress, not running, not done.
   logical, intent(out)          :: ok  !< Outcome.
   type(task_object)             :: t   !< Task.
   character(len=:), allocatable :: msg !< Message.
   real(real64)                  :: f   !< Progress.

   call t%progress(f, msg)
   ok = f < 0.0_real64 .and. msg == '' .and. .not. t%running() .and. .not. t%done()
   endsubroutine progress_before
endprogram figure_test_tasks
