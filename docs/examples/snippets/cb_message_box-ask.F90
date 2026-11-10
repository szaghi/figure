if (app%quit_requested()) asking = .true.
if (asking) then                                         ! every frame until answered
   answer = app%message_box('quit', 'Quit?', 'The case has unsaved changes.', &
                            [character(len=10) :: 'Quit', 'Save first', 'Cancel'])
   select case (answer)
   case (0)                                              ! still open
   case (1)
      write(output_unit, '(A)') 'quit'
      asking = .false.
      call app%quit()
   case (2)
      write(output_unit, '(A)') 'save first'
      asking = .false.
      saving = .true.                                    ! a message, then the question again
   case default
      write(output_unit, '(A)') 'cancelled'
      asking = .false.
   endselect
endif
