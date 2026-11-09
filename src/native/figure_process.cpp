// FIGURE processes: programs started from the program, in two modes (see figure_native.h, "Processes").
//
// Captured: SDL3's process API with standard output (and, merged, standard error) piped to the program. A reader
// thread per process drains the pipe into a buffer as the child writes, so a child printing megabytes never blocks
// on a full pipe while the program is busy or its loop sleeps (lazy redraw); each read wakes the frame loop
// (fig_wake). The reader also notices the child's end (SDL_WaitProcess, which reaps it). A captured child is killed
// when its object is released, at fig_shutdown, and at the program's exit (atexit).
//
// Detached: the child's output goes to a log file and the child survives the program. On POSIX FIGURE starts it
// itself with a double fork (setsid, then the grandchild execs): the grandchild belongs to init, which reaps it, so
// no zombie is left, and its pid is known on every system (SDL's background mode on macOS does not report it). On
// Windows SDL's background mode is used, with the log file opened shared so that the program can read it while the
// child writes it. The program follows the file (fig_process_take reads what was appended).
//
// Lines are not cut here: the Fortran side receives bytes up to the last newline (all of them at the end).
#include "figure_native.h"

#include <SDL3/SDL.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#else
#include <cerrno>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
extern char **environ;
#endif

namespace {

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

std::string str(const char *s, int n) { return std::string(s, n > 0 ? static_cast<size_t>(n) : 0); }

// Strings packed by the Fortran side: one buffer and the length of each.
std::vector<std::string> unpack(const char *buf, const int *lens, int count) {
   std::vector<std::string> v;
   size_t                   at = 0;
   for (int i = 0; i < count; ++i) {
      const size_t n = lens[i] > 0 ? static_cast<size_t>(lens[i]) : 0;
      v.emplace_back(buf + at, n);
      at += n;
   }
   return v;
}

struct process_t {
   bool                 detached = false;
   long long            pid = 0;
   std::mutex           m;              // guards everything below and the SDL_Process
   SDL_Process         *p = nullptr;    // captured: SDL's process, until released
   std::thread          reader;         // captured: drains the pipe
   std::atomic<bool>    stop{false};    // captured: the reader ends at its next wake-up
   std::string          out;            // captured: bytes read, not yet taken
   bool                 eof = false;    // captured: the reader has ended (nothing more will arrive)
   bool                 exited = false; // the child has ended
   int                  code = 0;       // its exit code (captured)
   bool                 killed = false; // ended after fig_process_kill
   std::string          log;            // detached: the log file
   long long            offset = 0;     // detached: bytes of the log file already taken
#ifdef _WIN32
   HANDLE               handle = nullptr; // detached: the child, for its end (kept: its pid is not reused)
#endif
};

std::mutex                                     reg_mutex;
std::map<int, std::shared_ptr<process_t>>      *reg = nullptr; // never destroyed: the atexit handler runs late
int                                            next_id = 1;
bool                                           atexit_set = false;

std::shared_ptr<process_t> find(int id) {
   std::lock_guard<std::mutex> lock(reg_mutex);
   if (!reg) return nullptr;
   const auto it = reg->find(id);
   return it == reg->end() ? nullptr : it->second;
}

// The child's end, without blocking (captured: reaps it). Called with q.m held.
void check_exit(process_t &q) {
   if (q.exited) return;
   if (!q.detached) {
      int code = 0;
      if (q.p && SDL_WaitProcess(q.p, false, &code)) {
         q.exited = true;
         q.code = code;
      }
      return;
   }
#ifdef _WIN32
   if (!q.handle || WaitForSingleObject(q.handle, 0) == WAIT_OBJECT_0) q.exited = true;
#else
   if (q.pid <= 0 || (::kill(static_cast<pid_t>(q.pid), 0) != 0 && errno == ESRCH)) q.exited = true;
#endif
}

void reader_main(std::shared_ptr<process_t> q, SDL_IOStream *io) {
   char buf[65536];
#ifndef _WIN32
   const int fd = static_cast<int>(
      SDL_GetNumberProperty(SDL_GetIOProperties(io), SDL_PROP_IOSTREAM_FILE_DESCRIPTOR_NUMBER, -1));
#endif
   using clock = std::chrono::steady_clock;
   clock::time_point ended{};
   bool              child_ended = false;
   for (;;) {
      const size_t n = SDL_ReadIO(io, buf, sizeof(buf));
      if (n > 0) {
         {
            std::lock_guard<std::mutex> lock(q->m);
            q->out.append(buf, n);
         }
         fig_wake();
         continue;
      }
      if (SDL_GetIOStatus(io) != SDL_IO_STATUS_NOT_READY) break; // the end of the pipe (or an error)
      if (q->stop) break;
      {
         std::lock_guard<std::mutex> lock(q->m);
         check_exit(*q);
         if (q->exited && !child_ended) {
            child_ended = true;
            ended = clock::now();
         }
      }
      // a child that ended while a program it started still holds the pipe: what it wrote is read for 100 ms more
      if (child_ended && clock::now() - ended > std::chrono::milliseconds(100)) break;
#ifdef _WIN32
      SDL_Delay(5); // the pipe is in PIPE_NOWAIT mode: no handle to wait on
#else
      pollfd pfd{fd, POLLIN, 0};
      if (fd >= 0) ::poll(&pfd, 1, 50);
      else SDL_Delay(5);
#endif
   }
   // wait for the end (a closed pipe comes first), up to the stop request
   for (;;) {
      {
         std::lock_guard<std::mutex> lock(q->m);
         check_exit(*q);
         if (q->exited || q->stop) {
            q->eof = true;
            break;
         }
      }
      SDL_Delay(5);
   }
   fig_wake();
}

// Kill a captured child and wait for its end (100 ms after a polite request, then by force); join the reader;
// release SDL's process. For release, shutdown and exit.
void finish_captured(process_t &q) {
   {
      std::lock_guard<std::mutex> lock(q.m);
      check_exit(q);
      if (!q.exited && q.p) {
         SDL_KillProcess(q.p, false);
         q.killed = true;
      }
   }
   for (int i = 0; i < 20; ++i) {
      {
         std::lock_guard<std::mutex> lock(q.m);
         check_exit(q);
         if (q.exited) break;
      }
      SDL_Delay(5);
   }
   {
      std::lock_guard<std::mutex> lock(q.m);
      check_exit(q);
      if (!q.exited && q.p) SDL_KillProcess(q.p, true);
   }
   for (int i = 0; i < 1000; ++i) { // reaped by check_exit (SDL_WaitProcess): no zombie; at most 5 s
      {
         std::lock_guard<std::mutex> lock(q.m);
         check_exit(q);
         if (q.exited || !q.p) break;
      }
      SDL_Delay(5);
   }
   q.stop = true;
   if (q.reader.joinable()) q.reader.join();
   std::lock_guard<std::mutex> lock(q.m);
   if (q.p) SDL_DestroyProcess(q.p);
   q.p = nullptr;
}

void release_all_captured() {
   std::vector<std::shared_ptr<process_t>> all;
   {
      std::lock_guard<std::mutex> lock(reg_mutex);
      if (!reg) return;
      for (auto &e : *reg)
         if (!e.second->detached) all.push_back(e.second);
   }
   for (auto &q : all) finish_captured(*q);
}

void at_exit() {
   try {
      release_all_captured();
   } catch (...) {
   }
}

#ifndef _WIN32
// The executable for argv[0], searched in PATH as execvp would, before the fork (execve is async-signal-safe,
// execvp is not).
std::string find_executable(const std::string &name, const std::string &path_env) {
   if (name.find('/') != std::string::npos) return name;
   size_t start = 0;
   for (;;) {
      const size_t end = path_env.find(':', start);
      std::string  dir = path_env.substr(start, end == std::string::npos ? std::string::npos : end - start);
      if (dir.empty()) dir = ".";
      const std::string f = dir + "/" + name;
      struct stat       sb;
      if (::stat(f.c_str(), &sb) == 0 && S_ISREG(sb.st_mode) && ::access(f.c_str(), X_OK) == 0) return f;
      if (end == std::string::npos) break;
      start = end + 1;
   }
   return std::string();
}

// Detached, POSIX: fork; the child calls setsid and forks again; the grandchild redirects its output to the log
// file, changes directory and execs; the child writes the grandchild's pid to a pipe and ends at once. An exec that
// fails is reported through a close-on-exec pipe.
int start_detached_posix(const std::vector<std::string> &args, const std::string &cwd,
                         const std::vector<std::string> &env, bool merge, const std::string &log, long long &pid) {
   std::vector<std::string> envs;
   for (char **e = environ; e && *e; ++e) {
      const std::string kv(*e);
      const std::string name = kv.substr(0, kv.find('='));
      bool              replaced = false;
      for (const auto &o : env)
         if (o.substr(0, o.find('=')) == name) replaced = true;
      if (!replaced) envs.push_back(kv);
   }
   for (const auto &o : env) envs.push_back(o);
   std::string path_env = "/usr/bin:/bin";
   for (const auto &kv : envs)
      if (kv.compare(0, 5, "PATH=") == 0) path_env = kv.substr(5);
   const std::string exe = find_executable(args[0], path_env);
   if (exe.empty()) return fail(FIG_ERR_FAILED, "process: cannot start '" + args[0] + "': not found in PATH");
   std::vector<char *> argv, envp;
   for (const auto &a : args) argv.push_back(const_cast<char *>(a.c_str()));
   argv.push_back(nullptr);
   for (const auto &kv : envs) envp.push_back(const_cast<char *>(kv.c_str()));
   envp.push_back(nullptr);
   const int out = ::open(log.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
   if (out < 0) return fail(FIG_ERR_FAILED, "process: cannot write the log file '" + log + "': " + std::strerror(errno));
   const int in = ::open("/dev/null", O_RDONLY | O_CLOEXEC);
   int       pid_pipe[2], err_pipe[2];
   if (::pipe(pid_pipe) != 0) {
      ::close(out);
      if (in >= 0) ::close(in);
      return fail(FIG_ERR_FAILED, std::string("process: pipe: ") + std::strerror(errno));
   }
   if (::pipe(err_pipe) != 0) {
      ::close(out);
      if (in >= 0) ::close(in);
      ::close(pid_pipe[0]);
      ::close(pid_pipe[1]);
      return fail(FIG_ERR_FAILED, std::string("process: pipe: ") + std::strerror(errno));
   }
   ::fcntl(err_pipe[1], F_SETFD, FD_CLOEXEC);
   ::fcntl(pid_pipe[0], F_SETFD, FD_CLOEXEC);
   ::fcntl(err_pipe[0], F_SETFD, FD_CLOEXEC);
   const char *dir = cwd.empty() ? nullptr : cwd.c_str();
   long        max_fd = ::sysconf(_SC_OPEN_MAX);
   if (max_fd < 0 || max_fd > 65536) max_fd = 65536;
   const pid_t child = ::fork();
   if (child < 0) {
      ::close(out);
      if (in >= 0) ::close(in);
      for (int f : {pid_pipe[0], pid_pipe[1], err_pipe[0], err_pipe[1]}) ::close(f);
      return fail(FIG_ERR_FAILED, std::string("process: fork: ") + std::strerror(errno));
   }
   if (child == 0) { // only async-signal-safe calls from here
      ::setsid();
      const pid_t grandchild = ::fork();
      if (grandchild == 0) {
         if (in >= 0) ::dup2(in, 0);
         ::dup2(out, 1);
         if (merge) ::dup2(out, 2);
         else if (in >= 0) {
            const int null = ::open("/dev/null", O_WRONLY);
            if (null >= 0) ::dup2(null, 2);
         }
         for (int f = 3; f < max_fd; ++f)
            if (f != err_pipe[1]) ::close(f);
         int e = 0;
         if (dir && ::chdir(dir) != 0) e = errno;
         if (e == 0) {
            ::execve(exe.c_str(), argv.data(), envp.data());
            e = errno;
         }
         ssize_t w = ::write(err_pipe[1], &e, sizeof(e));
         (void)w;
         ::_exit(127);
      }
      long long g = grandchild;
      ssize_t   w = ::write(pid_pipe[1], &g, sizeof(g));
      (void)w;
      ::_exit(0);
   }
   ::close(out);
   if (in >= 0) ::close(in);
   ::close(pid_pipe[1]);
   ::close(err_pipe[1]);
   int status = 0;
   while (::waitpid(child, &status, 0) < 0 && errno == EINTR) {
   }
   long long g = -1;
   ssize_t   r = ::read(pid_pipe[0], &g, sizeof(g));
   ::close(pid_pipe[0]);
   int e = 0;
   ssize_t re;
   while ((re = ::read(err_pipe[0], &e, sizeof(e))) < 0 && errno == EINTR) {
   }
   ::close(err_pipe[0]);
   if (r != static_cast<ssize_t>(sizeof(g)) || g <= 0)
      return fail(FIG_ERR_FAILED, "process: cannot start '" + args[0] + "': fork failed");
   if (re == static_cast<ssize_t>(sizeof(e)))
      return fail(FIG_ERR_FAILED, "process: cannot start '" + args[0] + "': " + std::strerror(e));
   pid = g;
   return FIG_OK;
}
#else
// Detached, Windows: a stream over the log file opened shared, for SDL's redirection.
bool SDLCALL io_close(void *) { return true; }
#endif

} // namespace

extern "C" {

int fig_process_start(int *id, const char *args, const int *arg_lens, int nargs, const char *cwd, int cwd_len,
                      const char *env, const int *env_lens, int nenv, int merge_stderr, int detached,
                      const char *log, int log_len) {
   try {
      *id = 0;
      if (nargs < 1) return fail(FIG_ERR_ARGUMENT, "process: no program given (args is empty)");
      const std::vector<std::string> a = unpack(args, arg_lens, nargs);
      if (a[0].empty()) return fail(FIG_ERR_ARGUMENT, "process: the program's name is empty");
      const std::vector<std::string> e = unpack(env, env_lens, nenv);
      for (const auto &kv : e)
         if (kv.find('=') == std::string::npos || kv[0] == '=')
            return fail(FIG_ERR_ARGUMENT, "process: environment entry '" + kv + "' is not NAME=value");
      const std::string dir = str(cwd, cwd_len), logf = str(log, log_len);
      if (detached && logf.empty()) return fail(FIG_ERR_ARGUMENT, "process: a detached process needs log_file");
      if (!detached && !logf.empty())
         return fail(FIG_ERR_ARGUMENT, "process: log_file is for detached processes (captured output is polled)");
      auto q = std::make_shared<process_t>();
      q->detached = detached != 0;
      q->log = logf;
#ifndef _WIN32
      if (q->detached) {
         long long pid = 0;
         const int s = start_detached_posix(a, dir, e, merge_stderr != 0, logf, pid);
         if (s != FIG_OK) return s;
         q->pid = pid;
      }
#endif
      if (!q->detached || q->pid == 0) {
         std::vector<const char *> argv;
         for (const auto &s : a) argv.push_back(s.c_str());
         argv.push_back(nullptr);
         const SDL_PropertiesID props = SDL_CreateProperties();
         if (!props) return fail(FIG_ERR_FAILED, std::string("process: ") + SDL_GetError());
         SDL_SetPointerProperty(props, SDL_PROP_PROCESS_CREATE_ARGS_POINTER, argv.data());
         if (!dir.empty()) SDL_SetStringProperty(props, SDL_PROP_PROCESS_CREATE_WORKING_DIRECTORY_STRING, dir.c_str());
         SDL_Environment *envp = nullptr;
         if (!e.empty()) {
            envp = SDL_CreateEnvironment(true);
            for (const auto &kv : e) {
               const size_t eq = kv.find('=');
               SDL_SetEnvironmentVariable(envp, kv.substr(0, eq).c_str(), kv.substr(eq + 1).c_str(), true);
            }
            SDL_SetPointerProperty(props, SDL_PROP_PROCESS_CREATE_ENVIRONMENT_POINTER, envp);
         }
         SDL_SetNumberProperty(props, SDL_PROP_PROCESS_CREATE_STDIN_NUMBER, SDL_PROCESS_STDIO_NULL);
         SDL_IOStream *logio = nullptr;
#ifdef _WIN32
         HANDLE logh = INVALID_HANDLE_VALUE;
         if (q->detached) {
            const int wn = MultiByteToWideChar(CP_UTF8, 0, logf.c_str(), -1, nullptr, 0);
            std::wstring w(static_cast<size_t>(wn > 0 ? wn : 1), L'\0');
            MultiByteToWideChar(CP_UTF8, 0, logf.c_str(), -1, &w[0], wn);
            logh = CreateFileW(w.c_str(), GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
                               CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
            if (logh == INVALID_HANDLE_VALUE) {
               SDL_DestroyProperties(props);
               if (envp) SDL_DestroyEnvironment(envp);
               return fail(FIG_ERR_FAILED, "process: cannot write the log file '" + logf + "'");
            }
            SDL_IOStreamInterface iface;
            SDL_INIT_INTERFACE(&iface);
            iface.close = io_close;
            logio = SDL_OpenIO(&iface, nullptr);
            if (logio) SDL_SetPointerProperty(SDL_GetIOProperties(logio), SDL_PROP_IOSTREAM_WINDOWS_HANDLE_POINTER, logh);
            SDL_SetBooleanProperty(props, SDL_PROP_PROCESS_CREATE_BACKGROUND_BOOLEAN, true);
            SDL_SetNumberProperty(props, SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER, SDL_PROCESS_STDIO_REDIRECT);
            SDL_SetPointerProperty(props, SDL_PROP_PROCESS_CREATE_STDOUT_POINTER, logio);
            if (merge_stderr) {
               SDL_SetNumberProperty(props, SDL_PROP_PROCESS_CREATE_STDERR_NUMBER, SDL_PROCESS_STDIO_REDIRECT);
               SDL_SetPointerProperty(props, SDL_PROP_PROCESS_CREATE_STDERR_POINTER, logio);
            } else {
               SDL_SetNumberProperty(props, SDL_PROP_PROCESS_CREATE_STDERR_NUMBER, SDL_PROCESS_STDIO_NULL);
            }
         } else
#endif
         {
            SDL_SetNumberProperty(props, SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER, SDL_PROCESS_STDIO_APP);
            if (merge_stderr) SDL_SetBooleanProperty(props, SDL_PROP_PROCESS_CREATE_STDERR_TO_STDOUT_BOOLEAN, true);
         }
         SDL_Process *p = SDL_CreateProcessWithProperties(props);
         const std::string err = p ? std::string() : std::string(SDL_GetError());
         SDL_DestroyProperties(props);
         if (envp) SDL_DestroyEnvironment(envp);
         if (logio) SDL_CloseIO(logio);
#ifdef _WIN32
         if (logh != INVALID_HANDLE_VALUE) CloseHandle(logh);
#endif
         if (!p) return fail(FIG_ERR_FAILED, "process: cannot start '" + a[0] + "': " + err);
         q->pid = static_cast<long long>(SDL_GetNumberProperty(SDL_GetProcessProperties(p), SDL_PROP_PROCESS_PID_NUMBER, 0));
         if (q->detached) {
#ifdef _WIN32
            q->handle = OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, static_cast<DWORD>(q->pid));
#endif
            SDL_DestroyProcess(p); // the child goes on
         } else {
            q->p = p;
            SDL_IOStream *io = SDL_GetProcessOutput(p);
            if (!io) {
               SDL_KillProcess(p, true);
               int code = 0;
               SDL_WaitProcess(p, true, &code);
               SDL_DestroyProcess(p);
               return fail(FIG_ERR_FAILED, std::string("process: no output stream: ") + SDL_GetError());
            }
            q->reader = std::thread(reader_main, q, io);
         }
      }
      std::lock_guard<std::mutex> lock(reg_mutex);
      if (!reg) reg = new std::map<int, std::shared_ptr<process_t>>();
      if (!atexit_set) {
         std::atexit(at_exit);
         atexit_set = true;
      }
      *id = next_id++;
      (*reg)[*id] = q;
      return FIG_OK;
   } catch (const std::exception &x) {
      return fail(FIG_ERR_EXCEPTION, std::string("C++ exception: ") + x.what());
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "unknown C++ exception");
   }
}

int fig_process_pending(int id, long long *len, int *running) {
   try {
      *len = 0;
      *running = 0;
      const auto q = find(id);
      if (!q) return fail(FIG_ERR_STATE, "process: not started");
      std::lock_guard<std::mutex> lock(q->m);
      check_exit(*q);
      if (!q->detached) {
         const bool ended = q->eof;
         *running = ended ? 0 : 1;
         if (ended) {
            *len = static_cast<long long>(q->out.size());
         } else {
            const size_t nl = q->out.rfind('\n');
            *len = nl == std::string::npos ? 0 : static_cast<long long>(nl + 1);
         }
         return FIG_OK;
      }
      *running = q->exited ? 0 : 1;
      FILE *f = std::fopen(q->log.c_str(), "rb");
      if (!f) return FIG_OK; // not created yet
      std::fseek(f, 0, SEEK_END);
      const long long size = std::ftell(f);
      if (size < q->offset) q->offset = 0; // truncated: read it again
      long long n = size - q->offset;
      if (n > 0 && q->exited == false) { // complete lines only while it runs
         std::vector<char> tail(static_cast<size_t>(n));
         std::fseek(f, static_cast<long>(q->offset), SEEK_SET);
         n = static_cast<long long>(std::fread(tail.data(), 1, tail.size(), f));
         long long last = -1;
         for (long long i = n - 1; i >= 0; --i)
            if (tail[static_cast<size_t>(i)] == '\n') {
               last = i;
               break;
            }
         n = last + 1;
      }
      std::fclose(f);
      *len = n > 0 ? n : 0;
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "process: C++ exception");
   }
}

