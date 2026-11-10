subroutine draw(s)
!< The interface, one frame of it: the same procedure in the application and in its test.
type(case_state), intent(inout) :: s !< State.

if (ig_begin_main_menu_bar()) then
   if (ig_begin_menu('File')) then
      if (ig_begin_menu('Recent')) then
         if (ig_menu_item('cavity.toml')) s%file = 'cavity.toml'
         if (ig_menu_item('channel.toml')) s%file = 'channel.toml'
         call ig_end_menu()
      endif
      call ig_end_menu()
   endif
   call ig_end_main_menu_bar()
endif
call ig_set_next_window(10.0_real64, 30.0_real64, 400.0_real64, 300.0_real64, always=.true.)
if (ig_begin('Solver')) then
   if (ig_input('CFL', s%cfl, format='%.2f')) continue          ! path 'Solver/CFL'
   if (ig_tree_node('Options')) then                            ! path 'Solver/Options'
      if (ig_checkbox('Implicit', s%implicit)) continue         ! path 'Solver/Options/Implicit'
      call ig_tree_pop()
   endif
   if (ig_button(ICON_PLAY)) s%runs = s%runs + 1_int32          ! an icon alone: a name for the tooltip
   call ig_tooltip('Run the solver')
endif
call ig_end()
endsubroutine draw
