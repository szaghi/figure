!< figure_test_remote, remote mode end to end: a WebSocket client clicks a button through the network.
program figure_test_remote
!< figure_test_remote, remote mode end to end: a WebSocket client clicks a button through the network.
!<
!< Serves the UI on a free port (no window, display or GPU), launches scripts/remote_client.py in the background, and
!< draws frames until the client's click arrives (or 30 s pass). The client checks the page, the handshake, every
!< message byte by byte (with a draw list over 65536 vertices: a 100000-point line, until the client presses Z), the
!< resize event, the skipping of unchanged frames and the frame-rate cap; this program checks that the click arrived
!< once, and the client's verdict. Needs python3 (3.11+) on the PATH; run from the repository root, as
!< scripts/run_tests.sh does.
use, intrinsic :: iso_fortran_env, only : error_unit, int32, int64, output_unit, real64
use figure, only : app_object, ig_begin, ig_button, ig_end, ig_item_rect, ig_set_next_window, ip_begin_plot, ip_end_plot, &
                   ip_line
use figure_cimgui, only : igIsKeyDown_Nil
use figure_cimgui_enums, only : ImGuiKey_Z

implicit none
character(len=*), parameter :: CLICK_FILE = 'figure_test_remote.click' !< Where the click point is written.
character(len=*), parameter :: OK_FILE    = 'figure_test_remote.ok'    !< Where the client writes its verdict.
type(app_object)            :: app                                      !< Application.
integer(int32)              :: port                                     !< Port the server listens on.
integer(int32)              :: clicks                                   !< Button clicks seen.
integer(int32)              :: frames                                   !< Frames drawn.
integer(int32)              :: unit                                     !< File unit.
integer(int32)              :: stat                                     !< Status.
integer(int64)              :: rate                                     !< Clock ticks per second.
integer(int64)              :: t0                                       !< Clock at the start.
integer(int64)              :: t                                        !< Clock now.
real(real64)                :: x0                                       !< Button rectangle, left [pixels].
real(real64)                :: y0                                       !< Button rectangle, top [pixels].
real(real64)                :: x1                                       !< Button rectangle, right [pixels].
real(real64)                :: y1                                       !< Button rectangle, bottom [pixels].
logical                     :: written                                  !< The click point is written.
logical                     :: exists                                   !< A file exists.
logical                     :: test_passed(3)                           !< Per-check outcome.
character(len=256)          :: verdict                                  !< The client's verdict.
character(len=512)          :: command                                  !< Command launching the client.
character(len=16)           :: os                                       !< The OS environment variable (Windows_NT).
real(real64)                :: lx(100000)                               !< A long line (over 65536 vertices): abscissae.
real(real64)                :: ly(100000)                               !< Its ordinates.
integer(int32)              :: i                                        !< Counter.
character(len=128)          :: url                                      !< The address to open, with the token.
character(len=64)           :: token                                    !< The access token.
logical                     :: long_shown                               !< The long line is drawn (until Z is down).

