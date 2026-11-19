if (ig_checkbox('hue wheel', wheel)) continue           ! the picker's form, chosen by the program
call ig_push_item_width(260.0_real64)                    ! the picker's width; its height follows
if (ig_color_picker('##surface', surface, wheel=wheel)) then ! true on the frames the user changes it
   write(text, '(A,4F6.2)') 'RGBA', surface
endif
call ig_pop_item_width()
call ig_text(trim(text))
