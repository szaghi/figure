if (ig_radio('fixed', kind, 1_int32)) changing = .true. ! a click sets kind to the button's value
call ig_same_line()
if (ig_radio('insulated', kind, 2_int32)) changing = .true.
inp%bc_kind(k) = KINDS(kind)
