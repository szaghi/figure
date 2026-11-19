do k = 1_int32, size(list, kind=int32)            ! a mark with the colour: never colour alone
   if (ig_text_link('[!!] '//trim(list(k)))) then ! a click: the section, scrolled to, its field given the keys
      section = SECTION_OF(ids(k))
      reveal = section
      focus_on = ids(k)
   endif
   if (k == 1_int32) call centre_of_last(problem_at)
enddo
