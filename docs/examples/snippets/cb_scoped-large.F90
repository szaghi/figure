call ig_text('residual')
write(line, '(ES9.2)') residual
call ig_push_font('', 36.0_real64)                    ! the current font, larger
call ig_text(trim(adjustl(line)))
call ig_pop_font()
