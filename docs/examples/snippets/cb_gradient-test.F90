call ip_colormap_stops('cool-warm', positions, colours)
write(output_unit, '(A,I0,A)') 'cool-warm: ', size(positions), ' stops'
if (.not. test_item_rect('##points', x, y, w, hr)) error stop 'no stops row'
mid = (size(positions, kind=int32) + 1_int32) / 2_int32
write(output_unit, '(A,F6.3,A,3F6.3)') 'its middle stop at ', positions(mid), ', colour', colours(:, mid)
cx = x + positions(mid) * (w - hr) + 0.5_real64 * hr     ! ImGradient's square of the stop at t
call drag(cx, y + 0.5_real64 * hr, cx + 0.03_real64 * w, y + 0.5_real64 * hr)
call ip_colormap_stops('cool-warm', positions, colours)
write(output_unit, '(A,F6.3)') 'dragged by 3% of the row, now at ', positions(mid)
call test_mouse_move(x + 0.9_real64 * w, y + 0.5_real64 * hr) ! a double click adds a stop
call test_next_frame()
call test_next_frame()
do k = 1_int32, 2_int32
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_mouse_button(.false.)
   call test_next_frame()
enddo
call frames(8_int32)
call ip_colormap_stops('cool-warm', positions, colours)
write(output_unit, '(A,I0,A)') 'after a double click: ', size(positions), ' stops'
call save('cool-warm', 'cb_gradient.csv.tmp')
call ip_load_colormap('cool-warm-saved', 'cb_gradient.csv.tmp')
diff = 0.0_real64
do k = 0_int32, 100_int32
   call plot_colormap_sample(ip_colormap('cool-warm'), real(k, real32) / 100.0_real32, a)
   call plot_colormap_sample(ip_colormap('cool-warm-saved'), real(k, real32) / 100.0_real32, b)
   diff = max(diff, abs(real(a(1) - b(1), real64)), abs(real(a(2) - b(2), real64)), abs(real(a(3) - b(3), real64)))
enddo
write(output_unit, '(A,I0,A)') 'saved and read back: within ', nint(diff * 255.0_real64), ' of 255 per channel'
