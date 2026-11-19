if (ig_input_text('title', inp%title)) continue    ! the field edits the variable as the user types
call centre_of_last(title_at)                     ! for the test: where a user would click
last = ig_last_item()                             ! what happened to the field, in one snapshot
if (last%activated) title_before = inp%title       ! it took the keys: the title as it was
if (last%deactivated_after_edit .and. inp%title /= title_before) then ! left after an edit: commit it
   before = inp
   before%title = title_before
   call push_undo(before)                         ! one undo step for the whole edit, not one per key
   edited = .true.
   call show_title()
endif
