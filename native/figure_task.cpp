// FIGURE tasks: Fortran procedures run on worker threads (see figure_native.h, "Tasks").
//
// A task is an SDL thread that calls a C function pointer (the Fortran side's bind(C) trampoline) with an opaque
// argument. Its progress, its message, its end and its failure are kept here, behind an SDL mutex, and read by the
// main thread when it likes; each report and the end wake the frame loop (fig_wake). Cancellation is cooperative: a
// flag the task reads at its safe points. Only SDL's portable primitives are used (threads, mutexes, atomics), plus
// C++'s thread_local for the flag that marks a worker: FIGURE's drawing entry points ask fig_task_refuse, which on a
// worker records the refusal in the task (FIG_ERR_STATE and its message), asks the task to stop, and answers 1.
#include "figure_native.h"

#include <SDL3/SDL.h>

#include <algorithm>
#include <cstring>
#include <map>
#include <memory>
#include <string>

namespace {

struct task_t {
   int            id = 0;
   SDL_Thread    *thread = nullptr;
   void         (*fn)(void *) = nullptr;
   void          *arg = nullptr;
   SDL_Mutex     *m = nullptr;     // guards the fields below
   double         fraction = 0.0;  // the last report, in [0, 1]; negative: none yet
   std::string    message;         // the last report's message
   std::string    error;           // the failure's message
   int            status = FIG_OK; // the failure's status: FIG_ERR_FAILED (fig_task_fail), FIG_ERR_STATE (refused)
   SDL_AtomicInt  cancel{};        // 1: asked to stop
   SDL_AtomicInt  done{};          // 1: the procedure has returned
};

SDL_Mutex                              *reg_m = nullptr; // created at the first task, never destroyed
std::map<int, std::shared_ptr<task_t>> *reg = nullptr;
int                                     next_id = 1;
thread_local task_t                    *current = nullptr; // the task this thread runs (null: not a worker)

// 64 MiB of stack: Fortran puts automatic arrays and temporaries there, and a secondary thread's default is small
// (512 KiB on macOS). Address space only: pages are committed as they are used.
constexpr Sint64 STACK = 64ll * 1024 * 1024;

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

std::shared_ptr<task_t> find(int id) {
   if (!reg_m) return nullptr;
   SDL_LockMutex(reg_m);
   std::shared_ptr<task_t> t;
   if (reg) {
      const auto it = reg->find(id);
      if (it != reg->end()) t = it->second;
   }
   SDL_UnlockMutex(reg_m);
   return t;
}

int SDLCALL task_main(void *data) {
   task_t *t = static_cast<task_t *>(data);
   current = t;
   t->fn(t->arg);
   current = nullptr;
   SDL_SetAtomicInt(&t->done, 1);
   fig_wake();
   return 0;
}

} // namespace

