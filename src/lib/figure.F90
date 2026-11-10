!< FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.
module figure
!< FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.
!<
!< Umbrella module: `use figure` gives the application loop (figure_app), the Dear ImGui widgets (figure_imgui),
!< menus, popups and shortcuts (figure_menu), groups of widgets (figure_group: child regions, collapsing headers, tabs,
!< tables, trees, id scopes, disabled blocks), docking (figure_dock), the style colours and variables by name (figure_style),
!< the ImPlot plots (figure_implot): items, heatmaps, images, their style (`ip_spec`) and ImPlot's constants, and the
!< GPU textures (figure_texture) that `ig_image` and `ip_image` draw, and the Lucide icons by name, `ICON_*`
!< (figure_icons), UTF-8 strings for any label: `ig_button(ICON_PLAY//' Run')`; programs started from the program and
!< a view of their output (figure_process: `process_object`, `log_view_object`); Fortran procedures run on a worker
!< thread (figure_task: `task_object`, `task_handle_object`); 3-D views of meshes (figure_view3d: `view3d_object`).
use figure_app, only : app_object
use figure_base, only : figure_last_error
use figure_c_native, only : FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
use figure_cimgui_enums, only : ImGuiDockNodeFlags_None, ImGuiDockNodeFlags_NoDockingOverCentralNode,         &
                                ImGuiDockNodeFlags_NoDockingSplit, ImGuiDockNodeFlags_NoResize,               &
                                ImGuiDockNodeFlags_AutoHideTabBar, ImGuiDockNodeFlags_NoUndocking
use figure_cimgui_enums, only : ImGuiWindowFlags_None, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, &
                                ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoScrollbar, &
                                ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoCollapse, &
                                ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground, &
                                ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoMouseInputs, &
                                ImGuiWindowFlags_HorizontalScrollbar, ImGuiWindowFlags_NoFocusOnAppearing, &
                                ImGuiWindowFlags_NoBringToFrontOnFocus, ImGuiWindowFlags_AlwaysVerticalScrollbar, &
                                ImGuiWindowFlags_AlwaysHorizontalScrollbar, ImGuiWindowFlags_NoNav, &
                                ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoInputs, ImGuiWindowFlags_NoDocking, &
                                ImGuiWindowFlags_MenuBar
use figure_icons ! every ICON_* constant, exported by the public statements of figure_icons_public.inc
use figure_dock, only : ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, ig_dock_split, &
                        ig_dock_window, ig_window_dock, ig_set_next_window_dock
use figure_cimgui_enums, only : ImGuiInputTextFlags_None, ImGuiInputTextFlags_CharsDecimal,                  &
                                ImGuiInputTextFlags_CharsScientific, ImGuiInputTextFlags_CharsUppercase,      &
                                ImGuiInputTextFlags_CharsNoBlank, ImGuiInputTextFlags_EnterReturnsTrue,       &
                                ImGuiInputTextFlags_ReadOnly, ImGuiInputTextFlags_Password,                   &
                                ImGuiInputTextFlags_AutoSelectAll, ImGuiInputTextFlags_WordWrap,              &
                                ImGuiInputTextFlags_NoUndoRedo
use figure_group, only : ig_begin_disabled, ig_begin_tab, ig_begin_tab_bar, ig_collapsing_header, ig_end_disabled, &
                         ig_end_tab, ig_end_tab_bar, ig_pop_id, ig_push_id, ig_begin_table, ig_end_table,    &
                         ig_table_setup_column, ig_table_headers_row, ig_table_next_row, ig_table_next_column, &
                         ig_table_set_column, ig_begin_child, ig_end_child, list_clipper_object,            &
                         ig_tree_node, ig_tree_pop, ig_set_next_item_open
use figure_cimgui_enums, only : ImGuiTableFlags_None, ImGuiTableFlags_Resizable, ImGuiTableFlags_RowBg,         &
                                ImGuiTableFlags_Borders, ImGuiTableFlags_BordersInnerV, ImGuiTableFlags_ScrollY, &
                                ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_SizingStretchSame
use figure_menu, only : ig_begin_main_menu_bar, ig_begin_menu, ig_begin_menu_bar, ig_end_main_menu_bar, ig_end_menu, &
                        ig_end_menu_bar, ig_menu_item, ig_set_next_item_shortcut, ig_shortcut, ig_open_popup, &
                        ig_begin_popup, ig_begin_popup_modal, ig_end_popup, ig_close_current_popup
use figure_imgui, only : ig_begin, ig_begin_side_bar, ig_button, ig_checkbox, ig_end, ig_image, ig_input, &
                         ig_item_rect, ig_same_line, &
                         ig_separator, ig_set_next_window, ig_show_demo_window, ig_slider, ig_text, ig_input_text,  &
                         ig_set_next_item_width, ig_combo, ig_tooltip, ig_selectable, ig_text_wrapped,      &
                         ig_text_disabled, ig_text_colored, ig_tool_button, ig_focus_window,            &
                         ig_align_text_to_frame_padding, ig_text_size, ig_progress_bar, ig_input_text_multiline, &
                         text_buffer_object, ig_set_clipboard, ig_get_clipboard
use figure_implot, only : ip_begin_subplots, ip_end_subplots,                                              &
                          ip_bars, ip_begin_plot, ip_colormap_scale, ip_end_plot, ip_heatmap, ip_image, ip_line,     &
                          ip_plot_limits, ip_plot_size, ip_scatter, ip_setup_axes, ip_setup_axes_limits, ip_shaded,   &
                          ip_spec, plot_spec_object, ip_colormap, ip_colormap_names, ip_load_colormap,                &
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
use figure_implot, only : ip_error_bars, ip_annotation, ip_drag_line_x, ip_drag_line_y, ip_drag_point, ip_contour, &
                          ip_contour_lines, ip_contour_levels, ip_colormap_legend
