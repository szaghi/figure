!< figure_markdown, Markdown in the window: a text at the cursor (ig_markdown) and documents (markdown_view_object).
module figure_markdown
!< figure_markdown, Markdown in the window: a text at the cursor (ig_markdown) and documents (markdown_view_object).
!<
!< The renderer is imgui_rich_md (pthom, MIT, vendored in third_party/imgui_rich_md with md4c, its parser) with FIGURE's
!< glue (native/figure_markdown.cpp): it draws through Dear ImGui only, so window, headless and remote modes show the
!< same pixels. Text in IBM Plex Sans (regular, bold, italic, bold italic: headings are larger), code spans and blocks
!< in IBM Plex Mono, with the Lucide icons and the fallback fonts as everywhere else; tables, lists, quotes, task lists,
!< GitHub's admonitions (`> [!NOTE]`), collapsible sections (`<details>`), images from PNG and JPEG files. No LaTeX, no
!< image from a URL. Links are reported, never opened: the call that draws a text returns true on the frame one of its
!< links is clicked, and gives its URL (polled, no callback); a link to a heading of the same text scrolls to it.
!<
!<```fortran
!< type(markdown_view_object)    :: help
!< character(len=:), allocatable :: url
!< call help%init()
!< call help%load('help/solver.md')
!< ... every frame, inside a window:
!< if (help%draw('help', url)) call follow(url)   ! the program decides: another page, a section, a browser
!<```
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_int, c_long_long
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure_base, only : figure_check, figure_draw_refused, figure_fail, figure_refused
use figure_c_native, only : FIG_ERR_STATE, FIG_OK

implicit none
private
public :: ig_markdown, markdown_view_object

type :: markdown_view_object
   !< A Markdown document: its text kept by FIGURE, drawn in a scroll area of its own with a table of contents beside it
   !< (from three headings) and a search (ctrl+f, or `find`). `view%init`, `view%set_text` or `view%load`, then
   !< `view%draw` every frame. Not to be copied (the copy would share the view); `destroy` releases it.
   integer(c_int), private :: handle = 0_c_int !< Native handle (0: none).
   contains
      procedure, pass(self) :: init => view_init !< Create the view.
      procedure, pass(self) :: destroy => view_destroy !< Release it.
      procedure, pass(self) :: is_initialized => view_is_initialized !< Whether it exists.
      procedure, pass(self) :: set_text => view_set_text !< Replace the text.
      procedure, pass(self) :: load => view_load !< Read the text from a file.
      procedure, pass(self) :: text => view_text !< The text.
      procedure, pass(self) :: draw => view_draw !< Draw the document as a widget.
      procedure, pass(self) :: find => view_find !< Search a text, or end the search.
      procedure, pass(self) :: matches => view_matches !< The matches of the search.
      procedure, pass(self) :: current_match => view_current_match !< The current match.
      procedure, pass(self) :: scroll_to => view_scroll_to !< Scroll to a heading.
endtype markdown_view_object

