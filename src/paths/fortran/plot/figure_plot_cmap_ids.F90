!< figure_plot_cmap_ids, the frame's colormap of a colormap id of FIGURE's API (the native registry's) on the Fortran path.
module figure_plot_cmap_ids
!< figure_plot_cmap_ids, the frame's colormap of a colormap id of FIGURE's API (the native registry's) on the Fortran path.
!<
!< szaghi/figure#15, the seam's switch. The ids `ip_colormap` gives stay the native registry's (ImPlot's, as on the
!< current path: the 3-D views register maps there by name too, so the two registries' ids cannot be kept equal by the
!< order of registration); the Fortran plot frames draw with their own registry (figure_plot_colormaps). `cm_frame_id`
!< gives the frame's map of an id: ImPlot's 16 maps have the same ids in both; another is the one `cm_frame_id_set`
!< recorded (`ip_colormap`), or found by its native name (`<name>`, `<name>|<levels>`) and recorded; the record is
!< forgotten in a new context (`fig_generations`: its native ids are new). Used by the 2-D and 3-D `ip_*`.
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_f_pointer, c_int, c_ptr
use, intrinsic :: iso_fortran_env, only : int32
use figure_c_native, only : fig_generations
use figure_cimplot, only : ImPlot_GetColormapName
use figure_plot_colormaps, only : cm_colormap

implicit none
private
public :: cm_frame_id, cm_frame_id_set

integer(int32), allocatable :: frame_ids(:)            !< The frame's id of each colormap id, -1 unknown yet.
integer(c_int)              :: frame_ids_ctx = -1_c_int !< ... of this context.

contains
   function cm_frame_id(id) result(fid)
   !< The frame's map of a colormap id: the ids of FIGURE's API are the native registry's (ImPlot's, which ImPlot3D and
   !< the 3-D views read, until the 3-D switch: the ids of the current path); the frame keeps its own registry
   !< (figure_plot_colormaps). ImPlot's 16 maps have the same ids in both; another is the one `ip_colormap` recorded,
   !< or found by its native name (`<name>`, `<name>|<levels>`: one registered by the native layer itself, a 3-D view's).
   integer(int32), intent(in)  :: id   !< Colormap id (registered: checked by the caller).
   integer(int32)              :: fid  !< The frame's id.
   type(c_ptr)                 :: p    !< The native name.
   character(kind=c_char), pointer :: c(:) !< ... its characters.
   character(len=:), allocatable :: nm !< ... as a string.
   integer(int32)              :: k, bar, lv !< Length, the '|', levels.

   fid = id
   if (id < 16_int32) return
   call ids_current()
   if (allocated(frame_ids)) then
      if (id <= ubound(frame_ids, 1)) then
         if (frame_ids(id) >= 0_int32) then
            fid = frame_ids(id)
            return
         endif
      endif
   endif
   p = ImPlot_GetColormapName(int(id, c_int))
   if (.not. c_associated(p)) return
   call c_f_pointer(p, c, [4096])
   k = 0_int32
   do while (c(k + 1_int32) /= achar(0))
      k = k + 1_int32
   enddo
   allocate(character(len=k) :: nm)
   do bar = 1_int32, k
      nm(bar:bar) = c(bar)
   enddo
   bar = index(nm, '|')
   if (bar > 0) then
      read(nm(bar + 1:), *) lv
      fid = cm_colormap(nm(1:bar - 1), lv)
   else
      fid = cm_colormap(nm)
   endif
   if (fid < 0_int32) fid = id
   call cm_frame_id_set(id, fid)
   endfunction cm_frame_id

   subroutine cm_frame_id_set(id, fid)
   !< The frame's map of a colormap id recorded (`cm_frame_id`).
   integer(int32), intent(in)  :: id   !< Colormap id.
   integer(int32), intent(in)  :: fid  !< The frame's.
   integer(int32), allocatable :: more(:) !< Grown table.

   if (id < 0_int32) return
   call ids_current()
   if (.not. allocated(frame_ids)) then
      allocate(frame_ids(0:max(63_int32, id)))
      frame_ids = -1_int32
   elseif (id > ubound(frame_ids, 1)) then
      allocate(more(0:2_int32 * id))
      more = -1_int32
      more(0:ubound(frame_ids, 1)) = frame_ids
      call move_alloc(more, frame_ids)
   endif
   frame_ids(id) = fid
   endsubroutine cm_frame_id_set

   subroutine ids_current()
   !< The record of `cm_frame_id_set` forgotten in a new context (its native ids are new).
   integer(c_int) :: ctx, sty !< Generations.

   call fig_generations(ctx, sty)
   if (ctx == frame_ids_ctx) return
   frame_ids_ctx = ctx
   if (allocated(frame_ids)) frame_ids = -1_int32
   endsubroutine ids_current
endmodule figure_plot_cmap_ids
