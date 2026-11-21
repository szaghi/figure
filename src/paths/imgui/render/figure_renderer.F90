!< figure_renderer, the renderer seam: which renderers draw the app's frames (the current path: Dear ImGui's).
module figure_renderer
!< figure_renderer, the renderer seam: which renderers draw the app's frames (the current path: Dear ImGui's).
!<
!< szaghi/figure#15 P9, §2: one module name, two implementations, a build mode's `src` picking one (no run-time flag).
!< This one, `src/paths/imgui/render/`, is the current path's: the native layer's own renderers draw every frame (in a
!< window the OpenGL 3 backend of Dear ImGui; headless and in remote mode figure_swrast.cpp), so it installs nothing.
!< The Fortran path's (`src/paths/fortran/render/`) installs the renderers written in Fortran.
implicit none
private
public :: renderer_install

contains
   subroutine renderer_install()
   !< Install the path's renderers in the native layer, before the app's contexts are made (nothing here).
   endsubroutine renderer_install
endmodule figure_renderer
