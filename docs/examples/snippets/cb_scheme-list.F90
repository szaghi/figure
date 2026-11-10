if (scheme == 3_int32) then                          ! a limiter only for TVD
   call ig_set_next_item_width(ig_em(10.0_real64))
   if (ig_combo('limiter', limiter, limiters)) call said('limiter')
endif
call ig_separator_text('applied to')
call ig_set_next_item_width(ig_em(10.0_real64))
if (ig_list_box('block', block, blocks, height=ig_em(9.0_real64))) call said('block')
