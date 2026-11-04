!> Benchmark (for FIGURE's comparison): a new 3840 x 2160 image from Fortran on screen every frame, with wxFortran.
!> Same loop as FIGURE's figure_bench_texture: fill the rgb array, hand it to the toolkit (wx_bitmap), draw it scaled
!> into a 1280 x 720 window. A repeating timer drives the frames; the paint handler draws and counts.
program wx_bench
    use wx
    use iso_c_binding, only: c_double
    use iso_fortran_env, only: int64, real64, output_unit
    implicit none
    integer, parameter :: w = 3840, h = 2160, warmup = 20
    type :: bench_t
        type(wx_app) :: app
        type(wx_frame) :: frame
        type(wx_canvas) :: canvas
        type(wx_timer) :: timer
        type(wx_bitmap) :: image
        integer, allocatable :: rgb(:,:,:)
        integer :: frame_no = 0, frames = 120, painted = 0
        integer(int64) :: rate = 0, t_start = 0
        real(real64) :: fill = 0, convert = 0, paint = 0
        logical :: pending = .false.
    end type bench_t
    type(bench_t), target :: s
    character(len=16) :: arg

    if (command_argument_count() > 0) then
        call get_command_argument(1, arg)
        read(arg, *) s%frames
    end if
    allocate(s%rgb(3, w, h))
    s%rgb = 255
    call system_clock(count_rate=s%rate)
    s%app = wx_app()
    s%frame = wx_frame('wxFortran: texture benchmark', width=1280, height=720)
    s%canvas = wx_canvas(s%frame)
    call s%canvas%bind(wxEVT_PAINT, on_paint, data=s)
    s%timer = wx_timer(owner=s%frame)
    call s%timer%bind(wxEVT_TIMER, on_tick, data=s)
    call s%frame%show()
    call s%timer%start(1)
    stop s%app%run()

contains

    subroutine on_tick(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        integer(int64) :: t0, t1
        integer :: i, j
        select type (s => data)
        type is (bench_t)
            if (s%pending) return                       ! one new image per painted frame
            s%frame_no = s%frame_no + 1
            if (s%frame_no == warmup + 1) then
                s%fill = 0; s%convert = 0; s%paint = 0; s%painted = 0
                call system_clock(s%t_start)
            end if
            call system_clock(t0)
            do j = 1, h
                do i = 1, w
                    s%rgb(1, i, j) = iand(i + s%frame_no, 255)
                    s%rgb(2, i, j) = iand(j, 127)
                end do
            end do
            call system_clock(t1)
            s%fill = s%fill + real(t1 - t0, real64) / s%rate
            call system_clock(t0)
            if (s%image%is_valid()) call s%image%destroy()
            s%image = wx_bitmap(s%rgb)
            call system_clock(t1)
            s%convert = s%convert + real(t1 - t0, real64) / s%rate
            s%pending = .true.
            call s%canvas%refresh()
        end select
    end subroutine on_tick

    subroutine on_paint(event, data)
        type(wx_event), intent(inout) :: event
        class(*), intent(inout), optional :: data
        type(wx_graphics) :: g
        integer(int64) :: t0, t1
        select type (s => data)
        type is (bench_t)
            call system_clock(t0)
            g = wx_graphics(event)
            if (s%image%is_valid()) call g%draw_bitmap(s%image, 20.0_real64, 11.25_real64, 1240.0_real64, 697.5_real64, &
                                                      smooth=.false.)
            call system_clock(t1)
            if (.not. s%pending) return
            s%pending = .false.
            s%paint = s%paint + real(t1 - t0, real64) / s%rate
            if (s%frame_no > warmup) s%painted = s%painted + 1
            if (s%painted == s%frames) then
                call system_clock(t1)
                call s%timer%stop()
                write(output_unit, '(A,I0,A,I0,A,I0,A)') 'wxFortran texture benchmark: ', w, ' x ', h, ' RGB, ', &
                    s%frames, ' frames'
                write(output_unit, '(A,F8.2,A)') '  fill    ', 1000 * s%fill / s%frames, ' ms/frame (write the rgb array)'
                write(output_unit, '(A,F8.2,A)') '  convert ', 1000 * s%convert / s%frames, ' ms/frame (wx_bitmap(rgb))'
                write(output_unit, '(A,F8.2,A)') '  paint   ', 1000 * s%paint / s%frames, ' ms/frame (draw_bitmap)'
                write(output_unit, '(A,F8.2,A,F7.1,A)') '  wall    ', &
                    1000 * real(t1 - s%t_start, real64) / s%rate / s%frames, ' ms/frame, ', &
                    s%frames * real(s%rate, real64) / real(t1 - s%t_start, real64), ' frames/s'
                flush(output_unit)
                if (s%frame%close()) continue
            end if
        end select
    end subroutine on_paint

end program wx_bench
