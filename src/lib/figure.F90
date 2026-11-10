!< FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.
module figure
!< FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.
!<
!< Umbrella module: `use figure` gives the application loop (figure_app), the Dear ImGui widgets (figure_imgui),
!< numbers and choices (figure_numbers: fields, drag boxes and sliders of any kind, vectors, radio buttons, list boxes),
!< a canvas and drawing primitives (figure_canvas: an area taking the mouse, lines, shapes, text and images on a layer),
!< menus, popups and shortcuts (figure_menu), groups of widgets (figure_group: child regions, collapsing headers, tabs,
!< tables, trees, id scopes, disabled blocks), docking (figure_dock), the style colours and variables by name (figure_style),
!< the ImPlot plots (figure_implot): items, heatmaps, images, their style (`ip_spec`) and ImPlot's constants, and the
!< GPU textures (figure_texture) that `ig_image` and `ip_image` draw, PNG and JPEG files read (`fig_read_image`,
!< `tex%load`), and the Lucide icons by name, `ICON_*`
!< (figure_icons), UTF-8 strings for any label: `ig_button(ICON_PLAY//' Run')`; programs started from the program and
!< a view of their output (figure_process: `process_object`, `log_view_object`); Fortran procedures run on a worker
!< thread (figure_task: `task_object`, `task_handle_object`); 3-D views of meshes (figure_view3d: `view3d_object`);
!< a player for snapshots (figure_player: `player_object`, `ig_player`).
use figure_app, only : app_object
use figure_base, only : figure_last_error, figure_time
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
                         ig_table_sort, ig_table_row_color, ig_table_hovered_column, ig_table_column_enabled, &
                         ig_tree_node, ig_tree_pop, ig_set_next_item_open, ig_begin_group, ig_end_group,    &
                         ig_align_begin, ig_align_end, ig_align_next
use figure_cimgui_enums, only : ImGuiTableFlags_None, ImGuiTableFlags_Resizable, ImGuiTableFlags_Reorderable, &
                                ImGuiTableFlags_Hideable, ImGuiTableFlags_Sortable, &
                                ImGuiTableFlags_NoSavedSettings, ImGuiTableFlags_ContextMenuInBody, &
                                ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersInnerH, &
                                ImGuiTableFlags_BordersOuterH, ImGuiTableFlags_BordersInnerV, &
                                ImGuiTableFlags_BordersOuterV, ImGuiTableFlags_BordersH, ImGuiTableFlags_BordersV, &
                                ImGuiTableFlags_BordersInner, ImGuiTableFlags_BordersOuter, &
                                ImGuiTableFlags_Borders, ImGuiTableFlags_NoBordersInBody, &
                                ImGuiTableFlags_NoBordersInBodyUntilResize, ImGuiTableFlags_SizingFixedFit, &
                                ImGuiTableFlags_SizingFixedSame, ImGuiTableFlags_SizingStretchProp, &
                                ImGuiTableFlags_SizingStretchSame, ImGuiTableFlags_NoHostExtendX, &
                                ImGuiTableFlags_NoHostExtendY, ImGuiTableFlags_NoKeepColumnsVisible, &
                                ImGuiTableFlags_PreciseWidths, ImGuiTableFlags_NoClip, ImGuiTableFlags_PadOuterX, &
                                ImGuiTableFlags_NoPadOuterX, ImGuiTableFlags_NoPadInnerX, ImGuiTableFlags_ScrollX, &
                                ImGuiTableFlags_ScrollY, ImGuiTableFlags_SortMulti, ImGuiTableFlags_SortTristate, &
                                ImGuiTableFlags_HighlightHoveredColumn
use figure_menu, only : ig_begin_main_menu_bar, ig_begin_menu, ig_begin_menu_bar, ig_end_main_menu_bar, ig_end_menu, &
                        ig_end_menu_bar, ig_menu_item, ig_set_next_item_shortcut, ig_shortcut, ig_open_popup, &
                        ig_begin_popup, ig_begin_popup_modal, ig_end_popup, ig_close_current_popup, &
                        ig_begin_popup_context
