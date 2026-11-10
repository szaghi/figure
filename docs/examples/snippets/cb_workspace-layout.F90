call app%save_layout('workspace.layout', comment='result = shown', stat=stat)   ! any time
if (stat == FIG_OK) write(output_unit, '(A)') 'layout saved to workspace.layout'
call app%load_layout('workspace.layout', stat=stat)                           ! applied before the next frame
if (stat == FIG_OK) write(output_unit, '(A)') 'layout loaded from workspace.layout'
