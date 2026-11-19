call app%init_headless(1100_int32, 680_int32, decorations='figure') ! no window, no GPU: the title bar still drawn
call app%set_title('FIGURE studio')               ! headless mode has no title until one is set
call app%set_confirm_quit(.true.)
call view%init()
call frames(3_int32)
