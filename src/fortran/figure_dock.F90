!< figure_dock, docking: windows docked into one another or into a dock space, and layouts set by the program.
module figure_dock
!< figure_dock, docking: windows docked into one another or into a dock space, and layouts set by the program.
!<
!< Every drawing procedure of this module refuses a call from a task (`FIG_ERR_STATE`): see processes.md; and a call
!< with no frame open, a usage error (`FIG_ERR_STATE`, `<procedure>: no frame open`). Every begin/end and push/pop
!< pair registers in the scope record of the frame, which checks each end before Dear ImGui sees it: a wrong end is
!< refused and reported by `app%next_frame` (`app%set_checks`; errors.md, "Pairing and frames").
!<
!< Docking is on by default (`app%set_docking` turns it off): the user drags a window by its title bar onto another
!< window, or onto a dock space, and drops it as a tab or a split. A dock space over the whole display is declared
!< every frame with `ig_dock_space`, before the windows that dock into it. A program lays out a dock space once, the
!< first time it appears:
!<
!<```fortran
!< root = ig_dock_id('main')
!< if (ig_dock_layout_begin(root)) then
!<    call ig_dock_split(root, 'left', 0.3_real64, left, right)
!<    call ig_dock_window('Controls', left)
!<    call ig_dock_window('Plots', right)
!<    call ig_dock_layout_end(root)
!< endif
!< call ig_dock_space(root)
!<```
!<
!< A window that appears after the layout was built (a file found later) is docked into a node with
!< `ig_set_next_window_dock(node)` before its `ig_begin`: the first time it appears, then where the user moves it.
!<
!< Dock ids are Dear ImGui's ImGuiID (unsigned 32-bit), carried in `integer(int32)`: compare and pass them, do not do
!< arithmetic on them.
use, intrinsic :: iso_c_binding, only : c_double, c_int
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure_base, only : figure_check, figure_draw_refused, figure_fail, figure_scope_open, figure_scope_refused, &
                        SCOPE_DOCK_LAYOUT
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK, fig_dock_id, fig_dock_layout_begin, fig_dock_layout_end, &
                            fig_dock_space, fig_dock_split, fig_dock_window, fig_window_dock
use figure_cimgui, only : igSetNextWindowDockID
use figure_cimgui_enums, only : ImGuiCond_Always, ImGuiCond_FirstUseEver, ImGuiDir_Down, ImGuiDir_Left, ImGuiDir_Right, &
                                ImGuiDir_Up, ImGuiDockNodeFlags_None

implicit none
private
public :: ig_dock_id, ig_dock_space, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_split, ig_dock_window
public :: ig_window_dock, ig_set_next_window_dock

