// The calls processes.md lets a task make (quit, quit_requested, request_frames, set_lazy, set_confirm_quit,
// content_scale, wake), made from 8 threads while the main thread runs the frame loop: built against a native layer
// compiled with -fsanitize=thread by scripts/tsan_check.sh, ThreadSanitizer reports any data race on these paths.
//
// Usage: tsan_flags headless|remote
#include "figure_native.h"

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <thread>
#include <vector>

int main(int argc, char **argv) {
   const bool remote = argc > 1 && std::strcmp(argv[1], "remote") == 0;
   int port = 0;
   const int st = remote ? fig_init_remote(320, 240, "127.0.0.1", 9, 0, &port) : fig_init_headless(320, 240);
   if (st != 0) {
      std::fprintf(stderr, "tsan_flags: init failed (%d)\n", st);
      return 2;
   }
   fig_set_lazy(1, 0.05); // the remote loop waits: the threads' calls end its waits
   std::atomic<bool> go{false};
   std::vector<std::thread> workers;
   for (int k = 0; k < 8; ++k)
      workers.emplace_back([k, &go] {
         while (!go.load()) std::this_thread::yield();
         for (int i = 0; i < 200; ++i) {
            fig_request_frames(1 + (i + k) % 8);
            fig_set_lazy(1, 0.05);
            fig_set_confirm_quit(0);
            (void)fig_quit_requested();
            (void)fig_content_scale();
            fig_wake();
            std::this_thread::sleep_for(std::chrono::microseconds(200));
         }
      });
   go = true;
   int frames = 0, running = 1;
   while (frames < 200) {
      if (fig_begin_frame(&running) != 0 || !running) break;
      fig_end_frame();
      ++frames;
   }
   for (auto &w : workers) w.join();
   std::thread quitter([] { // the end of the loop asked from another thread, while the loop runs
      std::this_thread::sleep_for(std::chrono::milliseconds(20));
      fig_quit();
   });
   for (int extra = 0; extra < 100000 && running; ++extra) {
      if (fig_begin_frame(&running) != 0 || !running) break;
      fig_end_frame();
   }
   quitter.join();
   std::printf("tsan_flags %s: %d frames, the loop %s after a quit from another thread\n", remote ? "remote" : "headless",
               frames, running ? "went on" : "ended");
   fig_shutdown();
   return running ? 1 : 0;
}
