if (ig_tool_button('Input', ICON_FILE_PEN, selected=tool == 1)) tool = 1
call ig_tooltip('the input files')
call ig_same_line()
if (ig_tool_button('Monitor', ICON_ACTIVITY, selected=tool == 2)) tool = 2
call ig_tooltip('the residuals of the run')
