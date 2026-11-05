!< figure_imgui, Dear ImGui widgets with Fortran arguments.
module figure_imgui
!< figure_imgui, Dear ImGui widgets with Fortran arguments.
!<
!< Immediate mode: call the widgets every frame; each returns what happened this frame (`ig_button` is true on the
!< frame it is clicked, `ig_checkbox`/`ig_slider` are true when they changed the value). Values are ordinary Fortran
!< variables, updated in place: no handles, no callbacks, no `target` requirements (the C `bool*` of a checkbox is a
!< local copy, written back).
use, intrinsic :: iso_c_binding, only : c_bool, c_double, c_float, c_int, c_loc, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure_base, only : cstr
use figure_c_native, only : fig_texture_sampling
use figure_texture, only : texture_object, texture_ref
use figure_cimgui, only : im_vec2, igBegin, igButton, igCheckbox, igEnd, igGetItemRectMax, igGetItemRectMin, igImage,     &
                          igInputDouble, igSameLine, igSeparator, igSetNextWindowPos, igSetNextWindowSize, igShowDemoWindow, &
                          igSliderScalar, igTextUnformatted
use figure_cimgui_enums, only : ImGuiCond_Always, ImGuiCond_FirstUseEver, ImGuiDataType_Double, ImGuiDataType_Float, &
                                ImGuiDataType_S32

implicit none
private
public :: ig_begin, ig_end, ig_button, ig_checkbox, ig_slider, ig_input, ig_text, ig_same_line, ig_separator
public :: ig_show_demo_window, ig_set_next_window, ig_item_rect, ig_image

interface ig_slider
   !< Slider for an integer or a real value.
   module procedure ig_slider_i32, ig_slider_r32, ig_slider_r64
endinterface ig_slider