use figure_imgui, only : ig_color_edit
use figure_style, only : ig_pop_style_color, ig_pop_style_var, ig_push_style_color, ig_push_style_var,        &
                         ip_pop_style_color, ip_pop_style_var, ip_push_style_color, ip_push_style_var,        &
                         ig_get_style_color, ig_get_style_var, ig_pop_font, ig_push_font, ig_set_style_color,    &
                         ig_set_style_var, ig_show_style_editor, ip_get_style_color, ip_get_style_var,                 &
                         ip_set_style_color, ip_set_style_var
use figure_texture, only : texture_object
use figure_process, only : process_object, log_view_object
use figure_task, only : task_object, task_handle_object, task_work
use figure_view3d, only : view3d_object

implicit none
private
public :: app_object, figure_last_error
public :: FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
public :: ig_begin, ig_begin_side_bar, ig_button, ig_checkbox, ig_end, ig_input, ig_item_rect, ig_same_line, ig_separator
public :: ig_set_next_window, ig_show_demo_window, ig_slider, ig_text, ig_image
public :: ig_input_text, ig_set_next_item_width, ig_combo, ig_tooltip
public :: ig_selectable, ig_text_wrapped, ig_text_disabled, ig_text_colored, ig_begin_child, ig_end_child
public :: ig_collapsing_header, ig_begin_tab_bar, ig_end_tab_bar, ig_begin_tab, ig_end_tab, ig_push_id, ig_pop_id
public :: ig_begin_disabled, ig_end_disabled
public :: ig_begin_table, ig_end_table, ig_table_setup_column, ig_table_headers_row, ig_table_next_row
public :: ig_table_next_column, ig_table_set_column, list_clipper_object
public :: ig_tree_node, ig_tree_pop, ig_set_next_item_open
public :: ig_tool_button, ig_focus_window, ig_align_text_to_frame_padding, ig_text_size, ig_progress_bar
public :: ig_input_text_multiline, text_buffer_object
public :: ig_set_clipboard, ig_get_clipboard
public :: ImGuiTableFlags_None, ImGuiTableFlags_Resizable, ImGuiTableFlags_RowBg, ImGuiTableFlags_Borders
public :: ImGuiTableFlags_BordersInnerV, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit
public :: ImGuiTableFlags_SizingStretchSame
public :: ImGuiInputTextFlags_None, ImGuiInputTextFlags_CharsDecimal, ImGuiInputTextFlags_CharsScientific
public :: ImGuiInputTextFlags_CharsUppercase, ImGuiInputTextFlags_CharsNoBlank, ImGuiInputTextFlags_EnterReturnsTrue
public :: ImGuiInputTextFlags_ReadOnly, ImGuiInputTextFlags_Password, ImGuiInputTextFlags_AutoSelectAll
public :: ImGuiInputTextFlags_WordWrap, ImGuiInputTextFlags_NoUndoRedo
public :: ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, ig_dock_split, ig_dock_window
public :: ig_window_dock, ig_set_next_window_dock
public :: ig_get_style_color, ig_get_style_var, ig_set_style_color, ig_set_style_var, ig_show_style_editor
public :: ig_push_font, ig_pop_font
public :: ig_push_style_color, ig_pop_style_color, ig_push_style_var, ig_pop_style_var
public :: ip_push_style_color, ip_pop_style_color, ip_push_style_var, ip_pop_style_var
public :: ImGuiWindowFlags_None, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove
public :: ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoCollapse
public :: ImGuiWindowFlags_AlwaysAutoResize
public :: ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoMouseInputs
public :: ImGuiWindowFlags_HorizontalScrollbar
public :: ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoBringToFrontOnFocus, ImGuiWindowFlags_AlwaysVerticalScrollbar
public :: ImGuiWindowFlags_AlwaysHorizontalScrollbar
public :: ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoInputs, ImGuiWindowFlags_NoDocking
public :: ImGuiWindowFlags_MenuBar
public :: ig_begin_main_menu_bar, ig_end_main_menu_bar, ig_begin_menu_bar, ig_end_menu_bar, ig_begin_menu, ig_end_menu
public :: ig_menu_item, ig_set_next_item_shortcut, ig_shortcut
public :: ig_open_popup, ig_begin_popup, ig_begin_popup_modal, ig_end_popup, ig_close_current_popup
public :: ip_get_style_color, ip_get_style_var, ip_set_style_color, ip_set_style_var
public :: ImGuiDockNodeFlags_None, ImGuiDockNodeFlags_NoDockingOverCentralNode, ImGuiDockNodeFlags_NoDockingSplit
public :: ImGuiDockNodeFlags_NoResize, ImGuiDockNodeFlags_AutoHideTabBar, ImGuiDockNodeFlags_NoUndocking
public :: ip_bars, ip_begin_plot, ip_end_plot, ip_line, ip_scatter, ip_setup_axes, ip_shaded, ip_spec, plot_spec_object
public :: ip_colormap_scale, ip_heatmap, ip_image, texture_object
public :: ip_colormap, ip_colormap_names, ip_load_colormap
public :: ip_error_bars, ip_annotation, ip_drag_line_x, ip_drag_line_y, ip_drag_point
public :: ip_contour, ip_contour_lines, ip_contour_levels
public :: ip_colormap_legend
public :: ig_color_edit
public :: process_object, log_view_object, task_object, task_handle_object, task_work
public :: view3d_object
public :: ip_plot_limits, ip_plot_size, ip_setup_axes_limits, ip_begin_subplots, ip_end_subplots
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
include 'figure_icons_public.inc' ! public :: ICON_..., generated by scripts/gen_icons.py
endmodule figure
