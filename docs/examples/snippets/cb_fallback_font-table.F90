call ig_push_font('plex-mono')
call ig_text('field    residual   reference')
call ig_text(RHO//'        1.2e-06    '//RHO//INF)          ! Greek and the operators: Noto Sans Math
call ig_text(NABLA//'p       3.4e-05    |'//NABLA//'p|'//SQUARE) ! the superscripts: Plex Mono's own
call ig_pop_font()
