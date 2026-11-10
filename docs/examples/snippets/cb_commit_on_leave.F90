!< cb_commit_on_leave, cookbook: check a value when the user leaves the field; open a row on double click.
program cb_commit_on_leave
!< cb_commit_on_leave, cookbook: check a value when the user leaves the field; open a row on double click.
!<
!< A list of cases on the left: a click selects a case, a double click opens it in the editor on the right. The
!< editor's CFL field is checked once, when the user leaves it (a click elsewhere, tab, enter), not on every key: a
!< value that is not a positive number is refused and the field shows the last good one again.
!< `cb_commit_on_leave --check` opens no window: it clicks and types headless and prints what happened.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_input_text, ig_last_item, ig_selectable, ig_set_next_window, &
                   ig_text, ig_text_disabled, item_status_object
use figure_testing, only : test_click, test_item_center, test_key, test_type
implicit none
type(app_object)         :: app          !< Application.
character(len=16)        :: cases(3)     !< The cases.
real(real64)             :: cfls(3)      !< The CFL number of each case.
character(len=16)        :: meshes(3)    !< The mesh file of each case.
integer(int32)           :: sel          !< Selected case.
integer(int32)           :: opened       !< Case open in the editor (0: none).
character(len=24)        :: cfl_text     !< The CFL field.
character(len=16)        :: mesh_text    !< The mesh field.
character(len=64)        :: message      !< What the last check said.
type(item_status_object) :: s            !< Status of an item.
character(len=16)        :: arg          !< First argument.
logical                  :: check        !< --check: headless, scripted input.
real(real64)             :: row_at(2, 3) !< Centre of each case in the list.
real(real64)             :: cfl_at(2)    !< Centre of the CFL field.
real(real64)             :: mesh_at(2)   !< Centre of the mesh field.
integer(int32)           :: frame        !< Frame counter.
integer(int32)           :: k            !< Case.
cases = ['wing     ', 'fuselage ', 'tail     ']
cfls = [0.8_real64, 1.2_real64, 0.5_real64]
meshes = ['wing.grd    ', 'fuselage.grd', 'tail.grd    ']
sel = 1_int32
opened = 0_int32
cfl_text = ''
mesh_text = ''
message = ''
row_at = 0.0_real64
cfl_at = 0.0_real64
mesh_at = 0.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(760_int32, 300_int32)
else
   call app%init('FIGURE: commit on leave', 760_int32, 300_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 240.0_real64, 280.0_real64)
   if (ig_begin('Cases')) then
      do k = 1_int32, size(cases, kind=int32)
         if (ig_selectable(trim(cases(k)), k == sel)) sel = k
         s = ig_last_item()
         if (s%double_clicked(1)) call open_case(k)          ! a double click opens the row
         call test_item_center(row_at(1, k), row_at(2, k))
      enddo
      call ig_text_disabled('double click: open')
   endif
   call ig_end()
   call ig_set_next_window(260.0_real64, 10.0_real64, 490.0_real64, 280.0_real64)
   if (ig_begin('Case')) then
      if (opened == 0_int32) then
         call ig_text('no case open')
      else
         call ig_text('case: '//trim(cases(opened)))
         if (ig_input_text('CFL', cfl_text)) continue           ! the text changes on every key
         s = ig_last_item()
         if (s%deactivated_after_edit) call commit_cfl()         ! once, when the user leaves the field
         call test_item_center(cfl_at(1), cfl_at(2))
         if (ig_input_text('mesh file', mesh_text)) continue
         s = ig_last_item()
         if (s%deactivated_after_edit) call commit_mesh()
         call test_item_center(mesh_at(1), mesh_at(2))
         call ig_text(trim(message))
      endif
   endif
   call ig_end()
   if (check) then
      call script(frame)
      if (frame == 90_int32) exit
   endif
enddo
call app%destroy()
contains
   subroutine open_case(k)
   !< Open case `k` in the editor: the fields show its values.
   integer(int32), intent(in) :: k !< Case.
   opened = k
   write(cfl_text, '(F0.2)') cfls(k)
   mesh_text = meshes(k)
   call said('opened '//trim(cases(k)))
   endsubroutine open_case

   subroutine commit_cfl()
   !< The user left the CFL field after changing it: keep a positive number, or show the last good value again.
   real(real64)   :: value !< The number typed.
   integer(int32) :: ios   !< Status of the read.
   read(cfl_text, *, iostat=ios) value
   if (ios /= 0 .or. value <= 0.0_real64) then
      call said('CFL: "'//trim(cfl_text)//'" is not a positive number')
   else
      cfls(opened) = value
      call said('CFL of '//trim(cases(opened))//' set')
   endif
   write(cfl_text, '(F0.2)') cfls(opened)                     ! the field is not edited now: it shows this
   endsubroutine commit_cfl

   subroutine commit_mesh()
   !< The user left the mesh field after changing it: a mesh file ends with .grd.
   integer(int32) :: n !< Length of the name.
   n = len_trim(mesh_text)
   if (n < 5_int32) then
      call said('mesh: "'//trim(mesh_text)//'" is not a .grd file')
   elseif (mesh_text(n-3:n) /= '.grd') then
      call said('mesh: "'//trim(mesh_text)//'" is not a .grd file')
   else
      meshes(opened) = mesh_text
      call said('mesh of '//trim(cases(opened))//' set')
      return
   endif
   mesh_text = meshes(opened)
   endsubroutine commit_mesh

   subroutine said(what)
   !< Show what happened (and print it in --check).
   character(len=*), intent(in) :: what !< What happened.
   message = what
   if (check) write(output_unit, '(A,I0,A)') 'frame ', frame, ': '//trim(what)
   endsubroutine said

   subroutine script(f)
   !< The input of --check, by frame.
   integer(int32), intent(in) :: f !< Frame.
   select case (f)
   case (5_int32)                       ! one click on tail: selected, not opened
      call test_click(row_at(1, 3), row_at(2, 3))
   case (12_int32)                      ! a double click on fuselage: opened
      call test_click(row_at(1, 2), row_at(2, 2))
      call test_click(row_at(1, 2), row_at(2, 2))
   case (25_int32)                      ! type over the CFL: nothing is checked while typing
      call replace(cfl_at, 'abc')
   case (35_int32)                      ! leave it by a click on the mesh field: checked once, refused
      call test_click(mesh_at(1), mesh_at(2))
      call test_key('escape')
   case (50_int32)                      ! type a good value and leave with enter: checked once, kept
      call replace(cfl_at, '1.5')
      call test_key('enter')
   case (65_int32)                      ! a mesh that is not a .grd file, left with tab
      call replace(mesh_at, 'fuse.dat')
      call test_key('tab')
   case (80_int32)                      ! the field clicked and left without a change: nothing to check
      call test_click(cfl_at(1), cfl_at(2))
      call test_key('enter')
   endselect
   endsubroutine script

   subroutine replace(at, text)
   !< Click the field at `at`, select its text (end, shift+home) and type `text`.
   real(real64),     intent(in) :: at(2) !< Centre of the field.
   character(len=*), intent(in) :: text  !< New text.
   call test_click(at(1), at(2))
   call test_key('end')
   call test_key('shift', down=.true.)
   call test_key('home')
   call test_key('shift', down=.false.)
   call test_type(text)
   endsubroutine replace
endprogram cb_commit_on_leave
