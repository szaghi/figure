subroutine label(text)
!< A label, then the next item 7 em from the window's left edge, level with it.
character(len=*), intent(in) :: text !< Label.
call ig_align_text_to_frame_padding()
call ig_text(text)
call ig_same_line(ig_em(7))
endsubroutine label
