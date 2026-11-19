call app%add_window('Case', closable=.false.)     ! always there: no close button
do k = 2_int32, size(PANELS, kind=int32)
   call app%add_window(trim(PANELS(k)))           ! Input, Run, Result, 3-D: closed with their tab's button
enddo
call app%add_window('Messages', visible=.false.)  ! opened from Help > Messages, or the View menu
call app%add_window('Help', visible=.false.)      ! opened from Help > Help (F1): floating, in no layout
call app%add_layout('Setup', windows=[character(len=8) :: 'Case', 'Input', 'Run', 'Result', '3-D'])
call app%add_layout('Analysis', windows=[character(len=8) :: 'Case', 'Run', 'Result', '3-D', 'Messages'])
