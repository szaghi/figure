!< figure_plot_colorbar, the plot frame's colour-scale legend: FIGURE's `ip_colormap_legend` drawn in Fortran.
module figure_plot_colorbar
!< figure_plot_colorbar, the plot frame's colour-scale legend: FIGURE's `ip_colormap_legend` drawn in Fortran.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 07). `pf_colormap_legend` and
!< `pf_colormap_legend_edit` draw what FIGURE's `fig_colormap_legend` (native/figure_colormap.cpp) draws for
!< `ip_colormap_legend` and `ip_colormap_legend_edit`, a Dear ImGui item of its own (not ImPlot's): a bar coloured by a
!< colormap of the frame's registry (figure_plot_colormaps) from vmin to vmax, its ticks and their values beside it.
!<
!< - The ticks: with `levels`, the bands' edges equally spaced in the scale, labelled with the precision they need
!<   (`parse_band_format`, `edge_label`: the format's precision raised until `strtod` of the label is the edge, up to
!<   6 decimals for f, 7 significant digits for e and g); without, round values (1, 2, 2.5 or 5 times a power of ten)
!<   about every 40 pixels (100 horizontal) on a linear scale, the decades on a log one, 0 and the signed decades on a
!<   symlog one (2 and 5 times them with fewer than two; round values with fewer still), thinned to the room their
!<   labels need (0 first, then the decades from the largest magnitude, then the others).
!< - The layout: the item's size (positive given, negative the room left, 0 the default), the bar `GetFrameHeight`
!<   thick on whole pixels with half a label's room at each end, the bands on whole pixels, a continuous bar as 64
!<   strips of two colours (`AddRectFilledMultiColor`), the border, the tick marks (4 pixels) and labels.
!< - `pf_colormap_legend_edit`: dragged along the bar the range moves with the pointer, the wheel zooms it about the
!<   value under the pointer (10% a step), in the scale's space; the wheel is the item's while hovered or held
!<   (`SetItemKeyOwner`).
!<
!< The labels are `snprintf` into 64 bytes (figure_plot_format: glibc's output, a format without conversion printed as
!< text); the C library's `log10`, `pow`, `asinh`, `sinh` as the native code calls them; float and double as there;
!< the ticks in module arrays grown once, the labels in fixed buffers: no allocation per frame (ADR 0001).
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_null_char, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure_cimgui_enums, only : ImGuiCol_Border, ImGuiCol_Text, ImGuiKey_MouseWheelY, ImGuiStyleVar_ItemInnerSpacing, &
                                ImGuiStyleVar_ItemSpacing
use figure_core, only : core_active_id, core_button_behavior, core_content_region_avail, core_cursor_screen_pos, &
                        core_draw_begin, core_draw_end, core_draw_line, core_draw_rect, core_draw_rect_filled,   &
                        core_draw_rect_filled_multicolor, core_draw_text, core_font_size, core_frame_height,     &
                        core_get_id, core_hovered_id, core_io_input, core_item_add, core_item_size,              &
                        core_mouse_pos, core_mouse_pos_valid, core_set_key_owner, core_style_color,              &
                        core_style_vec2, core_text_size
use figure_plot_colormaps, only : cm_count, cm_sample
use figure_plot_format, only : plot_format, fmt_parse, fmt_real, fmt_text
use figure_plot_locators, only : c_ceil, c_floor

implicit none
private
public :: pf_colormap_legend, pf_colormap_legend_edit

integer(int32), parameter :: LABEL_LEN = 63_int32   !< A label's room (snprintf into 64 bytes).
integer(int32), parameter :: EDGE_LEN = 127_int32   !< An edge label's room (its prefix and suffix around 63).
integer(int32), parameter :: MAX_LEVELS = 256_int32 !< Bands at most.
real(real32),   parameter :: TICK = 4.0_real32      !< A tick's length [pixels].
integer(int32), parameter :: STRIPS = 64_int32      !< A continuous bar's strips.

real(real64),   allocatable :: tk(:)      !< The ticks' values (grown once).
real(real64),   allocatable :: order(:)   !< ... sorted for the thinning.
real(real64),   allocatable :: rk(:)      !< ... their ranks.
integer(int32)              :: n_tk = 0_int32 !< Ticks.

interface
   pure function c_pow(x, y) result(r) bind(C, name='pow')
   !< C's `pow`.
   import :: c_double
   implicit none
   real(c_double), value :: x, y !< Base, exponent.
   real(c_double)        :: r    !< Power.
   endfunction c_pow

   pure function c_log10(x) result(r) bind(C, name='log10')
   !< C's `log10`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Logarithm.
   endfunction c_log10

   pure function c_asinh(x) result(r) bind(C, name='asinh')
   !< C's `asinh`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Inverse hyperbolic sine.
   endfunction c_asinh

   pure function c_sinh(x) result(r) bind(C, name='sinh')
   !< C's `sinh`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Hyperbolic sine.
   endfunction c_sinh

   function c_strtod(s, endp) result(v) bind(C, name='strtod')
   !< C's `strtod`.
   import :: c_char, c_double, c_ptr
   implicit none
   character(kind=c_char), intent(in)  :: s(*) !< Text, NUL-terminated.
   type(c_ptr),            intent(out) :: endp !< Where the number ends.
   real(c_double)                      :: v    !< Value.
   endfunction c_strtod
endinterface

type :: band_format
   !< `band_format`: a format of one f, e or g conversion split for raising its precision.
   logical           :: ok = .false.          !< Usable (else the format as it is).
   type(plot_format) :: f                     !< The conversion alone (no text around), its precision set per try.
   integer(int32)    :: precision = 6_int32   !< The format's precision.
   integer(int32)    :: max_precision = 6_int32 !< The highest tried.
endtype band_format

contains
   subroutine pf_colormap_legend(id, colormap, vmin, vmax, levels, horizontal, width, height, label_format, scale)
   !< A colour-scale legend (`ip_colormap_legend`): a bar coloured by `colormap` (an id of figure_plot_colormaps) from
   !< `vmin` to `vmax` (bottom to top, or left to right with `horizontal`), its ticks and values on its right (below);
   !< `levels` bands (2-256) or continuous; `scale` 'linear' (default), 'log', 'symlog'; `width`, `height` [pixels]
   !< (positive given, negative the room left, absent 0: the default); `label_format` a printf format of one real or a
   !< text ('' or absent: "%g"). An item of the current window. Usage errors (a colormap not registered, ends equal or
   !< not finite, levels out of range, ends not above 0 on 'log', an unknown scale) error-stop.
   character(len=*), intent(in)           :: id           !< Widget id, unique in the window (not shown).
   integer(int32),   intent(in)           :: colormap     !< Colormap.
   real(real64),     intent(in)           :: vmin         !< Value at the bottom (left).
   real(real64),     intent(in)           :: vmax         !< Value at the top (right).
   integer(int32),   intent(in), optional :: levels       !< Bands.
   logical,          intent(in), optional :: horizontal   !< Horizontal.
   real(real64),     intent(in), optional :: width        !< Width [pixels].
   real(real64),     intent(in), optional :: height       !< Height [pixels].
   character(len=*), intent(in), optional :: label_format !< printf format of one real, or a text.
   character(len=*), intent(in), optional :: scale        !< 'linear', 'log', 'symlog'.
   real(real64)                           :: range(2)     !< Unused.
   logical                                :: changed      !< Unused.

   call legend(id, colormap, vmin, vmax, levels, horizontal, width, height, label_format, scale, .false., range, &
               changed)
   endsubroutine pf_colormap_legend

   function pf_colormap_legend_edit(id, colormap, vmin, vmax, levels, horizontal, width, height, label_format, scale) &
      result(changed)
   !< `pf_colormap_legend` whose range the user changes (`ip_colormap_legend_edit`): dragged along the bar it moves
   !< with the pointer, the wheel zooms it about the value under the pointer (10% a step), in the scale's space;
   !< `vmin`, `vmax` updated in place, true on the frame they changed.
   character(len=*), intent(in)           :: id           !< Widget id, unique in the window (not shown).
   integer(int32),   intent(in)           :: colormap     !< Colormap.
   real(real64),     intent(inout)        :: vmin         !< Value at the bottom (left).
   real(real64),     intent(inout)        :: vmax         !< Value at the top (right).
   integer(int32),   intent(in), optional :: levels       !< Bands.
   logical,          intent(in), optional :: horizontal   !< Horizontal.
   real(real64),     intent(in), optional :: width        !< Width [pixels].
   real(real64),     intent(in), optional :: height       !< Height [pixels].
   character(len=*), intent(in), optional :: label_format !< printf format of one real, or a text.
   character(len=*), intent(in), optional :: scale        !< 'linear', 'log', 'symlog'.
   logical                                :: changed      !< The range changed on this frame.
   real(real64)                           :: range(2)     !< The range after this frame's input.

   call legend(id, colormap, vmin, vmax, levels, horizontal, width, height, label_format, scale, .true., range, &
               changed)
   if (changed) then
      vmin = range(1)
      vmax = range(2)
   endif
   endfunction pf_colormap_legend_edit

   subroutine legend(id, cmap, vmin, vmax, levels, horizontal, width, height, label_format, scale, interactive, range, &
                     changed)
   !< `fig_colormap_legend`.
   character(len=*), intent(in)           :: id           !< Widget id.
   integer(int32),   intent(in)           :: cmap         !< Colormap.
   real(real64),     intent(in)           :: vmin, vmax   !< Range.
   integer(int32),   intent(in), optional :: levels       !< Bands.
   logical,          intent(in), optional :: horizontal   !< Horizontal.
   real(real64),     intent(in), optional :: width        !< Width [pixels].
   real(real64),     intent(in), optional :: height       !< Height [pixels].
   character(len=*), intent(in), optional :: label_format !< Format.
   character(len=*), intent(in), optional :: scale        !< Scale.
   logical,          intent(in)           :: interactive  !< Dragged and scrolled.
   real(real64),     intent(out)          :: range(2)     !< The range after this frame's input.
   logical,          intent(out)          :: changed      !< Changed.
   type(plot_format)                      :: fmt          !< The labels' format.
   type(band_format)                      :: bf           !< ... split for the band edges.
   integer(int32)                         :: lv, sc, k, j, item, nl !< Bands, scale, counters, item, a label's length.
   logical                                :: horz, hovered, held, room !< Horizontal, the item's state, room.
   real(real64)                           :: s0, s1, lo, hi, n0, n1, d, sp, f, a, b, t0, t1, m, cw, ch !< Values.
   real(real64)                           :: ax, ay, mx, my, dx, dy, wheel, wheel_h, dmax(5), iis(2), isp(2) !< ...
   real(real32)                           :: bar, text_h, avail(2), length0, label_w, size_(2), pos(2), r(4) !< ...
   real(real32)                           :: length, p, gap, fa, fb, w_, h_ !< ...
   integer(int32)                         :: c0, c1, col, mods !< Colours, key mods.
   logical                                :: dnd          !< A drag and drop.
   character(len=EDGE_LEN)                :: lab          !< A label.
   integer(int32)                         :: kmin, kmax, pass !< Decades, pass.

   range(1) = vmin
   range(2) = vmax
   changed = .false.
   lv = 0_int32
   if (present(levels)) lv = levels
   horz = .false.
   if (present(horizontal)) horz = horizontal
   sc = 0_int32
   if (present(scale)) then
      select case (scale)
      case ('linear')
         sc = 0_int32
      case ('log')
         sc = 1_int32
      case ('symlog')
         sc = 2_int32
      case default
         error stop "figure_plot_colorbar: a scale is 'linear', 'log' or 'symlog'"
      endselect
   endif
   if (cmap < 0_int32 .or. cmap >= cm_count()) error stop 'figure_plot_colorbar: the colormap is not registered'
   if (.not. (abs(vmin) <= huge(1.0_real64) .and. abs(vmax) <= huge(1.0_real64)) .or. vmin == vmax) &
      error stop 'figure_plot_colorbar: vmin and vmax must be finite and different'
   if (lv /= 0_int32 .and. (lv < 2_int32 .or. lv > MAX_LEVELS)) error stop 'figure_plot_colorbar: levels in [2, 256]'
   if (sc == 1_int32 .and. (vmin <= 0.0_real64 .or. vmax <= 0.0_real64)) &
      error stop 'figure_plot_colorbar: a log scale needs vmin and vmax above 0'
   s0 = fwd(vmin)
   s1 = fwd(vmax)
   call fmt_parse('%g', fmt)
   if (present(label_format)) then
      if (len(label_format) > 0) call fmt_parse(label_format, fmt)
   endif
   bf = band_of(fmt)
   call core_style_vec2(ImGuiStyleVar_ItemInnerSpacing, iis(1), iis(2)) ! (no lookup by name: no allocation)
   call core_style_vec2(ImGuiStyleVar_ItemSpacing, isp(1), isp(2))
   bar = real(core_frame_height(), real32)
   text_h = real(core_font_size(), real32)
   call core_content_region_avail(ax, ay)
   avail = [real(ax, real32), real(ay, real32)]
   if (horz) then
      length0 = extent(opt(width), avail(1), avail(1))
   else
      length0 = extent(opt(height), avail(2), 300.0_real32)
   endif
   ! the ticks
   lo = min(vmin, vmax)
   hi = max(vmin, vmax)
   n_tk = 0_int32
   if (lv > 0_int32) then ! band edges, equally spaced in the scale
      do k = 0_int32, lv
         if (k == 0_int32) then
            call add(vmin)
         elseif (k == lv) then
            call add(vmax)
         else
            d = (s1 - s0) * real(k, real64)
            d = d / real(lv, real64)
            call add(inv(s0 + d))
         endif
      enddo
   elseif (sc == 0_int32) then
      call round_ticks()
   else ! decades (log), 0 and the signed decades (symlog); 2 and 5 times them with fewer than two; round values
      m = max(abs(lo), abs(hi))
      kmax = int(c_ceil(c_log10(m)), int32) + 1_int32
      if (sc == 1_int32) then
         kmin = int(c_floor(c_log10(lo)), int32) - 1_int32
      else
         kmin = kmax - 14_int32
      endif
      do pass = 0_int32, 1_int32
         if (n_tk >= 2_int32) exit
         n_tk = 0_int32
         if (sc == 2_int32 .and. inside(0.0_real64)) call add(0.0_real64)
         do k = kmin, kmax
            do j = 1_int32, merge(1_int32, 3_int32, pass == 0_int32)
               a = merge(1.0_real64, merge(2.0_real64, 5.0_real64, j == 2_int32), j == 1_int32)
               d = a * c_pow(10.0_real64, real(k, real64))
               if (inside(d)) call add(d)
               if (sc == 2_int32 .and. inside(-d)) call add(-d)
            enddo
         enddo
      enddo
      if (n_tk < 2_int32) call round_ticks()
   endif
   label_w = 0.0_real32
   do k = 1_int32, n_tk
      call tick_label(tk(k), lab, nl)
      call core_text_size(lab(1:nl), cw, ch)
      label_w = max(label_w, real(cw, real32))
   enddo
   if (horz) then
      size_(1) = length0
      fa = bar + TICK
      fa = fa + real(iis(2), real32)
      fa = fa + text_h
      size_(2) = extent(opt(height), avail(2), fa)
   else
      fa = bar + TICK
      fa = fa + real(iis(1), real32)
      fa = fa + label_w
      size_(1) = extent(opt(width), avail(1), fa)
      size_(2) = length0
   endif
   call core_cursor_screen_pos(ax, ay)
   pos = [real(ax, real32), real(ay, real32)]
   item = core_get_id(id)
   call core_item_size(real(size_(1), real64), real(size_(2), real64))
   if (.not. core_item_add(real(pos(1), real64), real(pos(2), real64), real(pos(1) + size_(1), real64), &
                           real(pos(2) + size_(2), real64), item)) return
   ! the bar, half a label's room beyond each end, on whole pixels
   if (horz) then
      r(1) = pos(1) + label_w * 0.5_real32
      r(2) = pos(2)
      r(3) = (pos(1) + size_(1)) - label_w * 0.5_real32
      r(4) = pos(2) + bar
   else
      r(1) = pos(1)
      r(2) = pos(2) + text_h * 0.5_real32
      r(3) = pos(1) + bar
      r(4) = (pos(2) + size_(2)) - text_h * 0.5_real32
   endif
   do k = 1_int32, 4_int32
      r(k) = floor_f(r(k))
   enddo
   if (r(3) <= r(1) .or. r(4) <= r(2)) return
   length = merge(r(3) - r(1), r(4) - r(2), horz)
   if (interactive) then
      if (core_button_behavior(real(pos(1), real64), real(pos(2), real64), real(pos(1) + size_(1), real64), &
                               real(pos(2) + size_(2), real64), item, hovered, held)) continue
      if (core_hovered_id() == item .or. core_active_id() == item) & ! SetItemKeyOwner
         call core_set_key_owner(ImGuiKey_MouseWheelY, item)
      call core_io_input(dx, dy, wheel, wheel_h, dmax, mods, dnd)
      call core_mouse_pos(mx, my)
      n0 = s0
      n1 = s1
      if (held .and. core_mouse_pos_valid()) then
         p = merge(real(dx, real32), -real(dy, real32), horz)
         if (p /= 0.0_real32) then
            d = real(p, real64) / real(length, real64)
            d = d * (s1 - s0)
            n0 = n0 - d
            n1 = n1 - d
         endif
      endif
      if (hovered .and. wheel /= 0.0_real64 .and. core_mouse_pos_valid()) then
         if (horz) then
            p = (real(mx, real32) - r(1)) / length
         else
            p = (r(4) - real(my, real32)) / length
         endif
         d = (n1 - n0) * min(max(real(p, real64), 0.0_real64), 1.0_real64)
         sp = n0 + d
         f = c_pow(1.1_real64, -real(real(wheel, real32), real64))
         d = (n0 - sp) * f
         n0 = sp + d
         d = (n1 - sp) * f
         n1 = sp + d
      endif
      if (n0 /= s0 .or. n1 /= s1) then
         a = inv(n0)
         b = inv(n1)
         if (abs(a) <= huge(1.0_real64) .and. abs(b) <= huge(1.0_real64) .and. a /= b .and. &
             (sc /= 1_int32 .or. (a > 0.0_real64 .and. b > 0.0_real64))) then
            range(1) = a
            range(2) = b
            changed = .true.
         endif
      endif
   endif
   if (sc /= 0_int32 .and. lv == 0_int32) call thin()
   call core_draw_begin()
   if (lv > 0_int32) then
      do k = 0_int32, lv - 1_int32
         fa = floor_f(at(real(k, real64) / real(lv, real64)) + 0.5_real32) ! bands on whole pixels
         fb = floor_f(at(real(k + 1_int32, real64) / real(lv, real64)) + 0.5_real32)
         col = cm_sample(cmap, real((real(k, real64) + 0.5_real64) / real(lv, real64), real32))
         if (horz) then
            call core_draw_rect_filled(real(fa, real64), real(r(2), real64), real(fb, real64), real(r(4), real64), col)
         else
            call core_draw_rect_filled(real(r(1), real64), real(fb, real64), real(r(3), real64), real(fa, real64), col)
         endif
      enddo
   else
      do k = 0_int32, STRIPS - 1_int32
         t0 = real(k, real64) / real(STRIPS, real64)
         t1 = real(k + 1_int32, real64) / real(STRIPS, real64)
         c0 = cm_sample(cmap, real(t0, real32))
         c1 = cm_sample(cmap, real(t1, real32))
         fa = at(t0)
         fb = at(t1)
         if (horz) then
            call core_draw_rect_filled_multicolor(real(fa, real64), real(r(2), real64), real(fb, real64), &
                                                  real(r(4), real64), c0, c1, c1, c0)
         else
            call core_draw_rect_filled_multicolor(real(r(1), real64), real(fb, real64), real(r(3), real64), &
                                                  real(fa, real64), c1, c1, c0, c0)
         endif
      enddo
   endif
   call core_draw_rect(real(r(1), real64), real(r(2), real64), real(r(3), real64), real(r(4), real64), &
                       core_style_color(ImGuiCol_Border))
   col = core_style_color(ImGuiCol_Text)
   do k = 1_int32, n_tk
      p = at(frac(tk(k)))
      call tick_label(tk(k), lab, nl)
      call core_text_size(lab(1:nl), cw, ch)
      w_ = real(cw, real32)
      h_ = real(ch, real32)
      if (horz) then
         call core_draw_line(real(p, real64), real(r(4), real64), real(p, real64), real(r(4) + TICK, real64), col)
         call core_draw_text(real(p - w_ * 0.5_real32, real64), &
                             real((r(4) + TICK) + real(iis(2), real32), real64), col, lab(1:nl))
      else
         call core_draw_line(real(r(3), real64), real(p, real64), real(r(3) + TICK, real64), real(p, real64), col)
         call core_draw_text(real((r(3) + TICK) + real(iis(1), real32), real64), &
                             real(p - h_ * 0.5_real32, real64), col, lab(1:nl))
      endif
   enddo
   call core_draw_end()
   contains
      pure function opt(v) result(x)
      !< A size given or 0.
      real(real64), intent(in), optional :: v !< Size.
      real(real32)                       :: x !< As float.

      x = 0.0_real32
      if (present(v)) x = real(v, real32)
      endfunction opt

      pure function extent(v, left, fallback) result(e)
      !< A size: given (> 0), the room left (< 0, at least 1), or the default (0).
      real(real32), intent(in) :: v, left, fallback !< Size, room, default.
      real(real32)             :: e                 !< Extent.

      if (v > 0.0_real32) then
         e = v
      elseif (v < 0.0_real32) then
         e = max(left, 1.0_real32)
      else
         e = fallback
      endif
      endfunction extent

      function fwd(v) result(s)
      !< The scale's transform: log10, 2 asinh(v/2), or v.
      real(real64), intent(in) :: v !< Value.
      real(real64)             :: s !< Transformed.

      select case (sc)
      case (1_int32)
         s = c_log10(v)
      case (2_int32)
         s = 2.0_real64 * c_asinh(v / 2.0_real64)
      case default
         s = v
      endselect
      endfunction fwd

      function inv(s) result(v)
      !< The inverse transform.
      real(real64), intent(in) :: s !< Transformed.
      real(real64)             :: v !< Value.

      select case (sc)
      case (1_int32)
         v = c_pow(10.0_real64, s)
      case (2_int32)
         v = 2.0_real64 * c_sinh(s / 2.0_real64)
      case default
         v = s
      endselect
      endfunction inv

      function frac(v) result(t)
      !< The value's fraction along the bar.
      real(real64), intent(in) :: v !< Value.
      real(real64)             :: t !< Fraction.

      t = (fwd(v) - s0) / (s1 - s0)
      endfunction frac

      function at(t) result(px)
      !< The pixel of the fraction t along the bar (vmin at the bottom, or left).
      real(real64), intent(in) :: t  !< Fraction.
      real(real32)             :: px !< Pixel.
      real(real32)             :: q  !< A product.

      if (horz) then
         q = real(t, real32) * (r(3) - r(1))
         px = r(1) + q
      else
         q = real(t, real32) * (r(4) - r(2))
         px = r(4) - q
      endif
      endfunction at

      function inside(v) result(yes)
      !< v within the range, by 1e-12 of its ends.
      real(real64), intent(in) :: v   !< Value.
      logical                  :: yes !< Inside.
      real(real64)             :: e   !< A product.

      e = 1.0e-12_real64 * abs(lo)
      yes = v >= lo - e
      e = 1.0e-12_real64 * abs(hi)
      yes = yes .and. v <= hi + e
      endfunction inside

      subroutine add(v)
      !< A tick appended (the arrays grown when full).
      real(real64), intent(in) :: v !< Value.
      real(real64), allocatable :: more(:) !< Grown storage.

      if (.not. allocated(tk)) allocate(tk(64), order(64), rk(64))
      if (n_tk == size(tk, kind=int32)) then
         allocate(more(2_int32 * n_tk))
         more(1:n_tk) = tk(1:n_tk)
         call move_alloc(more, tk)
         deallocate(order, rk)
         allocate(order(2_int32 * n_tk), rk(2_int32 * n_tk))
      endif
      n_tk = n_tk + 1_int32
      tk(n_tk) = v
      endsubroutine add

      subroutine round_ticks()
      !< Round values (1, 2, 2.5, 5 times a power of ten), about every 40 pixels (100 horizontal).
      real(real64) :: count, raw, pw, step, q, e, top !< The step's making, the counter.
      integer(int32) :: i                             !< Candidate.
      real(real64), parameter :: S(4) = [5.0_real64, 2.5_real64, 2.0_real64, 1.0_real64] !< Candidates.

      n_tk = 0_int32
      count = max(2.0_real64, c_floor(real(length0, real64) / merge(100.0_real64, 40.0_real64, horz)))
      raw = (hi - lo) / count
      pw = c_pow(10.0_real64, c_floor(c_log10(raw)))
      step = 10.0_real64 * pw
      do i = 1_int32, 4_int32
         e = S(i) * pw
         e = e * (1.0_real64 + 1.0e-12_real64)
         if (raw <= e) step = S(i) * pw
      enddo
      q = c_ceil(lo / step - 1.0e-9_real64)
      top = hi * (1.0_real64 + 1.0e-12_real64)
      top = top + 1.0e-300_real64
      do
         e = q * step
         if (.not. e <= top) exit
         if (abs(q) < 0.5_real64) then
            call add(0.0_real64)
         else
            call add(e)
         endif
         q = q + 1.0_real64
      enddo
      endsubroutine round_ticks

      subroutine thin()
      !< Ticks too close along the bar for their labels thinned: 0 first, then the decades from the largest magnitude,
      !< then the others (a stable sort by rank), each kept when no kept one is within a label's room.
      integer(int32) :: i, jj, nk  !< Counters, kept.
      real(real64)   :: v, rv      !< A tick, its rank.
      real(real32)   :: pk         !< A kept tick's pixel.

      do i = 1_int32, n_tk ! stable insertion sort by rank
         v = tk(i)
         rv = rank(v)
         jj = i - 1_int32
         do while (jj >= 1_int32)
            if (.not. rk(jj) > rv) exit
            order(jj + 1_int32) = order(jj)
            rk(jj + 1_int32) = rk(jj)
            jj = jj - 1_int32
         enddo
         order(jj + 1_int32) = v
         rk(jj + 1_int32) = rv
      enddo
      if (horz) then
         gap = label_w + real(isp(1), real32)
      else
         gap = text_h * 1.2_real32
      endif
      nk = 0_int32
      do i = 1_int32, n_tk
         p = real(frac(order(i)), real32) * length
         room = .true.
         do jj = 1_int32, nk
            pk = real(frac(tk(jj)), real32) * length
            if (abs(pk - p) < gap) room = .false.
         enddo
         if (room) then
            nk = nk + 1_int32
            tk(nk) = order(i)
         endif
      enddo
      n_tk = nk
      endsubroutine thin

      function rank(v) result(rr)
      !< A tick's rank: 0 for 0, decades before the others, larger magnitudes first.
      real(real64), intent(in) :: v  !< Tick.
      real(real64)             :: rr !< Rank.
      real(real64)             :: e  !< Its decade.

      if (v == 0.0_real64) then
         rr = 0.0_real64
         return
      endif
      e = c_log10(abs(v))
      rr = merge(1.0_real64, 2.0_real64, abs(e - anint(e)) < 1.0e-9_real64) * 1.0e3_real64
      rr = rr - e
      endfunction rank

      subroutine tick_label(v, s, n)
      !< A tick's label: a band edge's (`edge_label`) or the format's (`label`).
      real(real64),     intent(in)  :: v !< Value.
      character(len=*), intent(out) :: s !< Label.
      integer(int32),   intent(out) :: n !< Its length.

      if (lv > 0_int32) then
         call edge_label(bf, fmt, v, s, n)
      else
         n = 0_int32
         call fmt_real(s(1:LABEL_LEN), n, fmt, v)
      endif
      endsubroutine tick_label
   endsubroutine legend

   function band_of(f) result(b)
   !< `parse_band_format`: usable for an f, e or g conversion (its text around kept by `f`'s prefix and suffix), the
   !< precision tried from the format's (6 when absent) up to max(it, 7 for g, 6 else).
   type(plot_format), intent(in) :: f !< The parsed format.
   type(band_format)             :: b !< Split.

   b%ok = f%ok .and. .not. f%text .and. scan(f%ctype, 'fFeEgG') > 0
   if (.not. b%ok) return
   b%f = f
   b%f%prefix_len = 0_int32
   b%f%suffix_len = 0_int32
   b%precision = merge(f%prec, 6_int32, f%prec >= 0_int32)
   b%max_precision = max(b%precision, merge(7_int32, 6_int32, scan(f%ctype, 'gG') > 0))
   endfunction band_of

   subroutine edge_label(b, f, v, s, n)
   !< `edge_label`: the conversion at the format's precision raised until `strtod` of what it prints is v (to 0.5e-6,
   !< relative for e and g), the format's text around it; the format as it is when it is not one of f, e, g.
   type(band_format), intent(in)  :: b !< Split format.
   type(plot_format), intent(in)  :: f !< The format.
   real(real64),      intent(in)  :: v !< Value.
   character(len=*),  intent(out) :: s !< Label.
   integer(int32),    intent(out) :: n !< Its length.
   type(plot_format)              :: g !< The conversion at a precision.
   character(len=LABEL_LEN)       :: buf !< What it prints (64 bytes).
   character(kind=c_char), target :: cb(LABEL_LEN + 1) !< ... NUL-terminated.
   integer(int32)                 :: p, nb, k !< Precision, length, counter.
   type(c_ptr)                    :: e   !< Unused.
   real(real64)                   :: shown, tol !< The value read back, the tolerance.

   n = 0_int32
   if (.not. b%ok) then
      call fmt_real(s(1:LABEL_LEN), n, f, v)
      return
   endif
   g = b%f
   do p = b%precision, b%max_precision
      g%prec = p
      nb = 0_int32
      call fmt_real(buf, nb, g, v)
      do k = 1_int32, nb
         cb(k) = buf(k:k)
      enddo
      cb(nb + 1_int32) = c_null_char
      shown = c_strtod(cb, e)
      n = 0_int32
      call fmt_text(s, n, f%prefix(1:f%prefix_len))
      call fmt_text(s, n, buf(1:nb))
      call fmt_text(s, n, f%suffix(1:f%suffix_len))
      tol = 0.5e-6_real64 * merge(1.0_real64, abs(v), scan(f%ctype, 'fF') > 0)
      if (abs(shown - v) <= tol) exit
   enddo
   endsubroutine edge_label

   pure function floor_f(x) result(r)
   !< `std::floor` of a float.
   real(real32), intent(in) :: x !< Value.
   real(real32)             :: r !< Floor.

   r = real(floor(x), real32)
   endfunction floor_f

endmodule figure_plot_colorbar
