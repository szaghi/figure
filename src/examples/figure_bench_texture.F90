!< figure_bench_texture, benchmark: a new 3840 x 2160 image from Fortran on screen every frame.
program figure_bench_texture
!< figure_bench_texture, benchmark: a new 3840 x 2160 image from Fortran on screen every frame.
!<
!< Each frame: write new pixels into the RGBA array (fill), upload them (`tex%update`), draw the texture scaled into the
!< window and present (`next_frame`, vsync off, lazy redraw off). Prints the mean of each phase and the frame rate over
!< the measured frames (the first ones, warm-up, are not counted). Usage: `figure_bench_texture [frames]`.
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, output_unit, real64
use figure, only : app_object, ig_begin, ig_end, ig_image, ig_set_next_window, texture_object

implicit none
integer(int32), parameter :: W = 3840_int32         !< Image width [pixels].
integer(int32), parameter :: H = 2160_int32         !< Image height [pixels].
integer(int32), parameter :: WARMUP = 20_int32      !< Frames not measured.
type(app_object)          :: app                    !< Application.
type(texture_object)      :: tex                    !< The 4K texture.
integer(int8), allocatable :: rgba(:,:,:)           !< Pixels, rgba(4, W, H).
integer(int32)            :: frames                 !< Measured frames.
integer(int32)            :: frame                  !< Frame counter.
integer(int64)            :: rate                   !< Clock ticks per second.
integer(int64)            :: t0                     !< Clock at a phase start.
integer(int64)            :: t1                     !< Clock at a phase end.
integer(int64)            :: t_start                !< Clock at the first measured frame.
real(real64)              :: fill                   !< Total fill time [s].
real(real64)              :: upload                 !< Total upload time [s].
real(real64)              :: present                !< Total render and present time [s].
character(len=16)         :: arg                    !< Command-line argument.
integer(int32)            :: i                      !< Counter.
integer(int32)            :: j                      !< Counter.

frames = 120_int32
if (command_argument_count() > 0) then
   call get_command_argument(1, arg)
   read(arg, *) frames
endif
allocate(rgba(4, W, H))
rgba = -1_int8
fill = 0.0_real64
upload = 0.0_real64
present = 0.0_real64
call app%init('FIGURE: texture benchmark', 1280_int32, 720_int32, vsync=.false.)
call app%set_lazy(.false.)
call tex%init(W, H)
call system_clock(count_rate=rate)
do frame = 1_int32, WARMUP + frames
   if (frame == WARMUP + 1_int32) then
      fill = 0.0_real64
      upload = 0.0_real64
      present = 0.0_real64
      call system_clock(t_start)
   endif
   call system_clock(t0)
   do j = 1_int32, H                                ! new pixels: a gradient that moves every frame
      do i = 1_int32, W
         rgba(1, i, j) = int(iand(i + frame, 255_int32) - merge(256_int32, 0_int32, iand(i + frame, 255_int32) > 127), int8)
         rgba(2, i, j) = int(iand(j, 127_int32), int8)
      enddo
   enddo
   call system_clock(t1)
   fill = fill + real(t1 - t0, real64) / real(rate, real64)
   call system_clock(t0)
   call tex%update(rgba)
   call system_clock(t1)
   upload = upload + real(t1 - t0, real64) / real(rate, real64)
   call system_clock(t0)
   if (.not. app%next_frame()) exit
   call ig_set_next_window(0.0_real64, 0.0_real64, 1280.0_real64, 720.0_real64, always=.true.)
   if (ig_begin('4K')) call ig_image(tex, 1240.0_real64, 697.5_real64)
   call ig_end()
   call system_clock(t1)
   present = present + real(t1 - t0, real64) / real(rate, real64)
enddo
call system_clock(t1)
write(output_unit, '(A,I0,A,I0,A,I0,A)') 'FIGURE texture benchmark: ', W, ' x ', H, ' RGBA, ', frames, ' frames'
write(output_unit, '(A,F8.2,A)') '  fill    ', 1000.0_real64 * fill / frames, ' ms/frame (write the int8 RGBA array)'
write(output_unit, '(A,F8.2,A)') '  upload  ', 1000.0_real64 * upload / frames, ' ms/frame (tex%update)'
write(output_unit, '(A,F8.2,A)') '  present ', 1000.0_real64 * present / frames, ' ms/frame (next_frame: render, swap)'
write(output_unit, '(A,F8.2,A,F7.1,A)') '  wall    ', 1000.0_real64 * real(t1 - t_start, real64) / real(rate, real64) / frames, &
                                       ' ms/frame, ', real(frames, real64) * real(rate, real64) / real(t1 - t_start, real64), &
                                       ' frames/s'
call tex%destroy()
call app%destroy()
endprogram figure_bench_texture
