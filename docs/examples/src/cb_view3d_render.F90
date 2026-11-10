!< cb_view3d_render, reference example: a surface coloured per cell on a fixed range without lighting, a clipping
!< plane, and the renders counted: a 3-D view renders only when something changed; checked headless.
program cb_view3d_render
!< cb_view3d_render, reference example: a surface coloured per cell on a fixed range without lighting, a clipping
!< plane, and the renders counted: a 3-D view renders only when something changed; checked headless.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, view3d_object

implicit none
integer(int32), parameter :: NI = 21_int32, NJ = 21_int32 !< Nodes.
type(app_object)          :: app              !< Application.
type(view3d_object)       :: view             !< The 3-D view.
real(real64), target      :: xyz(3, NI, NJ)   !< A bump: node (i, j) at xyz(:, i, j).
real(real64), target      :: f(NI-1, NJ-1)    !< A value per cell.
integer(int32)            :: bump             !< Its mesh id.
integer(int32)            :: renders(4)       !< Renders counted after each stage.
integer(int32)            :: w, h             !< The last render's size [pixels].
integer(int32)            :: i, j             !< Counters.
!run cb_view3d_render ./cb_view3d_render

do j = 1_int32, NJ
   do i = 1_int32, NI
      xyz(:, i, j) = [real(i - 11, real64), real(j - 11, real64), 0.0_real64]
      xyz(3, i, j) = 4.0_real64 * exp(-(xyz(1, i, j)**2 + xyz(2, i, j)**2) / 20.0_real64)
   enddo
enddo
do j = 1_int32, NJ - 1_int32
   do i = 1_int32, NI - 1_int32
      f(i, j) = sum(xyz(3, i:i+1, j:j+1)) / 4.0_real64        ! the cell's mean height
   enddo
enddo

call app%init_headless(640_int32, 480_int32)
!region colours
call view%init(lighting=.false.)                              ! the colours exactly as mapped, for a legend
bump = view%surface(xyz, cell_scalar=f, colormap='batlow')    ! one colour per cell
call view%set_mesh(bump, vmin=0.0_real64, vmax=5.0_real64)    ! a fixed range: 0 to 5, whatever the data
!endregion colours
call frames(3_int32)
call view%render_info(count=renders(1))
call frames(3_int32)                                          ! nothing changed: no render
call view%render_info(count=renders(2))
!region clip
call view%clip([1.0_real64, 0.0_real64, 0.0_real64], [0.0_real64, 0.0_real64, 0.0_real64]) ! keep x >= 0
!endregion clip
call frames(3_int32)
call view%render_info(count=renders(3))
!region renders
xyz(3, :, :) = 0.5_real64 * xyz(3, :, :)                      ! the program changes the data in place ...
call view%changed(bump)                                       ! ... and says so: the next draw renders
call frames(3_int32)
call view%render_info(count=renders(4), width=w, height=h)
!endregion renders
write(output_unit, '(A,4(1X,I0))') 'renders after: the first draw, 3 idle frames, a clip, a change:', renders
write(output_unit, '(A,I0,A,I0,A)') 'the last render: ', w, ' x ', h, ' pixels'
call view%destroy()
call app%destroy()
if (renders(2) /= renders(1) .or. renders(3) /= renders(2) + 1 .or. renders(4) /= renders(3) + 1) &
   error stop 'cb_view3d_render: renders not as expected'

contains
   subroutine frames(n)
   !< Draw `n` frames of the window holding the view.
   integer(int32), intent(in) :: n !< Frames.
   integer(int32)             :: k !< Counter.

   do k = 1_int32, n
      if (.not. app%next_frame()) exit
      call ig_set_next_window(0.0_real64, 0.0_real64, 640.0_real64, 480.0_real64, always=.true.)
      if (ig_begin('View')) call view%draw('bump')
      call ig_end()
   enddo
   endsubroutine frames
endprogram cb_view3d_render
