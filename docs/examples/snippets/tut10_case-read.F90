subroutine read_case(file, c, stat, msg)
!< Read a case's input, the namelist `&heat` of `file`.
character(len=*),              intent(in)  :: file        !< Input file.
type(case_t),                  intent(out) :: c           !< Its input (defaults where the file is silent).
integer(int32),                intent(out) :: stat        !< Status: 0 read.
character(len=:), allocatable, intent(out) :: msg         !< What went wrong.
character(len=64)                          :: title       !< Namelist copies of the components.
integer(int32)                             :: nx, ny, max_iter
real(real64)                               :: lx, ly, bc_value(4), body_x, body_y, body_r, body_t, omega, tolerance
character(len=12)                          :: bc_kind(4)
character(len=256)                         :: iomsg       !< The run time's message.
integer(int32)                             :: u           !< Unit.
namelist /heat/ title, nx, ny, lx, ly, bc_kind, bc_value, body_x, body_y, body_r, body_t, omega, tolerance, max_iter

title = c%title; nx = c%nx; ny = c%ny; lx = c%lx; ly = c%ly; bc_kind = c%bc_kind; bc_value = c%bc_value
body_x = c%body_x; body_y = c%body_y; body_r = c%body_r; body_t = c%body_t
omega = c%omega; tolerance = c%tolerance; max_iter = c%max_iter
msg = ''
open(newunit=u, file=file, status='old', action='read', iostat=stat, iomsg=iomsg)
if (stat /= 0) then
   msg = 'no '//INPUT_FILE//' in '//file(:max(0, len(file) - len(INPUT_FILE) - 1))
   return
endif
read(u, nml=heat, iostat=stat, iomsg=iomsg)
close(u)
if (stat /= 0) then
   msg = file//': '//trim(iomsg)
   return
endif
c = case_t(title, nx, ny, lx, ly, bc_kind, bc_value, body_x, body_y, body_r, body_t, omega, tolerance, max_iter)
endsubroutine read_case
