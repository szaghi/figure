if (ig_shortcut('ctrl+z')) then                   ! focused: only while Input, or a region of it, has the focus
   if (form_shown) call undo()                    ! (in the text, ctrl+z is the text field's own undo)
endif
