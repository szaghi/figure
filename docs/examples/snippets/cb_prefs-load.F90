found = app%load_pref('case', case_file, default='naca0012.inp')
found = app%load_pref('cfl', cfl, default=0.8_real64)
found = app%load_pref('grid', grid, default=.true.)
