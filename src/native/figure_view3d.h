/* FIGURE's 3-D view (view3d_object): a software rasterizer drawing meshes into an RGBA texture, the same in every mode
 * (window, remote, headless). See docs/guide/view3d.md.
 *
 * The C ABI below is called by src/lib/figure_view3d.F90 (its interfaces are there, private). Conventions as
 * figure_native.h: int status (FIG_OK or FIG_ERR_*), strings as (pointer, byte length), no C++ exception escapes.
 * Every entry point runs on the main thread (the Fortran side refuses calls from tasks); the rasterizer may split a
 * frame over its own worker threads (threads > 1), which touch nothing else.
 *
 * Data in place: a mesh keeps the addresses of the program's arrays (coordinates, connectivity, scalars) and reads
 * them at every render; it derives once per change (at its creation and at fig_view3d_changed) the 0-based triangle
 * list, the edges and the vertex normals. A render happens only when something changed: the camera, the size, a
 * mesh, its style, the clipping planes or the background.
 */
#ifndef FIGURE_VIEW3D_H
#define FIGURE_VIEW3D_H

#ifdef __cplusplus
extern "C" {
#endif

/* A view: threads in [1, 4] (bands of rows rendered in parallel), fast_moves 1 renders at half resolution while the
 * user moves the camera, lighting 1 shades by a headlight, background rgb in [0, 1] (NULL: the window's background
 * colour of the style). */
int  fig_view3d_create(int threads, int fast_moves, int lighting, const double *background, int *handle);
void fig_view3d_destroy(int handle);
/* A mesh, kind 0 triangles conn(3, ncell), 1 quads conn(4, ncell), 2 a structured surface xyz(3, ni, nj) (conn
 * NULL), 3 lines: segments conn(2, ncell), or a polyline through the nv points (conn NULL). xyz(3, nv) real64;
 * conn 1-based int32. Returns its id (from 1). */
int  fig_view3d_mesh(int handle, int kind, const double *xyz, long long nv, const int *conn, long long ncell, int ni,
                     int nj, int *mesh);
/* The mesh's scalar, per vertex (on_cells 0, n = nv) or per cell (on_cells 1, n = the cells; for lines: segments);
 * scalar NULL removes it. */
int  fig_view3d_scalar(int handle, int mesh, const double *scalar, long long n, int on_cells);
/* Style: colormap name (len 0: keep), range (set_range 1: [vmin, vmax]; 2: back to the data's range), colour rgb (NULL:
 * keep), edges (-1 keep, 0 off, 1 on), edge colour (NULL keep), flat (-1 keep), visible (-1 keep). */
int  fig_view3d_style(int handle, int mesh, const char *colormap, int colormap_len, int set_range, double vmin,
                      double vmax, const double *color, int edges, const double *edge_color, int flat, int visible);
int  fig_view3d_remove(int handle, int mesh); /* mesh 0: every mesh */
int  fig_view3d_changed(int handle, int mesh); /* mesh 0: every mesh; the data changed in place */
/* Camera: target(3), distance, azimuth and elevation [degrees], fov (vertical field of view [degrees]). set: mask bits
 * 1 target, 2 distance, 4 azimuth, 8 elevation, 16 fov. */
int  fig_view3d_camera(int handle, int set, int mask, double *target, double *distance, double *azimuth,
                       double *elevation, double *fov);
int  fig_view3d_fit(int handle);
int  fig_view3d_standard(int handle, int which); /* 0 +x, 1 -x, 2 +y, 3 -y, 4 +z, 5 -z: the eye on that side */
/* Relative moves: orbit [degrees], pan along the screen's right and up [world units], zoom (distance / factor). */
int  fig_view3d_move(int handle, double d_azimuth, double d_elevation, double pan_right, double pan_up, double zoom);
/* Clipping planes (at most 6): the part where (x - point) . normal >= 0 is kept. */
int  fig_view3d_clip(int handle, const double *normal, const double *point);
int  fig_view3d_unclip(int handle);
/* The widget: width, height [pixels] as Dear ImGui's sizes (0: the available region, negative: up to that distance
 * from its edge). Draws the image, handles the mouse (left drag orbit, right or middle drag or shift + left pan,
 * wheel zoom, double click fit). */
int  fig_view3d_draw(int handle, const char *id, int id_len, double width, double height);
/* The element under (x, y) [pixels from the view's top-left] in the last render: hit 0 none; mesh id, element (from
 * 1: triangle, quad or cell), the point (world). what 0 pick at (x, y), 1 the element hovered in the last draw, 2 the
 * one clicked in the last draw. */
int  fig_view3d_pick(int handle, int what, double x, double y, int *hit, int *mesh, long long *element,
                     double *point);
/* The last render: its pixels (rgba NULL: only the size), size, renders so far, its time [ms], half resolution. */
int  fig_view3d_image(int handle, unsigned char *rgba, long long cap, int *width, int *height);
int  fig_view3d_info(int handle, int *renders, double *ms, int *width, int *height, int *half);
/* The camera's view and projection matrices (column-major 4x4, OpenGL's conventions) for the widget's size at the last
 * draw (1 x 1 before the first); either NULL: not wanted. */
int  fig_view3d_matrices(int handle, double *view, double *projection);
/* Gizmos (ImGuizmo), drawn over the image of the view drawn in this frame and window. The view cube: size [pixels],
 * corner 0 top-right, 1 top-left, 2 bottom-right, 3 bottom-left; changed 1 when it turned the camera. A gizmo moving
 * matrix (column-major 4x4, its last row 0 0 0 1): mode 0 translate, 1 rotate, 2 scale; space 0 world, 1 local; snap
 * (has_snap 1) in world units, degrees or a scale step; changed 1 when the user moved it (matrix updated). */
int  fig_view3d_cube(int handle, double size, int corner, int *changed);
int  fig_view3d_gizmo(int handle, const char *id, int id_len, double *matrix, int mode, int space, int has_snap,
                      double snap, int *changed);

#ifdef __cplusplus
}
#endif

#endif