interface
   function fig_markdown(text, n, clicked) result(status) bind(C, name='fig_markdown')
   import :: c_char, c_int, c_long_long
   implicit none
   character(kind=c_char), intent(in)  :: text(*)
   integer(c_long_long),   value       :: n
   integer(c_int),         intent(out) :: clicked
   integer(c_int)                      :: status
   endfunction fig_markdown

   function fig_markdown_link(buf, n) result(length) bind(C, name='fig_markdown_link')
   import :: c_char, c_long_long
   implicit none
   character(kind=c_char), intent(inout) :: buf(*)
   integer(c_long_long),   value         :: n
   integer(c_long_long)                  :: length
   endfunction fig_markdown_link

   function fig_markdown_view_create(handle, toc, search) result(status) bind(C, name='fig_markdown_view_create')
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: handle
   integer(c_int), value       :: toc, search
   integer(c_int)              :: status
   endfunction fig_markdown_view_create

   subroutine fig_markdown_view_destroy(handle) bind(C, name='fig_markdown_view_destroy')
   import :: c_int
   implicit none
   integer(c_int), value :: handle
   endsubroutine fig_markdown_view_destroy

   function fig_markdown_view_set_text(handle, text, n) result(status) bind(C, name='fig_markdown_view_set_text')
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         value      :: handle
   character(kind=c_char), intent(in) :: text(*)
   integer(c_long_long),   value      :: n
   integer(c_int)                     :: status
   endfunction fig_markdown_view_set_text

   function fig_markdown_view_load(handle, path, n) result(status) bind(C, name='fig_markdown_view_load')
   import :: c_char, c_int
   implicit none
   integer(c_int),         value      :: handle
   character(kind=c_char), intent(in) :: path(*)
   integer(c_int),         value      :: n
   integer(c_int)                     :: status
   endfunction fig_markdown_view_load

   function fig_markdown_view_text(handle, buf, n) result(length) bind(C, name='fig_markdown_view_text')
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         value         :: handle
   character(kind=c_char), intent(inout) :: buf(*)
   integer(c_long_long),   value         :: n
   integer(c_long_long)                  :: length
   endfunction fig_markdown_view_text

   function fig_markdown_view_find(handle, text, n) result(status) bind(C, name='fig_markdown_view_find')
   import :: c_char, c_int
   implicit none
   integer(c_int),         value      :: handle
   character(kind=c_char), intent(in) :: text(*)
   integer(c_int),         value      :: n
   integer(c_int)                     :: status
   endfunction fig_markdown_view_find

   function fig_markdown_view_scroll_to(handle, heading, n) result(status) bind(C, name='fig_markdown_view_scroll_to')
   import :: c_char, c_int
   implicit none
   integer(c_int),         value      :: handle
   character(kind=c_char), intent(in) :: heading(*)
   integer(c_int),         value      :: n
   integer(c_int)                     :: status
   endfunction fig_markdown_view_scroll_to

   function fig_markdown_view_info(handle, matches, current) result(status) bind(C, name='fig_markdown_view_info')
   import :: c_int
   implicit none
   integer(c_int), value       :: handle
   integer(c_int), intent(out) :: matches, current
   integer(c_int)              :: status
   endfunction fig_markdown_view_info

   function fig_markdown_view_draw(handle, id, id_len, width, height, clicked) result(status) &
      bind(C, name='fig_markdown_view_draw')
   import :: c_char, c_double, c_int
   implicit none
   integer(c_int),         value       :: handle
   character(kind=c_char), intent(in)  :: id(*)
   integer(c_int),         value       :: id_len
   real(c_double),         value       :: width, height
   integer(c_int),         intent(out) :: clicked
   integer(c_int)                      :: status
   endfunction fig_markdown_view_draw
endinterface

