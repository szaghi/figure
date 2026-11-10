call app%save_pref('case', trim(case_file))          ! kept: written within 30 s and at destroy
call app%save_pref('cfl', cfl)
call app%save_pref('grid', grid)