contains
   function ig_dock_id(name) result(id)
   !< The dock id of a name: the same name gives the same id in every frame and every run.
   character(len=*), intent(in) :: name !< Name.
   integer(int32)               :: id   !< Dock id.

   id = int(fig_dock_id(name, len(name, c_int)), int32)
   endfunction ig_dock_id

   recursive subroutine ig_dock_space(id, flags, stat)
   !< A dock space covering the display, every frame, before the windows docked into it. Where nothing is docked it
   !< is transparent: floating windows and the window background show through.
   integer(int32), intent(in)            :: id    !< Dock id (`ig_dock_id`).
   integer(int32), intent(in),  optional :: flags !< `ImGuiDockNodeFlags_*` (default none).
   integer(int32), intent(out), optional :: stat  !< Status: `FIG_ERR_STATE` outside a frame or with docking off.
   integer(c_int)                        :: f     !< Flags.

   if (figure_draw_refused('ig_dock_space', stat)) return ! a task does not draw
   f = ImGuiDockNodeFlags_None
   if (present(flags)) f = int(flags, c_int)
   call figure_check(fig_dock_space(int(id, c_int), f), stat)
   endsubroutine ig_dock_space

   recursive function ig_dock_layout_begin(id, stat) result(needed)
   !< True when the dock space `id` has no layout yet (its first frame, without an ini file keeping one), or must be
   !< laid out again (`app%switch_layout` to a layout not arranged yet, `app%reset_layout`): then lay it out (the
   !< layout `app%layout()`, if the program has several) with `ig_dock_split` and `ig_dock_window`, and close with
   !< `ig_dock_layout_end`. Call it before `ig_dock_space`.
   integer(int32), intent(in)            :: id     !< Dock id.
   integer(int32), intent(out), optional :: stat   !< Status.
   logical                               :: needed !< Build the layout now.
   integer(c_int)                        :: n      !< 1: needed.

   needed = .false.
   if (figure_draw_refused('ig_dock_layout_begin', stat)) return ! a task does not draw
   n = 0_c_int
   call figure_check(fig_dock_layout_begin(int(id, c_int), n), stat)
   needed = n == 1_c_int
   call figure_scope_open(SCOPE_DOCK_LAYOUT, 'ig_dock_layout_begin', '', needed, id)
   endfunction ig_dock_layout_begin

   recursive subroutine ig_dock_split(id, direction, fraction, id_at_dir, id_other, stat)
   !< Split the node `id` in two: `id_at_dir` takes `fraction` of it on the side `direction` (`'left'`, `'right'`,
   !< `'up'`, `'down'`), `id_other` the rest. Split the new nodes again for more areas.
   integer(int32),   intent(in)            :: id        !< Node to split.
   character(len=*), intent(in)            :: direction !< `'left'`, `'right'`, `'up'` or `'down'`.
   real(real64),     intent(in)            :: fraction  !< Part of the node at `direction`, in (0, 1).
   integer(int32),   intent(out)           :: id_at_dir !< The new node at `direction`.
   integer(int32),   intent(out)           :: id_other  !< The new node on the other side.
   integer(int32),   intent(out), optional :: stat      !< Status: `FIG_ERR_ARGUMENT` for a bad direction or fraction.
   integer(c_int)                          :: dir       !< ImGuiDir.
   integer(c_int)                          :: a         !< Node at `direction`.
   integer(c_int)                          :: b         !< Other node.

   id_at_dir = 0_int32
   id_other = 0_int32
   if (figure_draw_refused('ig_dock_split', stat)) return ! a task does not draw
   id_at_dir = 0_int32
   id_other = 0_int32
   select case (trim(direction))
   case ('left')
      dir = ImGuiDir_Left
   case ('right')
      dir = ImGuiDir_Right
   case ('up')
      dir = ImGuiDir_Up
   case ('down')
      dir = ImGuiDir_Down
   case default
      call figure_fail(FIG_ERR_ARGUMENT, "ig_dock_split: direction must be 'left', 'right', 'up' or 'down'", stat)
      return
   endselect
   a = 0_c_int
   b = 0_c_int
   call figure_check(fig_dock_split(int(id, c_int), dir, real(fraction, c_double), a, b), stat)
   id_at_dir = int(a, int32)
   id_other = int(b, int32)
   endsubroutine ig_dock_split

   recursive subroutine ig_dock_window(name, id, stat)
   !< Dock the window `name` (as passed to `ig_begin`) into the node `id` of a layout being built.
   character(len=*), intent(in)            :: name !< Window name.
   integer(int32),   intent(in)            :: id   !< Dock node.
   integer(int32),   intent(out), optional :: stat !< Status.

   if (figure_draw_refused('ig_dock_window', stat)) return ! a task does not draw
   call figure_check(fig_dock_window(name, len(name, c_int), int(id, c_int)), stat)
   endsubroutine ig_dock_window

   recursive subroutine ig_dock_layout_end(id, stat)
   !< Finish the layout started by `ig_dock_layout_begin`.
   integer(int32), intent(in)            :: id   !< Dock id.
   integer(int32), intent(out), optional :: stat !< Status.

   if (figure_scope_refused(SCOPE_DOCK_LAYOUT, 'ig_dock_layout_end', stat=stat)) return ! a task, no frame, not innermost
   call figure_check(fig_dock_layout_end(int(id, c_int)), stat)
   endsubroutine ig_dock_layout_end

   recursive subroutine ig_window_dock(id, docked)
   !< Inside a window (between `ig_begin` and `ig_end`): the dock node it is in (0 if none) and whether it is docked.
   integer(int32), intent(out) :: id     !< Dock node.
   logical,        intent(out) :: docked !< The window is docked.
   integer(c_int)              :: i      !< Node.
   integer(c_int)              :: d      !< 1: docked.

   id = 0_int32
   docked = .false.
   if (figure_draw_refused('ig_window_dock')) return ! a task does not draw
   i = 0_c_int
   d = 0_c_int
   if (fig_window_dock(i, d) /= FIG_OK) continue ! cannot fail inside a window
   id = int(i, int32)
   docked = d == 1_c_int
   endsubroutine ig_window_dock

   recursive subroutine ig_set_next_window_dock(id, always)
   !< Dock the next window (the next `ig_begin`) into the node `id`: the first time it appears (a window created after
   !< the layout was built), or every frame with `always`.
   integer(int32), intent(in)           :: id     !< Dock node (from the layout, or `ig_window_dock` of a docked window).
   logical,        intent(in), optional :: always !< Every frame (default: first use only, then the user decides).
   integer(c_int)                       :: cond   !< ImGuiCond.

   if (figure_draw_refused('ig_set_next_window_dock')) return ! a task does not draw
   cond = ImGuiCond_FirstUseEver
   if (present(always)) then
      if (always) cond = ImGuiCond_Always
   endif
   call igSetNextWindowDockID(int(id, c_int), cond)
   endsubroutine ig_set_next_window_dock
endmodule figure_dock
