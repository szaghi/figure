!< tut08_shell, tutorial chapter 8: the studio's shell, menus with shortcuts, docked panels, looks and palettes.
program tut08_shell
!< tut08_shell, tutorial chapter 8: the studio's shell, menus with shortcuts, docked panels, looks and palettes.
!<
!< Chapter 7's window, with the shell the next chapters fill: menus in the title bar and their shortcuts, a bar of
!< workspace buttons on the left, four panels docked in a layout kept between runs, a look and a palette chosen from
!< the View menu, and an About box.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, FIG_OK, figure_last_error, ICON_CHART_AREA, ICON_FILE_PEN, ICON_FLAME, ICON_FOLDER, &
                   ICON_INFO, ICON_LAYOUT, ICON_PALETTE, ICON_PLAY, ICON_POWER_SQUARE, ig_begin, ig_begin_main_menu_bar, &
                   ig_begin_menu, ig_begin_popup_modal, ig_begin_side_bar, ig_button, ig_close_current_popup,      &
                   ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, ig_dock_split,             &
                   ig_dock_window, ig_end, ig_end_main_menu_bar, ig_end_menu, ig_end_popup, ig_focus_window,       &
                   ig_menu_item, ig_open_popup, ig_same_line, ig_separator, ig_set_next_window, ig_shortcut, ig_text, &
                   ig_text_disabled, ig_text_wrapped, ig_tool_button, ig_tooltip

implicit none
character(len=*), parameter :: PANELS(4) = [character(len=6) :: 'Case', 'Input', 'Run', 'Result'] !< The panels.
character(len=*), parameter :: LOOKS(4) = [character(len=7) :: 'seal', 'fusion', 'adwaita', 'fluent'] !< Looks.
character(len=*), parameter :: PALETTES(6) = [character(len=16) :: 'seal', 'seal-light', 'nord', 'gruvbox-dark', &
                                              'solarized-light', 'catppuccin-latte'] !< Some of the palettes.
character(len=*), parameter :: DEFAULT_LAYOUT = 'tut08_shell-default.layout' !< The layout as the program sets it.
type(app_object)            :: app          !< Application.
character(len=16)           :: arg          !< First argument.
character(len=16)           :: look         !< The look in effect.
character(len=16)           :: palette      !< The palette in effect.
logical                     :: shown(4)     !< The panels shown.
integer(int32)              :: current      !< The workspace chosen in the bar.
logical                     :: ask_quit     !< File > Quit or its shortcut.
logical                     :: about        !< Help > About or its shortcut.
logical                     :: save_default !< Save the layout set by the program, at the next frame.
logical                     :: have_default !< The default layout is saved: View > Reset layout can load it.

ask_quit = .false.
about = .false.
shown = .true.
current = 1_int32
look = 'seal'
palette = 'seal'
save_default = .false.
inquire(file=DEFAULT_LAYOUT, exist=have_default)
call get_command_argument(1, arg)
if (trim(arg) == '--left') then
   call open_window('left')
else
   call open_window()
endif
do while (app%next_frame())
   call draw_studio()
enddo
call app%destroy()