contains
   recursive function ig_markdown(text, link, stat) result(clicked)
   !< Draw `text` (Markdown, UTF-8, lines ended by LF or CR LF) at the cursor, inside a window, as wide as the window
   !< and as tall as it needs (the window scrolls). True on the frame one of its links is clicked: its URL in `link`
   !< (`''` on the other frames); nothing is opened. A link to a heading of the same text (`[units](#units)`) scrolls
   !< the window there instead, and is not reported; one to a heading it does not have is (`'#units'`). The text can be
   !< selected with the mouse and copied (ctrl+c; a right click: Copy, Copy as Markdown, Copy Link). Statuses:
   !< `FIG_ERR_STATE` with no frame open and from a task; `FIG_ERR_FAILED` if the fonts cannot be loaded. The same in
   !< every mode.
   character(len=*),              intent(in)            :: text    !< Markdown.
   character(len=:), allocatable, intent(out), optional :: link    !< The URL of the link clicked.
   integer(int32),                intent(out), optional :: stat    !< Status.
   logical                                              :: clicked !< A link was clicked this frame.
   integer(c_int)                                       :: c       !< Clicked (C).

   clicked = .false.
   if (present(link)) link = ''
   if (figure_draw_refused('ig_markdown', stat)) return
   c = 0_c_int
   call figure_check(fig_markdown(text, len(text, c_long_long), c), stat)
   clicked = c /= 0_c_int
   if (clicked .and. present(link)) link = clicked_link()
   endfunction ig_markdown

   ! ---- markdown_view_object ------------------------------------------------------------------------------------------
   recursive subroutine view_init(self, toc, search, stat)
   !< Create the view (an existing one is destroyed first), empty. With `toc` (default true) a table of contents beside
   !< the text once it has three headings or more (a narrow view shows it as a line above the text); with `search`
   !< (default true) the find bar (ctrl+f, cmd+f on macOS, or "/" while the view has the focus; enter goes to the next
   !< match, escape closes it). Statuses: `FIG_ERR_STATE` from a task. Data only: before `app%init*` too.
   class(markdown_view_object), intent(inout)         :: self   !< View.
   logical,                     intent(in),  optional :: toc    !< A table of contents (default true).
   logical,                     intent(in),  optional :: search !< A search (default true).
   integer(int32),              intent(out), optional :: stat   !< Status.
   integer(c_int)                                     :: t, s   !< Options (C).

   if (figure_refused('markdown_view_object%init', stat)) return
   call self%destroy()
   t = 1_c_int
   if (present(toc)) t = merge(1_c_int, 0_c_int, toc)
   s = 1_c_int
   if (present(search)) s = merge(1_c_int, 0_c_int, search)
   call figure_check(fig_markdown_view_create(self%handle, t, s), stat)
   endsubroutine view_init

   recursive subroutine view_destroy(self)
   !< Release the view (safe in any state).
   class(markdown_view_object), intent(inout) :: self !< View.

   if (self%handle /= 0_c_int) call fig_markdown_view_destroy(self%handle)
   self%handle = 0_c_int
   endsubroutine view_destroy

   pure function view_is_initialized(self) result(yes)
   !< Whether the view exists.
   class(markdown_view_object), intent(in) :: self !< View.
   logical                                 :: yes  !< Initialized.

   yes = self%handle /= 0_c_int
   endfunction view_is_initialized

   recursive subroutine view_set_text(self, text, stat)
   !< Replace the text with `text` (Markdown, UTF-8): drawn from the next `draw`, its scroll and search kept. Statuses:
   !< `FIG_ERR_STATE` before `init` and from a task.
   class(markdown_view_object), intent(inout)         :: self !< View.
   character(len=*),            intent(in)            :: text !< Markdown.
   integer(int32),              intent(out), optional :: stat !< Status.

   if (.not. alive(self, 'set_text', stat)) return
   call figure_check(fig_markdown_view_set_text(self%handle, text, len(text, c_long_long)), stat)
   endsubroutine view_set_text

   recursive subroutine view_load(self, path, stat)
   !< Replace the text with the content of the file `path` (UTF-8 name and content). Its images are read from paths
   !< relative to the working directory, not to the file. Statuses: `FIG_ERR_ARGUMENT` for an empty name,
   !< `FIG_ERR_FAILED` if the file cannot be read (the text is kept); `FIG_ERR_STATE` before `init` and from a task.
   class(markdown_view_object), intent(inout)         :: self !< View.
   character(len=*),            intent(in)            :: path !< File.
   integer(int32),              intent(out), optional :: stat !< Status.

   if (.not. alive(self, 'load', stat)) return
   call figure_check(fig_markdown_view_load(self%handle, path, len(path, c_int)), stat)
   endsubroutine view_load

   recursive function view_text(self) result(t)
   !< The text (`''` before `init` and from a task).
   class(markdown_view_object), intent(in) :: self  !< View.
   character(len=:), allocatable           :: t     !< Markdown.
   integer(c_long_long)                    :: n     !< Length.
   character(kind=c_char, len=1)           :: probe !< Buffer for the length.

   t = ''
   if (.not. alive(self, 'text', quiet=.true.)) return
   n = fig_markdown_view_text(self%handle, probe, 0_c_long_long)
   if (n <= 0_c_long_long) return
   deallocate(t)
   allocate(character(len=n) :: t)
   n = fig_markdown_view_text(self%handle, t, n)
   endfunction view_text

   recursive function view_draw(self, id, link, width, height, stat) result(clicked)
   !< Draw the document as a widget at the cursor, inside a window, `width` x `height` pixels (0: the available region;
   !< negative: up to that distance from its edge): its text in a scroll area, the table of contents beside it, the
   !< find bar over it while searching. True on the frame one of its links is clicked, its URL in `link` (`''` on the
   !< other frames); nothing is opened. A link to one of its headings scrolls there instead (`[units](#units)`), and is
   !< not reported. Statuses: `FIG_ERR_ARGUMENT` for an empty id; `FIG_ERR_STATE` before `init`, with no frame open,
   !< from a task; `FIG_ERR_FAILED` if the fonts cannot be loaded. The same in every mode.
   class(markdown_view_object),   intent(inout)         :: self    !< View.
   character(len=*),              intent(in)            :: id      !< Widget id (unique in the window).
   character(len=:), allocatable, intent(out), optional :: link    !< The URL of the link clicked.
   real(real64),                  intent(in),  optional :: width   !< Width [pixels] (default 0: the available width).
   real(real64),                  intent(in),  optional :: height  !< Height [pixels] (default 0: the available height).
   integer(int32),                intent(out), optional :: stat    !< Status.
   logical                                              :: clicked !< A link was clicked this frame.
   real(c_double)                                       :: w, h    !< Size.
   integer(c_int)                                       :: c       !< Clicked (C).

   clicked = .false.
   if (present(link)) link = ''
   if (figure_draw_refused('markdown_view_object%draw', stat)) return
   if (.not. alive(self, 'draw', stat)) return
   w = 0.0_c_double
   if (present(width)) w = real(width, c_double)
   h = 0.0_c_double
   if (present(height)) h = real(height, c_double)
   c = 0_c_int
   call figure_check(fig_markdown_view_draw(self%handle, id, len(id, c_int), w, h, c), stat)
   clicked = c /= 0_c_int
   if (clicked .and. present(link)) link = clicked_link()
   endfunction view_draw

   recursive subroutine view_find(self, text, stat)
   !< Search `text` from the next `draw` (as the find bar does: any case, the matches highlighted, the first one below
   !< the top of the view made current and scrolled to); `''` ends the search and closes the bar. Statuses:
   !< `FIG_ERR_ARGUMENT` for a text over 255 bytes or of more than one line; `FIG_ERR_STATE` before `init` and from a
   !< task.
   class(markdown_view_object), intent(inout)         :: self !< View.
   character(len=*),            intent(in)            :: text !< Text searched.
   integer(int32),              intent(out), optional :: stat !< Status.

   if (.not. alive(self, 'find', stat)) return
   call figure_check(fig_markdown_view_find(self%handle, text, len(text, c_int)), stat)
   endsubroutine view_find

   recursive function view_matches(self) result(n)
   !< The matches of the search at the last `draw` (0 with no search, before `init` and from a task).
   class(markdown_view_object), intent(in) :: self !< View.
   integer(int32)                          :: n    !< Matches.
   integer(c_int)                          :: m, c !< Matches, current (C).

   n = 0_int32
   if (.not. alive(self, 'matches', quiet=.true.)) return
   if (fig_markdown_view_info(self%handle, m, c) == FIG_OK) n = int(m, int32)
   endfunction view_matches

   recursive function view_current_match(self) result(k)
   !< The current match of the search at the last `draw`, from 1 (0 with none, before `init` and from a task).
   class(markdown_view_object), intent(in) :: self !< View.
   integer(int32)                          :: k    !< Current match.
   integer(c_int)                          :: m, c !< Matches, current (C).

   k = 0_int32
   if (.not. alive(self, 'current_match', quiet=.true.)) return
   if (fig_markdown_view_info(self%handle, m, c) == FIG_OK) k = int(c, int32) + 1_int32
   endfunction view_current_match

   recursive subroutine view_scroll_to(self, heading, stat)
   !< Scroll to a heading from the next `draw` (over a few frames, as a click in the table of contents): `heading` its
   !< text (`'Boundary conditions'`) or its anchor after `#` (`'#boundary-conditions'`, GitHub's: lower case, blanks as
   !< `-`, punctuation dropped; a repeated title's second is `-1`). A heading the text does not have: nothing happens.
   !< Statuses: `FIG_ERR_ARGUMENT` for an empty heading; `FIG_ERR_STATE` before `init` and from a task.
   class(markdown_view_object), intent(inout)         :: self    !< View.
   character(len=*),            intent(in)            :: heading !< Its text, or `#` and its anchor.
   integer(int32),              intent(out), optional :: stat    !< Status.

   if (.not. alive(self, 'scroll_to', stat)) return
   call figure_check(fig_markdown_view_scroll_to(self%handle, heading, len(heading, c_int)), stat)
   endsubroutine view_scroll_to

   ! ---- private --------------------------------------------------------------------------------------------------------
   recursive function alive(self, name, stat, quiet) result(ok)
   !< True when the view exists and the caller is on the main thread; else the refusal (`FIG_ERR_STATE`), silent for a
   !< query (`quiet`: its default value is the answer).
   class(markdown_view_object), intent(in)            :: self  !< View.
   character(len=*),            intent(in)            :: name  !< The method.
   integer(int32),              intent(out), optional :: stat  !< Status.
   logical,                     intent(in),  optional :: quiet !< A query: no failure before `init`.
   logical                                            :: ok    !< Go on.
   logical                                            :: q     !< Quiet.

   ok = .false.
   if (figure_refused('markdown_view_object%'//name, stat)) return
   q = .false.
   if (present(quiet)) q = quiet
   if (self%handle == 0_c_int) then
      if (.not. q) call figure_fail(FIG_ERR_STATE, 'markdown_view_object%'//name//': the view is not initialized', stat)
      return
   endif
   ok = .true.
   endfunction alive

   recursive function clicked_link() result(url)
   !< The URL of the last link clicked.
   character(len=:), allocatable :: url   !< URL.
   integer(c_long_long)          :: n     !< Length.
   character(kind=c_char, len=1) :: probe !< Buffer for the length.

   url = ''
   n = fig_markdown_link(probe, 0_c_long_long)
   if (n <= 0_c_long_long) return
   deallocate(url)
   allocate(character(len=n) :: url)
   n = fig_markdown_link(url, n)
   endfunction clicked_link
endmodule figure_markdown
