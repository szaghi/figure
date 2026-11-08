list = problems(inp)
if (size(list) == 0) return
call app%palette_color('error', red)              ! the palette's: right in a light palette and in a dark one
do k = 1_int32, size(list, kind=int32)
   call ig_text_colored('[!!] '//trim(list(k)), red) ! a mark with the colour: never colour alone
enddo
