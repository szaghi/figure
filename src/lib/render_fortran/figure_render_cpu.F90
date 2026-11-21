!< figure_render_cpu, the CPU renderer: a frame's triangles drawn as the OpenGL 3 backend draws them on a GPU.
module figure_render_cpu
!< figure_render_cpu, the CPU renderer: a frame's triangles drawn as the OpenGL 3 backend draws them on a GPU.
!<
!< szaghi/figure#15 P9: native/figure_swrast.cpp in Fortran, the same picture to the bit (the C++ stays the current
!< path's renderer until P27). What imgui_impl_opengl3.cpp asks of a GPU:
!<
!< - triangles from the index buffer, placed by the backend's orthographic projection and the viewport, no culling;
!< - the scissor rectangle of each command as the backend computes it for glScissor (its corner and size truncated);
!< - fragment = vertex colour (interpolated) * texel (RGBA8, clamp to edge); the sampler linear by default, the
!<   texture's own filter after the "from the texture" callback, linear again after the reset, linear or nearest after
!<   the callbacks of those names;
!< - blending rgb = src * a + dst * (1 - a) into an 8-bit RGB picture, rounded after every triangle.
!<
!< Rasterization: vertices placed as the vertex shader and the viewport place them (single precision), snapped to 1/256
!< pixel, integer edge functions sampled at pixel centres, the image's top-left tie rule (two triangles sharing an edge
!< never both draw it), attributes interpolated by barycentric weights in single precision; a triangle with a vertex
!< beyond 2**21 pixels is first clipped against a guard band of 64 pixels in double precision. The float operations
!< are those of the C++ in the same order (parenthesized where Fortran would be free to reorder): built without fused
!< multiply-add, the picture is the same as figure_swrast's.
!<
!< Rows are rendered in bands of 16, every band running every command in order (OpenMP threads take the bands in
!< turn when the library is built with OpenMP: `FIGURE_RENDER_THREADS`, 1 to 64, else the hardware's, at most 8); the
!< picture does not depend on the split. A triangle of one colour and one texel blends through a table of the 256
!< results per channel when it covers more than 1536 pixels.
use, intrinsic :: iso_c_binding, only : c_float, c_int16_t, c_ptr
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real64
use figure_drawlist, only : draw_vert
use figure_render, only : render_frame, render_list, render_texture, renderer_object, RENDER_CALLBACK, RENDER_DRAW, &
                          RENDER_RESET, RENDER_SAMPLER_FROM_TEXTURE, RENDER_SAMPLER_LINEAR, RENDER_SAMPLER_NEAREST
#ifdef _OPENMP
use omp_lib, only : omp_get_max_threads
#endif

implicit none
private
public :: cpu_renderer, render_threads_default

integer(int64), parameter :: SUB = 256_int64        !< Sub-pixel steps per pixel.
real(real64),   parameter :: LIMIT = 2097152.0_real64 !< Beyond (pixels), a triangle is clipped first.
real(real64),   parameter :: GUARD = 64.0_real64      !< The guard band clipping keeps [pixels].
integer(int32), parameter :: BAND = 16_int32          !< Rows per band of work.
integer(int32), parameter :: MAX_THREADS = 64_int32   !< Threads at most.

type :: fvtx
   !< A vertex in the picture: fixed-point position, attributes.
   integer(int64) :: x = 0_int64, y = 0_int64 !< Position [1/256 pixel].
   real(c_float)  :: u = 0.0_c_float, v = 0.0_c_float !< Texture coordinates.
   real(c_float)  :: c(4) = 0.0_c_float       !< Colour [0, 1].
   logical        :: far = .false.            !< Beyond LIMIT (or not finite): clipped first.
endtype fvtx

type :: command
   !< A command ready to draw (structure of its state; its triangles read in place).
   integer(int32)       :: x0 = 0, y0 = 0, x1 = 0, y1 = 0 !< Scissor [x0, x1) x [y0, y1).
   type(render_texture) :: tex                 !< Texture.
   logical              :: has_tex = .false.   !< ... with pixels.
   logical              :: linear = .true.     !< Linear sampler.
   integer(int32)       :: list = 0            !< Its list.
   integer(int32)       :: idx0 = 0            !< First index (1-based in the list's indices).
   integer(int32)       :: count = 0           !< Indices.
   integer(int32)       :: vtx0 = 0            !< Vertex offset (0-based).
endtype command

type :: list_vertices
   !< A list's vertices in the picture.
   type(fvtx), allocatable :: v(:) !< 1-based.
endtype list_vertices

type, extends(renderer_object) :: cpu_renderer
   !< The CPU renderer; its work arrays kept from frame to frame.
   integer(int32)                   :: threads = 0_int32 !< Threads (0: `render_threads_default`).
   type(list_vertices), allocatable :: verts(:)          !< Each list's vertices.
   type(command), allocatable       :: cmds(:)           !< The commands to draw.
   integer(int32)                   :: ncmds = 0_int32   !< ... how many.
   contains
      procedure :: render
endtype cpu_renderer

real(c_float), save :: U8F(0:255)          !< Each byte's value in [0, 1], as a GPU reads an 8-bit channel.
logical,       save :: u8f_ready = .false. !< U8F is set.

contains
   function render_threads_default() result(n)
   !< The threads a render uses by default: FIGURE_RENDER_THREADS if set (1-64), else the hardware's, at most 8.
   integer(int32)    :: n   !< Threads.
   character(len=16) :: env !< FIGURE_RENDER_THREADS.
   integer(int32)    :: v, ios, l !< Value, status, length.

   call get_environment_variable('FIGURE_RENDER_THREADS', env, l)
   if (l > 0) then
      read(env, *, iostat=ios) v
      if (ios == 0 .and. v >= 1_int32 .and. v <= MAX_THREADS) then
         n = v
         return
      endif
   endif
   n = 1_int32
#ifdef _OPENMP
   n = min(max(int(omp_get_max_threads(), int32), 1_int32), 8_int32)
#endif
   endfunction render_threads_default

   subroutine render(self, frame, width, height, clear, rgb)
   !< Draw `frame` into an RGB picture of width x height pixels, first cleared to `clear`.
   class(cpu_renderer), intent(inout) :: self     !< Renderer.
   type(render_frame),  intent(in)    :: frame    !< Frame.
   integer(int32),      intent(in)    :: width    !< Width [pixels].
   integer(int32),      intent(in)    :: height   !< Height [pixels].
   real(c_float),       intent(in)    :: clear(3) !< Clear colour.
   integer(int8),       intent(inout) :: rgb(:)   !< Picture, 3 * width * height bytes.
   real(c_float)                      :: proj(4), half_w, half_h, nx, ny !< Projection, viewport.
   real(real64)                       :: x, y     !< A vertex in the picture.
   real(c_float)                      :: cmin(2), cmax(2) !< A scissor in the picture.
   integer(int32)                     :: gx, gy, gw, gh  !< ... as glScissor's.
   integer(int32)                     :: l, i, k, nb, b, nt !< Counters, bands, threads.
   integer(int8)                      :: cc(3)    !< Clear colour's bytes.
   logical                            :: linear, from_tex !< The sampler's state.
   type(command)                      :: c        !< A command.

   if (.not. u8f_ready) call init_u8f()
   if (width <= 0_int32 .or. height <= 0_int32) return
   cc = [f2u8(clear(1)), f2u8(clear(2)), f2u8(clear(3))]
   do i = 1_int32, width * height
      rgb(3 * i - 2:3 * i) = cc
   enddo
   if (frame%nlists < 0_int32) return
   associate(xl => frame%pos(1), xr => frame%pos(1) + frame%size(1), yt => frame%pos(2), &
             yb => frame%pos(2) + frame%size(2))
      proj = [2.0_c_float / (xr - xl), (xr + xl) / (xl - xr), 2.0_c_float / (yt - yb), (yt + yb) / (yb - yt)]
   endassociate
   half_w = 0.5_c_float * real(width, c_float)
   half_h = 0.5_c_float * real(height, c_float)
   if (allocated(self%verts)) then
      if (size(self%verts) < frame%nlists) deallocate(self%verts)
   endif
   if (.not. allocated(self%verts)) allocate(self%verts(max(frame%nlists, 8_int32)))
   self%ncmds = 0_int32
   linear = .true.
   from_tex = .false.
   do l = 1_int32, frame%nlists
      associate(lst => frame%lists(l), tv => self%verts(l))
         k = 0_int32
         if (associated(lst%vtx)) k = size(lst%vtx, kind=int32)
         if (allocated(tv%v)) then
            if (size(tv%v, kind=int32) < k) deallocate(tv%v)
         endif
         if (.not. allocated(tv%v)) allocate(tv%v(max(k, 1024_int32)))
         do i = 1_int32, k ! the vertex shader, ProjMtx * (pos, 0, 1), then the viewport, in single precision
            nx = proj(1) * lst%vtx(i)%x + proj(2)
            ny = proj(3) * lst%vtx(i)%y + proj(4)
            x = real(nx * half_w + half_w, real64)
            y = real(real(height, c_float) - (ny * half_h + half_h), real64)
            tv%v(i)%far = .not. (abs(x) <= LIMIT .and. abs(y) <= LIMIT)
            if (.not. tv%v(i)%far) then
               tv%v(i)%x = nint(x * real(SUB, real64), int64)
               tv%v(i)%y = nint(y * real(SUB, real64), int64)
            endif
            tv%v(i)%u = lst%vtx(i)%u
            tv%v(i)%v = lst%vtx(i)%v
            tv%v(i)%c = unpack_col(lst%vtx(i)%col)
         enddo
         do i = 1_int32, lst%ncmd
            select case (lst%kind(i))
            case (RENDER_RESET)
               linear = .true.
               from_tex = .false.
               cycle
            case (RENDER_SAMPLER_FROM_TEXTURE)
               from_tex = .true.
               cycle
            case (RENDER_SAMPLER_LINEAR)
               linear = .true.
               from_tex = .false.
               cycle
            case (RENDER_SAMPLER_NEAREST)
               linear = .false.
               from_tex = .false.
               cycle
            case (RENDER_CALLBACK)
               cycle ! a program's own callback draws nothing here
            endselect
            if (lst%count(i) < 3_int32) cycle
            cmin = [(lst%clip(1, i) - frame%pos(1)) * frame%fb_scale(1), (lst%clip(2, i) - frame%pos(2)) * frame%fb_scale(2)]
            cmax = [(lst%clip(3, i) - frame%pos(1)) * frame%fb_scale(1), (lst%clip(4, i) - frame%pos(2)) * frame%fb_scale(2)]
            if (cmax(1) <= cmin(1) .or. cmax(2) <= cmin(2)) cycle
            gx = int(cmin(1), int32) ! glScissor(x, fb_height - max.y, max.x - min.x, max.y - min.y), rows from the top
            gw = int(cmax(1) - cmin(1), int32)
            gy = int(real(height, c_float) - cmax(2), int32)
            gh = int(cmax(2) - cmin(2), int32)
            c = command()
            c%x0 = max(0_int32, gx)
            c%x1 = min(width, gx + gw)
            c%y0 = max(0_int32, height - (gy + gh))
            c%y1 = min(height, height - gy)
            if (c%x0 >= c%x1 .or. c%y0 >= c%y1) cycle
            c%has_tex = .false.
            if (associated(frame%texture_of)) c%has_tex = frame%texture_of(lst%tex_data(i), lst%tex_id(i), c%tex)
            if (from_tex) then
               c%linear = .true.
               if (c%has_tex) c%linear = c%tex%smooth
            else
               c%linear = linear
            endif
            c%list = l
            c%idx0 = lst%idx_offset(i) + 1_int32
            c%count = lst%count(i)
            c%vtx0 = lst%vtx_offset(i)
            call push_command(self, c)
         enddo
      endassociate
   enddo
   nb = (height + BAND - 1_int32) / BAND
   nt = self%threads
   if (nt <= 0_int32) nt = render_threads_default()
   nt = max(1_int32, min(nt, MAX_THREADS, nb))
   !$omp parallel do schedule(dynamic, 1) num_threads(nt) default(shared) private(b)
   do b = 0_int32, nb - 1_int32
      call render_band(self, frame, width, rgb, b * BAND, min(height, (b + 1_int32) * BAND))
   enddo
   !$omp end parallel do
   endsubroutine render

   ! private

   subroutine render_band(self, frame, width, rgb, y0, y1)
   !< The rows [y0, y1) of every command, in order.
   type(cpu_renderer), intent(in)    :: self   !< Renderer.
   type(render_frame), intent(in)    :: frame  !< Frame.
   integer(int32),     intent(in)    :: width  !< Picture's width.
   integer(int8),      intent(inout) :: rgb(:) !< Picture.
   integer(int32),     intent(in)    :: y0, y1 !< Rows.
   integer(int32)                    :: k, e, ry0, ry1 !< Command, index, rows.
   integer(int32)                    :: ia, ib, ic     !< A triangle's vertices (1-based).
   integer(int64)                    :: top, bottom    !< The band [1/256 pixel].

   do k = 1_int32, self%ncmds
      associate(cmd => self%cmds(k))
         ry0 = max(y0, cmd%y0)
         ry1 = min(y1, cmd%y1)
         if (ry0 >= ry1) cycle
         top = int(ry0, int64) * SUB
         bottom = int(ry1, int64) * SUB
         associate(lst => frame%lists(cmd%list), tv => self%verts(cmd%list)%v)
            do e = 0_int32, cmd%count - 3_int32, 3_int32
               ia = cmd%vtx0 + u16(lst%idx(cmd%idx0 + e)) + 1_int32
               ib = cmd%vtx0 + u16(lst%idx(cmd%idx0 + e + 1_int32)) + 1_int32
               ic = cmd%vtx0 + u16(lst%idx(cmd%idx0 + e + 2_int32)) + 1_int32
               if (tv(ia)%far .or. tv(ib)%far .or. tv(ic)%far) then
                  call clipped_triangle(rgb, width, frame, cmd, ry0, ry1, lst%vtx(ia), lst%vtx(ib), lst%vtx(ic))
                  cycle
               endif
               if (max(tv(ia)%y, tv(ib)%y, tv(ic)%y) < top .or. min(tv(ia)%y, tv(ib)%y, tv(ic)%y) >= bottom) cycle
               call triangle(rgb, width, cmd, ry0, ry1, tv(ia), tv(ib), tv(ic))
            enddo
         endassociate
      endassociate
   enddo
   endsubroutine render_band

   subroutine triangle(fb, width, cmd, ry0, ry1, a_in, b_in, c_in)
   !< One triangle, its rows within [ry0, ry1) and its columns within the command's scissor.
   integer(int8),  intent(inout) :: fb(:)      !< Picture.
   integer(int32), intent(in)    :: width      !< Its width.
   type(command),  intent(in)    :: cmd        !< Command (scissor, sampler).
   integer(int32), intent(in)    :: ry0, ry1   !< Rows.
   type(fvtx),     intent(in)    :: a_in, b_in, c_in !< Vertices.
   type(fvtx)                    :: A, B, C    !< ... B and C swapped to a positive area.
   integer(int64)                :: area, minx, maxx, miny, maxy, b0, b1, b2, d0, d1, d2, kmax, cx0, cy !< Setup.
   integer(int64)                :: e0r, e1r, e2r, e0, e1, klo, khi, k !< A row's edge functions, its span.
   integer(int32)                :: px0, px1, py0, py1, y, ch !< Pixels, row, channel.
   integer(int64)                :: p        !< A pixel's first byte (1-based).
   logical                       :: flat_uv, flat_c, table !< Flat attributes, the table's use.
   real(c_float)                 :: tex0(4), src(3), al, ia, inv, w0, w1, w2, col(4), tex(4) !< Shading.
   integer(int8)                 :: lut(0:255, 3) !< The table.
   integer(int32)                :: i        !< Byte value.

   A = a_in
   B = b_in
   C = c_in
   area = edge(A, B, C%x, C%y)
   if (area == 0_int64) return
   if (area < 0_int64) then
      B = c_in
      C = b_in
      area = -area
   endif
   minx = min(A%x, B%x, C%x)
   maxx = max(A%x, B%x, C%x)
   miny = min(A%y, B%y, C%y)
   maxy = max(A%y, B%y, C%y)
   px0 = int(max(int(cmd%x0, int64), ceil_div(minx - SUB / 2_int64, SUB)), int32)
   px1 = int(min(int(cmd%x1, int64) - 1_int64, floor_div(maxx - SUB / 2_int64, SUB)), int32)
   py0 = int(max(int(ry0, int64), ceil_div(miny - SUB / 2_int64, SUB)), int32)
   py1 = int(min(int(ry1, int64) - 1_int64, floor_div(maxy - SUB / 2_int64, SUB)), int32)
   if (px0 > px1 .or. py0 > py1) return
   b0 = merge(0_int64, 1_int64, owned(B, C))
   b1 = merge(0_int64, 1_int64, owned(C, A))
   b2 = merge(0_int64, 1_int64, owned(A, B))
   d0 = -(C%y - B%y) * SUB
   d1 = -(A%y - C%y) * SUB
   d2 = -(B%y - A%y) * SUB
   kmax = int(px1 - px0, int64)
   cx0 = int(px0, int64) * SUB + SUB / 2_int64
   flat_uv = A%u == B%u .and. A%u == C%u .and. A%v == B%v .and. A%v == C%v
   flat_c = all(A%c == B%c) .and. all(A%c == C%c)
   tex0 = 1.0_c_float
   if (flat_uv) call sample(cmd, A%u, A%v, tex0)
   if (flat_uv .and. flat_c) then ! one colour: the same blend for every pixel, by the destination's byte
      al = A%c(4) * tex0(4)
      if (al <= 0.0_c_float) return
      do ch = 1, 3
         src(ch) = (A%c(ch) * tex0(ch)) * al
      enddo
      ia = 1.0_c_float - al
      table = int(px1 - px0 + 1_int32, int64) * int(py1 - py0 + 1_int32, int64) > 1536_int64
      if (table) then
         do ch = 1, 3
            do i = 0, 255
               lut(i, ch) = f2u8(src(ch) + U8F(i) * ia)
            enddo
         enddo
      endif
      do y = py0, py1
         cy = int(y, int64) * SUB + SUB / 2_int64
         call span(edge(B, C, cx0, cy), edge(C, A, cx0, cy), edge(A, B, cx0, cy))
         if (klo > khi) cycle
         p = (int(y, int64) * int(width, int64) + int(px0, int64) + klo) * 3_int64 + 1_int64
         if (table) then
            do k = klo, khi
               fb(p) = lut(byte(fb(p)), 1)
               fb(p + 1_int64) = lut(byte(fb(p + 1_int64)), 2)
               fb(p + 2_int64) = lut(byte(fb(p + 2_int64)), 3)
               p = p + 3_int64
            enddo
         else
            do k = klo, khi
               do ch = 1, 3
                  fb(p + ch - 1) = f2u8(src(ch) + U8F(byte(fb(p + ch - 1))) * ia)
               enddo
               p = p + 3_int64
            enddo
         endif
      enddo
      return
   endif
   inv = 1.0_c_float / real(area, c_float)
   do y = py0, py1
      cy = int(y, int64) * SUB + SUB / 2_int64
      e0r = edge(B, C, cx0, cy)
      e1r = edge(C, A, cx0, cy)
      e2r = edge(A, B, cx0, cy)
      call span(e0r, e1r, e2r)
      if (klo > khi) cycle
      e0 = e0r + klo * d0
      e1 = e1r + klo * d1
      p = (int(y, int64) * int(width, int64) + int(px0, int64) + klo) * 3_int64 + 1_int64
      do k = klo, khi
         w0 = real(e0, c_float) * inv
         w1 = real(e1, c_float) * inv
         w2 = (1.0_c_float - w0) - w1
         if (flat_c) then
            col = A%c
         else
            do ch = 1, 4
               col(ch) = (A%c(ch) * w0 + B%c(ch) * w1) + C%c(ch) * w2
            enddo
         endif
         if (flat_uv) then
            tex = tex0
         else
            call sample(cmd, (A%u * w0 + B%u * w1) + C%u * w2, (A%v * w0 + B%v * w1) + C%v * w2, tex)
         endif
         al = col(4) * tex(4)
         if (al > 0.0_c_float) then
            do ch = 1, 3
               fb(p + ch - 1) = f2u8((col(ch) * tex(ch)) * al + U8F(byte(fb(p + ch - 1))) * (1.0_c_float - al))
            enddo
         endif
         e0 = e0 + d0
         e1 = e1 + d1
         p = p + 3_int64
      enddo
   enddo
   contains
      subroutine span(f0, f1, f2)
      !< The span of one row: k in [klo, khi] (pixels from px0) where every edge function is at least its bias.
      integer(int64), intent(in) :: f0, f1, f2 !< The edge functions at the row's first pixel.

      klo = 0_int64
      khi = kmax
      call limit(f0, d0, b0)
      call limit(f1, d1, b1)
      call limit(f2, d2, b2)
      endsubroutine span

      subroutine limit(f, d, bias)
      !< One edge's bound on the span.
      integer(int64), intent(in) :: f, d, bias !< Edge function, its step per pixel, its bias.

      if (d > 0_int64) then
         klo = max(klo, ceil_div(bias - f, d))
      elseif (d < 0_int64) then
         khi = min(khi, floor_div(f - bias, -d))
      elseif (f < bias) then
         khi = -1_int64
      endif
      endsubroutine limit
   endsubroutine triangle

   subroutine clipped_triangle(fb, width, frame, cmd, ry0, ry1, v1, v2, v3)
   !< A triangle with a vertex beyond LIMIT: clipped against the guard band in double precision (attributes
   !< interpolated linearly), then drawn as a fan.
   integer(int8),      intent(inout) :: fb(:)      !< Picture.
   integer(int32),     intent(in)    :: width      !< Its width.
   type(render_frame), intent(in)    :: frame      !< Frame (the view).
   type(command),      intent(in)    :: cmd        !< Command.
   integer(int32),     intent(in)    :: ry0, ry1   !< Rows.
   type(draw_vert),    intent(in)    :: v1, v2, v3 !< Vertices, as Dear ImGui gave them.
   real(real64)                      :: poly(8, 8), next(8, 8), r(8) !< Polygons (x, y, u, v, r, g, b, a), a vertex.
   integer(int32)                    :: n, m, i, plane, axis !< Vertices, counters, the plane's axis.
   logical                           :: upper, pin, qin !< Upper plane; the ends inside.
   real(real64)                      :: bound, t, lo(2), hi(2) !< The plane, the cut, the band.
   type(fvtx)                        :: first          !< The fan's first vertex.
   integer(int32)                    :: height         !< Picture's height.

   height = size(fb, kind=int32) / (3_int32 * width)
   call vertex_of(v1, poly(:, 1))
   call vertex_of(v2, poly(:, 2))
   call vertex_of(v3, poly(:, 3))
   do i = 1, 3
      if (.not. (abs(poly(1, i)) <= huge(1.0_real64)) .or. .not. (abs(poly(2, i)) <= huge(1.0_real64))) return
   enddo
   n = 3_int32
   lo = [-GUARD, -GUARD]
   hi = [real(width, real64) + GUARD, real(height, real64) + GUARD]
   do plane = 0, 3
      if (n <= 0_int32) exit
      axis = plane / 2 + 1
      upper = mod(plane, 2) == 1
      bound = merge(hi(axis), lo(axis), upper)
      m = 0_int32
      do i = 1_int32, n
         pin = inside(poly(:, i))
         qin = inside(poly(:, mod(i, n) + 1_int32))
         if (pin) then
            m = m + 1_int32
            next(:, m) = poly(:, i)
         endif
         if (pin .neqv. qin) then
            associate(pp => poly(:, i), qq => poly(:, mod(i, n) + 1_int32))
               t = (bound - pp(axis)) / (qq(axis) - pp(axis))
               r = pp + (qq - pp) * t
            endassociate
            r(axis) = bound
            m = m + 1_int32
            next(:, m) = r
         endif
      enddo
      poly(:, 1:m) = next(:, 1:m)
      n = m
   enddo
   if (n < 3_int32) return
   first = snap(poly(:, 1))
   do i = 2_int32, n - 1_int32
      call triangle(fb, width, cmd, ry0, ry1, first, snap(poly(:, i)), snap(poly(:, i + 1_int32)))
   enddo
   contains
      subroutine vertex_of(v, a)
      !< A vertex in the picture, double precision.
      type(draw_vert), intent(in)  :: v    !< Vertex.
      real(real64),    intent(out) :: a(8) !< x, y, u, v, r, g, b, alpha.
      real(c_float)                :: c(4) !< Colour.

      a(1) = (real(v%x, real64) - real(frame%pos(1), real64)) * real(frame%fb_scale(1), real64)
      a(2) = (real(v%y, real64) - real(frame%pos(2), real64)) * real(frame%fb_scale(2), real64)
      a(3) = real(v%u, real64)
      a(4) = real(v%v, real64)
      c = unpack_col(v%col)
      a(5:8) = real(c, real64)
      endsubroutine vertex_of

      logical function inside(a)
      !< A vertex on the kept side of the plane.
      real(real64), intent(in) :: a(8) !< Vertex.

      if (upper) then
         inside = a(axis) <= bound
      else
         inside = a(axis) >= bound
      endif
      endfunction inside

      function snap(a) result(f)
      !< A clipped vertex snapped to the fixed point.
      real(real64), intent(in) :: a(8) !< Vertex.
      type(fvtx)               :: f    !< Snapped.

      f%x = nint(a(1) * real(SUB, real64), int64)
      f%y = nint(a(2) * real(SUB, real64), int64)
      f%u = real(a(3), c_float)
      f%v = real(a(4), c_float)
      f%c = real(a(5:8), c_float)
      endfunction snap
   endsubroutine clipped_triangle

   subroutine sample(cmd, u, v, out)
   !< The command's texel at (u, v): magenta without a texture; nearest or bilinear, clamped to the edge.
   type(command), intent(in)  :: cmd    !< Command (texture, filter).
   real(c_float), intent(in)  :: u, v   !< Texture coordinates.
   real(c_float), intent(out) :: out(4) !< RGBA.
   real(c_float)              :: fx, fy, x0f, y0f, ax, ay, p00(4), p10(4), p01(4), p11(4), a, b !< Bilinear.
   integer(int32)             :: w, h, x0, y0, x1, y1, c !< Size, texels, channel.

   if (.not. cmd%has_tex) then
      out = [1.0_c_float, 0.0_c_float, 1.0_c_float, 1.0_c_float]
      return
   endif
   w = cmd%tex%width
   h = cmd%tex%height
   if (.not. cmd%linear) then
      x0 = min(max(int(floor(u * real(w, c_float)), int32), 0_int32), w - 1_int32)
      y0 = min(max(int(floor(v * real(h, c_float)), int32), 0_int32), h - 1_int32)
      call texel(cmd%tex, x0, y0, out)
      return
   endif
   fx = u * real(w, c_float) - 0.5_c_float
   fy = v * real(h, c_float) - 0.5_c_float
   x0f = floor(fx)
   y0f = floor(fy)
   ax = fx - x0f
   ay = fy - y0f
   x0 = int(x0f, int32)
   y0 = int(y0f, int32)
   x1 = min(max(x0 + 1_int32, 0_int32), w - 1_int32)
   y1 = min(max(y0 + 1_int32, 0_int32), h - 1_int32)
   x0 = min(max(x0, 0_int32), w - 1_int32)
   y0 = min(max(y0, 0_int32), h - 1_int32)
   call texel(cmd%tex, x0, y0, p00)
   call texel(cmd%tex, x1, y0, p10)
   call texel(cmd%tex, x0, y1, p01)
   call texel(cmd%tex, x1, y1, p11)
   do c = 1, 4
      a = p00(c) + (p10(c) - p00(c)) * ax
      b = p01(c) + (p11(c) - p01(c)) * ax
      out(c) = a + (b - a) * ay
   enddo
   endsubroutine sample

   subroutine texel(t, x, y, out)
   !< A texel (0-based x, y), its channels in [0, 1]; alpha-only textures white.
   type(render_texture), intent(in)  :: t      !< Texture.
   integer(int32),       intent(in)  :: x, y   !< Texel.
   real(c_float),        intent(out) :: out(4) !< RGBA.
   integer(int64)                    :: p      !< Its first byte (1-based).
   integer(int32)                    :: c      !< Channel.

   if (t%channels == 1_int32) then
      out(1:3) = 1.0_c_float
      out(4) = U8F(byte(t%pixels(int(y, int64) * int(t%width, int64) + int(x, int64) + 1_int64)))
      return
   endif
   p = (int(y, int64) * int(t%width, int64) + int(x, int64)) * 4_int64 + 1_int64
   do c = 1, 4
      out(c) = U8F(byte(t%pixels(p + c - 1)))
   enddo
   endsubroutine texel

   pure function edge(a, b, px, py) result(e)
   !< The edge function of a->b at (px, py) [1/256 pixel].
   type(fvtx),     intent(in) :: a, b   !< Edge.
   integer(int64), intent(in) :: px, py !< Point.
   integer(int64)             :: e      !< Value.

   e = (b%x - a%x) * (py - a%y) - (b%y - a%y) * (px - a%x)
   endfunction edge

   pure logical function owned(a, b)
   !< The edge a->b (positive area, y down) owns the pixel centres exactly on it (the image's top-left rule).
   type(fvtx), intent(in) :: a, b !< Edge.
   integer(int64)         :: dx, dy !< Its direction.

   dx = b%x - a%x
   dy = b%y - a%y
   owned = dy < 0_int64 .or. (dy == 0_int64 .and. dx > 0_int64)
   endfunction owned

   pure function floor_div(a, b) result(q)
   !< Floor of a / b, b > 0.
   integer(int64), intent(in) :: a, b !< Operands.
   integer(int64)             :: q    !< Quotient.

   if (a >= 0_int64) then
      q = a / b
   else
      q = -((-a + b - 1_int64) / b)
   endif
   endfunction floor_div

   pure function ceil_div(a, b) result(q)
   !< Ceiling of a / b, b > 0.
   integer(int64), intent(in) :: a, b !< Operands.
   integer(int64)             :: q    !< Quotient.

   q = -floor_div(-a, b)
   endfunction ceil_div

   pure function f2u8(v) result(u)
   !< A channel in [0, 1] (clamped) as a byte, rounded half up.
   real(c_float), intent(in) :: v !< Channel.
   integer(int8)             :: u !< Byte, in its bits.
   integer(int32)            :: i !< Value 0-255.

   i = int(min(max(v, 0.0_c_float), 1.0_c_float) * 255.0_c_float + 0.5_c_float, int32)
   if (i > 127_int32) i = i - 256_int32
   u = int(i, int8)
   endfunction f2u8

   pure function byte(b) result(i)
   !< A byte's unsigned value.
   integer(int8), intent(in) :: b !< Byte.
   integer(int32)            :: i !< 0-255.

   i = iand(int(b, int32), 255_int32)
   endfunction byte

   pure function u16(i) result(v)
   !< A 16-bit index's unsigned value.
   integer(c_int16_t), intent(in) :: i !< Index, in its bits.
   integer(int32)                 :: v !< 0-65535.

   v = iand(int(i, int32), 65535_int32)
   endfunction u16

   function unpack_col(col) result(c)
   !< A packed colour's channels in [0, 1] (red in the low byte).
   integer(int32), intent(in) :: col  !< Colour.
   real(c_float)              :: c(4) !< RGBA.

   c(1) = U8F(iand(col, 255_int32))
   c(2) = U8F(iand(ishft(col, -8), 255_int32))
   c(3) = U8F(iand(ishft(col, -16), 255_int32))
   c(4) = U8F(iand(ishft(col, -24), 255_int32))
   endfunction unpack_col

   subroutine init_u8f()
   !< Each byte's value in [0, 1], as a GPU reads an 8-bit channel.
   integer(int32) :: i !< Byte.

   do i = 0, 255
      U8F(i) = real(i, c_float) * (1.0_c_float / 255.0_c_float)
   enddo
   u8f_ready = .true.
   endsubroutine init_u8f

   subroutine push_command(self, c)
   !< Append a command (the array grown by half again).
   type(cpu_renderer), intent(inout) :: self    !< Renderer.
   type(command),      intent(in)    :: c       !< Command.
   type(command), allocatable        :: more(:) !< Larger array.

   if (.not. allocated(self%cmds)) allocate(self%cmds(256))
   if (self%ncmds >= size(self%cmds, kind=int32)) then
      allocate(more(size(self%cmds) + size(self%cmds) / 2 + 1))
      more(1:self%ncmds) = self%cmds(1:self%ncmds)
      call move_alloc(more, self%cmds)
   endif
   self%ncmds = self%ncmds + 1_int32
   self%cmds(self%ncmds) = c
   endsubroutine push_command
endmodule figure_render_cpu