use figure_imgui, only : ig_begin, ig_begin_side_bar, ig_splitter, ig_button, ig_checkbox, ig_end, ig_image, &
                         ig_item_rect, ig_same_line, &
                         ig_separator, ig_set_next_window, ig_show_demo_window, ig_text, ig_input_text,  &
                         ig_set_next_item_width, ig_combo, ig_tooltip, ig_selectable, ig_text_wrapped,      &
                         ig_text_disabled, ig_text_colored, ig_tool_button, ig_focus_window,            &
                         ig_align_text_to_frame_padding, ig_text_size, ig_progress_bar, ig_input_text_multiline, &
                         text_buffer_object, ig_set_clipboard, ig_get_clipboard, item_status_object, ig_last_item, &
                         ig_item_hovered, ig_any_item_hovered, ig_any_item_active, ig_scroll_here, ig_get_scroll, &
                         ig_set_scroll, ig_scroll_to_pos, ig_focus_here, ig_default_focus, ig_font_size,   &
                         ig_line_height, ig_frame_height, ig_em, ig_available, ig_spacing, ig_dummy, ig_new_line, &
                         ig_indent, ig_unindent, ig_separator_text, ig_push_item_width, ig_pop_item_width, &
                         ig_begin_tooltip, ig_begin_item_tooltip, ig_end_tooltip, ig_text_link, ig_text_link_url
use figure_implot, only : ip_setup_axis, ip_set_axes, ip_setup_axis_limits, ip_setup_axis_ticks,                  &
                          ip_setup_axis_constraints, ip_setup_legend,                                             &
                          ip_begin_subplots, ip_end_subplots,                                              &
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
                          ip_contour_lines, ip_contour_levels, ip_colormap_legend, &
                          ip_colormap_legend_edit, ip_field_image
use figure_implot, only : ip_plot_hovered, ip_plot_mouse, ip_plot_to_pixels, ip_pixels_to_plot, ip_plot_selection, &
                          ip_cancel_selection, ip_drag_rect, ip_tag, ip_inf_lines, ip_text, ip_stairs, ip_stems,     &
                          ip_histogram, ip_histogram2d, ImPlotStairsFlags_PreStep, ImPlotStairsFlags_Shaded,         &
                          ImPlotStemsFlags_Horizontal, ImPlotInfLinesFlags_Horizontal,                               &
                          ImPlotHistogramFlags_Horizontal, ImPlotHistogramFlags_Cumulative,                          &
                          ImPlotHistogramFlags_Density, ImPlotHistogramFlags_NoOutliers, ImPlotBin_Sqrt,             &
                          ImPlotBin_Sturges, ImPlotBin_Rice, ImPlotBin_Scott
use figure_imgui, only : ig_color_edit
use figure_numbers, only : ig_input, ig_drag, ig_slider, ig_slider_angle, ig_drag_range, ig_radio, ig_list_box
use figure_canvas, only : canvas_event_object, ig_canvas, ig_cursor_screen_pos, ig_invisible_button, ig_draw_line, &
                          ig_draw_rect, ig_draw_circle, ig_draw_polyline, ig_draw_polygon, ig_draw_text, ig_draw_image
use figure_style, only : ig_pop_style_color, ig_pop_style_var, ig_push_style_color, ig_push_style_var,        &
                         ip_pop_style_color, ip_pop_style_var, ip_push_style_color, ip_push_style_var,        &
                         ig_get_style_color, ig_get_style_var, ig_pop_font, ig_push_font, ig_set_style_color,    &
                         ig_set_style_var, ig_show_style_editor, ip_get_style_color, ip_get_style_var,                 &
                         ip_set_style_color, ip_set_style_var
use figure_texture, only : fig_read_image, texture_object
use figure_process, only : process_object, log_view_object
use figure_task, only : task_object, task_handle_object, task_work
use figure_view3d, only : view3d_object
use figure_player, only : player_object, ig_player

