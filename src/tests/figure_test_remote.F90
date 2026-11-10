!< figure_test_remote, remote mode end to end: a WebSocket client clicks a button through the network.
program figure_test_remote
!< figure_test_remote, remote mode end to end: a WebSocket client clicks a button through the network.
!<
!< Serves the UI on a free port (no window, display or GPU), launches scripts/remote_client.py in the background, and
!< draws frames until the client's click arrives (or 30 s pass). The client checks the page, the handshake, every
!< message byte by byte (with a draw list over 65536 vertices: a 100000-point line, until the client presses Z), the
!< resize event, the skipping of unchanged frames and the frame-rate cap, the clipboard message, and an image updated
!< in consecutive frames (12 frames, once the client holds A down) arriving as JPEG, then exact once it stops; this
!< program checks that the click arrived once, that the browser's paste reached its clipboard (it answers with a copy,
!< which the client checks), and the client's verdict. Needs python3 (3.11+) on the PATH; run from the repository
!< root, as scripts/run_tests.sh does.
use, intrinsic :: iso_fortran_env, only : error_unit, int8, int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_button, ig_end, ig_get_clipboard, ig_image, ig_item_rect, ig_set_clipboard, &
                   ig_set_next_window, ip_begin_plot, ip_end_plot, ip_line, texture_object, figure_time
use figure_cimgui, only : igIsKeyDown_Nil
use figure_cimgui_enums, only : ImGuiKey_A, ImGuiKey_Z

implicit none
character(len=*), parameter :: CLICK_FILE = 'figure_test_remote.click' !< Where the click point is written.
character(len=*), parameter :: OK_FILE    = 'figure_test_remote.ok'    !< Where the client writes its verdict.
type(app_object)            :: app                                      !< Application.
integer(int32)              :: port                                     !< Port the server listens on.
integer(int32)              :: clicks                                   !< Button clicks seen.
integer(int32)              :: frames                                   !< Frames drawn.
integer(int32)              :: unit                                     !< File unit.
integer(int32)              :: stat                                     !< Status.
real(real64)                :: t0                                       !< figure_time at the start [s].
real(real64)                :: t                                        !< figure_time now [s].
real(real64)                :: x0                                       !< Button rectangle, left [pixels].
real(real64)                :: y0                                       !< Button rectangle, top [pixels].
real(real64)                :: x1                                       !< Button rectangle, right [pixels].
real(real64)                :: y1                                       !< Button rectangle, bottom [pixels].
logical                     :: written                                  !< The click point is written.
logical                     :: exists                                   !< A file exists.
logical                     :: test_passed(4)                           !< Per-check outcome.
logical                     :: pasted                                   !< The browser's paste reached the clipboard.
character(len=*), parameter :: PASTE = 'pasted in the browser '//char(195)//char(169) !< As scripts/remote_client.py.
character(len=256)          :: verdict                                  !< The client's verdict.
character(len=512)          :: command                                  !< Command launching the client.
character(len=16)           :: os                                       !< The OS environment variable (Windows_NT).
real(real64)                :: lx(100000)                               !< A long line (over 65536 vertices): abscissae.
real(real64)                :: ly(100000)                               !< Its ordinates.
integer(int32)              :: i                                        !< Counter.
character(len=128)          :: url                                      !< The address to open, with the token.
character(len=64)           :: token                                    !< The access token.
logical                     :: long_shown                               !< The long line is drawn (until Z is down).
integer(int32), parameter   :: TW = 64_int32                            !< The changing image's width [pixels].
integer(int32), parameter   :: TH = 48_int32                            !< Its height [pixels].
type(texture_object)        :: tex                                      !< An image updated in consecutive frames.
integer(int8), target       :: rgba(4, TW, TH)                          !< Its pixels (opaque).
integer(int32)              :: moves                                    !< Frames of change left (-1: not started).
logical                     :: asked                                    !< The client asked for the change (A down).
integer(int32)              :: j                                        !< Counter.

