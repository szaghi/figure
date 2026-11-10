if (ig_selectable(trim(label), i == body_of(block))) call select(first_of(i))
if (reveal .and. i == body_of(block)) call ig_scroll_here(0.5_real64) ! this row to the middle
