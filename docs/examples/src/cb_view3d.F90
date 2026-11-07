!< cb_view3d, cookbook: show a surface coloured by a field in a 3-D view, with its grid, a cut and the cell clicked.
program cb_view3d
!< cb_view3d, cookbook: show a surface coloured by a field in a 3-D view, with its grid, a cut and the cell clicked.
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_end, ig_same_line, ig_separator, &
                   ig_set_next_window, ig_text, view3d_object

implicit none
integer(int32), parameter :: NI = 72_int32   !< Nodes around the body.
integer(int32), parameter :: NJ = 37_int32   !< Nodes from nose to tail.
real(real64),   parameter :: PI = acos(-1.0_real64) !< Pi.
type(app_object)          :: app             !< Application.
type(view3d_object)       :: view            !< The 3-D view.
real(real64), target      :: body(3, NI, NJ) !< A slender body: node (i, j) at body(:, i, j).
real(real64), target      :: cp(NI, NJ)      !< Its pressure coefficient, one value per node.
real(real64), target      :: axis(3, 2)      !< The free stream's direction, drawn as a line.
integer(int32)            :: hull, wake      !< Mesh ids.
logical                   :: edges = .true.  !< Grid lines shown.
logical                   :: cut = .false.   !< Half the body cut away.
integer(int32)            :: mesh            !< The mesh picked.
integer(int64)            :: cell = 0_int64  !< The cell clicked (0: none).
real(real64)              :: point(3)        !< The point clicked.
character(len=80)         :: text            !< Its description.
integer(int32)            :: i, j            !< Counters.
real(real64)              :: th, s, r        !< Angle around, abscissa along, radius.

do j = 1_int32, NJ
   s = real(j - 1, real64) / (NJ - 1)                       ! 0 at the nose, 1 at the tail
   r = 0.6_real64 * sin(PI * s)**0.7_real64                 ! closed at both ends
   do i = 1_int32, NI
      th = 2.0_real64 * PI * (i - 1) / (NI - 1)
      body(:, i, j) = [4.0_real64 * s, r * cos(th), 0.8_real64 * r * sin(th)]
      cp(i, j) = 1.0_real64 - 2.2_real64 * sin(PI * s)**2 * (0.6_real64 + 0.4_real64 * cos(th)**2) ! a smooth field
   enddo
enddo
axis = reshape([-1.0_real64, 0.0_real64, 0.0_real64, 5.0_real64, 0.0_real64, 0.0_real64], [3, 2])
text = 'click a cell'

call app%init('FIGURE: a 3-D view', 1000_int32, 640_int32)
!region setup
call view%init()                                                   ! after app%init
hull = view%surface(body, scalar=cp, colormap='cool-warm', edges=.true.) ! the arrays are read in place
wake = view%lines(axis, color=[0.9_real64, 0.75_real64, 0.2_real64])
call view%set_camera(azimuth=-55.0_real64, elevation=25.0_real64)
!endregion setup
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 980.0_real64, 620.0_real64)
   if (ig_begin('Body')) then
      !region controls
      if (ig_button('+x')) call view%view('+x')
      call ig_same_line()
      if (ig_button('-y')) call view%view('-y')
      call ig_same_line()
      if (ig_button('+z')) call view%view('+z')
      call ig_same_line()
      if (ig_button('Fit')) call view%fit()
      call ig_same_line()
      if (ig_checkbox('grid', edges)) call view%set_mesh(hull, edges=edges)
      call ig_same_line()
      if (ig_checkbox('cut at z = 0', cut)) then
         call view%unclip()
         if (cut) call view%clip([0.0_real64, 0.0_real64, -1.0_real64], [0.0_real64, 0.0_real64, 0.0_real64])
      endif
      call ig_same_line()
      call ig_text(trim(text))
      call ig_separator()
      !endregion controls
      !region draw
      call view%draw('view')                                       ! the rest of the window
      if (view%clicked(mesh, cell, point)) then
         if (mesh == hull) then
            i = int(mod(cell - 1_int64, int(NI - 1, int64)), int32) + 1_int32  ! cell (i, j) of the surface
            j = int((cell - 1_int64) / (NI - 1), int32) + 1_int32
            write(text, '(A,I0,A,I0,A,F6.3,A,3F6.2,A)') 'cell (', i, ', ', j, '): Cp = ', cp(i, j), ' at (', point, ')'
         endif
      endif
      !endregion draw
   endif
   call ig_end()
enddo
call view%destroy()
call app%destroy()
endprogram cb_view3d