extern "C" {

int fig_task_start(void (*fn)(void *), void *arg, int *id) {
   *id = 0;
   if (current) return fail(FIG_ERR_STATE, "task: a task cannot start another task");
   if (!fn) return fail(FIG_ERR_ARGUMENT, "task: no procedure");
   if (!reg_m) {
      reg_m = SDL_CreateMutex();
      if (!reg_m) return fail(FIG_ERR_FAILED, std::string("task: ") + SDL_GetError());
      reg = new std::map<int, std::shared_ptr<task_t>>();
   }
   auto t = std::make_shared<task_t>();
   t->fn = fn;
   t->arg = arg;
   t->fraction = -1.0;
   t->m = SDL_CreateMutex();
   if (!t->m) return fail(FIG_ERR_FAILED, std::string("task: ") + SDL_GetError());
   SDL_LockMutex(reg_m);
   t->id = next_id++;
   (*reg)[t->id] = t;
   SDL_UnlockMutex(reg_m);
   const SDL_PropertiesID props = SDL_CreateProperties();
   SDL_SetPointerProperty(props, SDL_PROP_THREAD_CREATE_ENTRY_FUNCTION_POINTER, reinterpret_cast<void *>(task_main));
   SDL_SetStringProperty(props, SDL_PROP_THREAD_CREATE_NAME_STRING, "figure task");
   SDL_SetPointerProperty(props, SDL_PROP_THREAD_CREATE_USERDATA_POINTER, t.get());
   SDL_SetNumberProperty(props, SDL_PROP_THREAD_CREATE_STACKSIZE_NUMBER, STACK);
   *id = t->id; // before the thread starts: the task's handle holds it from its first line
   t->thread = SDL_CreateThreadWithProperties(props);
   SDL_DestroyProperties(props);
   if (!t->thread) {
      *id = 0;
      const std::string err = SDL_GetError();
      SDL_LockMutex(reg_m);
      reg->erase(t->id);
      SDL_UnlockMutex(reg_m);
      SDL_DestroyMutex(t->m);
      return fail(FIG_ERR_FAILED, "task: cannot start a thread: " + err);
   }
   return FIG_OK;
}

int fig_task_state(int id, int *done, double *fraction, char *msg, int msg_len, int *len, int *status) {
   *done = 0;
   *fraction = -1.0;
   *len = 0;
   *status = FIG_OK;
   const auto t = find(id);
   if (!t) return fail(FIG_ERR_STATE, "task: not started");
   *done = SDL_GetAtomicInt(&t->done);
   SDL_LockMutex(t->m);
   *fraction = t->fraction;
   *len = static_cast<int>(t->message.size());
   if (msg && msg_len > 0) std::memcpy(msg, t->message.data(), static_cast<size_t>(std::min(*len, msg_len)));
   *status = t->status;
   SDL_UnlockMutex(t->m);
   return FIG_OK;
}

int fig_task_report(int id, double fraction, const char *msg, int msg_len, int keep_message) {
   const auto t = find(id);
   if (!t) return FIG_ERR_STATE;
   SDL_LockMutex(t->m);
   t->fraction = std::max(0.0, std::min(1.0, fraction));
   if (!keep_message) t->message.assign(msg, msg_len > 0 ? static_cast<size_t>(msg_len) : 0);
   SDL_UnlockMutex(t->m);
   fig_wake();
   return FIG_OK;
}

int fig_task_fail(int id, const char *msg, int msg_len) {
   const auto t = find(id);
   if (!t) return FIG_ERR_STATE;
   SDL_LockMutex(t->m);
   if (t->status == FIG_OK) { // the first failure is kept
      t->status = FIG_ERR_FAILED;
      t->error.assign(msg, msg_len > 0 ? static_cast<size_t>(msg_len) : 0);
   }
   SDL_UnlockMutex(t->m);
   return FIG_OK;
}

int fig_task_cancel(int id) {
   const auto t = find(id);
   if (!t) return fail(FIG_ERR_STATE, "task: not started");
   SDL_SetAtomicInt(&t->cancel, 1);
   return FIG_OK;
}

int fig_task_cancelled(int id) {
   const auto t = find(id);
   return t && SDL_GetAtomicInt(&t->cancel) != 0 ? 1 : 0;
}

// Main thread, after the end: wait for the thread, put the failure's message in fig_last_error, return its status.
int fig_task_finish(int id) {
   const auto t = find(id);
   if (!t) return fail(FIG_ERR_STATE, "task: not started");
   if (!SDL_GetAtomicInt(&t->done)) return fail(FIG_ERR_STATE, "task: it still runs");
   if (t->thread) {
      SDL_WaitThread(t->thread, nullptr);
      t->thread = nullptr;
   }
   SDL_LockMutex(t->m);
   const int         status = t->status;
   const std::string error = t->error;
   SDL_UnlockMutex(t->m);
   if (status != FIG_OK) return fail(status, error);
   return FIG_OK;
}

// Forget a task: a running one is asked to stop, and waited for (until its next safe point).
void fig_task_release(int id) {
   const auto t = find(id);
   if (!t) return;
   SDL_SetAtomicInt(&t->cancel, 1); // still registered: the task sees the request through its handle
   if (t->thread) SDL_WaitThread(t->thread, nullptr);
   t->thread = nullptr;
   SDL_LockMutex(reg_m);
   reg->erase(id);
   SDL_UnlockMutex(reg_m);
   SDL_DestroyMutex(t->m);
   t->m = nullptr;
}

int fig_task_on_worker(void) { return current ? 1 : 0; }

int fig_task_refuse(const char *name, int name_len) {
   task_t *t = current;
   if (!t) return 0;
   SDL_LockMutex(t->m);
   if (t->status != FIG_ERR_STATE) { // the first refusal is kept, over a failure reported before it
      t->status = FIG_ERR_STATE;
      t->error = std::string(name, name_len > 0 ? static_cast<size_t>(name_len) : 0) +
                 ": a drawing procedure called from a task (only the main thread draws); the task is asked to stop";
   }
   SDL_UnlockMutex(t->m);
   SDL_SetAtomicInt(&t->cancel, 1);
   return 1;
}

} // extern "C"
