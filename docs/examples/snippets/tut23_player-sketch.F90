call ig_canvas('sketch', -1.0_real64, ig_em(9), ev)  ! the width of the form, 9 em high
s = min((ev%size(1) - ig_em(10)) / inp%lx, (ev%size(2) - ig_em(3)) / inp%ly) ! the plate fits, labels around it
x0 = ev%origin(1) + ig_em(5)
y0 = ev%origin(2) + ev%size(2) - ig_em(1.5_real64) ! y up on the plate, down on the screen
x1 = x0 + s * inp%lx
y1 = y0 - s * inp%ly
ends(:, 1) = [x0, y0, x0, y1]                      ! west, east, south, north
ends(:, 2) = [x1, y0, x1, y1]
ends(:, 3) = [x0, y0, x1, y0]
ends(:, 4) = [x0, y1, x1, y1]
side_hover = 0_int32
if (ev%hovered) then                               ! hit testing is the program's: the side nearest the pointer
   do k = 1_int32, 4_int32
      d = segment_distance(ev%origin + ev%mouse, ends(:, k))
      if (d < 6.0_real64) side_hover = k
   enddo
endif
if (ev%clicked(1)) side_sel = side_hover           ! a click on the plate's inside clears the choice
call app%palette_color('text', text_rgb)
call ig_draw_rect(x0, y0, x1, y1, [0.35_real64, 0.33_real64, 0.30_real64], filled=.true.)
call ig_draw_circle(x0 + s * inp%body_x, y0 - s * inp%body_y, s * inp%body_r, [0.75_real64, 0.75_real64, &
                    0.78_real64], filled=.true.)
do k = 1_int32, 4_int32
   call ig_draw_line(ends(1, k), ends(2, k), ends(3, k), ends(4, k), &
                     merge(WARM, COOL, inp%bc_kind(k) == KINDS(1)), &
                     thickness=merge(5.0_real64, 2.0_real64, k == side_hover .or. k == side_sel))
enddo
call ig_draw_text(x0 - ig_em(4.5_real64), 0.5_real64 * (y0 + y1), side_label(1), text_rgb) ! the words carry
call ig_draw_text(x1 + ig_em(0.5_real64), 0.5_real64 * (y0 + y1), side_label(2), text_rgb) ! the meaning, not
call ig_draw_text(0.5_real64 * (x0 + x1), y0 + ig_em(0.2_real64), side_label(3), text_rgb) ! the colour alone
call ig_draw_text(0.5_real64 * (x0 + x1), y1 - ig_em(1.2_real64), side_label(4), text_rgb)
