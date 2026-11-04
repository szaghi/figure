!< figure_c_native, the raw C interfaces: FIGURE's native glue and the cimgui/cimplot functions bound directly.
module figure_c_native
!< figure_c_native, the raw C interfaces: FIGURE's native glue and the cimgui/cimplot functions bound directly.
!<
!< Private to the library: applications use figure_app, figure_imgui and figure_implot. A C function is bound here
!< directly only if all its arguments are scalars, pointers or the two-float `ImVec2_c`; functions taking larger
!< structs by value (e.g. `ImPlotSpec_c`) go through the glue (native/figure_native.cpp), which builds them in C++.
!< Strings passed to cimgui/cimplot must be NUL-terminated; strings passed to the glue are (pointer, length).
use, intrinsic :: iso_c_binding, only : c_bool, c_char, c_double, c_float, c_int, c_ptr

implicit none
private
public :: FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
public :: IMGUI_DATATYPE_S32, IMGUI_DATATYPE_FLOAT, IMGUI_DATATYPE_DOUBLE
public :: IMGUI_COND_ALWAYS, IMGUI_COND_ONCE, IMGUI_COND_FIRST_USE_EVER
public :: im_vec2
public :: fig_init, fig_init_headless, fig_begin_frame, fig_end_frame, fig_shutdown, fig_set_lazy, fig_request_frames
public :: fig_content_scale, fig_last_error, fig_input_mouse, fig_plot_line
public :: igBegin, igEnd, igButton, igCheckbox, igSliderScalar, igInputDouble, igTextUnformatted, igSameLine
public :: igSeparator, igShowDemoWindow, igSetNextWindowPos, igSetNextWindowSize, igGetItemRectMin, igGetItemRectMax
public :: ImPlot_BeginPlot, ImPlot_EndPlot, ImPlot_SetupAxes

! Status codes: must match native/figure_native.h.
integer(c_int), parameter :: FIG_OK            = 0_c_int !< Success.
integer(c_int), parameter :: FIG_ERR_STATE     = 1_c_int !< Call not allowed in the current state.
integer(c_int), parameter :: FIG_ERR_ARGUMENT  = 2_c_int !< Invalid argument.
integer(c_int), parameter :: FIG_ERR_FAILED    = 3_c_int !< The platform (SDL, OpenGL) reported a failure.
integer(c_int), parameter :: FIG_ERR_EXCEPTION = 4_c_int !< A C++ exception was caught at the boundary.

! Dear ImGui enums (cimgui.h, Dear ImGui v1.93.0).
integer(c_int), parameter :: IMGUI_DATATYPE_S32        = 4_c_int !< ImGuiDataType_S32.
integer(c_int), parameter :: IMGUI_DATATYPE_FLOAT      = 8_c_int !< ImGuiDataType_Float.
integer(c_int), parameter :: IMGUI_DATATYPE_DOUBLE     = 9_c_int !< ImGuiDataType_Double.
integer(c_int), parameter :: IMGUI_COND_ALWAYS         = 1_c_int !< ImGuiCond_Always.
integer(c_int), parameter :: IMGUI_COND_ONCE           = 2_c_int !< ImGuiCond_Once.
integer(c_int), parameter :: IMGUI_COND_FIRST_USE_EVER = 4_c_int !< ImGuiCond_FirstUseEver.

type, bind(C) :: im_vec2
   !< ImVec2_c: a 2D vector of floats, passed by value.
   real(c_float) :: x = 0.0_c_float !< Abscissa.
   real(c_float) :: y = 0.0_c_float !< Ordinate.
endtype im_vec2

