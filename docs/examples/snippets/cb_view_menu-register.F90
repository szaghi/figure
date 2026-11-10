call app%add_window('Case', closable=.false.)              ! always there: no close button
call app%add_window('Residuals')
call app%add_window('Log', visible=.false.)                ! hidden at the first run
call app%add_layout('Input', windows=[character(len=9) :: 'Case', 'Log'])
call app%add_layout('Monitor', windows=[character(len=9) :: 'Case', 'Residuals', 'Log'])
