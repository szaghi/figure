!< figure_test_plot_alloc_counter, a count of the heap allocations a thread makes between two calls (tests only).
module figure_test_plot_alloc_counter
!< figure_test_plot_alloc_counter, a count of the heap allocations a thread makes between two calls (tests only).
!<
!< szaghi/figure#15 P10, step 9 (ADR 0001: no allocation per item per frame in the plot frame). The C library's
!< allocator entry points, `malloc`, `calloc`, `realloc`, `posix_memalign`, `aligned_alloc` and `memalign`, are defined
!< here (`bind(C)` with their C names) and forward to glibc's own (`__libc_malloc`, `__libc_calloc`, `__libc_realloc`,
!< `__libc_memalign`, exported by glibc for this use): a program linking this module takes every allocation of the
!< process through them, the Fortran run-time's (gfortran's, nvfortran's, ifx's ALLOCATE and character temporaries),
!< Dear ImGui's and the C++ library's, since an executable's definition of a symbol comes first in the dynamic
!< linker's lookup. `free` stays glibc's: every block still comes from glibc's allocator. Between `alloc_arm` and
!< `alloc_disarm` the allocations of the thread that armed it are counted (other threads, a GL driver's, are not);
!< the first `TRACES` of them print their call stack on standard error (glibc's `backtrace_symbols_fd`: no
!< allocation; addresses resolved with `addr2line -f -e <program> <offset>`). Linux with glibc only.
!<
!< Only test programs use this module: linked into a library, it would take every program's allocations.
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_int, c_long, c_new_line, c_ptr, c_size_t
use, intrinsic :: iso_fortran_env, only : int32, int64

implicit none
private
public :: alloc_arm, alloc_disarm, alloc_count

integer(c_int), parameter :: TRACES = 8_c_int      !< Allocations whose call stack is printed.
integer(c_int), parameter :: DEPTH = 24_c_int      !< Frames of a stack.
integer(c_int), parameter :: ENOMEM = 12_c_int     !< errno ENOMEM.

logical         :: armed = .false.   !< Counting.
logical         :: inside = .false.  !< In a trace (its own allocations not counted).
integer(c_long) :: owner = 0_c_long  !< The thread counted (pthread_t).
integer(int64)  :: counted = 0_int64 !< Allocations counted.
integer(c_int)  :: traced = 0_c_int  !< Stacks printed.
type(c_ptr)     :: frames(DEPTH)     !< A stack's return addresses.

interface
   function libc_malloc(n) result(p) bind(C, name='__libc_malloc')
   !< glibc's `malloc`.
   import :: c_ptr, c_size_t
   implicit none
   integer(c_size_t), value :: n !< Bytes.
   type(c_ptr)              :: p !< Block.
   endfunction libc_malloc

   function libc_calloc(m, n) result(p) bind(C, name='__libc_calloc')
   !< glibc's `calloc`.
   import :: c_ptr, c_size_t
   implicit none
   integer(c_size_t), value :: m, n !< Elements, bytes each.
   type(c_ptr)              :: p    !< Block.
   endfunction libc_calloc

   function libc_realloc(q, n) result(p) bind(C, name='__libc_realloc')
   !< glibc's `realloc`.
   import :: c_ptr, c_size_t
   implicit none
   type(c_ptr),       value :: q !< Block.
   integer(c_size_t), value :: n !< Bytes.
   type(c_ptr)              :: p !< Block.
   endfunction libc_realloc

   function libc_memalign(a, n) result(p) bind(C, name='__libc_memalign')
   !< glibc's `memalign`.
   import :: c_ptr, c_size_t
   implicit none
   integer(c_size_t), value :: a, n !< Alignment, bytes.
   type(c_ptr)              :: p    !< Block.
   endfunction libc_memalign

   function pthread_self() result(t) bind(C, name='pthread_self')
   !< The calling thread.
   import :: c_long
   implicit none
   integer(c_long) :: t !< pthread_t.
   endfunction pthread_self

   function backtrace(buffer, size) result(n) bind(C, name='backtrace')
   !< glibc's `backtrace`.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    intent(inout) :: buffer(*) !< Return addresses.
   integer(c_int), value         :: size      !< Room.
   integer(c_int)                :: n         !< Frames.
   endfunction backtrace

   subroutine backtrace_symbols_fd(buffer, size, fd) bind(C, name='backtrace_symbols_fd')
   !< glibc's `backtrace_symbols_fd`.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    intent(in) :: buffer(*) !< Return addresses.
   integer(c_int), value      :: size      !< Frames.
   integer(c_int), value      :: fd        !< File descriptor.
   endsubroutine backtrace_symbols_fd

   function c_write(fd, buffer, n) result(r) bind(C, name='write')
   !< POSIX `write`.
   import :: c_char, c_int, c_long, c_size_t
   implicit none
   integer(c_int),         value      :: fd        !< File descriptor.
   character(kind=c_char), intent(in) :: buffer(*) !< Bytes.
   integer(c_size_t),      value      :: n         !< Bytes to write.
   integer(c_long)                    :: r         !< Bytes written.
   endfunction c_write
endinterface

contains
   subroutine alloc_arm()
   !< Count the calling thread's allocations from now (the count reset).
   integer(c_int) :: n !< Frames.

   n = backtrace(frames, DEPTH) ! its first call loads the unwinder (allocating): before counting
   counted = 0_int64
   traced = 0_c_int
   owner = pthread_self()
   armed = .true.
   endsubroutine alloc_arm

   subroutine alloc_disarm()
   !< Stop counting.

   armed = .false.
   endsubroutine alloc_disarm

   function alloc_count() result(n)
   !< Allocations counted since the last `alloc_arm`.
   integer(int64) :: n !< Allocations.

   n = counted
   endfunction alloc_count

   subroutine note()
   !< An allocation: counted if armed, on the armed thread; the first ones' stacks printed.
   character(kind=c_char, len=*), parameter :: HEAD = 'figure_test_plot_alloc_counter: an allocation counted' &
                                                      //c_new_line !< A stack's header.
   integer(c_int)                          :: n    !< Frames.
   integer(c_long)                         :: r    !< Bytes written.

   if (.not. armed) return
   if (inside) return
   if (pthread_self() /= owner) return
   counted = counted + 1_int64
   if (traced >= TRACES) return
   inside = .true.
   traced = traced + 1_c_int
   r = c_write(2_c_int, HEAD, len(HEAD, c_size_t))
   n = backtrace(frames, DEPTH)
   call backtrace_symbols_fd(frames, n, 2_c_int)
   inside = .false.
   endsubroutine note

   function hook_malloc(n) result(p) bind(C, name='malloc')
   !< `malloc`.
   integer(c_size_t), value :: n !< Bytes.
   type(c_ptr)              :: p !< Block.

   call note()
   p = libc_malloc(n)
   endfunction hook_malloc

   function hook_calloc(m, n) result(p) bind(C, name='calloc')
   !< `calloc`.
   integer(c_size_t), value :: m, n !< Elements, bytes each.
   type(c_ptr)              :: p    !< Block.

   call note()
   p = libc_calloc(m, n)
   endfunction hook_calloc

   function hook_realloc(q, n) result(p) bind(C, name='realloc')
   !< `realloc`.
   type(c_ptr),       value :: q !< Block.
   integer(c_size_t), value :: n !< Bytes.
   type(c_ptr)              :: p !< Block.

   call note()
   p = libc_realloc(q, n)
   endfunction hook_realloc

   function hook_memalign(a, n) result(p) bind(C, name='memalign')
   !< `memalign`.
   integer(c_size_t), value :: a, n !< Alignment, bytes.
   type(c_ptr)              :: p    !< Block.

   call note()
   p = libc_memalign(a, n)
   endfunction hook_memalign

   function hook_aligned_alloc(a, n) result(p) bind(C, name='aligned_alloc')
   !< `aligned_alloc`.
   integer(c_size_t), value :: a, n !< Alignment, bytes.
   type(c_ptr)              :: p    !< Block.

   call note()
   p = libc_memalign(a, n)
   endfunction hook_aligned_alloc

   function hook_posix_memalign(q, a, n) result(r) bind(C, name='posix_memalign')
   !< `posix_memalign`.
   type(c_ptr),       intent(out) :: q    !< Block.
   integer(c_size_t), value       :: a, n !< Alignment, bytes.
   integer(c_int)                 :: r    !< 0, or ENOMEM.

   call note()
   q = libc_memalign(a, n)
   r = 0_c_int
   if (.not. c_associated(q)) r = ENOMEM
   endfunction hook_posix_memalign
endmodule figure_test_plot_alloc_counter
