if (ig_shortcut('left', repeat=.true.)) probe_x = max(0.0_real64, probe_x - flx / (size(field, 1) - 1)) ! a node
if (ig_shortcut('right', repeat=.true.)) probe_x = min(flx, probe_x + flx / (size(field, 1) - 1))     ! left, right
