!< cb_colormap, cookbook: colour a field with a colormap by name, reversed, in discrete bands, or loaded from a file.
program cb_colormap
!< cb_colormap, cookbook: colour a field with a colormap by name, reversed, in discrete bands, or loaded from a file.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, figure_last_error, FIG_OK, ig_begin, ig_end, ig_same_line, ip_begin_plot, &
                   ip_colormap, ip_colormap_names, ip_colormap_scale, ip_end_plot, ip_heatmap, ip_load_colormap

implicit none
integer(int32), parameter     :: N = 40_int32 !< Cells a side.
type(app_object)              :: app          !< Application.
real(real64)                  :: w(N, N)      !< A vorticity-like field, negative and positive.
character(len=:), allocatable :: names(:)     !< Colormap names.
integer(int32)                :: cmap         !< A colormap id.
integer(int32)                :: stat         !< Status.
integer(int32)                :: i, j         !< Counters.
integer                       :: u            !< Unit.
!run cb_colormap ./cb_colormap

do j = 1_int32, N
   do i = 1_int32, N
      w(i, j) = sin(6.283_real64 * i / N) * sin(3.1416_real64 * j / N)
   enddo
enddo
call app%init_headless(800_int32, 400_int32)
!region names
call ip_colormap_names(names)
write(output_unit, '(I0,A)') size(names), ' colormaps, the first ones:'
write(output_unit, '(*(A,:,", "))') (trim(names(i)), i = 1, 6)
!endregion names
!region load
open(newunit=u, file='ocean.csv', status='replace', action='write') ! a user map: r, g, b rows in [0, 255]
write(u, '(A)') '# deep to shallow', '8,29,88', '37,52,148', '34,94,168', '29,145,192', '65,182,196', '161,218,180'
close(u)
call ip_load_colormap('ocean', 'ocean.csv', stat=stat)
if (stat /= FIG_OK) write(output_unit, '(A)') figure_last_error()
!endregion load
if (app%next_frame()) then
   if (ig_begin('Fields')) then
      !region diverging
      cmap = ip_colormap('vik', levels=10_int32)      ! diverging, ten bands: zero sits between two of them
      if (ip_begin_plot('vorticity', width=300.0_real64, height=300.0_real64)) then
         call ip_heatmap('w', w, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale_min=-1.0_real64, &
                         scale_max=1.0_real64, colormap=cmap)
         call ip_end_plot()
      endif
      call ig_same_line()
      call ip_colormap_scale('##w', -1.0_real64, 1.0_real64, height=300.0_real64, colormap=cmap)
      !endregion diverging
      !region reversed
      if (ip_begin_plot('depth', width=300.0_real64, height=300.0_real64)) then
         call ip_heatmap('d', abs(w), 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=ip_colormap('ocean_r'))
         call ip_end_plot()
      endif
      !endregion reversed
   endif
   call ig_end()
endif
!region unknown
cmap = ip_colormap('jet', stat=stat)                ! names are case-sensitive: ImPlot's is 'Jet'
if (stat /= FIG_OK) write(output_unit, '(A)') figure_last_error()
!endregion unknown
call app%destroy()
open(newunit=u, file='ocean.csv')
close(u, status='delete')
endprogram cb_colormap
