call ig_push_item_width(ig_em(12))                ! every field 12 em wide
call ig_separator_text('Grid')
call label('name')
if (ig_input_text('##name', case_name)) continue
s = ig_last_item()
field = s%rect
call label('cells')
if (ig_input('##cells', cells, step=16_int32)) continue
call ig_separator_text('Run')
call label('CFL')
if (ig_input('##cfl', cfl)) continue
call label('end time [s]')
if (ig_input('##t_end', t_end)) continue
call label('viscous')
if (ig_checkbox('##viscous', viscous)) continue
call ig_pop_item_width()
call ig_spacing()
call ig_align_begin('buttons', 'right')           ! at the right edge, whatever their width at this font
if (ig_button('Reset')) continue
call ig_same_line()
if (ig_button('Run')) continue
call ig_align_end()
