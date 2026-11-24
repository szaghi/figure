!< figure_plot_scope, the Fortran plot frames' part of the scope record, and the plots' style brought in, on the Fortran path.
module figure_plot_scope
!< figure_plot_scope, the Fortran plot frames' part of the scope record, and the plots' style brought in, on the Fortran path.
!<
!< szaghi/figure#15, the seam's switch. `plot_path_ready`, which the Fortran path's `figure_implot` and
!< `figure_implot3d` call at their entry points: the hooks of native/figure_scope.cpp registered once
!< (`fig_scope_plot_hooks`: the record snapshots the 2-D frame's open plot and subplot and the 3-D frame's open plot,
!< as it snapshots ImPlot's and ImPlot3D's; recovers them, `pf_recover_to` and `pf3_end_plot`; closes the plot kinds'
!< entries with the frames' ends), and FIGURE's ImPlot and ImPlot3D styles, which the native layer holds, brought into
!< the frames' when they changed (`ps_refresh`, `ps3_refresh`).
use, intrinsic :: iso_c_binding, only : c_funloc, c_int
use, intrinsic :: iso_fortran_env, only : int32
use figure_base, only : SCOPE_ALIGNED, SCOPE_LEGEND_POPUP, SCOPE_PLOT, SCOPE_PLOT3D, SCOPE_SUBPLOTS
use figure_c_native, only : fig_scope_plot_hooks
use figure_core, only : core_end_popup
use figure_plot_frame, only : pf_aligned_open, pf_end_aligned, pf_end_legend_popup, pf_end_plot, pf_end_subplots, &
                              pf_open_ids, pf_recover_to
use figure_plot_style, only : ps_refresh
use figure_plot3d_frame, only : pf3_end_plot, pf3_open_id
use figure_plot3d_style, only : ps3_refresh

implicit none
private
public :: plot_path_ready

logical :: hooks_set = .false. !< The scope record's hooks registered.

contains
   subroutine plot_path_ready()
   !< The scope record's hooks registered (once), FIGURE's plot styles brought into the frames' when they changed.
   if (.not. hooks_set) then
      call fig_scope_plot_hooks(c_funloc(scope_state), c_funloc(scope_recover), c_funloc(scope_close))
      hooks_set = .true.
   endif
   call ps_refresh()
   call ps3_refresh()
   endsubroutine plot_path_ready

   subroutine scope_state(open) bind(C)
   !< The scope record's snapshot of the frames (native/figure_scope.cpp's `take_sizes`): the 2-D frame's open plot's
   !< and subplot's slots, the 3-D frame's open plot's (as ImPlot's CurrentPlot, CurrentSubplot, ImPlot3D's
   !< CurrentPlot), 0 none.
   integer(c_int), intent(out) :: open(3) !< Plot, subplot, 3-D plot.
   integer(int32)              :: p, s    !< Slots.

   call pf_open_ids(p, s)
   open(1) = int(p, c_int)
   open(2) = int(s, c_int)
   open(3) = int(pf3_open_id(), c_int)
   endsubroutine scope_state

   subroutine scope_recover(then) bind(C)
   !< The scope record's `recover_to`: the frames' plots open now and not in the snapshot ended (the 2-D plot, its
   !< subplot, then the 3-D plot, as the record ends ImPlot's and ImPlot3D's).
   integer(c_int), intent(in) :: then(3) !< The snapshot.

   call pf_recover_to(then(1) /= 0_c_int, then(2) /= 0_c_int)
   if (pf3_open_id() /= 0_int32 .and. then(3) == 0_c_int) call pf3_end_plot()
   endsubroutine scope_recover

   function scope_close(kind) result(done) bind(C)
   !< The scope record's `close_entry` of a plot kind: the frame's end (only of what is open); 0 for the other kinds.
   integer(c_int), value :: kind !< SCOPE_*.
   integer(c_int)        :: done !< 1: closed here.
   integer(int32)        :: p, s !< Slots.

   done = 1_c_int
   call pf_open_ids(p, s)
   select case (kind)
   case (SCOPE_PLOT)
      if (p /= 0_int32) call pf_end_plot()
   case (SCOPE_SUBPLOTS)
      if (s /= 0_int32) call pf_end_subplots()
   case (SCOPE_ALIGNED)
      if (pf_aligned_open()) call pf_end_aligned()
   case (SCOPE_LEGEND_POPUP)
      if (p /= 0_int32) then
         call pf_end_legend_popup()
      else
         call core_end_popup() ! (EndLegendPopup is EndPopup)
      endif
   case (SCOPE_PLOT3D)
      if (pf3_open_id() /= 0_int32) call pf3_end_plot()
   case default
      done = 0_c_int
   endselect
   endfunction scope_close
endmodule figure_plot_scope
