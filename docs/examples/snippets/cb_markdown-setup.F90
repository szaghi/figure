type(markdown_view_object)    :: help       !< The help page.
character(len=:), allocatable :: url        !< A link clicked in this frame.
character(len=:), allocatable :: last       !< The link clicked last.
call help%init()
call help%load(trim(file), stat=stat)
if (stat /= FIG_OK) call help%set_text('# Help'//new_line('a')//new_line('a')//'The help file `'//trim(file)// &
                                       '` cannot be read.')
