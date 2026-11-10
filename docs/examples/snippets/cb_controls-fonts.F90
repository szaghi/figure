call ig_push_font('plex-mono')                          ! columns of numbers that line up
call ig_text('   step   residual')
call ig_text('    100   1.25e-03')
call ig_text('   1000   4.10e-07')
call ig_pop_font()
call ig_push_font('', 28.0_real64)                      ! a big value, in the current font
call ig_text('3.1416')
call ig_pop_font()
