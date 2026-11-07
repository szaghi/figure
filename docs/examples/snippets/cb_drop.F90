!< cb_drop, cookbook: open what the user drops on the window, told apart by the pane it lands on; copy a path.
program cb_drop
!< cb_drop, cookbook: open what the user drops on the window, told apart by the pane it lands on; copy a path.
!<
!< A case folder dropped on the left pane becomes the case; files dropped on the right pane are added to its list. The
!< program shows the paths only (it opens nothing), so its pictures depend on no file of the machine.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ICON_COPY, ICON_FILE, ICON_FOLDER, ig_begin, ig_begin_child, ig_begin_disabled, &
                   ig_button, ig_end, ig_end_child, ig_end_disabled, ig_item_rect, ig_same_line, ig_set_clipboard, &
                   ig_set_next_window, ig_text, ig_text_disabled

implicit none
integer(int32), parameter     :: MAX_FILES = 8_int32 !< Files kept.
type(app_object)              :: app                 !< Application.
character(len=:), allocatable :: paths(:)            !< Paths dropped this frame.
character(len=:), allocatable :: case_dir            !< The case folder.
character(len=256)            :: files(MAX_FILES)    !< The files dropped.
integer(int32)                :: nfiles              !< Files kept.
integer(int32)                :: k                   !< Counter.
real(real64)                  :: x, y                !< Point of the drop [pixels].
real(real64)                  :: case_rect(4)        !< The case pane, last frame: xmin, ymin, xmax, ymax.
real(real64)                  :: files_rect(4)       !< The files pane, last frame.
logical                       :: copied              !< The case path was copied.

case_dir = ''
nfiles = 0_int32
case_rect = 0.0_real64
files_rect = 0.0_real64
copied = .false.
call app%init('FIGURE: open what the user drops', 760_int32, 300_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 740.0_real64, 280.0_real64)
   if (ig_begin('Drop files here')) then
      if (app%dropped(paths, x, y)) then              ! this frame only; the panes' rectangles are the last frame's
         if (inside(case_rect, x, y)) then
            case_dir = trim(paths(1))                 ! the case: the first path dropped on its pane
            copied = .false.
         elseif (inside(files_rect, x, y)) then
            do k = 1_int32, size(paths, kind=int32)   ! the files: every path dropped on theirs
               if (nfiles == MAX_FILES) exit
               nfiles = nfiles + 1_int32
               files(nfiles) = paths(k)
            enddo
         endif
      endif
      if (ig_begin_child('case', width=340.0_real64, height=-40.0_real64, border=.true.)) then
         call ig_text(ICON_FOLDER//' Case')
         if (len(case_dir) == 0) then
            call ig_text_disabled('drop a case folder here')
         else
            call ig_text(case_dir)
         endif
      endif
      call ig_end_child()
      call ig_item_rect(case_rect(1), case_rect(2), case_rect(3), case_rect(4))
      call ig_same_line()
      if (ig_begin_child('files', height=-40.0_real64, border=.true.)) then
         call ig_text(ICON_FILE//' Files')
         if (nfiles == 0_int32) call ig_text_disabled('drop files here')
         do k = 1_int32, nfiles
            call ig_text(trim(files(k)))
         enddo
      endif
      call ig_end_child()
      call ig_item_rect(files_rect(1), files_rect(2), files_rect(3), files_rect(4))
      call ig_begin_disabled(len(case_dir) == 0)
      if (ig_button(ICON_COPY//' Copy the case path')) then
         call ig_set_clipboard(case_dir)              ! pasted elsewhere with ctrl+v
         copied = .true.
      endif
      call ig_end_disabled()
      if (copied) then
         call ig_same_line()
         call ig_text('copied: '//case_dir)
      endif
   endif
   call ig_end()
enddo
call app%destroy()

contains
   pure function inside(rect, x, y) result(is_inside)
   !< The point (x, y) is inside the rectangle `rect` (xmin, ymin, xmax, ymax).
   real(real64), intent(in) :: rect(4)   !< Rectangle [pixels].
   real(real64), intent(in) :: x         !< Abscissa [pixels].
   real(real64), intent(in) :: y         !< Ordinate [pixels].
   logical                  :: is_inside !< Inside.

   is_inside = x >= rect(1) .and. x <= rect(3) .and. y >= rect(2) .and. y <= rect(4)
   endfunction inside
endprogram cb_drop
