!< FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.
module figure
!< FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.
!<
!< Umbrella module: `use figure` gives the application loop (figure_app), the Dear ImGui widgets (figure_imgui) and
!< the ImPlot plots (figure_implot).
use figure_app, only : app_object
use figure_base, only : figure_last_error
use figure_c_native, only : FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
use figure_imgui, only : ig_begin, ig_button, ig_checkbox, ig_end, ig_input, ig_item_rect, ig_same_line, ig_separator, &
                         ig_set_next_window, ig_show_demo_window, ig_slider, ig_text
use figure_implot, only : ip_begin_plot, ip_end_plot, ip_line, ip_setup_axes

implicit none
private
public :: app_object, figure_last_error
public :: FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
public :: ig_begin, ig_button, ig_checkbox, ig_end, ig_input, ig_item_rect, ig_same_line, ig_separator
public :: ig_set_next_window, ig_show_demo_window, ig_slider, ig_text
public :: ip_begin_plot, ip_end_plot, ip_line, ip_setup_axes
endmodule figure