int fig_process_take(int id, char *buf, long long len, long long *got) {
   try {
      const auto q = find(id);
      *got = 0;
      if (!q) return fail(FIG_ERR_STATE, "process: not started");
      if (len <= 0) return FIG_OK;
      std::lock_guard<std::mutex> lock(q->m);
      if (!q->detached) {
         const size_t n = std::min(static_cast<size_t>(len), q->out.size());
         std::memcpy(buf, q->out.data(), n);
         q->out.erase(0, n);
         *got = static_cast<long long>(n);
         return FIG_OK;
      }
      FILE *f = std::fopen(q->log.c_str(), "rb");
      if (!f) return fail(FIG_ERR_FAILED, "process: cannot read the log file '" + q->log + "'");
      std::fseek(f, static_cast<long>(q->offset), SEEK_SET);
      const size_t n = std::fread(buf, 1, static_cast<size_t>(len), f);
      std::fclose(f);
      q->offset += static_cast<long long>(n);
      *got = static_cast<long long>(n);
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "process: C++ exception");
   }
}

int fig_process_info(int id, int *running, int *exited, int *code, int *killed, long long *pid, int *detached) {
   const auto q = find(id);
   *running = 0;
   *exited = 0;
   *code = 0;
   *killed = 0;
   *pid = 0;
   *detached = 0;
   if (!q) return fail(FIG_ERR_STATE, "process: not started");
   std::lock_guard<std::mutex> lock(q->m);
   check_exit(*q);
   *running = (q->detached ? q->exited : q->eof) ? 0 : 1;
   *exited = q->exited ? 1 : 0;
   *code = q->code;
   *killed = q->killed ? 1 : 0;
   *pid = q->pid;
   *detached = q->detached ? 1 : 0;
   return FIG_OK;
}

