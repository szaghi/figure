!< figure_test_tasks_work, the work procedures of figure_test_tasks (module procedures: they run on other threads).
module figure_test_tasks_work
!< figure_test_tasks_work, the work procedures of figure_test_tasks (module procedures: they run on other threads).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure, only : app_object, ig_begin, ig_end, ip_begin_plot, task_handle_object

implicit none
private
public :: sum_job, sum_work, forever_work, draw_work, fail_work, pause, ended_by_object

type :: sum_job
   !< A sum of the integers first..last, in 10 chunks, with a pause after each [s].
   integer(int64) :: first = 1_int64   !< First integer.
   integer(int64) :: last = 0_int64    !< Last integer.
   integer(int64) :: total = 0_int64   !< The sum.
   real(real64)   :: seconds = 0.0_real64 !< Pause after each chunk [s].
   integer(int32) :: chunks = 0_int32  !< Chunks done.
   logical        :: drawn(3) = .true. !< Drawing calls that returned true (they must not).
endtype sum_job

logical :: ended_by_object = .false. !< forever_work saw the cancel of its object's end.

contains
   subroutine pause(seconds)
   !< Wait `seconds` (by the clock).
   real(real64), intent(in) :: seconds     !< Time [s].
   integer(int64)           :: t0, t, rate !< Clock.

   call system_clock(t0, rate)
   do
      call system_clock(t)
      if (real(t - t0, real64) / real(rate, real64) >= seconds) exit
   enddo
   endsubroutine pause

   subroutine sum_work(h, data)
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

   subroutine forever_work(h, data)
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

   subroutine draw_work(h, data)
   !< Breaks the threading rule: calls drawing procedures, which must refuse.
   type(task_handle_object), intent(inout) :: h    !< Handle.
   class(*),                 intent(inout) :: data !< A sum_job.
   type(app_object)                        :: app  !< An application object (not initialized here).

   select type (data)
   type is (sum_job)
      data%drawn(1) = ig_begin('from a task')
      call ig_end()
      data%drawn(2) = ip_begin_plot('##from a task')
      data%drawn(3) = app%next_frame()
      data%chunks = merge(1_int32, 0_int32, h%cancelled())  ! the refusal asked the task to stop
   endselect
   endsubroutine draw_work

   subroutine fail_work(h, data)
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
use figure_test_tasks_work, only : draw_work, ended_by_object, fail_work, forever_work, pause, sum_job, sum_work

implicit none
type(app_object)              :: app             !< Application.
logical                       :: test_passed(9)  !< Per-check outcome.

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
   !< Drawing calls from a task return at once; the task's status is FIG_ERR_STATE, named in the message.
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
      ok = ok .and. .not. any(data%drawn) .and. data%chunks == 1_int32
   class default
      ok = .false.
   endselect
   if (.not. ok) write(error_unit, '(A,I0,A,A)') 'drawing refused: stat ', stat, ', ', msg
   endsubroutine drawing_refused

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
