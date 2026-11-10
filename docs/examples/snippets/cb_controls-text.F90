call ig_separator()
call ig_align_text_to_frame_padding()                   ! the label level with the field's text
call ig_text('CFL')
call ig_same_line(ig_em(5))                             ! the field at 5 em from the left edge
call ig_set_next_item_width(ig_em(8))
if (ig_input('##cfl', cfl, format='%.3f')) continue
call ig_item_rect(r(1), r(2), r(3), r(4))
cfl_at = [0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4))]
call ig_same_line()
call ig_text_disabled('default 0.5')
if (cfl > 1.0_real64) call ig_text_colored('[!!] above 1: the explicit scheme is unstable', &
                                           [0.90_real64, 0.35_real64, 0.25_real64])
r(1:2) = ig_text_size('Apply')                          ! width, height [pixels]
r(3:4) = ig_text_size('Restore defaults')
w = max(r(1), r(3))                                     ! the widest label
if (ig_button('Apply', width=w + ig_em(1))) continue    ! two buttons of one width
call ig_same_line()
if (ig_button('Restore defaults', width=w + ig_em(1))) cfl = 0.5_real64
call ig_text_wrapped('The CFL number bounds the time step: dt = CFL dx / max|u|. Values above 1 make the ' // &
                     'explicit scheme unstable; 0.5 is a safe start for a new case.')
