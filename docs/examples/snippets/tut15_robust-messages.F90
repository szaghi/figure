call app%notifications(list, kinds, shown)        ! the last 100, oldest first
if (size(list) == 0) call ig_text_disabled('No message yet.')
do k = size(list, kind=int32), 1_int32, -1_int32
   select case (kinds(k))
   case ('error')
      call app%palette_color('error', rgba)
      call ig_text_colored('[!!] '//trim(list(k)), rgba)
   case ('warning')
      call app%palette_color('warning', rgba)
      call ig_text_colored('(!)  '//trim(list(k)), rgba)
   case ('success')
      call app%palette_color('success', rgba)
      call ig_text_colored('[ok] '//trim(list(k)), rgba)
   case default
      call ig_text('     '//trim(list(k)))
   endselect
enddo
