!< cb_open_browser, cookbook: open a file with FIGURE's file browser, the same in a window and in remote mode.
program cb_open_browser
!< cb_open_browser, cookbook: open a file with FIGURE's file browser, the same in a window and in remote mode.
!<
!< `cb_open_browser [FOLDER]` first writes a folder of example cases (default `figure-cases` in the working directory),
!< with fixed names, sizes and modification times, so that its pictures are the same at every run; then the button
!< opens the browser there.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, FIG_OK, ig_begin, ig_button, ig_end, ig_same_line, ig_set_next_window, ig_text

implicit none
type(app_object)              :: app       !< Application.
character(len=:), allocatable :: chosen    !< Path from the browser.
character(len=:), allocatable :: path      !< The file opened.
character(len=:), allocatable :: saved     !< The file saved.
character(len=512)            :: cases     !< The folder of the example cases.
integer(int32)                :: stat      !< Status of the answer.
logical                       :: done      !< The browser was answered.
logical                       :: cancelled !< ... by Cancel.

call get_command_argument(1, cases)
if (len_trim(cases) == 0) cases = 'figure-cases'
call write_cases(trim(cases))
path = ''
saved = ''
call app%init('FIGURE: open a file', 900_int32, 560_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 880.0_real64, 120.0_real64)
   if (ig_begin('Case')) then
      if (ig_button('Open...')) call app%open_file_browser('open', [character(len=32) :: &
                                                           'Xall files|input;grd;log;dat', 'All files|*'], &
                                                           default_path=trim(cases))
      call ig_same_line()
      if (ig_button('Save as...')) call app%save_file_browser('save', default_path=trim(cases)//'/copy.input')
      call app%file_dialog_result('open', chosen, done, cancelled, stat=stat)
      if (done .and. .not. cancelled .and. stat == FIG_OK) path = chosen
      call app%file_dialog_result('save', chosen, done, cancelled, stat=stat)
      if (done .and. .not. cancelled .and. stat == FIG_OK) saved = chosen
      call ig_text('opened: '//path)
      call ig_text('saved:  '//saved)
   endif
   call ig_end()
enddo
call app%destroy()

contains
   subroutine write_cases(folder)
   !< The example cases: three case folders and five files, sizes fixed, all modified on 2026-10-15 at fixed times
   !< (`touch -t`, POSIX; elsewhere the files keep the time they are written).
   character(len=*), intent(in) :: folder !< Folder.
   integer(int32)               :: ios    !< Status of a command.

   call execute_command_line('mkdir "'//folder//'"', exitstat=ios)
   call execute_command_line('mkdir "'//folder//'/cylinder Re100"', exitstat=ios)
   call execute_command_line('mkdir "'//folder//'/naca0012 '//char(206)//char(177)//'=4'//char(194)//char(176)//'"', &
                             exitstat=ios)                                          ! "naca0012 α=4°": UTF-8 names
   call execute_command_line('mkdir "'//folder//'/sphere"', exitstat=ios)
   call write_file(folder//'/overset.input', 1250_int32, '202610150910')
   call write_file(folder//'/mesh.grd', 3500000_int32, '202610150915')
   call write_file(folder//'/run.log', 18400_int32, '202610151742')
   call write_file(folder//'/forces.dat', 96000_int32, '202610151741')
   call write_file(folder//'/notes.txt', 300_int32, '202610150900')
   call write_file(folder//'/cylinder Re100/overset.input', 1100_int32, '202610141600')
   call execute_command_line('touch -t 202610150905 "'//folder//'"/*/', exitstat=ios)
   endsubroutine write_cases

   subroutine write_file(name, bytes, stamp)
   !< A file of `bytes` bytes, modified at `stamp` (`touch -t` format, CCYYMMDDhhmm, local time).
   character(len=*), intent(in) :: name  !< File.
   integer(int32),   intent(in) :: bytes !< Size [bytes].
   character(len=*), intent(in) :: stamp !< Modification time.
   integer(int32)               :: u     !< Unit.
   integer(int32)               :: ios   !< Status.

   open(newunit=u, file=name, access='stream', form='unformatted', status='replace', iostat=ios)
   if (ios /= 0) return
   write(u) repeat('#', bytes)
   close(u)
   call execute_command_line('touch -t '//stamp//' "'//name//'"', exitstat=ios)
   endsubroutine write_file
endprogram cb_open_browser