contains
   function ig_begin(name, open) result(visible)
   !< Begin a window; always pair with `ig_end`. With `open`, the window has a close button that sets it false.
   character(len=*), intent(in)              :: name    !< Window name (unique id and title).
   logical,          intent(inout), optional :: open    !< Window open.
   logical                                   :: visible !< False when collapsed or clipped: skip its content.
   logical(c_bool), target                   :: o       !< C copy of `open`.
   type(c_ptr)                               :: p       !< bool* or null.

   p = c_null_ptr
   if (present(open)) then
      o = logical(open, c_bool)
      p = c_loc(o)
   endif
   visible = logical(igBegin(cstr(name), p, 0_c_int))
   if (present(open)) open = logical(o)
   endfunction ig_begin

   subroutine ig_end()
   !< End the window opened by `ig_begin` (whatever it returned).
   call igEnd()
   endsubroutine ig_end

   subroutine ig_set_next_window(x, y, width, height, always)
   !< Position (and size) of the next window [pixels]: on first use only, or every frame if `always`.
   real(real64), intent(in)           :: x      !< Left [pixels].
   real(real64), intent(in)           :: y      !< Top [pixels].
   real(real64), intent(in), optional :: width  !< Width [pixels].
   real(real64), intent(in), optional :: height !< Height [pixels].
   logical,      intent(in), optional :: always !< Enforce every frame (default: first use only).
   integer(c_int)                     :: cond   !< ImGuiCond.

   cond = ImGuiCond_FirstUseEver
   if (present(always)) then
      if (always) cond = ImGuiCond_Always
   endif
   call igSetNextWindowPos(im_vec2(real(x, c_float), real(y, c_float)), cond, im_vec2(0.0_c_float, 0.0_c_float))
   if (present(width) .and. present(height)) &
      call igSetNextWindowSize(im_vec2(real(width, c_float), real(height, c_float)), cond)
   endsubroutine ig_set_next_window

   function ig_button(label, width, height) result(pressed)
   !< A button; true on the frame it is clicked.
   character(len=*), intent(in)           :: label   !< Label.
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: fit the label).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: fit the label).
   logical                                :: pressed !< Clicked this frame.
   type(im_vec2)                          :: extent   !< Size (not `size`: see docs/guide/known-issues.md).

   extent = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   pressed = logical(igButton(cstr(label), extent))
   endfunction ig_button

   function ig_checkbox(label, value) result(changed)
   !< A check box bound to `value`; true when the user toggled it.
   character(len=*), intent(in)    :: label   !< Label.
   logical,          intent(inout) :: value   !< Value.
   logical                         :: changed !< Toggled this frame.
   logical(c_bool), target         :: v       !< C copy of `value`.

   v = logical(value, c_bool)
   changed = logical(igCheckbox(cstr(label), c_loc(v)))
   value = logical(v)
   endfunction ig_checkbox

   function ig_slider_i32(label, value, vmin, vmax) result(changed)
   !< Integer slider; true when the user changed `value`.
   character(len=*), intent(in)    :: label   !< Label.
   integer(int32),   intent(inout) :: value   !< Value.
   integer(int32),   intent(in)    :: vmin    !< Minimum.
   integer(int32),   intent(in)    :: vmax    !< Maximum.
   logical                         :: changed !< Changed this frame.
   integer(c_int), target          :: v       !< C copy of `value`.
   integer(c_int), target          :: lo      !< C copy of `vmin`.
   integer(c_int), target          :: hi      !< C copy of `vmax`.

   v = int(value, c_int)
   lo = int(vmin, c_int)
   hi = int(vmax, c_int)
   changed = logical(igSliderScalar(cstr(label), ImGuiDataType_S32, c_loc(v), c_loc(lo), c_loc(hi), c_null_ptr, 0_c_int))
   value = int(v, int32)
   endfunction ig_slider_i32

   function ig_slider_r32(label, value, vmin, vmax) result(changed)
   !< Single-precision slider; true when the user changed `value`.
   character(len=*), intent(in)    :: label   !< Label.
   real(real32),     intent(inout) :: value   !< Value.
   real(real32),     intent(in)    :: vmin    !< Minimum.
   real(real32),     intent(in)    :: vmax    !< Maximum.
   logical                         :: changed !< Changed this frame.
   real(c_float), target           :: v       !< C copy of `value`.
   real(c_float), target           :: lo      !< C copy of `vmin`.
   real(c_float), target           :: hi      !< C copy of `vmax`.

   v = real(value, c_float)
   lo = real(vmin, c_float)
   hi = real(vmax, c_float)
   changed = logical(igSliderScalar(cstr(label), ImGuiDataType_Float, c_loc(v), c_loc(lo), c_loc(hi), c_null_ptr, &
                                    0_c_int))
   value = real(v, real32)
   endfunction ig_slider_r32

   function ig_slider_r64(label, value, vmin, vmax) result(changed)
   !< Double-precision slider; true when the user changed `value`.
   character(len=*), intent(in)    :: label   !< Label.
   real(real64),     intent(inout) :: value   !< Value.
   real(real64),     intent(in)    :: vmin    !< Minimum.
   real(real64),     intent(in)    :: vmax    !< Maximum.
   logical                         :: changed !< Changed this frame.
   real(c_double), target          :: v       !< C copy of `value`.
   real(c_double), target          :: lo      !< C copy of `vmin`.
   real(c_double), target          :: hi      !< C copy of `vmax`.

   v = real(value, c_double)
   lo = real(vmin, c_double)
   hi = real(vmax, c_double)
   changed = logical(igSliderScalar(cstr(label), ImGuiDataType_Double, c_loc(v), c_loc(lo), c_loc(hi), c_null_ptr, &
                                    0_c_int))
   value = real(v, real64)
   endfunction ig_slider_r64

   function ig_input(label, value, step, format) result(changed)
   !< Numeric input field for a real value; true when the user changed it.
   character(len=*), intent(in)           :: label   !< Label.
   real(real64),     intent(inout)        :: value   !< Value.
   real(real64),     intent(in), optional :: step    !< +/- buttons step (default: none).
   character(len=*), intent(in), optional :: format  !< printf format (default '%.6g').
   logical                                :: changed !< Changed this frame.
   real(c_double), target                 :: v       !< C copy of `value`.
   real(c_double)                         :: s       !< Step.

   v = real(value, c_double)
   s = 0.0_c_double
   if (present(step)) s = real(step, c_double)
   if (present(format)) then
      changed = logical(igInputDouble(cstr(label), c_loc(v), s, 10.0_c_double * s, cstr(format), 0_c_int))
   else
      changed = logical(igInputDouble(cstr(label), c_loc(v), s, 10.0_c_double * s, cstr('%.6g'), 0_c_int))
   endif
   value = real(v, real64)
   endfunction ig_input

   subroutine ig_text(text)
   !< Plain text (no formatting: compose it with Fortran internal writes).
   character(len=*), intent(in) :: text !< Text.

   call igTextUnformatted(cstr(text), c_null_ptr)
   endsubroutine ig_text

   subroutine ig_same_line()
   !< Put the next item on the same line as the previous one.
   call igSameLine(0.0_c_float, -1.0_c_float)
   endsubroutine ig_same_line

   subroutine ig_separator()
   !< Horizontal separator.
   call igSeparator()
   endsubroutine ig_separator

   subroutine ig_show_demo_window(open)
   !< The Dear ImGui demo window (a live catalogue of every widget).
   logical, intent(inout), optional :: open !< Window open (close button).
   logical(c_bool), target          :: o    !< C copy of `open`.

   if (present(open)) then
      o = logical(open, c_bool)
      call igShowDemoWindow(c_loc(o))
      open = logical(o)
   else
      call igShowDemoWindow(c_null_ptr)
   endif
   endsubroutine ig_show_demo_window

   subroutine ig_item_rect(xmin, ymin, xmax, ymax)
   !< Screen rectangle of the last item [pixels] (tests, custom layout).
   real(real64), intent(out) :: xmin !< Left.
   real(real64), intent(out) :: ymin !< Top.
   real(real64), intent(out) :: xmax !< Right.
   real(real64), intent(out) :: ymax !< Bottom.
   type(im_vec2)             :: v    !< Corner.

   v = igGetItemRectMin()
   xmin = real(v%x, real64)
   ymin = real(v%y, real64)
   v = igGetItemRectMax()
   xmax = real(v%x, real64)
   ymax = real(v%y, real64)
   endsubroutine ig_item_rect

   subroutine ig_image(tex, width, height)
   !< A texture, pixel row 1 at the top (screen and image-file convention), `width` x `height` pixels (default: the
   !< texture's size).
   type(texture_object), intent(in)           :: tex    !< Texture.
   real(real64),         intent(in), optional :: width  !< Width [pixels].
   real(real64),         intent(in), optional :: height !< Height [pixels].
   type(im_vec2)                              :: extent !< Size (named so: a local `size` crashes nvfortran 26.9).

   extent = im_vec2(real(tex%width(), c_float), real(tex%height(), c_float))
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   call fig_texture_sampling(0_c_int, 1_c_int) ! the texture's own filter (nearest unless created smooth)
   call igImage(texture_ref(tex), extent, im_vec2(0.0_c_float, 0.0_c_float), im_vec2(1.0_c_float, 1.0_c_float))
   call fig_texture_sampling(0_c_int, 0_c_int)
   endsubroutine ig_image
endmodule figure_imgui
