if (edited) then                                  ! in the bar drawn by FIGURE, and the task bar's
   call app%set_title('* '//trim(inp%title)//' - FIGURE studio')
else
   call app%set_title(trim(inp%title)//' - FIGURE studio')
endif
