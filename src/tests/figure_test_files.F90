!< figure_test_files, FIGURE's file browser, headless, on a folder the test writes.
program figure_test_files
!< figure_test_files, FIGURE's file browser, headless, on a folder the test writes.
!<
!< The folder `figure_test_files.tmp` (removed first and at the end) holds three files of known sizes, one with a
!< space in its name, a hidden one, and four folders. Each browser is driven as a user would, by clicks, keys and
!< typed text (`figure_testing`), and its state read with `test_file_browser`:
!<
!< - the entries listed, folders first, by name; sorted by size after a click on the header; hidden files shown on
!<   request;
!< - Cancel and Escape reported as cancelled through `app%file_dialog_result`;
!< - a filter hides files, the other filter of the list shows them;
!< - a folder entered by a double-click and left by the parent button; a recent folder (from a settings file written
!<   by the test) offered among the places and entered;
!< - a file chosen by a double-click and returned through `file_dialog_result` (a name with a space), its folder kept
!<   as the most recent in the settings file;
!< - a folder chosen in folder mode;
!< - a save over an existing file asks first: kept, then replaced;
!< - a new folder with a non-ASCII name, entered, and a non-ASCII file name typed and returned;
!< - the path field completed by Tab and entered by Enter;
!< - a folder that vanished, and (POSIX) one that cannot be read, reported in the browser;
!< - an id already open, a malformed filter and a browser before `init*` refused.
use, intrinsic :: iso_c_binding, only : c_char, c_int, c_null_char
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit, error_unit
use figure, only : app_object, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK
use figure_testing, only : test_click, test_file_browser, test_file_browser_rect, test_key, test_settings_file, &
                           test_type

implicit none
interface
#ifdef _WIN32
   function c_mkdir(path) result(r) bind(C, name='_mkdir')
   !< Make a folder (MSVCRT).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*) !< Folder, NUL-terminated.
   integer(c_int)                     :: r       !< 0 on success.
   endfunction c_mkdir

   function c_rmdir(path) result(r) bind(C, name='_rmdir')
   !< Remove an empty folder (MSVCRT).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*) !< Folder, NUL-terminated.
   integer(c_int)                     :: r       !< 0 on success.
   endfunction c_rmdir
#else
   function c_mkdir(path, mode) result(r) bind(C, name='mkdir')
   !< Make a folder (POSIX).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*) !< Folder, NUL-terminated.
   integer(c_int), value              :: mode    !< Permissions.
   integer(c_int)                     :: r       !< 0 on success.
   endfunction c_mkdir

   function c_rmdir(path) result(r) bind(C, name='rmdir')
   !< Remove an empty folder (POSIX).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*) !< Folder, NUL-terminated.
   integer(c_int)                     :: r       !< 0 on success.
   endfunction c_rmdir

   function c_chmod(path, mode) result(r) bind(C, name='chmod')
   !< Change a file's permissions (POSIX).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*) !< File, NUL-terminated.
   integer(c_int), value              :: mode    !< Permissions.
   integer(c_int)                     :: r       !< 0 on success.
   endfunction c_chmod

   function c_access(path, mode) result(r) bind(C, name='access')
   !< Whether the process may access a file (POSIX).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*) !< File, NUL-terminated.
   integer(c_int), value              :: mode    !< 4: read.
   integer(c_int)                     :: r       !< 0: allowed.
   endfunction c_access
#endif
endinterface

character(len=*), parameter   :: BASE = 'figure_test_files.tmp'           !< The folder written.
character(len=*), parameter   :: SETTINGS = 'figure_test_files.settings.ini' !< The settings file of the test.
character(len=*), parameter   :: RESUME = 'R'//char(195)//char(169)//'sum'//char(195)//char(169)//' '// &
                                          char(195)//char(188)            !< "Résumé ü" (UTF-8).
