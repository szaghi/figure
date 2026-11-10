call ig_align_begin('close', 'right')          ! the button at the right edge: its width from the last frame
if (ig_button('Close')) call ig_close_current_popup()
call ig_align_end()