interface
   ! ---- FIGURE glue ---------------------------------------------------------------------------------------------------
   function fig_init(title, title_len, width, height, vsync) result(status) bind(C, name='fig_init')
   !< Open the window and create the ImGui/ImPlot contexts.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: title(*)  !< Window title (UTF-8, not NUL-terminated).
   integer(c_int), value              :: title_len !< Title length [bytes].
   integer(c_int), value              :: width     !< Window width [logical pixels].
   integer(c_int), value              :: height    !< Window height [logical pixels].
   integer(c_int), value              :: vsync     !< 1: synchronize swaps with the display.
   integer(c_int)                     :: status    !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_init

   function fig_init_headless(width, height) result(status) bind(C, name='fig_init_headless')
   !< Create the ImGui/ImPlot contexts without a window or GPU (tests).
   import :: c_int
   implicit none
   integer(c_int), value :: width  !< Virtual display width [pixels].
   integer(c_int), value :: height !< Virtual display height [pixels].
   integer(c_int)        :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_init_headless

   function fig_begin_frame(running) result(status) bind(C, name='fig_begin_frame')
   !< Process events (waiting if lazy) and open a frame; `running` is 0 when the user closed the window.
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: running !< 1 while the application should keep running.
   integer(c_int)              :: status  !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_begin_frame

   function fig_end_frame() result(status) bind(C, name='fig_end_frame')
   !< Render the frame and present it.
   import :: c_int
   implicit none
   integer(c_int) :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_end_frame

   subroutine fig_shutdown() bind(C, name='fig_shutdown')
   !< Destroy contexts, window and platform; safe to call in any state.
   implicit none
   endsubroutine fig_shutdown

   subroutine fig_set_lazy(enabled, max_wait_s) bind(C, name='fig_set_lazy')
   !< Lazy redraw: sleep until an event or `max_wait_s` seconds once the UI has settled.
   import :: c_double, c_int
   implicit none
   integer(c_int), value :: enabled    !< 1: lazy redraw on.
   real(c_double), value :: max_wait_s !< Longest sleep [s].
   endsubroutine fig_set_lazy

   subroutine fig_request_frames(n) bind(C, name='fig_request_frames')
   !< Draw at least `n` more frames without waiting (animations, data that changed).
   import :: c_int
   implicit none
   integer(c_int), value :: n !< Frames.
   endsubroutine fig_request_frames

   function fig_content_scale() result(scale) bind(C, name='fig_content_scale')
   !< Display content scale (1 on standard displays, 2 on most high-DPI ones).
   import :: c_double
   implicit none
   real(c_double) :: scale !< Content scale.
   endfunction fig_content_scale

   function fig_last_error(len) result(msg) bind(C, name='fig_last_error')
   !< Message of the last failure (borrowed: copy it).
   import :: c_int, c_ptr
   implicit none
   integer(c_int), intent(out) :: len !< Message length [bytes].
   type(c_ptr)                 :: msg !< First byte of the message (borrowed).
   endfunction fig_last_error

   subroutine fig_input_mouse(x, y, left_down) bind(C, name='fig_input_mouse')
   !< Queue a synthetic mouse state (tests).
   import :: c_float, c_int
   implicit none
   real(c_float), value  :: x         !< Abscissa [pixels].
   real(c_float), value  :: y         !< Ordinate [pixels].
   integer(c_int), value :: left_down !< 1: left button pressed.
   endsubroutine fig_input_mouse

   function fig_plot_line(label, label_len, xs, ys, n) result(status) bind(C, name='fig_plot_line')
   !< ImPlot::PlotLine with default spec.
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in) :: label(*)  !< Item label (not NUL-terminated).
   integer(c_int), value              :: label_len !< Label length [bytes].
   real(c_double), intent(in)         :: xs(*)     !< Abscissae.
   real(c_double), intent(in)         :: ys(*)     !< Ordinates.
   integer(c_int), value              :: n         !< Number of points.
   integer(c_int)                     :: status    !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_plot_line

   ! ---- cimgui -------------------------------------------------------------------------------------------------------
   function igBegin(name, p_open, flags) result(visible) bind(C, name='igBegin')
   !< ImGui::Begin.
   import :: c_bool, c_char, c_int, c_ptr
   implicit none
   character(kind=c_char), intent(in) :: name(*) !< Window name (NUL-terminated).
   type(c_ptr), value                 :: p_open  !< bool* (c_null_ptr: no close button).
   integer(c_int), value              :: flags   !< ImGuiWindowFlags.
   logical(c_bool)                    :: visible !< False when collapsed or clipped.
   endfunction igBegin

   subroutine igEnd() bind(C, name='igEnd')
   !< ImGui::End (always called, whatever igBegin returned).
   implicit none
   endsubroutine igEnd

   function igButton(label, size) result(pressed) bind(C, name='igButton')
   !< ImGui::Button.
   import :: c_bool, c_char, im_vec2
   implicit none
   character(kind=c_char), intent(in) :: label(*) !< Label (NUL-terminated).
   type(im_vec2), value               :: size     !< Size (0, 0: fit the label).
   logical(c_bool)                    :: pressed  !< Clicked this frame.
   endfunction igButton

   function igCheckbox(label, v) result(changed) bind(C, name='igCheckbox')
   !< ImGui::Checkbox.
   import :: c_bool, c_char
   implicit none
   character(kind=c_char), intent(in) :: label(*) !< Label (NUL-terminated).
   logical(c_bool), intent(inout)     :: v        !< Value.
   logical(c_bool)                    :: changed  !< Toggled this frame.
   endfunction igCheckbox

   function igSliderScalar(label, data_type, p_data, p_min, p_max, format, flags) result(changed) &
      bind(C, name='igSliderScalar')
   !< ImGui::SliderScalar.
   import :: c_bool, c_char, c_int, c_ptr
   implicit none
   character(kind=c_char), intent(in) :: label(*)  !< Label (NUL-terminated).
   integer(c_int), value              :: data_type !< ImGuiDataType.
   type(c_ptr), value                 :: p_data    !< Value.
   type(c_ptr), value                 :: p_min     !< Minimum.
   type(c_ptr), value                 :: p_max     !< Maximum.
   type(c_ptr), value                 :: format    !< printf format (c_null_ptr: default).
   integer(c_int), value              :: flags     !< ImGuiSliderFlags.
   logical(c_bool)                    :: changed   !< Changed this frame.
   endfunction igSliderScalar

   function igInputDouble(label, v, step, step_fast, format, flags) result(changed) bind(C, name='igInputDouble')
   !< ImGui::InputDouble.
   import :: c_bool, c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in) :: label(*)  !< Label (NUL-terminated).
   real(c_double), intent(inout)      :: v         !< Value.
   real(c_double), value              :: step      !< +/- step (0: no buttons).
   real(c_double), value              :: step_fast !< Fast step.
   character(kind=c_char), intent(in) :: format(*) !< printf format (NUL-terminated).
   integer(c_int), value              :: flags     !< ImGuiInputTextFlags.
   logical(c_bool)                    :: changed   !< Changed this frame.
   endfunction igInputDouble

   subroutine igTextUnformatted(text, text_end) bind(C, name='igTextUnformatted')
   !< ImGui::TextUnformatted: no printf formatting.
   import :: c_char, c_ptr
   implicit none
   character(kind=c_char), intent(in) :: text(*)  !< Text (NUL-terminated when `text_end` is null).
   type(c_ptr), value                 :: text_end !< One past the last byte (c_null_ptr: up to the NUL).
   endsubroutine igTextUnformatted

   subroutine igSameLine(offset_from_start_x, spacing) bind(C, name='igSameLine')
   !< ImGui::SameLine.
   import :: c_float
   implicit none
   real(c_float), value :: offset_from_start_x !< 0: right after the previous item.
   real(c_float), value :: spacing             !< -1: default spacing.
   endsubroutine igSameLine

   subroutine igSeparator() bind(C, name='igSeparator')
   !< ImGui::Separator.
   implicit none
   endsubroutine igSeparator

   subroutine igShowDemoWindow(p_open) bind(C, name='igShowDemoWindow')
   !< ImGui::ShowDemoWindow.
   import :: c_ptr
   implicit none
   type(c_ptr), value :: p_open !< bool* (c_null_ptr: no close button).
   endsubroutine igShowDemoWindow

   subroutine igSetNextWindowPos(pos, cond, pivot) bind(C, name='igSetNextWindowPos')
   !< ImGui::SetNextWindowPos.
   import :: c_int, im_vec2
   implicit none
   type(im_vec2), value  :: pos   !< Position [pixels].
   integer(c_int), value :: cond  !< ImGuiCond.
   type(im_vec2), value  :: pivot !< Pivot (0, 0: top-left).
   endsubroutine igSetNextWindowPos

   subroutine igSetNextWindowSize(size, cond) bind(C, name='igSetNextWindowSize')
   !< ImGui::SetNextWindowSize.
   import :: c_int, im_vec2
   implicit none
   type(im_vec2), value  :: size !< Size [pixels].
   integer(c_int), value :: cond !< ImGuiCond.
   endsubroutine igSetNextWindowSize

   function igGetItemRectMin() result(corner) bind(C, name='igGetItemRectMin')
   !< ImGui::GetItemRectMin: top-left of the last item [screen pixels].
   import :: im_vec2
   implicit none
   type(im_vec2) :: corner !< Top-left corner [screen pixels].
   endfunction igGetItemRectMin

   function igGetItemRectMax() result(corner) bind(C, name='igGetItemRectMax')
   !< ImGui::GetItemRectMax: bottom-right of the last item [screen pixels].
   import :: im_vec2
   implicit none
   type(im_vec2) :: corner !< Bottom-right corner [screen pixels].
   endfunction igGetItemRectMax

   ! ---- cimplot ------------------------------------------------------------------------------------------------------
   function ImPlot_BeginPlot(title_id, size, flags) result(visible) bind(C, name='ImPlot_BeginPlot')
   !< ImPlot::BeginPlot.
   import :: c_bool, c_char, c_int, im_vec2
   implicit none
   character(kind=c_char), intent(in) :: title_id(*) !< Title (NUL-terminated).
   type(im_vec2), value               :: size        !< Size (-1, 0: full width, default height).
   integer(c_int), value              :: flags       !< ImPlotFlags.
   logical(c_bool)                    :: visible     !< Plot visible.
   endfunction ImPlot_BeginPlot

   subroutine ImPlot_EndPlot() bind(C, name='ImPlot_EndPlot')
   !< ImPlot::EndPlot (only if ImPlot_BeginPlot returned true).
   implicit none
   endsubroutine ImPlot_EndPlot

   subroutine ImPlot_SetupAxes(x_label, y_label, x_flags, y_flags) bind(C, name='ImPlot_SetupAxes')
   !< ImPlot::SetupAxes.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: x_label(*) !< X label (NUL-terminated).
   character(kind=c_char), intent(in) :: y_label(*) !< Y label (NUL-terminated).
   integer(c_int), value              :: x_flags    !< ImPlotAxisFlags.
   integer(c_int), value              :: y_flags    !< ImPlotAxisFlags.
   endsubroutine ImPlot_SetupAxes
endinterface
endmodule figure_c_native