int fig_process_kill(int id, int force) {
   const auto q = find(id);
   if (!q) return fail(FIG_ERR_STATE, "process: not started");
   std::lock_guard<std::mutex> lock(q->m);
   check_exit(*q);
   if (q->exited) return FIG_OK; // already ended: nothing to do
   bool ok = true;
   if (!q->detached) {
      ok = q->p && SDL_KillProcess(q->p, force != 0);
   } else {
#ifdef _WIN32
      HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, static_cast<DWORD>(q->pid));
      ok = h && TerminateProcess(h, 1);
      if (h) CloseHandle(h);
#else
      ok = ::kill(static_cast<pid_t>(q->pid), force ? SIGKILL : SIGTERM) == 0;
#endif
   }
   if (!ok) return fail(FIG_ERR_FAILED, std::string("process: cannot kill: ") + SDL_GetError());
   q->killed = true;
   return FIG_OK;
}

// Forget a process: a captured one is killed (and reaped) if still running; a detached one goes on.
void fig_process_release(int id) {
   std::shared_ptr<process_t> q;
   {
      std::lock_guard<std::mutex> lock(reg_mutex);
      if (!reg) return;
      const auto it = reg->find(id);
      if (it == reg->end()) return;
      q = it->second;
      reg->erase(it);
   }
   try {
      if (!q->detached) finish_captured(*q);
#ifdef _WIN32
      if (q->handle) CloseHandle(q->handle);
      q->handle = nullptr;
#endif
   } catch (...) {
   }
}

void fig_process_shutdown(void) {
   try {
      release_all_captured();
   } catch (...) {
   }
}

} // extern "C"