character(len=*), parameter   :: NAIVE = 'na'//char(195)//char(175)//'ve file.inp' !< "naïve file.inp" (UTF-8).
type(app_object)              :: app                 !< Application (headless).
logical                       :: test_passed(17)     !< Per-check outcome.
logical                       :: answered            !< The browser was answered (polled every frame).
logical                       :: was_cancelled       !< ... by a cancel.
character(len=:), allocatable :: answer              !< ... with this path.
character(len=:), allocatable :: base_abs            !< The folder written, absolute, as the browser gives it.
character(len=:), allocatable :: alpha_abs           !< Its folder alpha.
character(len=1)              :: sep                 !< The platform's separator, as the browser writes paths.
character(len=:), allocatable :: folder, err, field  !< Browser state.
character(len=:), allocatable :: entries(:), recent(:) !< Browser lists.
logical                       :: shown, asking, ok   !< Browser state, outcomes.
integer(int32)                :: stat(4)             !< Statuses.
integer(int32)                :: k                   !< Counter.

test_passed = .false.
call app%open_file_browser('early', stat=stat(1))                     ! before init: refused
call cleanup()
call make_tree()
call test_settings_file(SETTINGS)
call app%init_headless(1000_int32, 700_int32)
call frames(3)

! 1-4: listed and sorted, by size, hidden files, cancel
call app%open_file_browser('f', default_path=BASE)
call frames(3)
call test_file_browser(shown, folder=folder, entries=entries)
base_abs = folder
sep = '/'
if (index(base_abs, '\') > 0) sep = '\'
alpha_abs = base_abs//sep//'alpha'
#ifdef _WIN32
test_passed(1) = shown .and. same(entries, [character(len=16) :: 'alpha/', 'gone/', 'sub folder/', 'a.inp', 'b.dat', &
                                            'my case.inp'])
#else
test_passed(1) = shown .and. same(entries, [character(len=16) :: 'alpha/', 'gone/', 'locked/', 'sub folder/', 'a.inp', &
                                            'b.dat', 'my case.inp'])
#endif
call click('sort:size')
call test_file_browser(shown, entries=entries)
k = size(entries, kind=int32)                                          ! by size, folders still first
if (k >= 4_int32) test_passed(2) = entries(1) == 'alpha/' .and. entries(k - 2) == 'my case.inp' .and. &
                                   entries(k - 1) == 'b.dat' .and. entries(k) == 'a.inp'
call click('hidden')
call test_file_browser(shown, entries=entries)
test_passed(3) = any(entries == '.hidden.inp')
call click('cancel')
test_passed(4) = answered .and. was_cancelled .and. answer == ''
call test_file_browser(shown)
test_passed(4) = test_passed(4) .and. .not. shown

! 5: a filter hides files; the list's other filter shows them; 17: a recent folder from the settings file, entered
call write_settings(alpha_abs)
call close_any()
call app%open_file_browser('f', filters=[character(len=24) :: 'Input files|inp', 'All files|*'], default_path=BASE)
call frames(3)
call test_file_browser(shown, entries=entries, recent=recent)
test_passed(5) = .not. any(entries == 'b.dat') .and. any(entries == 'a.inp')
call click('filter')
call click('filter:2')
call test_file_browser(shown, entries=entries)
test_passed(5) = test_passed(5) .and. any(entries == 'b.dat')
test_passed(17) = size(recent) == 1
if (test_passed(17)) test_passed(17) = recent(1) == alpha_abs
call click('place:recent:1')
call test_file_browser(shown, folder=folder)
test_passed(17) = test_passed(17) .and. folder == alpha_abs

! 6: a folder entered by a double-click, left by the parent button; 7, 8: a file chosen, its folder the most recent
call click('parent')
call double_click('entry:sub folder')
call test_file_browser(shown, folder=folder, entries=entries)
test_passed(6) = folder == base_abs//sep//'sub folder' .and. same(entries, [character(len=8) :: 'deep.inp'])
call click('parent')
call test_file_browser(shown, folder=folder)
test_passed(6) = test_passed(6) .and. folder == base_abs
call double_click('entry:my case.inp')
test_passed(7) = answered .and. .not. was_cancelled .and. answer == base_abs//sep//'my case.inp'
call test_file_browser(shown, recent=recent)
test_passed(8) = .not. shown .and. size(recent) == 2
if (test_passed(8)) test_passed(8) = recent(1) == base_abs .and. recent(2) == alpha_abs .and. &
                                     settings_has('recent = '//base_abs) .and. settings_has('recent = '//alpha_abs)

! 9: a folder chosen in folder mode
call close_any()
call app%open_file_browser('f', default_path=BASE, folders=.true.)
call frames(3)
call click('entry:alpha')
call click('ok')
test_passed(9) = answered .and. answer == alpha_abs

! 10: a save over an existing file asks first: kept, then replaced
call close_any()
call app%save_file_browser('f', default_path=BASE)
call frames(3)
call click('name')
call test_type('a.inp')
call test_key('enter')
call frames(4)
call test_file_browser(shown, asking=asking)
test_passed(10) = shown .and. asking .and. .not. answered
call click('keep')
call test_file_browser(shown, asking=asking)
test_passed(10) = test_passed(10) .and. shown .and. .not. asking .and. .not. answered
call click('ok')
call click('replace')
test_passed(10) = test_passed(10) .and. answered .and. answer == base_abs//sep//'a.inp'

! 11: a new folder with a non-ASCII name, entered; a non-ASCII file name typed and returned
call close_any()
call app%save_file_browser('f', default_path=BASE)
call frames(3)
call click('new folder')
call click('new folder name')
call test_type(RESUME)
call click('create')
call test_file_browser(shown, entries=entries)
test_passed(11) = any(entries == RESUME//'/')
call double_click('entry:'//RESUME)
call test_file_browser(shown, folder=folder)
test_passed(11) = test_passed(11) .and. folder == base_abs//sep//RESUME
call click('name')
call test_type(NAIVE)
call test_key('enter')
call frames(4)
test_passed(11) = test_passed(11) .and. answered .and. answer == base_abs//sep//RESUME//sep//NAIVE

! 12: the path field completed by Tab, entered by Enter
call close_any()
call app%open_file_browser('f', default_path=BASE)
call frames(3)
call click('path')
call test_key('end')
call test_type(sep//'su')
call test_key('tab')
call frames(4)
call test_file_browser(shown, path_field=field)
test_passed(12) = field == base_abs//sep//'sub folder'//sep
call test_key('enter')
call frames(4)
call test_file_browser(shown, folder=folder)
test_passed(12) = test_passed(12) .and. folder == base_abs//sep//'sub folder'

! 13, 14: a folder that vanished reported (Refresh); Escape cancels
call click('parent')
call double_click('entry:gone')
call test_file_browser(shown, folder=folder, error=err)
test_passed(13) = folder == base_abs//sep//'gone' .and. err == ''
k = c_rmdir(BASE//'/gone'//c_null_char)
call click('refresh')
call test_file_browser(shown, entries=entries, error=err)
test_passed(13) = test_passed(13) .and. index(err, 'gone') > 0 .and. size(entries) == 0
call test_key('escape')
call frames(4)
test_passed(14) = answered .and. was_cancelled

! 15: a folder that cannot be read reported (POSIX; skipped when permissions do not stop this process: root)
#ifdef _WIN32
test_passed(15) = .true.
#else
call close_any()
call app%open_file_browser('f', default_path=BASE)
call frames(3)
k = c_chmod(BASE//'/locked'//c_null_char, 0_c_int)
call double_click('entry:locked')
call test_file_browser(shown, folder=folder, error=err)
if (c_access(BASE//'/locked'//c_null_char, 4_c_int) == 0_c_int) then
   write(output_unit, '(A)') 'figure_test_files: permissions do not apply to this process; check 15 skipped'
   test_passed(15) = .true.
else
   test_passed(15) = folder == base_abs//sep//'locked' .and. index(err, 'locked') > 0
endif
k = c_chmod(BASE//'/locked'//c_null_char, int(o'755', c_int))
call click('cancel')
#endif

! 16: refusals: before init, an id open twice, a malformed filter
call close_any()
call app%open_file_browser('twice', default_path=BASE)
call app%open_file_browser('twice', default_path=BASE, stat=stat(2))
call app%save_file_browser('other', filters=[character(len=8) :: 'no bar'], stat=stat(3))
call frames(2)
call click('cancel')
call app%file_dialog_result('twice', answer, ok, was_cancelled, stat=stat(4))
test_passed(16) = stat(1) == FIG_ERR_STATE .and. stat(2) == FIG_ERR_STATE .and. stat(3) == FIG_ERR_ARGUMENT .and. &
                  stat(4) == FIG_OK .and. ok .and. was_cancelled ! the first 'twice' answered (cancelled)

call app%destroy()
call cleanup()
do k = 1_int32, size(test_passed, kind=int32)
   if (.not. test_passed(k)) write(error_unit, '(A,I0,A)') 'figure_test_files: check ', k, ' failed'
enddo
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine frames(n)
   !< Draw n frames; the answer to the browser 'f' is polled every frame, as a program does.
   integer(int32), intent(in)    :: n    !< Frames.
   character(len=:), allocatable :: path !< Answer.
   logical                       :: done, cancelled !< Answer state.
   integer(int32)                :: i    !< Counter.

   do i = 1_int32, n
      if (.not. app%next_frame()) exit
      call app%file_dialog_result('f', path, done, cancelled)
      if (done) then
         answered = .true.
         was_cancelled = cancelled
         answer = path
      endif
   enddo
   endsubroutine frames

   subroutine click(part)
   !< A click on a part of the browser, as drawn in the last frame; the answer state is reset first.
   character(len=*), intent(in) :: part !< Part.
   real(real64)                 :: r(4) !< Its rectangle.
   logical                      :: found !< It was drawn.

   answered = .false.
   was_cancelled = .false.
   answer = ''
   call test_file_browser_rect(part, r(1), r(2), r(3), r(4), found)
   if (.not. found) then
      write(error_unit, '(A)') 'figure_test_files: not drawn: '//part
      return
   endif
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
   call frames(6)
   endsubroutine click

   subroutine double_click(part)
   !< A double-click on a part of the browser.
   character(len=*), intent(in) :: part !< Part.
   real(real64)                 :: r(4) !< Its rectangle.
   logical                      :: found !< It was drawn.

   answered = .false.
   was_cancelled = .false.
   answer = ''
   call test_file_browser_rect(part, r(1), r(2), r(3), r(4), found)
   if (.not. found) then
      write(error_unit, '(A)') 'figure_test_files: not drawn: '//part
      return
   endif
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
   call frames(10)
   endsubroutine double_click

   subroutine close_any()
   !< A browser left open by a failed check is cancelled, so that the next section starts with none.
   logical :: open_now !< A browser is shown.
   logical :: asked    !< A replace is asked.

   call test_file_browser(open_now)
   if (.not. open_now) return
   write(error_unit, '(A)') 'figure_test_files: a browser was left open'
   call test_file_browser(open_now, asking=asked)
   if (asked) call click('keep')
   call click('cancel')
   call app%file_dialog_result('f', answer, open_now)      ! its answer dropped
   call test_file_browser(open_now)
   if (open_now) then
      call test_key('escape')
      call frames(4)
   endif
   endsubroutine close_any

   function same(got, expected) result(equal)
   !< The lists are equal, entry by entry (trailing blanks ignored).
   character(len=*), intent(in) :: got(:)      !< Got.
   character(len=*), intent(in) :: expected(:) !< Expected.
   logical                      :: equal       !< Equal.
   integer(int32)               :: i           !< Counter.

   equal = size(got) == size(expected)
   if (.not. equal) then
      write(error_unit, '(A,I0,A,I0)') 'figure_test_files: entries ', size(got), ', expected ', size(expected)
      do i = 1_int32, size(got, kind=int32)
         write(error_unit, '(A)') '  '//trim(got(i))
      enddo
      return
   endif
   do i = 1_int32, size(got, kind=int32)
      equal = equal .and. trim(got(i)) == trim(expected(i))
   enddo
   endfunction same

   subroutine write_file(name, bytes)
   !< A file of `bytes` bytes.
   character(len=*), intent(in) :: name  !< File.
   integer(int32),   intent(in) :: bytes !< Size [bytes].
   integer(int32)               :: u     !< Unit.

   open(newunit=u, file=name, access='stream', form='unformatted', status='replace')
   if (bytes > 0_int32) write(u) repeat('x', bytes)
   close(u)
   endsubroutine write_file

   subroutine make_folder(name)
   !< A folder.
   character(len=*), intent(in) :: name !< Folder.
   integer(c_int)               :: r    !< Outcome.

#ifdef _WIN32
   r = c_mkdir(name//c_null_char)
#else
   r = c_mkdir(name//c_null_char, int(o'755', c_int))
#endif
   if (r /= 0_c_int) write(error_unit, '(A)') 'figure_test_files: cannot make '//name
   endsubroutine make_folder

   subroutine make_tree()
   !< The folder of the test: three files, a hidden one, four folders (one with a file).
   call make_folder(BASE)
   call make_folder(BASE//'/alpha')
   call make_folder(BASE//'/sub folder')
   call make_folder(BASE//'/gone')
#ifndef _WIN32
   call make_folder(BASE//'/locked')
#endif
   call write_file(BASE//'/a.inp', 2000_int32)
   call write_file(BASE//'/b.dat', 100_int32)
   call write_file(BASE//'/my case.inp', 10_int32)
   call write_file(BASE//'/.hidden.inp', 1_int32)
   call write_file(BASE//'/sub folder/deep.inp', 5_int32)
   endsubroutine make_tree

   subroutine write_settings(recent_folder)
   !< A settings file with one recent folder.
   character(len=*), intent(in) :: recent_folder !< Folder.
   integer(int32)               :: u             !< Unit.

   open(newunit=u, file=SETTINGS, status='replace')
   write(u, '(A)') '[file browser]'
   write(u, '(A)') 'recent = '//recent_folder
   close(u)
   endsubroutine write_settings

   function settings_has(line) result(has)
   !< The settings file has this line.
   character(len=*), intent(in) :: line !< Line.
   logical                      :: has  !< Found.
   character(len=4096)          :: buf  !< A line read.
   integer(int32)               :: u, ios !< Unit, status.

   has = .false.
   open(newunit=u, file=SETTINGS, status='old', action='read', iostat=ios)
   if (ios /= 0) return
   do
      read(u, '(A)', iostat=ios) buf
      if (ios /= 0) exit
      if (trim(buf) == line) has = .true.
   enddo
   close(u)
   endfunction settings_has

   subroutine cleanup()
   !< The folder of the test and its settings file removed (left by an earlier run, or at the end).
   integer(int32) :: u, ios !< Unit, status.
   logical        :: there  !< The settings file exists.

#ifdef _WIN32
   call execute_command_line('if exist '//BASE//' rmdir /s /q '//BASE, wait=.true., exitstat=ios)
#else
   ios = c_chmod(BASE//'/locked'//c_null_char, int(o'755', c_int))
   call execute_command_line('rm -rf '//BASE, wait=.true., exitstat=ios)
#endif
   inquire(file=SETTINGS, exist=there)
   if (there) then
      open(newunit=u, file=SETTINGS, iostat=ios)
      close(u, status='delete', iostat=ios)
   endif
   endsubroutine cleanup
endprogram figure_test_files
