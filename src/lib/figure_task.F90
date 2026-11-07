!< figure_task, background tasks: Fortran procedures run on a worker thread, with progress and cooperative cancel.
module figure_task
!< figure_task, background tasks: Fortran procedures run on a worker thread, with progress and cooperative cancel.
!<
!< A task runs `work(h, data)` on a thread of its own while the frame loop goes on: `t%start(work, data)`, then every
!< frame `t%progress(fraction, message)` and `t%done()`; once done, `t%result(data)`. Inside `work`, `h%report` posts
!< progress (and wakes the frame loop), `h%cancelled()` tells whether the program asked it to stop, `h%fail` reports a
!< failure.
!<
!< **The threading rule:** a task computes and reads its own files; it never calls FIGURE's drawing procedures, since
!< Dear ImGui is single-threaded. FIGURE's drawing entry points (`app%next_frame`, `ig_begin`/`ig_end`, the child
!< regions, side bars, menu bars, popups, tab bars, tables, trees and headers, plots and subplots, dock spaces,
!< textures, `log%draw`) refuse such a call from a worker: they return at once, the task's status becomes
!< `FIG_ERR_STATE` (given by `t%result`) and the task is asked to stop.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_funloc, c_f_pointer, c_int, c_loc, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure_base, only : figure_check, figure_fail
use figure_c_native, only : FIG_ERR_STATE, FIG_OK, fig_task_cancel, fig_task_cancelled,          &
                            fig_task_fail, fig_task_finish, fig_task_release, fig_task_report, fig_task_start,      &
                            fig_task_state

implicit none
private
public :: task_object, task_handle_object, task_work

type :: task_handle_object
   !< What a running task knows of itself: given to its `work` procedure.
   integer(c_int), private :: id = 0_c_int !< Native handle.
   contains
      procedure, pass(self) :: report => handle_report       !< Post progress.
      procedure, pass(self) :: cancelled => handle_cancelled !< The program asked the task to stop.
      procedure, pass(self) :: fail => handle_fail           !< Report a failure.
endtype task_handle_object

abstract interface
   subroutine task_work(h, data)
   !< A task's work: computes on `data`, reports progress through `h`, checks `h%cancelled()` at its safe points.
   import :: task_handle_object
   implicit none
   type(task_handle_object), intent(inout) :: h    !< The task's handle.
   class(*),                 intent(inout) :: data !< The task's data (its own copy).
   endsubroutine task_work
endinterface

type :: task_record
   !< What the worker thread reaches: the procedure, the data, the handle (at a fixed address while it runs).
   procedure(task_work), pointer, nopass :: work => null() !< The work.
   class(*), allocatable                 :: data           !< Its data.
   type(task_handle_object)              :: handle         !< Its handle.
endtype task_record

type :: task_object
   !< A procedure of the program run on a worker thread. Not to be copied. An object that ends while its task runs
   !< asks the task to stop and waits for it (until its next safe point).
   type(task_record), pointer, private :: rec => null() !< The running task's record.
   integer(c_int),             private :: id = 0_c_int  !< Native handle (0: none).
   contains
      procedure, pass(self) :: start => task_start       !< Start a task.
      procedure, pass(self) :: running => task_running   !< It runs.
      procedure, pass(self) :: done => task_done         !< It has ended (its result is waiting).
      procedure, pass(self) :: progress => task_progress !< Its last progress and message.
      procedure, pass(self) :: cancel => task_cancel     !< Ask it to stop.
      procedure, pass(self) :: result => task_result     !< Its data, once done.
      final                 :: task_final
endtype task_object