implicit none
private
public :: app_object, fig_read_image, figure_last_error, figure_time
public :: FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
public :: ig_splitter
public :: ig_begin, ig_begin_side_bar, ig_button, ig_checkbox, ig_end, ig_input, ig_item_rect, ig_same_line, ig_separator
public :: ig_set_next_window, ig_show_demo_window, ig_slider, ig_text, ig_image
public :: ig_drag, ig_slider_angle, ig_drag_range, ig_radio, ig_list_box
public :: canvas_event_object, ig_canvas, ig_cursor_screen_pos, ig_invisible_button
public :: ig_draw_line, ig_draw_rect, ig_draw_circle, ig_draw_polyline, ig_draw_polygon, ig_draw_text, ig_draw_image
public :: ig_input_text, ig_set_next_item_width, ig_combo, ig_tooltip
public :: ig_selectable, ig_text_wrapped, ig_text_disabled, ig_text_colored, ig_begin_child, ig_end_child
public :: ig_collapsing_header, ig_begin_tab_bar, ig_end_tab_bar, ig_begin_tab, ig_end_tab, ig_push_id, ig_pop_id
public :: ig_begin_disabled, ig_end_disabled
public :: ig_begin_table, ig_end_table, ig_table_setup_column, ig_table_headers_row, ig_table_next_row
public :: ig_table_next_column, ig_table_set_column, list_clipper_object
public :: ig_table_sort, ig_table_row_color, ig_table_hovered_column, ig_table_column_enabled
public :: ig_tree_node, ig_tree_pop, ig_set_next_item_open
public :: ig_tool_button, ig_focus_window, ig_align_text_to_frame_padding, ig_text_size, ig_progress_bar
public :: ig_input_text_multiline, text_buffer_object
public :: ig_set_clipboard, ig_get_clipboard
public :: item_status_object, ig_last_item, ig_item_hovered, ig_any_item_hovered, ig_any_item_active
public :: ig_scroll_here, ig_get_scroll, ig_set_scroll, ig_scroll_to_pos, ig_focus_here, ig_default_focus
public :: ig_font_size, ig_line_height, ig_frame_height, ig_em, ig_available, ig_spacing, ig_dummy, ig_new_line
public :: ig_indent, ig_unindent, ig_separator_text, ig_push_item_width, ig_pop_item_width
public :: ig_begin_tooltip, ig_begin_item_tooltip, ig_end_tooltip, ig_text_link, ig_text_link_url
public :: ig_begin_group, ig_end_group, ig_align_begin, ig_align_end, ig_align_next
public :: ImGuiTableFlags_None, ImGuiTableFlags_Resizable, ImGuiTableFlags_Reorderable
public :: ImGuiTableFlags_Hideable, ImGuiTableFlags_Sortable, ImGuiTableFlags_NoSavedSettings
public :: ImGuiTableFlags_ContextMenuInBody, ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersInnerH
public :: ImGuiTableFlags_BordersOuterH, ImGuiTableFlags_BordersInnerV, ImGuiTableFlags_BordersOuterV
public :: ImGuiTableFlags_BordersH, ImGuiTableFlags_BordersV, ImGuiTableFlags_BordersInner
public :: ImGuiTableFlags_BordersOuter, ImGuiTableFlags_Borders, ImGuiTableFlags_NoBordersInBody
public :: ImGuiTableFlags_NoBordersInBodyUntilResize, ImGuiTableFlags_SizingFixedFit
public :: ImGuiTableFlags_SizingFixedSame, ImGuiTableFlags_SizingStretchProp
public :: ImGuiTableFlags_SizingStretchSame, ImGuiTableFlags_NoHostExtendX, ImGuiTableFlags_NoHostExtendY
public :: ImGuiTableFlags_NoKeepColumnsVisible, ImGuiTableFlags_PreciseWidths, ImGuiTableFlags_NoClip
public :: ImGuiTableFlags_PadOuterX, ImGuiTableFlags_NoPadOuterX, ImGuiTableFlags_NoPadInnerX
public :: ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SortMulti
public :: ImGuiTableFlags_SortTristate, ImGuiTableFlags_HighlightHoveredColumn
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
public :: ig_begin_popup_context
public :: ip_get_style_color, ip_get_style_var, ip_set_style_color, ip_set_style_var
public :: ImGuiDockNodeFlags_None, ImGuiDockNodeFlags_NoDockingOverCentralNode, ImGuiDockNodeFlags_NoDockingSplit
public :: ImGuiDockNodeFlags_NoResize, ImGuiDockNodeFlags_AutoHideTabBar, ImGuiDockNodeFlags_NoUndocking
public :: ip_bars, ip_begin_plot, ip_end_plot, ip_line, ip_scatter, ip_setup_axes, ip_shaded, ip_spec, plot_spec_object
public :: ip_colormap_scale, ip_heatmap, ip_image, texture_object
public :: ip_colormap, ip_colormap_names, ip_load_colormap
public :: ip_error_bars, ip_annotation, ip_drag_line_x, ip_drag_line_y, ip_drag_point
public :: ip_contour, ip_contour_lines, ip_contour_levels
public :: ip_colormap_legend, ip_colormap_legend_edit, ip_field_image
public :: ig_color_edit
public :: process_object, log_view_object, task_object, task_handle_object, task_work
public :: view3d_object
public :: player_object, ig_player
public :: ip_plot_limits, ip_plot_size, ip_setup_axes_limits, ip_begin_subplots, ip_end_subplots
public :: ip_setup_axis, ip_set_axes, ip_setup_axis_limits, ip_setup_axis_ticks, ip_setup_axis_constraints
public :: ip_setup_legend
public :: ImPlotMarker_None, ImPlotMarker_Auto, ImPlotMarker_Circle, ImPlotMarker_Square, ImPlotMarker_Diamond
public :: ImPlotMarker_Up, ImPlotMarker_Down, ImPlotMarker_Left, ImPlotMarker_Right, ImPlotMarker_Cross
public :: ImPlotMarker_Plus, ImPlotMarker_Asterisk, ImPlotMarker_Vertical, ImPlotMarker_Horizontal
public :: ImPlotItemFlags_None, ImPlotItemFlags_NoLegend, ImPlotItemFlags_NoFit
public :: ImPlotLineFlags_Segments, ImPlotLineFlags_Loop, ImPlotLineFlags_SkipNaN, ImPlotLineFlags_NoClip
public :: ImPlotLineFlags_Shaded, ImPlotScatterFlags_NoClip, ImPlotBarsFlags_Horizontal
public :: ip_plot_hovered, ip_plot_mouse, ip_plot_to_pixels, ip_pixels_to_plot, ip_plot_selection, ip_cancel_selection
public :: ip_drag_rect, ip_tag, ip_inf_lines, ip_text, ip_stairs, ip_stems, ip_histogram, ip_histogram2d
public :: ImPlotStairsFlags_PreStep, ImPlotStairsFlags_Shaded, ImPlotStemsFlags_Horizontal, ImPlotInfLinesFlags_Horizontal
public :: ImPlotHistogramFlags_Horizontal, ImPlotHistogramFlags_Cumulative, ImPlotHistogramFlags_Density
public :: ImPlotHistogramFlags_NoOutliers, ImPlotBin_Sqrt, ImPlotBin_Sturges, ImPlotBin_Rice, ImPlotBin_Scott
public :: ImPlotColormap_Deep, ImPlotColormap_Dark, ImPlotColormap_Pastel, ImPlotColormap_Paired, ImPlotColormap_Viridis
public :: ImPlotColormap_Plasma, ImPlotColormap_Hot, ImPlotColormap_Cool, ImPlotColormap_Pink, ImPlotColormap_Jet
public :: ImPlotColormap_Twilight, ImPlotColormap_RdBu, ImPlotColormap_BrBG, ImPlotColormap_PiYG, ImPlotColormap_Spectral
public :: ImPlotColormap_Greys
include 'figure_icons_public.inc' ! public :: ICON_..., generated by scripts/gen_icons.py
endmodule figure