call remove_file(CLICK_FILE)
call remove_file(OK_FILE)
lx = [(real(i, real64), i = 1_int32, size(lx))]
ly = sin(0.01_real64 * lx)
long_shown = .true.
pasted = .false.
clicks = 0_int32
frames = 0_int32
written = .false.
test_passed = .false.
verdict = 'no verdict'
call app%init_remote(port=0_int32, port_used=port, quiet=.true., compress='always', url=url, stat=stat) ! deflate all
token = url(index(url, '?token=') + 7:)                                 ! the random token, 32 hex digits
test_passed(1) = stat == 0_int32 .and. port > 0_int32 .and. len_trim(token) == 32 .and. verify(trim(token), '0123456789abcdef') == 0
moves = -1_int32
asked = .false.
if (test_passed(1)) then
   call tex%init(TW, TH, smooth=.true.)
   call paint(0_int32)
   call tex%update(rgba) ! once: sent exact
   call get_environment_variable('OS', os)
   if (trim(os) == 'Windows_NT') then ! cmd.exe: start /b runs the client without waiting for it
      write(command, '(A,I0,A)') 'start "" /b python3 scripts/remote_client.py ', port, ' '//CLICK_FILE//' '//OK_FILE//' '// &
                                 trim(token)
   else ! sh: & runs it in the background
      write(command, '(A,I0,A)') 'python3 scripts/remote_client.py ', port, ' '//CLICK_FILE//' '//OK_FILE//' '// &
                                 trim(token)//' &'
   endif
   call execute_command_line(trim(command), wait=.true.)
   t0 = figure_time()
   do while (app%next_frame())
      frames = frames + 1_int32
      call ig_set_next_window(20.0_real64, 20.0_real64, 300.0_real64, 120.0_real64, always=.true.)
      if (ig_begin('Remote')) then
         if (ig_button('Hit me through the network')) clicks = clicks + 1_int32
         call ig_item_rect(x0, y0, x1, y1)
      endif
      call ig_end()
      if (.not. pasted) then ! the client's paste: answered with a copy, which goes back to the page
         if (ig_get_clipboard() == PASTE) then
            pasted = .true.
            call ig_set_clipboard('copied on the server')
         endif
      endif
      if (igIsKeyDown_Nil(ImGuiKey_Z)) long_shown = .false. ! the client has seen it: small frames from now on
      if (igIsKeyDown_Nil(ImGuiKey_A)) asked = .true. ! the client asks for a changing image
      if (moves < 0_int32 .and. asked .and. frames >= 4_int32) moves = 12_int32 ! not next to its first update (frame 1)
      if (moves > 0_int32) then ! updated in 12 consecutive frames: JPEG from the second; exact once it stops
         call paint(moves)
         call tex%update(rgba)
         moves = moves - 1_int32
         call app%request_frames(2_int32)
      endif
      call ig_set_next_window(20.0_real64, 160.0_real64, 120.0_real64, 100.0_real64, always=.true.)
      if (ig_begin('Image')) call ig_image(tex)
      call ig_end()
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
      t = figure_time()
      if (clicks > 0_int32 .or. t - t0 > 30.0_real64) exit
   enddo
   call tex%destroy()
   call app%destroy() ! closes the connection: the client finishes and writes its verdict
   t0 = figure_time()
   do ! wait for the verdict, at most 10 s
      inquire(file=OK_FILE, exist=exists)
      t = figure_time()
      if (exists .or. t - t0 > 10.0_real64) exit
   enddo
   if (exists) then ! written atomically by the client (rename), so complete once it exists
      verdict = 'unreadable verdict file'
      t0 = figure_time()
      do ! Windows may still hold the file just after the rename: retry the open for up to 5 s
         open(newunit=unit, file=OK_FILE, action='read', status='old', iostat=stat)
         if (stat == 0_int32) then
            read(unit, '(A)', iostat=stat) verdict
            if (stat /= 0_int32) verdict = 'unreadable verdict file'
            close(unit)
            exit
         endif
         t = figure_time()
         if (t - t0 > 5.0_real64) exit
      enddo
   endif
endif
test_passed(2) = clicks == 1_int32         ! the network click reached the button, once
test_passed(3) = trim(verdict) == 'ok'     ! the client's protocol checks passed
test_passed(4) = pasted                    ! the browser's paste reached the program's clipboard
call remove_file(CLICK_FILE)
call remove_file(OK_FILE)

write(output_unit, '(A,4L2)') 'figure_test_remote checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) then
   write(error_unit, '(A,I0,A,I0,A,I0,A)') 'port ', port, ', frames ', frames, ', clicks ', clicks, &
                                          ', client: '//trim(verdict)
   error stop 1
endif

contains
   subroutine paint(step)
   !< The image's pixels at a step of its change: a diagonal gradient moving with `step`, opaque.
   integer(int32), intent(in) :: step !< Step.

   do j = 1_int32, TH
      do i = 1_int32, TW
         rgba(1, i, j) = int(mod(4 * (i + j) + 16 * step, 256) - 128, int8)
         rgba(2, i, j) = int(mod(5 * j + 9 * step, 256) - 128, int8)
         rgba(3, i, j) = int(mod(3 * i, 256) - 128, int8)
         rgba(4, i, j) = -1_int8
      enddo
   enddo
   endsubroutine paint

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