contains
   ! ---- the worker's side ---------------------------------------------------------------------------------------------
   subroutine task_trampoline(arg) bind(C)
   !< The worker thread's entry: the task's work on its data.
   type(c_ptr), value         :: arg !< The task's record.
   type(task_record), pointer :: rec !< Record.

   call c_f_pointer(arg, rec)
   call rec%work(rec%handle, rec%data)
   endsubroutine task_trampoline

   subroutine handle_report(self, fraction, message)
   !< Post the progress, `fraction` of the work done in [0, 1] (clamped), and a message (absent: the previous one
   !< stays); the frame loop is woken to show it. Cheap: call it as often as useful, a few times a second is plenty.
   class(task_handle_object), intent(in)           :: self     !< Handle.
   real(real64),              intent(in)           :: fraction !< Done, in [0, 1].
   character(len=*),          intent(in), optional :: message  !< What is being done.
   integer(c_int)                                  :: status   !< Native status.

   if (present(message)) then
      status = fig_task_report(self%id, real(fraction, c_double), message, len(message, c_int), 0_c_int)
   else
      status = fig_task_report(self%id, real(fraction, c_double), '', 0_c_int, 1_c_int)
   endif
   endsubroutine handle_report

   function handle_cancelled(self) result(cancelled)
   !< True once the program asked the task to stop (`t%cancel`, the object's end, a refused drawing call): return
   !< from `work` at this safe point, leaving `data` consistent.
   class(task_handle_object), intent(in) :: self      !< Handle.
   logical                               :: cancelled !< Stop.

   cancelled = fig_task_cancelled(self%id) == 1_c_int
   endfunction handle_cancelled

   subroutine handle_fail(self, message)
   !< Report a failure (a file that cannot be read): `t%result` gives `FIG_ERR_FAILED` and `message`. The task should
   !< then return; the first failure is kept.
   class(task_handle_object), intent(in) :: self    !< Handle.
   character(len=*),          intent(in) :: message !< What failed.
   integer(c_int)                        :: status  !< Native status.

   status = fig_task_fail(self%id, message, len(message, c_int))
   endsubroutine handle_fail

   ! ---- the program's side --------------------------------------------------------------------------------------------
   subroutine task_start(self, work, data, stat)
   !< Run `work(h, data)` on a worker thread. `data` (any type: a file name, an extended type with the arrays to
   !< fill) is copied into the task, which works on its copy; `t%result` gives it back without a copy. Statuses:
   !< `FIG_ERR_STATE` while this object's task runs (a finished one whose result was not taken is discarded) or when
   !< called from a task, `FIG_ERR_FAILED` when no thread can be created. The same in every mode.
   class(task_object), intent(inout)         :: self !< Task.
   procedure(task_work)                      :: work !< The work.
   class(*),           intent(in)            :: data !< Its data.
   integer(int32),     intent(out), optional :: stat !< Status.
   integer(c_int)                            :: status !< Native status.

   if (self%running()) then
      call figure_fail(FIG_ERR_STATE, 'task_object%start: its task still runs: cancel it or wait for its end', stat)
      return
   endif
   call release(self)
   allocate(self%rec)
   self%rec%work => work
   allocate(self%rec%data, source=data)
   ! the handle's id is written by the native layer before the thread starts: the worker sees it from its first line
   status = fig_task_start(c_funloc(task_trampoline), c_loc(self%rec), self%rec%handle%id)
   if (status /= FIG_OK) then
      deallocate(self%rec)
      call figure_check(status, stat)
      return
   endif
   self%id = self%rec%handle%id
   call figure_check(status, stat)
   endsubroutine task_start

   function task_running(self) result(running)
   !< True while the task runs (false before `start`, once it has ended, after `result`).
   class(task_object), intent(in) :: self    !< Task.
   logical                        :: running !< It runs.

   running = .false.
   if (self%id == 0_c_int) return
   running = .not. self%done()
   endfunction task_running

   function task_done(self) result(done)
   !< True once the task has ended (finished, cancelled or failed) and its result waits for `t%result`; false before
   !< `start`, while it runs, and after `result`.
   class(task_object), intent(in) :: self   !< Task.
   logical                        :: done   !< It has ended.
   integer(c_int)                 :: d, l, s !< Native state.
   real(c_double)                 :: f      !< Progress.
   character(kind=c_char)         :: m(1)   !< Message (not read).

   done = .false.
   if (self%id == 0_c_int) return
   if (fig_task_state(self%id, d, f, m, 0_c_int, l, s) == FIG_OK) done = d == 1_c_int
   endfunction task_done

   subroutine task_progress(self, fraction, message)
   !< The last progress the task reported: `fraction` in [0, 1] (-1 before its first report or before `start`) and
   !< its message ('' if none).
   class(task_object),            intent(in)            :: self     !< Task.
   real(real64),                  intent(out)           :: fraction !< Done, in [0, 1].
   character(len=:), allocatable, intent(out), optional :: message  !< What is being done.
   character(kind=c_char, len=512)                      :: buf      !< Message buffer.
   integer(c_int)                                       :: d, l, s  !< Native state.
   real(c_double)                                       :: f        !< Progress.

   fraction = -1.0_real64
   if (present(message)) message = ''
   if (self%id == 0_c_int) return
   if (fig_task_state(self%id, d, f, buf, len(buf, c_int), l, s) /= FIG_OK) return
   fraction = real(f, real64)
   if (present(message)) message = buf(1:min(l, len(buf, c_int)))
   endsubroutine task_progress

   subroutine task_cancel(self, stat)
   !< Ask the task to stop: it does at its next safe point (`h%cancelled()`); nothing is stopped mid-write.
   !< `t%done()` tells when it has. `FIG_ERR_STATE` before `start`.
   class(task_object), intent(inout)         :: self !< Task.
   integer(int32),     intent(out), optional :: stat !< Status.

   if (self%id == 0_c_int) then
      call figure_fail(FIG_ERR_STATE, 'task_object%cancel: no task started', stat)
      return
   endif
   call figure_check(fig_task_cancel(self%id), stat)
   endsubroutine task_cancel

   subroutine task_result(self, data, stat)
   !< The task's data once it has ended, moved out (no copy); the object is then free for another `start`. Statuses:
   !< `FIG_ERR_STATE` before `start` or while it runs (`data` not allocated), and for a task that called a drawing
   !< procedure; `FIG_ERR_FAILED` for a task that reported a failure (`h%fail`): `data` is given as the task left it,
   !< and `figure_last_error()` gives the message. A cancelled task is not a failure.
   class(task_object),    intent(inout)         :: self    !< Task.
   class(*), allocatable, intent(out)           :: data    !< Its data.
   integer(int32),        intent(out), optional :: stat    !< Status.
   integer(c_int)                               :: status  !< Native status.

   if (self%id == 0_c_int) then
      call figure_fail(FIG_ERR_STATE, 'task_object%result: no task started', stat)
      return
   endif
   if (.not. self%done()) then
      call figure_fail(FIG_ERR_STATE, 'task_object%result: the task still runs', stat)
      return
   endif
   status = fig_task_finish(self%id)
   call move_alloc(self%rec%data, data)
   call release(self)
   call figure_check(status, stat)
   endsubroutine task_result

   subroutine release(self)
   !< Forget the task: a running one is asked to stop and waited for.
   class(task_object), intent(inout) :: self !< Task.

   if (self%id /= 0_c_int) call fig_task_release(self%id)
   self%id = 0_c_int
   if (associated(self%rec)) deallocate(self%rec)
   self%rec => null()
   endsubroutine release

   subroutine task_final(self)
   !< The object ends: its task, if running, is asked to stop and waited for.
   type(task_object), intent(inout) :: self !< Task.

   call release(self)
   endsubroutine task_final
endmodule figure_task