contains
   subroutine open_window(side)
   !< Open the studio's window, its frame drawn by FIGURE, its layout kept in a file between runs.
   character(len=*), intent(in), optional :: side !< Where the buttons go: 'left' or 'right' (absent: the platform's).
   integer(int32)                         :: stat !< Status of the icon.

   call app%init('FIGURE studio', 1100_int32, 680_int32, decorations='figure', buttons=side, &
                 ini_file='tut08_shell.ini')     ! Dear ImGui keeps the panels' layout here, between runs
   call app%set_icon(ICON_FLAME, stat=stat)
   if (stat /= FIG_OK) write(output_unit, '(A)') 'no window icon here: '//figure_last_error()
   call app%set_confirm_quit(.true.)
   endsubroutine open_window

   subroutine draw_studio()
   !< One frame of the studio.
   call draw_menus()
   call draw_tools()
   call draw_panels()
   call draw_dialogs()
   endsubroutine draw_studio

   subroutine draw_menus()
   !< The menus, in the title bar, and their shortcuts.
   integer(int32) :: k  !< Counter.
   logical        :: on !< A check mark.

   if (ig_begin_main_menu_bar()) then
      if (ig_begin_menu('File')) then
         if (ig_menu_item(ICON_POWER_SQUARE//' Quit', shortcut='Ctrl+Q')) ask_quit = .true.
         call ig_end_menu()
      endif
      if (ig_begin_menu('View')) then
         do k = 1_int32, size(PANELS, kind=int32)
            if (ig_menu_item(trim(PANELS(k)), selected=shown(k))) continue ! a pick toggles the check mark
         enddo
         call ig_separator()
         if (ig_begin_menu(ICON_LAYOUT//' Look')) then
            do k = 1_int32, size(LOOKS, kind=int32)
               on = look == LOOKS(k)
               if (ig_menu_item(trim(LOOKS(k)), selected=on)) call set_look(trim(LOOKS(k)))
            enddo
            call ig_end_menu()
         endif
         if (ig_begin_menu(ICON_PALETTE//' Palette')) then
            do k = 1_int32, size(PALETTES, kind=int32)
               on = palette == PALETTES(k)
               if (ig_menu_item(trim(PALETTES(k)), selected=on)) call set_palette(trim(PALETTES(k)))
            enddo
            call ig_end_menu()
         endif
         call ig_separator()
         if (ig_menu_item('Reset layout', enabled=have_default)) call app%load_layout(DEFAULT_LAYOUT)
         call ig_end_menu()
      endif
      if (ig_begin_menu('Help')) then
         if (ig_menu_item(ICON_INFO//' About', shortcut='F1')) about = .true.
         call ig_end_menu()
      endif
      call ig_end_main_menu_bar()
   endif
   if (ig_shortcut('ctrl+q')) ask_quit = .true.    ! every frame, outside the menus: cmd+q on macOS
   if (ig_shortcut('f1')) about = .true.
   endsubroutine draw_menus

   subroutine draw_tools()
   !< The workspace buttons, in a bar along the left side: a click brings the panel forward.
   character(len=*), parameter :: ICONS(4) = [character(len=4) :: ICON_FOLDER, ICON_FILE_PEN, ICON_PLAY, ICON_CHART_AREA]
   integer(int32)              :: k !< Counter.

   if (ig_begin_side_bar('tools', 'left', 76.0_real64)) then ! left out of the dock space
      do k = 1_int32, size(PANELS, kind=int32)
         if (ig_tool_button(trim(PANELS(k)), trim(ICONS(k)), width=60.0_real64, selected=current == k)) then
            current = k
            shown(k) = .true.
            if (ig_focus_window(trim(PANELS(k)))) continue ! a docked panel: its tab comes forward
         endif
         call ig_tooltip('Show the '//trim(PANELS(k))//' panel')
      enddo
   endif
   call ig_end()
   endsubroutine draw_tools

   subroutine draw_panels()
   !< The dock space and the four panels; each panel says what the next chapters put in it.
   integer(int32) :: root  !< The dock space.
   integer(int32) :: left  !< The case's column.
   integer(int32) :: right !< The rest.
   integer(int32) :: work  !< Input and Result, tabs of one node.
   integer(int32) :: run   !< Run, below them.

   if (save_default) then                                    ! the frame after the layout was set
      call app%save_layout(DEFAULT_LAYOUT, comment='the studio as the program lays it out')
      if (ig_focus_window('Input')) continue                 ! of the two tabs, Input in front
      have_default = .true.
      save_default = .false.
   endif
   root = ig_dock_id('studio')
   if (ig_dock_layout_begin(root)) then                      ! no layout yet: the first run, or no ini file
      call ig_dock_split(root, 'left', 0.25_real64, left, right)
      call ig_dock_split(right, 'down', 0.35_real64, run, work)
      call ig_dock_window('Case', left)
      call ig_dock_window('Result', work)
      call ig_dock_window('Input', work)                     ! the same node: Result and Input are tabs
      call ig_dock_window('Run', run)
      call ig_dock_layout_end(root)
      save_default = .true.
   endif
   call ig_dock_space(root)                                  ! every frame, after the bars, before the panels
   if (shown(1)) then
      if (ig_begin('Case', open=shown(1))) call ig_text_disabled('No case open.') ! open: the tab gets a close button
      call ig_end()
   endif
   if (shown(2)) then
      if (ig_begin('Input', open=shown(2))) call ig_text_disabled('The input of the case, once one is open.')
      call ig_end()
   endif
   if (shown(3)) then
      if (ig_begin('Run', open=shown(3))) call ig_text_disabled('The solver, its log and its residuals.')
      call ig_end()
   endif
   if (shown(4)) then
      if (ig_begin('Result', open=shown(4))) call ig_text_disabled('The field the solver computed.')
      call ig_end()
   endif
   endsubroutine draw_panels

   subroutine draw_dialogs()
   !< The questions and boxes the menus and the frame open, at the top level.
   if (app%quit_requested() .or. ask_quit) then
      call ig_open_popup('Quit the studio?')
      ask_quit = .false.
   endif
   if (ig_begin_popup_modal('Quit the studio?')) then
      call ig_text('The studio closes.')
      if (ig_button('Quit')) call app%quit()
      call ig_same_line()
      if (ig_button('Cancel')) call ig_close_current_popup()
      call ig_end_popup()
   endif
   if (about) then
      call ig_open_popup('About the studio')
      about = .false.
   endif
   call ig_set_next_window(400.0_real64, 230.0_real64, 320.0_real64, 160.0_real64) ! where it opens, and its size
   if (ig_begin_popup_modal('About the studio')) then
      call ig_text(ICON_FLAME//' FIGURE studio')
      call ig_text_wrapped('The solver studio of FIGURE''s tutorial: a case, its input, a run of the solver and '// &
                           'its result, in one window.')
      call ig_text('Look: '//trim(look)//', palette: '//trim(palette))
      if (ig_button('Close')) call ig_close_current_popup()
      call ig_end_popup()
   endif
   endsubroutine draw_dialogs

   subroutine set_look(name)
   !< The look (the geometry) changes; the palette stays.
   character(len=*), intent(in) :: name !< Look.

   call app%set_style(look=name)              ! rounding, padding, spacing: the colours stay
   look = name
   endsubroutine set_look

   subroutine set_palette(name)
   !< The palette (the colours) changes; the look stays.
   character(len=*), intent(in) :: name !< Palette.

   call app%set_style(palette=name)           ! every colour, the title bar's included: the geometry stays
   palette = name
   endsubroutine set_palette
endprogram tut08_shell
