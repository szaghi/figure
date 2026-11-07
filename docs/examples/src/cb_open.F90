!< cb_open, cookbook: open a file with the system's dialog, or with FIGURE's browser where there is none (remote mode).
program cb_open
!< cb_open, cookbook: open a file with the system's dialog, or with FIGURE's browser where there is none (remote mode).
!<
!< `cb_open --remote PORT` serves the interface to a web browser, where the program has no window and therefore no
!< system dialog: the same button then opens FIGURE's file browser, which lists the files of the machine the program
!< runs on.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, FIG_OK, ig_begin, ig_button, ig_end, ig_set_next_window, ig_text

implicit none
character(len=*), parameter   :: FILTERS(2) = [character(len=24) :: 'Input files|input;inp', 'All files|*'] !< Types.
type(app_object)              :: app        !< Application.
character(len=:), allocatable :: chosen     !< Path from the dialog.
character(len=:), allocatable :: path       !< The file opened.
character(len=16)             :: arg        !< Command-line argument.
integer(int32)                :: port       !< Port of remote mode.
integer(int32)                :: stat       !< Status of the dialog.
logical                       :: done       !< The dialog was answered.
logical                       :: cancelled  !< ... by Cancel.

path = ''
call get_command_argument(1, arg)
if (trim(arg) == '--remote') then
   call get_command_argument(2, arg)
   read(arg, *) port
   call app%init_remote(port=port, width=800_int32, height=500_int32) ! room for the browser
else
   call app%init('FIGURE: open a file', 800_int32, 500_int32)
endif
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 180.0_real64)
   if (ig_begin('Input file')) then
      !region open
      if (ig_button('Open...')) then
         call app%open_file_dialog('open', FILTERS, stat=stat)
         if (stat /= FIG_OK) call app%open_file_browser('open', FILTERS) ! remote: no system dialog, FIGURE's browser
      endif
      call app%file_dialog_result('open', chosen, done, cancelled, stat=stat) ! either one answers here
      if (done .and. .not. cancelled .and. stat == FIG_OK) path = chosen
      !endregion open
      call ig_text('file: '//path)
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_open
