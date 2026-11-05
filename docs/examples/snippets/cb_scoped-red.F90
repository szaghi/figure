call ig_push_style_color('Button', '#b42d1a')         ! this button only
call ig_push_style_color('ButtonHovered', '#d9442c')
call ig_push_style_color('ButtonActive', '#e8664c')
call ig_push_style_var('FramePadding', [16.0_real64, 6.0_real64])
if (ig_button('Stop')) running = .false.
call ig_pop_style_var()
call ig_pop_style_color(3)                            ! the three colours