call remove_file(CLICK_FILE)
call remove_file(OK_FILE)
lx = [(real(i, real64), i = 1_int32, size(lx))]
ly = sin(0.01_real64 * lx)
long_shown = .true.
clicks = 0_int32
frames = 0_int32
written = .false.
test_passed = .false.
verdict = 'no verdict'
call app%init_remote(port=0_int32, port_used=port, quiet=.true., compress='always', url=url, stat=stat) ! deflate all
token = url(index(url, '?token=') + 7:)                                 ! the random token, 32 hex digits
test_passed(1) = stat == 0_int32 .and. port > 0_int32 .and. len_trim(token) == 32 .and. verify(trim(token), '0123456789abcdef') == 0
if (test_passed(1)) then
   call get_environment_variable('OS', os)
   if (trim(os) == 'Windows_NT') then ! cmd.exe: start /b runs the client without waiting for it
      write(command, '(A,I0,A)') 'start "" /b python3 scripts/remote_client.py ', port, ' '//CLICK_FILE//' '//OK_FILE//' '// &
                                 trim(token)
   else ! sh: & runs it in the background
      write(command, '(A,I0,A)') 'python3 scripts/remote_client.py ', port, ' '//CLICK_FILE//' '//OK_FILE//' '// &
                                 trim(token)//' &'
   endif
   call execute_command_line(trim(command), wait=.true.)
   call system_clock(t0, rate)
   do while (app%next_frame())
      frames = frames + 1_int32
      call ig_set_next_window(20.0_real64, 20.0_real64, 300.0_real64, 120.0_real64, always=.true.)
      if (ig_begin('Remote')) then
         if (ig_button('Hit me through the network')) clicks = clicks + 1_int32
         call ig_item_rect(x0, y0, x1, y1)
      endif
      call ig_end()
      if (igIsKeyDown_Nil(ImGuiKey_Z)) long_shown = .false. ! the client has seen it: small frames from now on
      if (long_shown) then
         call ig_set_next_window(340.0_real64, 20.0_real64, 280.0_real64, 220.0_real64, always=.true.)
         if (ig_begin('Long line')) then ! one draw list over 65536 vertices: indices relative to each command's offset
            if (ip_begin_plot('long', height=-1.0_real64)) then
               call ip_line('y', lx, ly)
               call ip_end_plot()
            endif
         endif
         call ig_end()
      endif
      if (.not. written .and. frames > 3_int32) then ! the layout has settled: tell the client where to click
         open(newunit=unit, file=CLICK_FILE, action='write', status='replace')
         write(unit, '(F0.1,1X,F0.1)') 0.5_real64 * (x0 + x1), 0.5_real64 * (y0 + y1)
         close(unit)
         written = .true.
      endif
      call system_clock(t)
      if (clicks > 0_int32 .or. real(t - t0, real64) / real(rate, real64) > 30.0_real64) exit
   enddo
   call app%destroy() ! closes the connection: the client finishes and writes its verdict
   call system_clock(t0)
   do ! wait for the verdict, at most 10 s
      inquire(file=OK_FILE, exist=exists)
      call system_clock(t)
      if (exists .or. real(t - t0, real64) / real(rate, real64) > 10.0_real64) exit
   enddo
   if (exists) then ! written atomically by the client (rename), so complete once it exists
      verdict = 'unreadable verdict file'
      call system_clock(t0)
      do ! Windows may still hold the file just after the rename: retry the open for up to 5 s
         open(newunit=unit, file=OK_FILE, action='read', status='old', iostat=stat)
         if (stat == 0_int32) then
            read(unit, '(A)', iostat=stat) verdict
            if (stat /= 0_int32) verdict = 'unreadable verdict file'
            close(unit)
            exit
         endif
         call system_clock(t)
         if (real(t - t0, real64) / real(rate, real64) > 5.0_real64) exit
      enddo
   endif
endif
test_passed(2) = clicks == 1_int32         ! the network click reached the button, once
test_passed(3) = trim(verdict) == 'ok'     ! the client's protocol checks passed
call remove_file(CLICK_FILE)
call remove_file(OK_FILE)

write(output_unit, '(A,3L2)') 'figure_test_remote checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) then
   write(error_unit, '(A,I0,A,I0,A,I0,A)') 'port ', port, ', frames ', frames, ', clicks ', clicks, &
                                          ', client: '//trim(verdict)
   error stop 1
endif

contains
   subroutine remove_file(name)
   !< Delete a file if it exists.
   character(len=*), intent(in) :: name   !< File name.
   integer(int32)               :: u      !< File unit.
   logical                      :: exists !< The file exists.

   inquire(file=name, exist=exists)
   if (exists) then
      open(newunit=u, file=name, status='old')
      close(u, status='delete')
   endif
   endsubroutine remove_file
endprogram figure_test_remote
