!< figure_render_gl3, the OpenGL 3 renderer: a frame's triangles drawn by the GPU, as imgui_impl_opengl3.cpp draws them.
module figure_render_gl3
!< figure_render_gl3, the OpenGL 3 renderer: a frame's triangles drawn by the GPU, as imgui_impl_opengl3.cpp draws them.
!<
!< szaghi/figure#15 P9 (K3): Dear ImGui's OpenGL 3 backend in Fortran, for the Fortran path's windows (the C++ backend
!< stays the current path's renderer until P27). The GL functions are loaded through `SDL_GL_GetProcAddress` and
!< called through procedure pointers (`c_f_procpointer`), from the context the native layer made current. What the
!< backend does, in its order, so that a window's picture is the C++ backend's on the same driver:
!<
!< - `init`: the context's version (`GL_MAJOR_VERSION`, `GL_MINOR_VERSION`), profile and texture size limit; the
!<   GLSL version line; what the context has (glPolygonMode on desktop GL, sampler objects from 3.3, the base vertex
!<   of a draw from 3.2); registered in Dear ImGui by `figure_renderer_backend` (its name, the back-end flags
!<   RendererHasTextures and RendererHasVtxOffset, the texture size limit, the samplers' callbacks);
!< - `new_frame`: the shader program, buffers and samplers made on the first frame (the backend's shaders: GLSL 1.20,
!<   1.30, 3.00 ES or 4.10 core, chosen by the version line);
!< - `textures`: Dear ImGui's textures created, updated (their update rectangles) and destroyed as the frame asks
!<   (`ImDrawData::Textures`, ImTextureData's protocol), RGBA8, linear, clamped to the edge;
!< - `render`: the GL state saved, the render state set (blending, no culling, depth or stencil test, scissor test,
!<   polygon fill, the orthographic projection, the vertex layout of `ImDrawVert`), each list's buffers uploaded and
!<   its commands drawn with their scissor rectangle and texture (the samplers' callbacks followed, a program's own
!<   callback called), the saved state restored.
!<
!< The clip origin is GL's lower left, as the backend's default (FIGURE never asks for another, so the backend never
!< queries `GL_CLIP_ORIGIN` and its extension scan has no effect); multi-viewports are not enabled by FIGURE, so the
!< back-end flag RendererHasViewports is not raised.
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_f_pointer, c_f_procpointer, c_float, c_funloc, &
                                        c_funptr, c_int, c_intptr_t, c_loc, c_long_long, c_null_char, c_null_ptr, &
                                        c_ptr, c_signed_char, c_size_t
use, intrinsic :: iso_fortran_env, only : error_unit, int8, int32, int64
use figure_cimgui_core, only : figure_ImDrawData_callback, figure_ImDrawData_texture, figure_ImDrawData_textures, &
                               figure_ImTextureData_id, figure_ImTextureData_pixels, figure_ImTextureData_rect,     &
                               figure_ImTextureData_set, figure_ImTextureData_state, figure_renderer_backend
use figure_cimgui_enums, only : ImTextureStatus_Destroyed, ImTextureStatus_OK, ImTextureStatus_WantCreate, &
                                ImTextureStatus_WantDestroy, ImTextureStatus_WantUpdates
use figure_render, only : render_frame, renderer_object, RENDER_CALLBACK, RENDER_DRAW, RENDER_RESET, &
                          RENDER_SAMPLER_FROM_TEXTURE, RENDER_SAMPLER_LINEAR, RENDER_SAMPLER_NEAREST

implicit none
private
public :: gl3_renderer

! the GL enumerants the backend uses
integer(c_int), parameter :: GL_FALSE = 0, GL_TRUE = 1, GL_ONE = 1, GL_TRIANGLES = int(z'0004', c_int)
integer(c_int), parameter :: GL_SRC_ALPHA = int(z'0302', c_int), GL_ONE_MINUS_SRC_ALPHA = int(z'0303', c_int)
integer(c_int), parameter :: GL_FRONT = int(z'0404', c_int), GL_BACK = int(z'0405', c_int)
integer(c_int), parameter :: GL_FRONT_AND_BACK = int(z'0408', c_int), GL_POLYGON_MODE = int(z'0B40', c_int)
integer(c_int), parameter :: GL_CULL_FACE = int(z'0B44', c_int), GL_DEPTH_TEST = int(z'0B71', c_int)
integer(c_int), parameter :: GL_STENCIL_TEST = int(z'0B90', c_int), GL_VIEWPORT = int(z'0BA2', c_int)
integer(c_int), parameter :: GL_BLEND = int(z'0BE2', c_int), GL_SCISSOR_BOX = int(z'0C10', c_int)
integer(c_int), parameter :: GL_SCISSOR_TEST = int(z'0C11', c_int), GL_UNPACK_ROW_LENGTH = int(z'0CF2', c_int)
integer(c_int), parameter :: GL_UNPACK_ALIGNMENT = int(z'0CF5', c_int), GL_MAX_TEXTURE_SIZE = int(z'0D33', c_int)
integer(c_int), parameter :: GL_TEXTURE_2D = int(z'0DE1', c_int), GL_UNSIGNED_BYTE = int(z'1401', c_int)
integer(c_int), parameter :: GL_UNSIGNED_SHORT = int(z'1403', c_int), GL_FLOAT = int(z'1406', c_int)
integer(c_int), parameter :: GL_RGBA = int(z'1908', c_int), GL_FILL = int(z'1B02', c_int)
integer(c_int), parameter :: GL_VERSION = int(z'1F02', c_int), GL_NEAREST = int(z'2600', c_int)
integer(c_int), parameter :: GL_LINEAR = int(z'2601', c_int), GL_TEXTURE_MAG_FILTER = int(z'2800', c_int)
integer(c_int), parameter :: GL_TEXTURE_MIN_FILTER = int(z'2801', c_int), GL_TEXTURE_WRAP_S = int(z'2802', c_int)
integer(c_int), parameter :: GL_TEXTURE_WRAP_T = int(z'2803', c_int), GL_FUNC_ADD = int(z'8006', c_int)
integer(c_int), parameter :: GL_BLEND_EQUATION_RGB = int(z'8009', c_int), GL_TEXTURE_BINDING_2D = int(z'8069', c_int)
integer(c_int), parameter :: GL_BLEND_DST_RGB = int(z'80C8', c_int), GL_BLEND_SRC_RGB = int(z'80C9', c_int)
integer(c_int), parameter :: GL_BLEND_DST_ALPHA = int(z'80CA', c_int), GL_BLEND_SRC_ALPHA = int(z'80CB', c_int)
integer(c_int), parameter :: GL_CLAMP_TO_EDGE = int(z'812F', c_int), GL_MAJOR_VERSION = int(z'821B', c_int)
integer(c_int), parameter :: GL_MINOR_VERSION = int(z'821C', c_int), GL_TEXTURE0 = int(z'84C0', c_int)
integer(c_int), parameter :: GL_ACTIVE_TEXTURE = int(z'84E0', c_int), GL_VERTEX_ARRAY_BINDING = int(z'85B5', c_int)
integer(c_int), parameter :: GL_BLEND_EQUATION_ALPHA = int(z'883D', c_int), GL_ARRAY_BUFFER = int(z'8892', c_int)
integer(c_int), parameter :: GL_ELEMENT_ARRAY_BUFFER = int(z'8893', c_int)
integer(c_int), parameter :: GL_ARRAY_BUFFER_BINDING = int(z'8894', c_int), GL_STREAM_DRAW = int(z'88E0', c_int)
integer(c_int), parameter :: GL_PIXEL_UNPACK_BUFFER = int(z'88EC', c_int)
integer(c_int), parameter :: GL_PIXEL_UNPACK_BUFFER_BINDING = int(z'88EF', c_int)
integer(c_int), parameter :: GL_SAMPLER_BINDING = int(z'8919', c_int), GL_FRAGMENT_SHADER = int(z'8B30', c_int)
integer(c_int), parameter :: GL_VERTEX_SHADER = int(z'8B31', c_int), GL_COMPILE_STATUS = int(z'8B81', c_int)
integer(c_int), parameter :: GL_LINK_STATUS = int(z'8B82', c_int), GL_INFO_LOG_LENGTH = int(z'8B84', c_int)
integer(c_int), parameter :: GL_CURRENT_PROGRAM = int(z'8B8D', c_int), GL_PRIMITIVE_RESTART = int(z'8F9D', c_int)
integer(c_int), parameter :: GL_CONTEXT_PROFILE_MASK = int(z'9126', c_int)
integer(c_int), parameter :: GL_CONTEXT_COMPATIBILITY_PROFILE_BIT = 2
integer(c_intptr_t), parameter :: VTX_SIZE = 20_c_intptr_t !< sizeof(ImDrawVert): pos, uv (floats), col (4 bytes).
integer(c_intptr_t), parameter :: IDX_SIZE = 2_c_intptr_t  !< sizeof(ImDrawIdx).

! The interfaces of the GL functions, called through procedure pointers: every C pointer an argument or a result
! carries is an integer(c_intptr_t) (`addr`): nvfortran 26.9 does not pass a `type(c_ptr), value` argument, nor return a
! `type(c_ptr)` result, through a procedure pointer of a bind(C) interface as C does (glTexImage2D read its pixels
! from a wrong address; glGetString's result was garbage), while an integer of the pointer's size goes as C's pointer
abstract interface
   subroutine gl_get_integerv_t(pname, data) bind(C)
   import :: c_int
   integer(c_int), value :: pname   !< Parameter.
   integer(c_int)        :: data(*) !< Its value(s).
   endsubroutine gl_get_integerv_t
   function gl_get_string_t(name) result(s) bind(C)
   !< The C string's address as an integer: nvfortran 26.9 returns a `type(c_ptr)` result of a procedure pointer's
   !< bind(C) interface as no C function returns it (the address read back was garbage).
   import :: c_int, c_intptr_t
   integer(c_int), value :: name !< Which string.
   integer(c_intptr_t)   :: s    !< `const GLubyte*`.
   endfunction gl_get_string_t
   subroutine gl_enum_t(a) bind(C)
   import :: c_int
   integer(c_int), value :: a !< An enumerant or a name.
   endsubroutine gl_enum_t
   subroutine gl_enum2_t(a, b) bind(C)
   import :: c_int
   integer(c_int), value :: a, b !< Two enumerants or names.
   endsubroutine gl_enum2_t
   subroutine gl_enum3_t(a, b, c) bind(C)
   import :: c_int
   integer(c_int), value :: a, b, c !< Three enumerants or names.
   endsubroutine gl_enum3_t
   subroutine gl_enum4_t(a, b, c, d) bind(C)
   import :: c_int
   integer(c_int), value :: a, b, c, d !< Four enumerants, names or sizes.
   endsubroutine gl_enum4_t
   function gl_is_t(a) result(r) bind(C)
   import :: c_int, c_signed_char
   integer(c_int), value  :: a !< A capability or a name.
   integer(c_signed_char) :: r !< GL_TRUE or GL_FALSE.
   endfunction gl_is_t
   subroutine gl_gen_t(n, names) bind(C)
   import :: c_int
   integer(c_int), value :: n        !< How many.
   integer(c_int)        :: names(*) !< Names.
   endsubroutine gl_gen_t
   subroutine gl_uniform_matrix4fv_t(location, count, transpose, value) bind(C)
   import :: c_float, c_int, c_signed_char
   integer(c_int),         value      :: location !< Uniform.
   integer(c_int),         value      :: count    !< Matrices.
   integer(c_signed_char), value      :: transpose !< GL_FALSE.
   real(c_float),          intent(in) :: value(*) !< Column-major.
   endsubroutine gl_uniform_matrix4fv_t
   subroutine gl_vertex_attrib_pointer_t(index, size, type, normalized, stride, offset) bind(C)
   import :: c_int, c_intptr_t, c_signed_char
   integer(c_int),         value :: index, size, type !< Attribute, components, type.
   integer(c_signed_char), value :: normalized        !< Normalized.
   integer(c_int),         value :: stride            !< Bytes between vertices.
   integer(c_intptr_t),    value :: offset            !< Offset in the bound buffer (a pointer's bits).
   endsubroutine gl_vertex_attrib_pointer_t
   subroutine gl_buffer_data_t(target, size, data, usage) bind(C)
   import :: c_int, c_intptr_t
   integer(c_int),      value :: target !< Buffer.
   integer(c_intptr_t), value :: size   !< Bytes.
   integer(c_intptr_t), value :: data   !< Data's address.
   integer(c_int),      value :: usage  !< Usage.
   endsubroutine gl_buffer_data_t
   subroutine gl_draw_elements_base_vertex_t(mode, count, type, offset, base) bind(C)
   import :: c_int, c_intptr_t
   integer(c_int),      value :: mode, count, type !< Primitives, indices, their type.
   integer(c_intptr_t), value :: offset            !< Offset in the index buffer (a pointer's bits).
   integer(c_int),      value :: base              !< Base vertex.
   endsubroutine gl_draw_elements_base_vertex_t
   subroutine gl_draw_elements_t(mode, count, type, offset) bind(C)
   import :: c_int, c_intptr_t
   integer(c_int),      value :: mode, count, type !< Primitives, indices, their type.
   integer(c_intptr_t), value :: offset            !< Offset in the index buffer (a pointer's bits).
   endsubroutine gl_draw_elements_t
   subroutine gl_tex_image_2d_t(target, level, internal, width, height, border, format, type, pixels) bind(C)
   import :: c_int, c_intptr_t
   integer(c_int),      value :: target, level, internal, width, height, border, format, type !< The image.
   integer(c_intptr_t), value :: pixels !< Pixels' address.
   endsubroutine gl_tex_image_2d_t
   subroutine gl_tex_sub_image_2d_t(target, level, x, y, width, height, format, type, pixels) bind(C)
   import :: c_int, c_intptr_t
   integer(c_int),      value :: target, level, x, y, width, height, format, type !< The rectangle.
   integer(c_intptr_t), value :: pixels !< Pixels' address.
   endsubroutine gl_tex_sub_image_2d_t
   function gl_create_t(a) result(r) bind(C)
   import :: c_int
   integer(c_int), value :: a !< Shader type (none for a program: the value is ignored).
   integer(c_int)        :: r !< Name.
   endfunction gl_create_t
   function gl_create_program_t() result(r) bind(C)
   import :: c_int
   integer(c_int) :: r !< Name.
   endfunction gl_create_program_t
   subroutine gl_shader_source_t(shader, count, strings, lengths) bind(C)
   import :: c_int, c_intptr_t
   integer(c_int),      value :: shader     !< Shader.
   integer(c_int),      value :: count      !< Strings.
   integer(c_intptr_t)        :: strings(*) !< The C strings' addresses.
   integer(c_intptr_t), value :: lengths    !< 0 (NULL): null-terminated.
   endsubroutine gl_shader_source_t
   subroutine gl_get_iv_t(name, pname, value) bind(C)
   import :: c_int
   integer(c_int), value :: name, pname !< Object, parameter.
   integer(c_int)        :: value       !< Its value.
   endsubroutine gl_get_iv_t
   subroutine gl_get_info_log_t(name, size, length, log) bind(C)
   import :: c_char, c_int, c_intptr_t
   integer(c_int),         value :: name, size !< Object, room.
   integer(c_intptr_t),    value :: length     !< 0 (NULL).
   character(kind=c_char)        :: log(*)     !< The log.
   endsubroutine gl_get_info_log_t
   function gl_get_location_t(program, name) result(r) bind(C)
   import :: c_char, c_int
   integer(c_int),         value      :: program !< Program.
   character(kind=c_char), intent(in) :: name(*) !< Null-terminated name.
   integer(c_int)                     :: r       !< Location.
   endfunction gl_get_location_t
endinterface

interface
   function SDL_GL_GetProcAddress(proc) result(f) bind(C, name='SDL_GL_GetProcAddress')
   !< SDL3: the address of an OpenGL function of the current context's driver.
   import :: c_char, c_funptr
   character(kind=c_char), intent(in) :: proc(*) !< Null-terminated name.
   type(c_funptr)                     :: f       !< The function, or null.
   endfunction SDL_GL_GetProcAddress
endinterface

! the GL functions, loaded by `load` from the current context
procedure(gl_get_integerv_t),              pointer :: glGetIntegerv => null()
procedure(gl_get_string_t),                pointer :: glGetString => null()
procedure(gl_enum_t),                      pointer :: glActiveTexture => null(), glUseProgram => null(),       &
                                                      glEnable => null(), glDisable => null(),                 &
                                                      glBlendEquation => null(), glBindVertexArray => null(),  &
                                                      glEnableVertexAttribArray => null(), glCompileShader => null(), &
                                                      glLinkProgram => null(), glDeleteShader => null(),       &
                                                      glDeleteProgram => null()
procedure(gl_enum2_t),                     pointer :: glBindTexture => null(), glBindSampler => null(),        &
                                                      glBindBuffer => null(), glPolygonMode => null(),         &
                                                      glBlendEquationSeparate => null(), glUniform1i => null(), &
                                                      glPixelStorei => null(), glAttachShader => null(),       &
                                                      glDetachShader => null()
procedure(gl_enum3_t),                     pointer :: glTexParameteri => null(), glSamplerParameteri => null()
procedure(gl_enum4_t),                     pointer :: glBlendFuncSeparate => null(), glViewport => null(),     &
                                                      glScissor => null()
procedure(gl_is_t),                        pointer :: glIsEnabled => null(), glIsProgram => null()
procedure(gl_gen_t),                       pointer :: glGenVertexArrays => null(), glDeleteVertexArrays => null(), &
                                                      glGenTextures => null(), glDeleteTextures => null(),     &
                                                      glGenBuffers => null(), glDeleteBuffers => null(),       &
                                                      glGenSamplers => null(), glDeleteSamplers => null()
procedure(gl_uniform_matrix4fv_t),         pointer :: glUniformMatrix4fv => null()
procedure(gl_vertex_attrib_pointer_t),     pointer :: glVertexAttribPointer => null()
procedure(gl_buffer_data_t),               pointer :: glBufferData => null()
procedure(gl_draw_elements_base_vertex_t), pointer :: glDrawElementsBaseVertex => null()
procedure(gl_draw_elements_t),             pointer :: glDrawElements => null()
procedure(gl_tex_image_2d_t),              pointer :: glTexImage2D => null()
procedure(gl_tex_sub_image_2d_t),          pointer :: glTexSubImage2D => null()
procedure(gl_create_t),                    pointer :: glCreateShader => null()
procedure(gl_create_program_t),            pointer :: glCreateProgram => null()
procedure(gl_shader_source_t),             pointer :: glShaderSource => null()
procedure(gl_get_iv_t),                    pointer :: glGetShaderiv => null(), glGetProgramiv => null()
procedure(gl_get_info_log_t),              pointer :: glGetShaderInfoLog => null(), glGetProgramInfoLog => null()
procedure(gl_get_location_t),              pointer :: glGetUniformLocation => null(), glGetAttribLocation => null()

type, extends(renderer_object) :: gl3_renderer
   !< The OpenGL 3 renderer: the context's properties, the device objects, the render state of a frame.
   integer(c_int)    :: gl_version = 0       !< Major * 100 + minor * 10 (e.g. 330).
   logical           :: es3 = .false.        !< An OpenGL ES 3 context.
   logical           :: compat = .false.     !< A compatibility profile.
   integer(c_int)    :: max_texture = 0      !< GL_MAX_TEXTURE_SIZE.
   logical           :: polygon_mode = .false. !< glPolygonMode exists (desktop GL).
   logical           :: bind_sampler = .false. !< Sampler objects exist (3.3, ES 3).
   character(len=32) :: glsl = ''            !< The GLSL version line, with its newline.
   integer(c_int)    :: shader = 0           !< Program.
   integer(c_int)    :: loc_tex = 0, loc_proj = 0 !< Uniforms.
   integer(c_int)    :: loc_pos = 0, loc_uv = 0, loc_col = 0 !< Attributes.
   integer(c_int)    :: vbo = 0, ebo = 0     !< Buffers.
   integer(c_int)    :: samplers(2) = 0      !< Linear, nearest.
   ! a frame's render state (ImGui_ImplOpenGL3_RenderState)
   logical           :: use_bind_sampler = .false. !< Sampler objects in use.
   logical           :: use_tex_filter = .false.   !< The filter set on each texture instead.
   integer(c_int)    :: sampler = 0               !< The bound sampler.
   integer(c_int)    :: tex_filter = 0            !< The filter set on each texture.
   type(c_ptr)       :: dd = c_null_ptr           !< The frame's `ImDrawData*` (its programs' callbacks).
   contains
      procedure :: init      !< The context's properties; registered in Dear ImGui.
      procedure :: new_frame !< The device objects, made on the first frame.
      procedure :: textures  !< Dear ImGui's textures created, updated, destroyed as a frame asks.
      procedure :: render    !< Draw a frame into the bound framebuffer.
      procedure :: shutdown  !< Device objects and textures released; unregistered.
      procedure, private :: create_objects !< Shader program, buffers, samplers.
      procedure, private :: setup          !< The render state.
      procedure, private :: set_sampler    !< A sampler's callback.
      procedure, private :: update_texture !< One texture's request.
endtype gl3_renderer

contains
   function init(self, glsl_version) result(ok)
   !< The context's version, profile and limits, what it has, the GLSL version line (`glsl_version`, or the version's
   !< default when empty); registered in Dear ImGui (back-end name and flags, texture size, samplers' callbacks). The
   !< GL functions are loaded first: `.false.` when one is missing.
   class(gl3_renderer), intent(inout) :: self         !< Renderer.
   character(len=*),    intent(in)    :: glsl_version !< `#version ...`, or empty.
   logical                            :: ok           !< Loaded and registered.
   integer(c_int)                     :: major(1), minor(1), mask(1), mt(1) !< Queries.
   character(len=16)                  :: vstr         !< GL_VERSION's start.

   ok = load()
   if (.not. ok) return
   vstr = c_string(transfer(glGetString(GL_VERSION), c_null_ptr), len(vstr))
   major = 0
   minor = 0
   call glGetIntegerv(GL_MAJOR_VERSION, major)
   call glGetIntegerv(GL_MINOR_VERSION, minor)
   if (major(1) == 0 .and. minor(1) == 0) read(vstr, *, iostat=mt(1)) major(1), minor(1) ! "M.m ..." (GL 2.x)
   self%gl_version = major(1) * 100_c_int + minor(1) * 10_c_int
   mt = 0
   call glGetIntegerv(GL_MAX_TEXTURE_SIZE, mt)
   self%max_texture = mt(1)
   self%es3 = vstr(1:11) == 'OpenGL ES 3'
   mask = 0
   if (.not. self%es3 .and. self%gl_version >= 320_c_int) call glGetIntegerv(GL_CONTEXT_PROFILE_MASK, mask)
   self%compat = iand(mask(1), GL_CONTEXT_COMPATIBILITY_PROFILE_BIT) /= 0_c_int
   call figure_renderer_backend(1_c_int, merge(1_c_int, 0_c_int, self%gl_version >= 320_c_int), self%max_texture, &
                                c_funloc(cb_reset), c_funloc(cb_from_texture), c_funloc(cb_linear), c_funloc(cb_nearest))
   if (len_trim(glsl_version) > 0) then
      self%glsl = glsl_version//new_line('a')
   elseif (self%gl_version >= 410_c_int) then
      self%glsl = '#version 410'//new_line('a')
   else
      self%glsl = '#version 130'//new_line('a')
   endif
   self%polygon_mode = .not. self%es3
   self%bind_sampler = self%gl_version >= 330_c_int .or. self%es3
   endfunction init

   subroutine new_frame(self)
   !< The device objects, made on the first frame (the shader program, buffers, samplers).
   class(gl3_renderer), intent(inout) :: self !< Renderer.

   if (self%shader == 0_c_int) then
      if (.not. self%create_objects()) error stop 'figure_render_gl3: the device objects were not made'
   endif
   endsubroutine new_frame

   subroutine textures(self, dd)
   !< Dear ImGui's textures created, updated and destroyed as the frame asks (ImDrawData::Textures).
   class(gl3_renderer), intent(inout) :: self !< Renderer.
   type(c_ptr),         intent(in)    :: dd   !< `ImDrawData*`.
   integer(c_int)                     :: n, k !< Textures, counter.
   type(c_ptr)                        :: td   !< `ImTextureData*`.
   integer(c_int)                     :: status, format, w, h, unused, refs, nup !< Its state.
   integer(c_long_long)               :: id   !< Its GL name.

   self%dd = dd
   n = figure_ImDrawData_textures(dd)
   do k = 0_c_int, n - 1_c_int
      td = figure_ImDrawData_texture(dd, k)
      nup = figure_ImTextureData_state(td, status, format, w, h, id, unused, refs)
      if (status /= ImTextureStatus_OK) call self%update_texture(td)
   enddo
   endsubroutine textures

   subroutine render(self, frame, width, height, clear, rgb)
   !< Draw `frame` into the bound framebuffer (width x height pixels), as the backend's RenderDrawData; the native
   !< layer clears it and reads it back (`clear` and `rgb` are not used: a GPU renderer's picture is the framebuffer).
   class(gl3_renderer), intent(inout) :: self      !< Renderer.
   type(render_frame),  intent(in)    :: frame     !< Frame.
   integer(int32),      intent(in)    :: width     !< Framebuffer width [pixels].
   integer(int32),      intent(in)    :: height    !< Framebuffer height [pixels].
   real(c_float),       intent(in)    :: clear(3)  !< Not used.
   integer(int8),       intent(inout) :: rgb(:)    !< Not used.
   integer(c_int) :: last_active(1), last_program(1), last_texture(1), last_sampler(1), last_array(1), last_vao(1)
   integer(c_int) :: last_poly(2), last_viewport(4), last_scissor(4), last_bsrc_rgb(1), last_bdst_rgb(1)
   integer(c_int) :: last_bsrc_a(1), last_bdst_a(1), last_beq_rgb(1), last_beq_a(1) !< The saved state.
   integer(c_signed_char) :: on_blend, on_cull, on_depth, on_stencil, on_scissor, on_restart !< ... capabilities.
   integer(c_int)         :: vao(1)        !< The frame's vertex array.
   integer(c_int)         :: fb_w, fb_h    !< Framebuffer size.
   integer(int32)         :: l, c          !< List, command.
   real(c_float)          :: cmin(2), cmax(2) !< A scissor rectangle in the framebuffer.
   type(c_ptr)            :: p             !< A buffer.
   integer(c_long_long)   :: tex           !< A command's texture.

   associate(cl => clear, pix => rgb, w0 => width, h0 => height)
   endassociate
   if (frame%nlists < 0_int32) return
   fb_w = int(frame%size(1) * frame%fb_scale(1) + 0.5_c_float, c_int)
   fb_h = int(frame%size(2) * frame%fb_scale(2) + 0.5_c_float, c_int)
   if (fb_w <= 0_c_int .or. fb_h <= 0_c_int) return
   ! the GL state, saved
   call glGetIntegerv(GL_ACTIVE_TEXTURE, last_active)
   call glActiveTexture(GL_TEXTURE0)
   call glGetIntegerv(GL_CURRENT_PROGRAM, last_program)
   call glGetIntegerv(GL_TEXTURE_BINDING_2D, last_texture)
   last_sampler = 0_c_int
   if (self%bind_sampler) call glGetIntegerv(GL_SAMPLER_BINDING, last_sampler)
   call glGetIntegerv(GL_ARRAY_BUFFER_BINDING, last_array)
   call glGetIntegerv(GL_VERTEX_ARRAY_BINDING, last_vao)
   if (self%polygon_mode) call glGetIntegerv(GL_POLYGON_MODE, last_poly)
   call glGetIntegerv(GL_VIEWPORT, last_viewport)
   call glGetIntegerv(GL_SCISSOR_BOX, last_scissor)
   call glGetIntegerv(GL_BLEND_SRC_RGB, last_bsrc_rgb)
   call glGetIntegerv(GL_BLEND_DST_RGB, last_bdst_rgb)
   call glGetIntegerv(GL_BLEND_SRC_ALPHA, last_bsrc_a)
   call glGetIntegerv(GL_BLEND_DST_ALPHA, last_bdst_a)
   call glGetIntegerv(GL_BLEND_EQUATION_RGB, last_beq_rgb)
   call glGetIntegerv(GL_BLEND_EQUATION_ALPHA, last_beq_a)
   on_blend = glIsEnabled(GL_BLEND)
   on_cull = glIsEnabled(GL_CULL_FACE)
   on_depth = glIsEnabled(GL_DEPTH_TEST)
   on_stencil = glIsEnabled(GL_STENCIL_TEST)
   on_scissor = glIsEnabled(GL_SCISSOR_TEST)
   on_restart = 0_c_signed_char
   if (.not. self%es3 .and. self%gl_version >= 310_c_int) on_restart = glIsEnabled(GL_PRIMITIVE_RESTART)
   ! the render state; a vertex array made for the frame (as the backend: one context or several)
   call glGenVertexArrays(1_c_int, vao)
   call self%setup(frame, fb_w, fb_h, vao(1))
   do l = 1_int32, frame%nlists
      associate(lst => frame%lists(l))
         p = c_null_ptr
         if (associated(lst%vtx)) then
            if (size(lst%vtx) > 0) p = c_loc(lst%vtx(1))
         endif
         call glBufferData(GL_ARRAY_BUFFER, list_size(lst%vtx) * VTX_SIZE, addr(p), GL_STREAM_DRAW)
         p = c_null_ptr
         if (associated(lst%idx)) then
            if (size(lst%idx) > 0) p = c_loc(lst%idx(1))
         endif
         call glBufferData(GL_ELEMENT_ARRAY_BUFFER, idx_count(lst) * IDX_SIZE, addr(p), GL_STREAM_DRAW)
         do c = 1_int32, lst%ncmd
            select case (lst%kind(c))
            case (RENDER_RESET)
               call self%setup(frame, fb_w, fb_h, vao(1))
            case (RENDER_SAMPLER_LINEAR)
               call self%set_sampler(1_int32, GL_LINEAR)
            case (RENDER_SAMPLER_NEAREST)
               call self%set_sampler(2_int32, GL_NEAREST)
            case (RENDER_SAMPLER_FROM_TEXTURE)
               if (self%bind_sampler) then
                  self%sampler = 0_c_int
                  call glBindSampler(0_c_int, 0_c_int)
               endif
               self%use_bind_sampler = .false.
               self%use_tex_filter = .false.
            case (RENDER_CALLBACK)
               call figure_ImDrawData_callback(self%dd, int(l - 1_int32, c_int), int(c - 1_int32, c_int))
            case (RENDER_DRAW)
               ! the scissor rectangle in the framebuffer (Y up), as the backend computes it in single precision
               cmin = (lst%clip(1:2, c) - frame%pos) * frame%fb_scale
               cmax = (lst%clip(3:4, c) - frame%pos) * frame%fb_scale
               if (cmax(1) <= cmin(1) .or. cmax(2) <= cmin(2)) cycle
               call glScissor(int(cmin(1), c_int), int(real(fb_h, c_float) - cmax(2), c_int), &
                              int(cmax(1) - cmin(1), c_int), int(cmax(2) - cmin(2), c_int))
               tex = lst%tex_id(c)
               if (c_associated(lst%tex_data(c))) tex = figure_ImTextureData_id(lst%tex_data(c))
               call glBindTexture(GL_TEXTURE_2D, int(tex, c_int))
               if (self%use_tex_filter) then
                  call glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, self%tex_filter)
                  call glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, self%tex_filter)
               endif
               if (self%gl_version >= 320_c_int) then
                  call glDrawElementsBaseVertex(GL_TRIANGLES, int(lst%count(c), c_int), GL_UNSIGNED_SHORT, &
                                                int(lst%idx_offset(c), c_intptr_t) * IDX_SIZE,              &
                                                int(lst%vtx_offset(c), c_int))
               else
                  call glDrawElements(GL_TRIANGLES, int(lst%count(c), c_int), GL_UNSIGNED_SHORT, &
                                      int(lst%idx_offset(c), c_intptr_t) * IDX_SIZE)
               endif
            endselect
         enddo
      endassociate
   enddo
   call glDeleteVertexArrays(1_c_int, vao)
   ! the GL state, restored
   if (last_program(1) == 0_c_int) then
      call glUseProgram(last_program(1))
   elseif (glIsProgram(last_program(1)) /= 0_c_signed_char) then
      call glUseProgram(last_program(1))
   endif
   call glBindTexture(GL_TEXTURE_2D, last_texture(1))
   if (self%bind_sampler) call glBindSampler(0_c_int, last_sampler(1))
   call glActiveTexture(last_active(1))
   call glBindVertexArray(last_vao(1))
   call glBindBuffer(GL_ARRAY_BUFFER, last_array(1))
   call glBlendEquationSeparate(last_beq_rgb(1), last_beq_a(1))
   call glBlendFuncSeparate(last_bsrc_rgb(1), last_bdst_rgb(1), last_bsrc_a(1), last_bdst_a(1))
   call capability(GL_BLEND, on_blend)
   call capability(GL_CULL_FACE, on_cull)
   call capability(GL_DEPTH_TEST, on_depth)
   call capability(GL_STENCIL_TEST, on_stencil)
   call capability(GL_SCISSOR_TEST, on_scissor)
   if (.not. self%es3 .and. self%gl_version >= 310_c_int) call capability(GL_PRIMITIVE_RESTART, on_restart)
   if (self%polygon_mode) then
      if (self%gl_version <= 310_c_int .or. self%compat) then
         call glPolygonMode(GL_FRONT, last_poly(1))
         call glPolygonMode(GL_BACK, last_poly(2))
      else
         call glPolygonMode(GL_FRONT_AND_BACK, last_poly(1))
      endif
   endif
   call glViewport(last_viewport(1), last_viewport(2), last_viewport(3), last_viewport(4))
   call glScissor(last_scissor(1), last_scissor(2), last_scissor(3), last_scissor(4))
   endsubroutine render

   subroutine shutdown(self)
   !< The device objects released, Dear ImGui's textures this renderer alone holds destroyed (RefCount 1), the
   !< renderer unregistered from Dear ImGui (as the backend's Shutdown).
   class(gl3_renderer), intent(inout) :: self !< Renderer.
   integer(c_int)                     :: n, k, status, format, w, h, unused, refs, nup !< Textures, a texture's state.
   integer(c_long_long)               :: id   !< Its GL name.
   type(c_ptr)                        :: td   !< `ImTextureData*`.

   if (.not. associated(glDeleteProgram)) return ! never initialized
   if (self%samplers(1) /= 0_c_int) then
      call glDeleteSamplers(2_c_int, self%samplers)
      self%samplers = 0_c_int
   endif
   if (self%vbo /= 0_c_int) call glDeleteBuffers(1_c_int, [self%vbo])
   if (self%ebo /= 0_c_int) call glDeleteBuffers(1_c_int, [self%ebo])
   if (self%shader /= 0_c_int) call glDeleteProgram(self%shader)
   self%vbo = 0_c_int
   self%ebo = 0_c_int
   self%shader = 0_c_int
   n = figure_ImDrawData_textures(c_null_ptr) ! the platform's textures
   do k = 0_c_int, n - 1_c_int
      td = figure_ImDrawData_texture(c_null_ptr, k)
      nup = figure_ImTextureData_state(td, status, format, w, h, id, unused, refs)
      if (refs == 1_c_int) call destroy_texture(td, id)
   enddo
   call figure_renderer_backend(0_c_int, 0_c_int, 0_c_int, c_funloc(cb_reset), c_funloc(cb_from_texture), &
                                c_funloc(cb_linear), c_funloc(cb_nearest))
   self%dd = c_null_ptr
   endsubroutine shutdown

   function create_objects(self) result(ok)
   !< The shader program (the backend's shaders for the GLSL version), its uniforms and attributes, the vertex and
   !< index buffers, the samplers (linear, nearest; clamped to the edge); the bindings it changes restored.
   class(gl3_renderer), intent(inout) :: self !< Renderer.
   logical                            :: ok   !< Made.
   integer(c_int)                     :: last_texture(1), last_array(1), last_unpack(1), last_vao(1) !< Bindings.
   integer(c_int)                     :: version, ios, vert, frag, k, filter !< GLSL version, shaders.
   character(len=:), allocatable      :: vs, fs !< Their sources.
   character(len=1), parameter        :: NL = new_line('a') !< Newline.

   call glGetIntegerv(GL_TEXTURE_BINDING_2D, last_texture)
   call glGetIntegerv(GL_ARRAY_BUFFER_BINDING, last_array)
   last_unpack = 0_c_int
   if (self%gl_version >= 210_c_int) then
      call glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING, last_unpack)
      call glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0_c_int)
   endif
   call glGetIntegerv(GL_VERTEX_ARRAY_BINDING, last_vao)
   version = 130_c_int
   read(self%glsl(10:max(10, index(self%glsl, NL) - 1)), *, iostat=ios) version ! "#version N[ es]"
   if (ios /= 0) version = 130_c_int
   if (version < 130_c_int) then
      vs = 'uniform mat4 ProjMtx;'//NL//'attribute vec2 Position;'//NL//'attribute vec2 UV;'//NL//      &
           'attribute vec4 Color;'//NL//'varying vec2 Frag_UV;'//NL//'varying vec4 Frag_Color;'//NL// &
           'void main()'//NL//'{'//NL//'    Frag_UV = UV;'//NL//'    Frag_Color = Color;'//NL//       &
           '    gl_Position = ProjMtx * vec4(Position.xy,0,1);'//NL//'}'//NL
      fs = '#ifdef GL_ES'//NL//'    precision mediump float;'//NL//'#endif'//NL//'uniform sampler2D Texture;'//NL// &
           'varying vec2 Frag_UV;'//NL//'varying vec4 Frag_Color;'//NL//'void main()'//NL//'{'//NL//             &
           '    gl_FragColor = Frag_Color * texture2D(Texture, Frag_UV.st);'//NL//'}'//NL
   elseif (version >= 410_c_int) then
      vs = 'layout (location = 0) in vec2 Position;'//NL//'layout (location = 1) in vec2 UV;'//NL//            &
           'layout (location = 2) in vec4 Color;'//NL//'uniform mat4 ProjMtx;'//NL//'out vec2 Frag_UV;'//NL// &
           'out vec4 Frag_Color;'//NL//'void main()'//NL//'{'//NL//'    Frag_UV = UV;'//NL//                 &
           '    Frag_Color = Color;'//NL//'    gl_Position = ProjMtx * vec4(Position.xy,0,1);'//NL//'}'//NL
      fs = 'in vec2 Frag_UV;'//NL//'in vec4 Frag_Color;'//NL//'uniform sampler2D Texture;'//NL//              &
           'layout (location = 0) out vec4 Out_Color;'//NL//'void main()'//NL//'{'//NL//                     &
           '    Out_Color = Frag_Color * texture(Texture, Frag_UV.st);'//NL//'}'//NL
   elseif (version == 300_c_int) then
      vs = 'precision highp float;'//NL//'layout (location = 0) in vec2 Position;'//NL//                      &
           'layout (location = 1) in vec2 UV;'//NL//'layout (location = 2) in vec4 Color;'//NL//              &
           'uniform mat4 ProjMtx;'//NL//'out vec2 Frag_UV;'//NL//'out vec4 Frag_Color;'//NL//'void main()'//NL// &
           '{'//NL//'    Frag_UV = UV;'//NL//'    Frag_Color = Color;'//NL//                                  &
           '    gl_Position = ProjMtx * vec4(Position.xy,0,1);'//NL//'}'//NL
      fs = 'precision mediump float;'//NL//'uniform sampler2D Texture;'//NL//'in vec2 Frag_UV;'//NL//         &
           'in vec4 Frag_Color;'//NL//'layout (location = 0) out vec4 Out_Color;'//NL//'void main()'//NL//     &
           '{'//NL//'    Out_Color = Frag_Color * texture(Texture, Frag_UV.st);'//NL//'}'//NL
   else
      vs = 'uniform mat4 ProjMtx;'//NL//'in vec2 Position;'//NL//'in vec2 UV;'//NL//'in vec4 Color;'//NL//    &
           'out vec2 Frag_UV;'//NL//'out vec4 Frag_Color;'//NL//'void main()'//NL//'{'//NL//                  &
           '    Frag_UV = UV;'//NL//'    Frag_Color = Color;'//NL//                                            &
           '    gl_Position = ProjMtx * vec4(Position.xy,0,1);'//NL//'}'//NL
      fs = 'uniform sampler2D Texture;'//NL//'in vec2 Frag_UV;'//NL//'in vec4 Frag_Color;'//NL//              &
           'out vec4 Out_Color;'//NL//'void main()'//NL//'{'//NL//                                             &
           '    Out_Color = Frag_Color * texture(Texture, Frag_UV.st);'//NL//'}'//NL
   endif
   ok = .false.
   vert = compile(GL_VERTEX_SHADER, vs, 'vertex shader')
   if (vert == 0_c_int) return
   frag = compile(GL_FRAGMENT_SHADER, fs, 'fragment shader')
   if (frag == 0_c_int) return
   self%shader = glCreateProgram()
   call glAttachShader(self%shader, vert)
   call glAttachShader(self%shader, frag)
   call glLinkProgram(self%shader)
   if (.not. linked(self%shader)) return
   call glDetachShader(self%shader, vert)
   call glDetachShader(self%shader, frag)
   call glDeleteShader(vert)
   call glDeleteShader(frag)
   self%loc_tex = glGetUniformLocation(self%shader, 'Texture'//c_null_char)
   self%loc_proj = glGetUniformLocation(self%shader, 'ProjMtx'//c_null_char)
   self%loc_pos = glGetAttribLocation(self%shader, 'Position'//c_null_char)
   self%loc_uv = glGetAttribLocation(self%shader, 'UV'//c_null_char)
   self%loc_col = glGetAttribLocation(self%shader, 'Color'//c_null_char)
   block
      integer(c_int) :: names(1) !< A name.
      call glGenBuffers(1_c_int, names)
      self%vbo = names(1)
      call glGenBuffers(1_c_int, names)
      self%ebo = names(1)
   endblock
   if (self%bind_sampler) then
      call glGenSamplers(2_c_int, self%samplers)
      do k = 1_c_int, 2_c_int
         filter = merge(GL_LINEAR, GL_NEAREST, k == 1_c_int)
         call glSamplerParameteri(self%samplers(k), GL_TEXTURE_MIN_FILTER, filter)
         call glSamplerParameteri(self%samplers(k), GL_TEXTURE_MAG_FILTER, filter)
         call glSamplerParameteri(self%samplers(k), GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
         call glSamplerParameteri(self%samplers(k), GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
      enddo
   endif
   call glBindTexture(GL_TEXTURE_2D, last_texture(1))
   call glBindBuffer(GL_ARRAY_BUFFER, last_array(1))
   if (self%gl_version >= 210_c_int) call glBindBuffer(GL_PIXEL_UNPACK_BUFFER, last_unpack(1))
   call glBindVertexArray(last_vao(1))
   ok = .true.

   contains
      function compile(kind, source, what) result(handle)
      !< A shader of the version line and `source`, compiled; 0 (and the log on standard error) when it fails.
      integer(c_int),   intent(in)         :: kind   !< GL_VERTEX_SHADER or GL_FRAGMENT_SHADER.
      character(len=*), intent(in)         :: source !< Its source, after the version line.
      character(len=*), intent(in)         :: what   !< Its name in a message.
      integer(c_int)                       :: handle !< Shader.
      character(kind=c_char, len=:), allocatable, target :: s1, s2 !< The two strings, null-terminated.
      integer(c_intptr_t)                  :: strings(2) !< Their addresses.
      integer(c_int)                       :: status, n  !< Compile status, log length.

      s1 = trim(self%glsl)//c_null_char
      s2 = source//c_null_char
      strings = [addr(c_loc(s1)), addr(c_loc(s2))]
      handle = glCreateShader(kind)
      call glShaderSource(handle, 2_c_int, strings, 0_c_intptr_t)
      call glCompileShader(handle)
      status = 0_c_int
      n = 0_c_int
      call glGetShaderiv(handle, GL_COMPILE_STATUS, status)
      call glGetShaderiv(handle, GL_INFO_LOG_LENGTH, n)
      if (status == GL_FALSE) write(error_unit, '(A)') 'ERROR: figure_render_gl3: failed to compile '//what// &
                                                        '! With GLSL: '//trim(self%glsl)
      if (n > 1_c_int) then
         block
            character(kind=c_char, len=n + 1) :: log !< The log.
            log = ''
            call glGetShaderInfoLog(handle, n, 0_c_intptr_t, log)
            write(error_unit, '(A)') log(1:n - 1)
         endblock
      endif
      if (status == GL_FALSE) handle = 0_c_int
      endfunction compile

      logical function linked(program)
      !< The program linked (else its log on standard error).
      integer(c_int), intent(in) :: program !< Program.
      integer(c_int)             :: status, n !< Link status, log length.

      status = 0_c_int
      n = 0_c_int
      call glGetProgramiv(program, GL_LINK_STATUS, status)
      call glGetProgramiv(program, GL_INFO_LOG_LENGTH, n)
      if (status == GL_FALSE) write(error_unit, '(A)') 'ERROR: figure_render_gl3: failed to link shader program! '// &
                                                        'With GLSL '//trim(self%glsl)
      if (n > 1_c_int) then
         block
            character(kind=c_char, len=n + 1) :: log !< The log.
            log = ''
            call glGetProgramInfoLog(program, n, 0_c_intptr_t, log)
            write(error_unit, '(A)') log(1:n - 1)
         endblock
      endif
      linked = status /= GL_FALSE
      endfunction linked
   endfunction create_objects

   subroutine setup(self, frame, fb_w, fb_h, vao)
   !< The render state (the backend's SetupRenderState): blending, no culling, depth or stencil test, the scissor
   !< test, polygon fill, the viewport and orthographic projection, the program, the linear sampler, the vertex layout.
   class(gl3_renderer), intent(inout) :: self       !< Renderer.
   type(render_frame),  intent(in)    :: frame      !< Frame (the view).
   integer(c_int),      intent(in)    :: fb_w, fb_h !< Framebuffer size [pixels].
   integer(c_int),      intent(in)    :: vao        !< The frame's vertex array.
   real(c_float)                      :: l, r, t, b !< The view's edges.
   real(c_float)                      :: ortho(16)  !< Projection, column-major.

   call glEnable(GL_BLEND)
   call glBlendEquation(GL_FUNC_ADD)
   call glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
   call glDisable(GL_CULL_FACE)
   call glDisable(GL_DEPTH_TEST)
   call glDisable(GL_STENCIL_TEST)
   call glEnable(GL_SCISSOR_TEST)
   if (.not. self%es3 .and. self%gl_version >= 310_c_int) call glDisable(GL_PRIMITIVE_RESTART)
   if (self%polygon_mode) call glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
   call glViewport(0_c_int, 0_c_int, fb_w, fb_h)
   l = frame%pos(1)
   r = frame%pos(1) + frame%size(1)
   t = frame%pos(2)
   b = frame%pos(2) + frame%size(2)
   ortho = 0.0_c_float
   ortho(1) = 2.0_c_float / (r - l)
   ortho(6) = 2.0_c_float / (t - b)
   ortho(11) = -1.0_c_float
   ortho(13) = (r + l) / (l - r)
   ortho(14) = (t + b) / (b - t)
   ortho(16) = 1.0_c_float
   call glUseProgram(self%shader)
   call glUniform1i(self%loc_tex, 0_c_int)
   call glUniformMatrix4fv(self%loc_proj, 1_c_int, int(GL_FALSE, c_signed_char), ortho)
   self%use_bind_sampler = self%bind_sampler
   self%use_tex_filter = .false.
   self%sampler = 0_c_int
   self%tex_filter = 0_c_int
   if (self%bind_sampler .and. self%use_bind_sampler) then
      self%sampler = self%samplers(1)
      call glBindSampler(0_c_int, self%sampler)
   endif
   call glBindVertexArray(vao)
   call glBindBuffer(GL_ARRAY_BUFFER, self%vbo)
   call glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self%ebo)
   call glEnableVertexAttribArray(self%loc_pos)
   call glEnableVertexAttribArray(self%loc_uv)
   call glEnableVertexAttribArray(self%loc_col)
   call glVertexAttribPointer(self%loc_pos, 2_c_int, GL_FLOAT, int(GL_FALSE, c_signed_char), int(VTX_SIZE, c_int), &
                              0_c_intptr_t)
   call glVertexAttribPointer(self%loc_uv, 2_c_int, GL_FLOAT, int(GL_FALSE, c_signed_char), int(VTX_SIZE, c_int), &
                              8_c_intptr_t)
   call glVertexAttribPointer(self%loc_col, 4_c_int, GL_UNSIGNED_BYTE, int(GL_TRUE, c_signed_char), &
                              int(VTX_SIZE, c_int), 16_c_intptr_t)
   endsubroutine setup

   subroutine set_sampler(self, which, filter)
   !< The linear (1) or nearest (2) sampler's callback: its sampler object bound, or its filter set on each texture.
   class(gl3_renderer), intent(inout) :: self   !< Renderer.
   integer(int32),      intent(in)    :: which  !< 1 linear, 2 nearest.
   integer(c_int),      intent(in)    :: filter !< GL_LINEAR or GL_NEAREST.

   if (self%bind_sampler .and. self%use_bind_sampler) then
      self%sampler = self%samplers(which)
      self%use_tex_filter = .false.
      call glBindSampler(0_c_int, self%sampler)
   else
      self%use_tex_filter = .true.
      self%tex_filter = filter
   endif
   endsubroutine set_sampler

   subroutine update_texture(self, td)
   !< One of Dear ImGui's textures: created (RGBA8, linear, clamped), its update rectangles uploaded, or destroyed
   !< once unused, as its status asks (the backend's UpdateTexture); its status set back.
   class(gl3_renderer), intent(inout) :: self !< Renderer.
   type(c_ptr),         intent(in)    :: td   !< `ImTextureData*`.
   integer(c_int)       :: status, format, w, h, unused, refs, nup, k, ch !< Its state, updates, counter, channels.
   integer(c_long_long) :: id                 !< Its GL name.
   integer(c_int)       :: last_row(1), last_align(1), last_texture(1), name(1), rect(4) !< Saved state, a name.
   type(c_ptr)          :: pixels             !< Its pixels.
   integer(int8), pointer :: px(:)            !< ... as bytes.
   logical              :: save               !< The unpack state saved and restored.

   associate(s => self)
   endassociate
   nup = figure_ImTextureData_state(td, status, format, w, h, id, unused, refs)
   save = status == ImTextureStatus_WantCreate .or. status == ImTextureStatus_WantUpdates
   if (save) then
      call glGetIntegerv(GL_UNPACK_ROW_LENGTH, last_row)
      call glGetIntegerv(GL_UNPACK_ALIGNMENT, last_align)
      call glPixelStorei(GL_UNPACK_ALIGNMENT, 1_c_int)
   endif
   if (status == ImTextureStatus_WantCreate) then
      if (figure_ImTextureData_pixels(td, pixels, w, h, ch) /= 1_c_int) pixels = c_null_ptr
      call glGetIntegerv(GL_TEXTURE_BINDING_2D, last_texture)
      call glGenTextures(1_c_int, name)
      call glBindTexture(GL_TEXTURE_2D, name(1))
      call glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
      call glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
      call glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
      call glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
      call glPixelStorei(GL_UNPACK_ROW_LENGTH, 0_c_int)
      call glTexImage2D(GL_TEXTURE_2D, 0_c_int, GL_RGBA, w, h, 0_c_int, GL_RGBA, GL_UNSIGNED_BYTE, addr(pixels))
      call figure_ImTextureData_set(td, int(name(1), c_long_long), ImTextureStatus_OK)
      call glBindTexture(GL_TEXTURE_2D, last_texture(1))
   elseif (status == ImTextureStatus_WantUpdates) then
      call glGetIntegerv(GL_TEXTURE_BINDING_2D, last_texture)
      call glBindTexture(GL_TEXTURE_2D, int(id, c_int))
      call glPixelStorei(GL_UNPACK_ROW_LENGTH, w)
      if (figure_ImTextureData_pixels(td, pixels, w, h, ch) == 1_c_int) then
         call c_f_pointer(pixels, px, [int(w, int64) * int(h, int64) * int(ch, int64)])
         do k = 0_c_int, nup - 1_c_int
            call figure_ImTextureData_rect(td, k, rect) ! x, y, w, h; the pixels at (x, y)
            call glTexSubImage2D(GL_TEXTURE_2D, 0_c_int, rect(1), rect(2), rect(3), rect(4), GL_RGBA, GL_UNSIGNED_BYTE, &
                                 addr(c_loc(px(1_int64 + (int(rect(1), int64) + int(rect(2), int64) * int(w, int64)) * ch))))
         enddo
      endif
      call figure_ImTextureData_set(td, id, ImTextureStatus_OK)
      call glBindTexture(GL_TEXTURE_2D, last_texture(1))
   elseif (status == ImTextureStatus_WantDestroy .and. unused > 0_c_int) then
      call destroy_texture(td, id)
   endif
   if (save) then
      call glPixelStorei(GL_UNPACK_ROW_LENGTH, last_row(1))
      call glPixelStorei(GL_UNPACK_ALIGNMENT, last_align(1))
   endif
   endsubroutine update_texture

   subroutine destroy_texture(td, id)
   !< One of Dear ImGui's textures deleted; its id cleared, its status Destroyed.
   type(c_ptr),          intent(in) :: td !< `ImTextureData*`.
   integer(c_long_long), intent(in) :: id !< Its GL name.

   call glDeleteTextures(1_c_int, [int(id, c_int)])
   call figure_ImTextureData_set(td, 0_c_long_long, ImTextureStatus_Destroyed)
   endsubroutine destroy_texture

   subroutine capability(cap, on)
   !< A capability enabled or disabled as it was.
   integer(c_int),         intent(in) :: cap !< Capability.
   integer(c_signed_char), intent(in) :: on  !< It was enabled.

   if (on /= 0_c_signed_char) then
      call glEnable(cap)
   else
      call glDisable(cap)
   endif
   endsubroutine capability

   pure function list_size(v) result(n)
   !< A list's vertices (0 when it has none).
   use figure_drawlist, only : draw_vert
   type(draw_vert), pointer, intent(in) :: v(:) !< Vertices.
   integer(c_intptr_t)                  :: n    !< How many.

   n = 0_c_intptr_t
   if (associated(v)) n = size(v, kind=c_intptr_t)
   endfunction list_size

   pure function idx_count(lst) result(n)
   !< A list's indices (0 when it has none).
   use figure_render, only : render_list
   type(render_list), intent(in) :: lst !< List.
   integer(c_intptr_t)           :: n   !< How many.

   n = 0_c_intptr_t
   if (associated(lst%idx)) n = size(lst%idx, kind=c_intptr_t)
   endfunction idx_count

   pure function addr(p) result(a)
   !< A C pointer as the integer the GL interfaces take.
   type(c_ptr), intent(in) :: p !< Pointer.
   integer(c_intptr_t)     :: a !< Its address.

   a = transfer(p, 0_c_intptr_t)
   endfunction addr

   function c_string(p, n) result(s)
   !< The first n characters of a C string (blank-padded; blank for a null pointer).
   type(c_ptr),    intent(in) :: p !< C string.
   integer,        intent(in) :: n !< Characters wanted.
   character(len=n)           :: s !< Them.
   character(kind=c_char), pointer :: c(:) !< The string's bytes.
   integer                    :: k !< Counter.

   s = ''
   if (.not. c_associated(p)) return
   call c_f_pointer(p, c, [n])
   do k = 1, n
      if (c(k) == c_null_char) exit
      s(k:k) = c(k)
   enddo
   endfunction c_string

   function load() result(ok)
   !< The GL functions of the current context, through SDL_GL_GetProcAddress: `.false.` (and a message) when one is
   !< missing.
   logical :: ok !< All found.

   ok = .true.
   call c_f_procpointer(get('glGetIntegerv'), glGetIntegerv)
   call c_f_procpointer(get('glGetString'), glGetString)
   call c_f_procpointer(get('glActiveTexture'), glActiveTexture)
   call c_f_procpointer(get('glUseProgram'), glUseProgram)
   call c_f_procpointer(get('glEnable'), glEnable)
   call c_f_procpointer(get('glDisable'), glDisable)
   call c_f_procpointer(get('glBlendEquation'), glBlendEquation)
   call c_f_procpointer(get('glBindVertexArray'), glBindVertexArray)
   call c_f_procpointer(get('glEnableVertexAttribArray'), glEnableVertexAttribArray)
   call c_f_procpointer(get('glCompileShader'), glCompileShader)
   call c_f_procpointer(get('glLinkProgram'), glLinkProgram)
   call c_f_procpointer(get('glDeleteShader'), glDeleteShader)
   call c_f_procpointer(get('glDeleteProgram'), glDeleteProgram)
   call c_f_procpointer(get('glBindTexture'), glBindTexture)
   call c_f_procpointer(get('glBindBuffer'), glBindBuffer)
   call c_f_procpointer(get('glPolygonMode'), glPolygonMode)
   call c_f_procpointer(get('glBlendEquationSeparate'), glBlendEquationSeparate)
   call c_f_procpointer(get('glUniform1i'), glUniform1i)
   call c_f_procpointer(get('glPixelStorei'), glPixelStorei)
   call c_f_procpointer(get('glAttachShader'), glAttachShader)
   call c_f_procpointer(get('glDetachShader'), glDetachShader)
   call c_f_procpointer(get('glTexParameteri'), glTexParameteri)
   call c_f_procpointer(get('glBlendFuncSeparate'), glBlendFuncSeparate)
   call c_f_procpointer(get('glViewport'), glViewport)
   call c_f_procpointer(get('glScissor'), glScissor)
   call c_f_procpointer(get('glIsEnabled'), glIsEnabled)
   call c_f_procpointer(get('glIsProgram'), glIsProgram)
   call c_f_procpointer(get('glGenVertexArrays'), glGenVertexArrays)
   call c_f_procpointer(get('glDeleteVertexArrays'), glDeleteVertexArrays)
   call c_f_procpointer(get('glGenTextures'), glGenTextures)
   call c_f_procpointer(get('glDeleteTextures'), glDeleteTextures)
   call c_f_procpointer(get('glGenBuffers'), glGenBuffers)
   call c_f_procpointer(get('glDeleteBuffers'), glDeleteBuffers)
   call c_f_procpointer(get('glUniformMatrix4fv'), glUniformMatrix4fv)
   call c_f_procpointer(get('glVertexAttribPointer'), glVertexAttribPointer)
   call c_f_procpointer(get('glBufferData'), glBufferData)
   call c_f_procpointer(get('glDrawElements'), glDrawElements)
   call c_f_procpointer(get('glTexImage2D'), glTexImage2D)
   call c_f_procpointer(get('glTexSubImage2D'), glTexSubImage2D)
   call c_f_procpointer(get('glCreateShader'), glCreateShader)
   call c_f_procpointer(get('glCreateProgram'), glCreateProgram)
   call c_f_procpointer(get('glShaderSource'), glShaderSource)
   call c_f_procpointer(get('glGetShaderiv'), glGetShaderiv)
   call c_f_procpointer(get('glGetProgramiv'), glGetProgramiv)
   call c_f_procpointer(get('glGetShaderInfoLog'), glGetShaderInfoLog)
   call c_f_procpointer(get('glGetProgramInfoLog'), glGetProgramInfoLog)
   call c_f_procpointer(get('glGetUniformLocation'), glGetUniformLocation)
   call c_f_procpointer(get('glGetAttribLocation'), glGetAttribLocation)
   ! GL 3.2 and 3.3 (optional: used when the context's version has them)
   call c_f_procpointer(get('glDrawElementsBaseVertex', .false.), glDrawElementsBaseVertex)
   call c_f_procpointer(get('glBindSampler', .false.), glBindSampler)
   call c_f_procpointer(get('glGenSamplers', .false.), glGenSamplers)
   call c_f_procpointer(get('glDeleteSamplers', .false.), glDeleteSamplers)
   call c_f_procpointer(get('glSamplerParameteri', .false.), glSamplerParameteri)

   contains
      function get(name, required) result(f)
      !< A GL function's address.
      character(len=*), intent(in)           :: name     !< Its name.
      logical,          intent(in), optional :: required !< Missing is an error (default).
      type(c_funptr)                         :: f        !< Address.
      logical                                :: needed   !< Required.

      f = SDL_GL_GetProcAddress(name//c_null_char)
      needed = .true.
      if (present(required)) needed = required
      if (needed .and. .not. c_associated(f)) then
         write(error_unit, '(A)') 'figure_render_gl3: the GL function '//name//' is missing'
         ok = .false.
      endif
      endfunction get
   endfunction load

   ! the samplers' callbacks registered in Dear ImGui: never called by this renderer, which tells them apart by their
   ! addresses (figure_render_imgui: RENDER_RESET, RENDER_SAMPLER_*) and follows them itself
   subroutine cb_reset(list, cmd) bind(C)
   !< The render state's reset.
   type(c_ptr), value :: list !< `const ImDrawList*`.
   type(c_ptr), value :: cmd  !< `const ImDrawCmd*`.
   associate(a => list, b => cmd)
   endassociate
   endsubroutine cb_reset

   subroutine cb_from_texture(list, cmd) bind(C)
   !< The sampler: each texture's own filter.
   type(c_ptr), value :: list !< `const ImDrawList*`.
   type(c_ptr), value :: cmd  !< `const ImDrawCmd*`.
   associate(a => list, b => cmd)
   endassociate
   endsubroutine cb_from_texture

   subroutine cb_linear(list, cmd) bind(C)
   !< The sampler: linear.
   type(c_ptr), value :: list !< `const ImDrawList*`.
   type(c_ptr), value :: cmd  !< `const ImDrawCmd*`.
   associate(a => list, b => cmd)
   endassociate
   endsubroutine cb_linear

   subroutine cb_nearest(list, cmd) bind(C)
   !< The sampler: nearest.
   type(c_ptr), value :: list !< `const ImDrawList*`.
   type(c_ptr), value :: cmd  !< `const ImDrawCmd*`.
   associate(a => list, b => cmd)
   endassociate
   endsubroutine cb_nearest
endmodule figure_render_gl3
