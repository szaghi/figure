call ig_set_style_color('Button', '#2f5d50')            ! colours: hex or [r, g, b(, a)] in [0, 1]
call ig_set_style_color('ButtonHovered', '#3d7a69')
call ig_set_style_color('SliderGrab', '#e0b04c')
call ig_set_style_color('CheckMark', '#e0b04c')
call ig_set_style_var('FrameRounding', 6.0_real64)      ! a number
call ig_set_style_var('ItemSpacing', [10.0_real64, 8.0_real64]) ! a pair
call ip_set_style_color('PlotBg', '#101820')            ! ImPlot's colours, the same way
