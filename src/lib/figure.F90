!< FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.
module figure
!< FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.
!<
!< Umbrella module: `use figure` gives the application loop (figure_app), the Dear ImGui widgets (figure_imgui) and
!< the ImPlot plots (figure_implot): items, heatmaps, images, their style (`ip_spec`) and ImPlot's constants, and the
!< GPU textures (figure_texture) that `ig_image` and `ip_image` draw.
use figure_app, only : app_object
use figure_base, only : figure_last_error
use figure_c_native, only : FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
use figure_imgui, only : ig_begin, ig_button, ig_checkbox, ig_end, ig_image, ig_input, ig_item_rect, ig_same_line,     &
                         ig_separator, ig_set_next_window, ig_show_demo_window, ig_slider, ig_text
use figure_implot, only : ip_bars, ip_begin_plot, ip_colormap_scale, ip_end_plot, ip_heatmap, ip_image, ip_line,          &
                          ip_scatter, ip_setup_axes, ip_shaded, ip_spec, plot_spec_object,                            &
                          ImPlotMarker_None, ImPlotMarker_Auto, ImPlotMarker_Circle, ImPlotMarker_Square,             &
                          ImPlotMarker_Diamond, ImPlotMarker_Up, ImPlotMarker_Down, ImPlotMarker_Left,                &
                          ImPlotMarker_Right, ImPlotMarker_Cross, ImPlotMarker_Plus, ImPlotMarker_Asterisk,           &
                          ImPlotMarker_Vertical, ImPlotMarker_Horizontal,                                             &
                          ImPlotItemFlags_None, ImPlotItemFlags_NoLegend, ImPlotItemFlags_NoFit,                      &
                          ImPlotLineFlags_Segments, ImPlotLineFlags_Loop, ImPlotLineFlags_SkipNaN,                    &
                          ImPlotLineFlags_NoClip, ImPlotLineFlags_Shaded, ImPlotScatterFlags_NoClip,                  &
                          ImPlotBarsFlags_Horizontal,                                                                 &
                          ImPlotColormap_Deep, ImPlotColormap_Dark, ImPlotColormap_Pastel, ImPlotColormap_Paired,     &
                          ImPlotColormap_Viridis, ImPlotColormap_Plasma, ImPlotColormap_Hot, ImPlotColormap_Cool,     &
                          ImPlotColormap_Pink, ImPlotColormap_Jet, ImPlotColormap_Twilight, ImPlotColormap_RdBu,      &
                          ImPlotColormap_BrBG, ImPlotColormap_PiYG, ImPlotColormap_Spectral, ImPlotColormap_Greys
use figure_texture, only : texture_object

implicit none
private
public :: app_object, figure_last_error
public :: FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
public :: ig_begin, ig_button, ig_checkbox, ig_end, ig_input, ig_item_rect, ig_same_line, ig_separator
public :: ig_set_next_window, ig_show_demo_window, ig_slider, ig_text, ig_image
public :: ip_bars, ip_begin_plot, ip_end_plot, ip_line, ip_scatter, ip_setup_axes, ip_shaded, ip_spec, plot_spec_object
public :: ip_colormap_scale, ip_heatmap, ip_image, texture_object
public :: ImPlotMarker_None, ImPlotMarker_Auto, ImPlotMarker_Circle, ImPlotMarker_Square, ImPlotMarker_Diamond
public :: ImPlotMarker_Up, ImPlotMarker_Down, ImPlotMarker_Left, ImPlotMarker_Right, ImPlotMarker_Cross
public :: ImPlotMarker_Plus, ImPlotMarker_Asterisk, ImPlotMarker_Vertical, ImPlotMarker_Horizontal
public :: ImPlotItemFlags_None, ImPlotItemFlags_NoLegend, ImPlotItemFlags_NoFit
public :: ImPlotLineFlags_Segments, ImPlotLineFlags_Loop, ImPlotLineFlags_SkipNaN, ImPlotLineFlags_NoClip
public :: ImPlotLineFlags_Shaded, ImPlotScatterFlags_NoClip, ImPlotBarsFlags_Horizontal
public :: ImPlotColormap_Deep, ImPlotColormap_Dark, ImPlotColormap_Pastel, ImPlotColormap_Paired, ImPlotColormap_Viridis
public :: ImPlotColormap_Plasma, ImPlotColormap_Hot, ImPlotColormap_Cool, ImPlotColormap_Pink, ImPlotColormap_Jet
public :: ImPlotColormap_Twilight, ImPlotColormap_RdBu, ImPlotColormap_BrBG, ImPlotColormap_PiYG, ImPlotColormap_Spectral
public :: ImPlotColormap_Greys
endmodule figure
