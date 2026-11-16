!< figure_editor, a code editor (code_editor_object) with highlighting, marks, completion and find, and a text diff.
module figure_editor
!< figure_editor, a code editor (code_editor_object) with highlighting, marks, completion and find, and a text diff.
!<
!< The editor is ImGuiColorTextEdit (the goossens fork, MIT, vendored in third_party/ImGuiColorTextEdit) with FIGURE's
!< own glue (native/figure_editor.cpp): it draws through Dear ImGui only, so window, headless and remote modes show the
!< same pixels. Text is UTF-8; lines and columns are numbered from 1, columns in characters. Everything is polled:
!< `ed%draw` returns true on the frame the user changed the text, `ed%completing` while the completion popup is open.
!<
!<```fortran
!< type(code_editor_object) :: ed
!< call ed%init(code_language('input'))          ! key = value files; code_language('fortran') for Fortran
!< call ed%set_text(text)
!< call ed%set_completions(['reynolds number', 'save frequency '])
!< ... every frame, inside a window:
!< if (ed%draw('editor')) call validate(ed%text())   ! the user changed it: check it again
!< call ed%clear_marks()
!< call ed%mark(3, 'error', 'reynolds number must be positive')
!<```
!<
!< A language (`language_object`) is data: keywords, types, comments, strings, numbers, case, and a key = value mode;
!< `code_language` gives the shipped ones (Fortran, input files, plain text) and the fork's own (C, C++, Python, JSON,
!< Markdown, ...). `code_diff` draws the difference of two texts, `code_diff_lines` reports the lines that differ.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_long_long
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure_base, only : cstr, figure_check, figure_draw_refused, figure_fail, figure_refused
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK

implicit none
private
public :: code_editor_object, language_object, code_language, code_diff, code_diff_lines

character(len=*), parameter :: LF = achar(10) !< Line feed.
character(len=*), parameter :: US = achar(31) !< Field separator of a packed language.
!< The fork's own languages, by the names `code_language` takes.
character(len=*), parameter :: FORK_LANGUAGES(13) = ['angelscript', 'c          ', 'c++        ', 'c#         ', &
                                                     'glsl       ', 'hlsl       ', 'json       ', 'julia      ', &
                                                     'lua        ', 'markdown   ', 'python     ', 'sql        ', &
                                                     'wgsl       ']

type :: language_object
   !< A language the editor highlights: `lang%init(name, ...)`, or one of `code_language`'s. Default: plain text.
   character(len=:), allocatable, private :: name_            !< Its name ('': plain text).
   logical,                       private :: fork = .false.   !< One of the fork's own languages.
   character(len=:), allocatable, private :: keywords         !< Keywords, LF-separated.
   character(len=:), allocatable, private :: types            !< Types and attributes, LF-separated.
   character(len=:), allocatable, private :: comment          !< Start of a line comment.
   character(len=:), allocatable, private :: comment_alt      !< Another start of a line comment.
   character(len=:), allocatable, private :: block_start      !< Start of a block comment.
   character(len=:), allocatable, private :: block_end        !< End of a block comment.
   character(len=:), allocatable, private :: preprocessor     !< The character starting a preprocessor line.
   logical,                       private :: single_quotes = .true.  !< '...' strings.
   logical,                       private :: double_quotes = .true.  !< "..." strings.
   logical,                       private :: numbers = .true.        !< Numbers coloured.
   logical,                       private :: case_sensitive = .true. !< Keywords and types by case.
   logical,                       private :: key_value = .false.     !< key = value lines.
   contains
      procedure, pass(self) :: init => language_init !< Define the language.
      procedure, pass(self) :: name => language_name !< Its name.
endtype language_object

type :: code_editor_object
   !< A code editor: `ed%init([language])`, `ed%set_text`, then `ed%draw` every frame. Not to be copied (the copy would
   !< share the editor). No finaliser, as `texture_object`: an assignment or a function result would finalise a copy
   !< and destroy the editor the original still uses; `destroy` releases it (at the program's end the system does).
   integer(c_int), private :: handle = 0_c_int !< Native handle (0: none).
   contains
      procedure, pass(self) :: init => editor_init !< Create the editor.
      procedure, pass(self) :: destroy => editor_destroy !< Release it.
      procedure, pass(self) :: is_initialized => editor_is_initialized !< Whether it exists.
      procedure, pass(self) :: set_language => editor_set_language !< Highlight another language.
      procedure, pass(self) :: set_text => editor_set_text !< Replace the text.
      procedure, pass(self) :: text => editor_text !< The text.
      procedure, pass(self) :: line_count => editor_line_count !< The number of lines.
      procedure, pass(self) :: draw => editor_draw !< Draw the editor as a widget.
      procedure, pass(self) :: mark => editor_mark !< Mark a line with a message.
      procedure, pass(self) :: clear_marks => editor_clear_marks !< Remove every mark.
      procedure, pass(self) :: mark_of => editor_mark_of !< The mark on a line.
      procedure, pass(self) :: goto => editor_goto !< Move the cursor to a line.
      procedure, pass(self) :: focus => editor_focus !< Give the editor the keyboard.
      procedure, pass(self) :: find => editor_find !< Select the next occurrence of a text.
      procedure, pass(self) :: replace => editor_replace !< Replace every occurrence of a text.
      procedure, pass(self) :: cursor => editor_cursor !< The cursor's line and column.
      procedure, pass(self) :: selection => editor_selection !< The selection.
      procedure, pass(self) :: select => editor_select !< Select a range.
      procedure, pass(self) :: insert => editor_insert !< Insert a text at the cursor.
      procedure, pass(self) :: word_at_cursor => editor_word_at_cursor !< The word at the cursor.
      procedure, pass(self) :: set_completions => editor_set_completions !< The words completion offers.
      procedure, pass(self) :: completing => editor_completing !< The completion popup is open.
      procedure, pass(self) :: read_only => editor_read_only !< Make it read-only, or editable.
      procedure, pass(self) :: is_read_only => editor_is_read_only !< Whether it is read-only.
      procedure, pass(self) :: set_options => editor_set_options !< Line numbers, tab size, whitespace, the current line.
      procedure, pass(self) :: undo => editor_undo !< Undo the last change.
      procedure, pass(self) :: redo => editor_redo !< Redo the last undone change.
      procedure, pass(self) :: line_rect => editor_line_rect !< A line's rectangle on the screen.
endtype code_editor_object

interface
   function fig_editor_create(handle) result(status) bind(C, name='fig_editor_create')
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: handle
   integer(c_int)              :: status
   endfunction fig_editor_create

   subroutine fig_editor_destroy(handle) bind(C, name='fig_editor_destroy')
   import :: c_int
   implicit none
   integer(c_int), value :: handle
   endsubroutine fig_editor_destroy

   function fig_editor_language(handle, packed, packed_len) result(status) bind(C, name='fig_editor_language')
   import :: c_char, c_int
   implicit none
   integer(c_int),         value      :: handle
   character(kind=c_char), intent(in) :: packed(*)
   integer(c_int),         value      :: packed_len
   integer(c_int)                     :: status
   endfunction fig_editor_language

   function fig_editor_set_text(handle, text, n) result(status) bind(C, name='fig_editor_set_text')
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         value      :: handle
   character(kind=c_char), intent(in) :: text(*)
   integer(c_long_long),   value      :: n
   integer(c_int)                     :: status
   endfunction fig_editor_set_text

   function fig_editor_string(handle, what, buf, n) result(length) bind(C, name='fig_editor_string')
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         value         :: handle, what
   character(kind=c_char), intent(inout) :: buf(*)
   integer(c_long_long),   value         :: n
   integer(c_long_long)                  :: length
   endfunction fig_editor_string

   function fig_editor_draw(handle, id, id_len, width, height, changed) result(status) bind(C, name='fig_editor_draw')
   import :: c_char, c_double, c_int
   implicit none
   integer(c_int),         value       :: handle
   character(kind=c_char), intent(in)  :: id(*)
   integer(c_int),         value       :: id_len
   real(c_double),         value       :: width, height
   integer(c_int),         intent(out) :: changed
   integer(c_int)                      :: status
   endfunction fig_editor_draw

   function fig_editor_mark(handle, line, severity, message, message_len) result(status) &
      bind(C, name='fig_editor_mark')
   import :: c_char, c_int
   implicit none
   integer(c_int),         value      :: handle, line, severity
   character(kind=c_char), intent(in) :: message(*)
   integer(c_int),         value      :: message_len
   integer(c_int)                     :: status
   endfunction fig_editor_mark

   function fig_editor_clear_marks(handle) result(status) bind(C, name='fig_editor_clear_marks')
   import :: c_int
   implicit none
   integer(c_int), value :: handle
   integer(c_int)        :: status
   endfunction fig_editor_clear_marks

   function fig_editor_mark_of(handle, line, severity, buf, n) result(length) bind(C, name='fig_editor_mark_of')
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         value         :: handle, line
   integer(c_int),         intent(out)   :: severity
   character(kind=c_char), intent(inout) :: buf(*)
   integer(c_long_long),   value         :: n
   integer(c_long_long)                  :: length
   endfunction fig_editor_mark_of

   function fig_editor_goto(handle, line, column, focus) result(status) bind(C, name='fig_editor_goto')
   import :: c_int
   implicit none
   integer(c_int), value :: handle, line, column, focus
   integer(c_int)        :: status
   endfunction fig_editor_goto

   function fig_editor_find(handle, text, n, case_sensitive, whole_word, found) result(status) &
      bind(C, name='fig_editor_find')
   import :: c_char, c_int
   implicit none
   integer(c_int),         value       :: handle
   character(kind=c_char), intent(in)  :: text(*)
   integer(c_int),         value       :: n, case_sensitive, whole_word
   integer(c_int),         intent(out) :: found
   integer(c_int)                      :: status
   endfunction fig_editor_find

   function fig_editor_replace(handle, what, what_len, by, by_len, case_sensitive, whole_word, count) result(status) &
      bind(C, name='fig_editor_replace')
   import :: c_char, c_int
   implicit none
   integer(c_int),         value       :: handle
   character(kind=c_char), intent(in)  :: what(*)
   integer(c_int),         value       :: what_len
   character(kind=c_char), intent(in)  :: by(*)
   integer(c_int),         value       :: by_len, case_sensitive, whole_word
   integer(c_int),         intent(out) :: count
   integer(c_int)                      :: status
   endfunction fig_editor_replace

   function fig_editor_cursor(handle, line, column) result(status) bind(C, name='fig_editor_cursor')
   import :: c_int
   implicit none
   integer(c_int), value       :: handle
   integer(c_int), intent(out) :: line, column
   integer(c_int)              :: status
   endfunction fig_editor_cursor

   function fig_editor_selection(handle, pos, has) result(status) bind(C, name='fig_editor_selection')
   import :: c_int
   implicit none
   integer(c_int), value       :: handle
   integer(c_int), intent(out) :: pos(4)
   integer(c_int), intent(out) :: has
   integer(c_int)              :: status
   endfunction fig_editor_selection

   function fig_editor_select(handle, l0, c0, l1, c1) result(status) bind(C, name='fig_editor_select')
   import :: c_int
   implicit none
   integer(c_int), value :: handle, l0, c0, l1, c1
   integer(c_int)        :: status
   endfunction fig_editor_select

   function fig_editor_insert(handle, text, n) result(status) bind(C, name='fig_editor_insert')
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         value      :: handle
   character(kind=c_char), intent(in) :: text(*)
   integer(c_long_long),   value      :: n
   integer(c_int)                     :: status
   endfunction fig_editor_insert

   function fig_editor_completions(handle, words, n) result(status) bind(C, name='fig_editor_completions')
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         value      :: handle
   character(kind=c_char), intent(in) :: words(*)
   integer(c_long_long),   value      :: n
   integer(c_int)                     :: status
   endfunction fig_editor_completions

   function fig_editor_completing(handle, active) result(status) bind(C, name='fig_editor_completing')
   import :: c_int
   implicit none
   integer(c_int), value       :: handle
   integer(c_int), intent(out) :: active
   integer(c_int)              :: status
   endfunction fig_editor_completing

   function fig_editor_option(handle, option, set, value) result(status) bind(C, name='fig_editor_option')
   import :: c_int
   implicit none
   integer(c_int), value         :: handle, option, set
   integer(c_int), intent(inout) :: value
   integer(c_int)                :: status
   endfunction fig_editor_option

   function fig_editor_undo(handle, redo, done) result(status) bind(C, name='fig_editor_undo')
   import :: c_int
   implicit none
   integer(c_int), value       :: handle, redo
   integer(c_int), intent(out) :: done
   integer(c_int)              :: status
   endfunction fig_editor_undo

   function fig_editor_info(handle, lines, can_undo, can_redo) result(status) bind(C, name='fig_editor_info')
   import :: c_int
   implicit none
   integer(c_int), value       :: handle
   integer(c_int), intent(out) :: lines, can_undo, can_redo
   integer(c_int)              :: status
   endfunction fig_editor_info

   function fig_editor_focus(handle) result(status) bind(C, name='fig_editor_focus')
   import :: c_int
   implicit none
   integer(c_int), value :: handle
   integer(c_int)        :: status
   endfunction fig_editor_focus

   function fig_editor_line_rect(handle, line, rect, visible) result(status) bind(C, name='fig_editor_line_rect')
   import :: c_float, c_int
   implicit none
   integer(c_int), value       :: handle, line
   real(c_float),  intent(out) :: rect(4)
   integer(c_int), intent(out) :: visible
   integer(c_int)              :: status
   endfunction fig_editor_line_rect

   function fig_code_diff(id, id_len, left, left_len, right, right_len, packed, packed_len, side_by_side, width, &
                          height) result(status) bind(C, name='fig_code_diff')
   import :: c_char, c_double, c_int, c_long_long
   implicit none
   character(kind=c_char), intent(in) :: id(*)
   integer(c_int),         value      :: id_len
   character(kind=c_char), intent(in) :: left(*)
   integer(c_long_long),   value      :: left_len
   character(kind=c_char), intent(in) :: right(*)
   integer(c_long_long),   value      :: right_len
   character(kind=c_char), intent(in) :: packed(*)
   integer(c_int),         value      :: packed_len, side_by_side
   real(c_double),         value      :: width, height
   integer(c_int)                     :: status
   endfunction fig_code_diff

   function fig_code_diff_lines(left, left_len, right, right_len, added, n_added, removed, n_removed, cap) &
      result(status) bind(C, name='fig_code_diff_lines')
   import :: c_char, c_int, c_long_long
   implicit none
   character(kind=c_char), intent(in)    :: left(*)
   integer(c_long_long),   value         :: left_len
   character(kind=c_char), intent(in)    :: right(*)
   integer(c_long_long),   value         :: right_len
   integer(c_int),         intent(inout) :: added(*)
   integer(c_int),         intent(out)   :: n_added
   integer(c_int),         intent(inout) :: removed(*)
   integer(c_int),         intent(out)   :: n_removed
   integer(c_int),         value         :: cap
   integer(c_int)                        :: status
   endfunction fig_code_diff_lines
endinterface

contains
   ! ---- language_object -----------------------------------------------------------------------------------------------
   recursive subroutine language_init(self, name, keywords, types, comment, comment_alt, block_comment, preprocessor, &
                                      single_quotes, double_quotes, numbers, case_sensitive, key_value, stat)
   !< Define a language: `name` (shown nowhere, it tells languages apart), the words it colours, its comments and
   !< strings. Keywords and types are each trimmed of trailing blanks; matched whole, by case only if `case_sensitive`.
   !< With `key_value`, a line `[section]` takes the types' colour and the words before a line's `=` the keywords'.
   !< Status: `FIG_ERR_ARGUMENT` for an empty name, a keyword or type with a blank or a separator inside, a preprocessor
   !< of more than one character. Any thread (it is data).
   class(language_object), intent(inout)         :: self             !< Language.
   character(len=*),       intent(in)            :: name             !< Its name.
   character(len=*),       intent(in),  optional :: keywords(:)      !< Keywords (the keywords' colour).
   character(len=*),       intent(in),  optional :: types(:)         !< Types, attributes (the types' colour).
   character(len=*),       intent(in),  optional :: comment          !< Start of a line comment (default none).
   character(len=*),       intent(in),  optional :: comment_alt      !< Another start of a line comment.
   character(len=*),       intent(in),  optional :: block_comment(2) !< Start and end of a block comment.
   character(len=*),       intent(in),  optional :: preprocessor     !< The character of a preprocessor line (`'#'`).
   logical,                intent(in),  optional :: single_quotes    !< '...' strings (default true).
   logical,                intent(in),  optional :: double_quotes    !< "..." strings (default true).
   logical,                intent(in),  optional :: numbers          !< Numbers coloured (default true).
   logical,                intent(in),  optional :: case_sensitive   !< By case (default true).
   logical,                intent(in),  optional :: key_value        !< key = value lines (default false).
   integer(int32),         intent(out), optional :: stat             !< Status.
   logical                                       :: ok               !< Words valid.

   if (len_trim(name) == 0) then
      call figure_fail(FIG_ERR_ARGUMENT, 'language_object%init: the name is empty', stat)
      return
   endif
   if (present(preprocessor)) then
      if (len(preprocessor) > 1) then
         call figure_fail(FIG_ERR_ARGUMENT, 'language_object%init: the preprocessor is one character', stat)
         return
      endif
   endif
   self%fork = .false.
   self%single_quotes = .true.
   self%double_quotes = .true.
   self%numbers = .true.
   self%case_sensitive = .true.
   self%key_value = .false.
   self%name_ = trim(name)
   self%keywords = ''
   self%types = ''
   if (present(keywords)) then
      call joined(keywords, self%keywords, ok)
      if (.not. ok) then
         call figure_fail(FIG_ERR_ARGUMENT, 'language_object%init: a keyword is empty or holds a blank', stat)
         return
      endif
   endif
   if (present(types)) then
      call joined(types, self%types, ok)
      if (.not. ok) then
         call figure_fail(FIG_ERR_ARGUMENT, 'language_object%init: a type is empty or holds a blank', stat)
         return
      endif
   endif
   self%comment = ''
   if (present(comment)) self%comment = trim(comment)
   self%comment_alt = ''
   if (present(comment_alt)) self%comment_alt = trim(comment_alt)
   self%block_start = ''
   self%block_end = ''
   if (present(block_comment)) then
      self%block_start = trim(block_comment(1))
      self%block_end = trim(block_comment(2))
   endif
   self%preprocessor = ''
   if (present(preprocessor)) self%preprocessor = preprocessor
   if (present(single_quotes)) self%single_quotes = single_quotes
   if (present(double_quotes)) self%double_quotes = double_quotes
   if (present(numbers)) self%numbers = numbers
   if (present(case_sensitive)) self%case_sensitive = case_sensitive
   if (present(key_value)) self%key_value = key_value
   if (present(stat)) stat = FIG_OK
   endsubroutine language_init

   pure function language_name(self) result(name)
   !< The language's name (`''` for plain text).
   class(language_object), intent(in) :: self !< Language.
   character(len=:), allocatable      :: name !< Its name.

   name = ''
   if (allocated(self%name_)) name = self%name_
   endfunction language_name

   recursive function code_language(name, stat) result(lang)
   !< A shipped language by name, in any case: `'fortran'` (free form, any case, `!` comments, both quotes, kinds and
   !< exponents in numbers, `#` preprocessor lines), `'input'` (key = value files: `[section]` lines, keys, `!` and `#`
   !< comments, the words `true`, `false`, `yes`, `no`, `on`, `off`), `'text'` or `''` (plain), and the fork's own:
   !< `'angelscript'`, `'c'`, `'c++'`, `'c#'`, `'glsl'`, `'hlsl'`, `'json'`, `'julia'`, `'lua'`, `'markdown'`,
   !< `'python'`, `'sql'`, `'wgsl'`. Status: `FIG_ERR_ARGUMENT` for another name (plain text returned). Any thread.
   character(len=*), intent(in)            :: name !< Language name.
   integer(int32),   intent(out), optional :: stat !< Status.
   type(language_object)                   :: lang !< The language.
   character(len=:), allocatable           :: n    !< Name in lower case.
   integer(int32)                          :: i    !< Counter.

   n = lower(trim(adjustl(name)))
   if (present(stat)) stat = FIG_OK
   select case (n)
   case ('fortran')
      call lang%init('Fortran', keywords=fortran_keywords(), types=fortran_types(), comment='!', preprocessor='#', &
                     case_sensitive=.false.)
   case ('input')
      call lang%init('Input', keywords=['true ', 'false', 'yes  ', 'no   ', 'on   ', 'off  '], comment='!', &
                     comment_alt='#', case_sensitive=.false., key_value=.true.)
   case ('text', '')
      continue
   case default
      do i = 1_int32, size(FORK_LANGUAGES, kind=int32)
         if (n == trim(FORK_LANGUAGES(i))) then
            lang%name_ = n
            lang%fork = .true.
            return
         endif
      enddo
      call figure_fail(FIG_ERR_ARGUMENT, 'code_language: unknown language "'//trim(name)//'"', stat)
   endselect
   endfunction code_language

   ! ---- code_editor_object --------------------------------------------------------------------------------------------
   recursive subroutine editor_init(self, language, stat)
   !< Create the editor (an existing one is destroyed first), empty, highlighting `language` (default: plain text). It
   !< shows line numbers, highlights the current line, matches brackets, and has the fork's find and replace window
   !< (ctrl+f; cmd+f on macOS), undo and redo (ctrl+z, ctrl+y), cut, copy and paste with the clipboard. After
   !< `app%init*`. Statuses: `FIG_ERR_STATE` from a task. The same in every mode.
   class(code_editor_object), intent(inout)         :: self     !< Editor.
   type(language_object),     intent(in),  optional :: language !< Language (default: plain text).
   integer(int32),            intent(out), optional :: stat     !< Status.
   integer(int32)                                   :: s        !< Status.

   if (figure_refused('code_editor_object%init', stat)) return
   call self%destroy()
   call figure_check(fig_editor_create(self%handle), s)
   if (s == FIG_OK .and. present(language)) call self%set_language(language, s)
   if (present(stat)) then
      stat = s
   elseif (s /= FIG_OK) then
      call figure_check(int(s, c_int))
   endif
   endsubroutine editor_init

   recursive subroutine editor_destroy(self)
   !< Release the editor (safe in any state).
   class(code_editor_object), intent(inout) :: self !< Editor.

   if (self%handle /= 0_c_int) call fig_editor_destroy(self%handle)
   self%handle = 0_c_int
   endsubroutine editor_destroy

   pure function editor_is_initialized(self) result(yes)
   !< Whether the editor exists.
   class(code_editor_object), intent(in) :: self !< Editor.
   logical                               :: yes  !< Initialized.

   yes = self%handle /= 0_c_int
   endfunction editor_is_initialized

   recursive subroutine editor_set_language(self, language, stat)
   !< Highlight `language` from now on (the text, its marks and its undo history kept). Statuses: `FIG_ERR_STATE`
   !< before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self     !< Editor.
   type(language_object),     intent(in)            :: language !< Language.
   integer(int32),            intent(out), optional :: stat     !< Status.
   character(len=:), allocatable                    :: packed   !< Its definition.

   if (.not. alive(self, 'set_language', stat)) return
   packed = pack_language(language)
   call figure_check(fig_editor_language(self%handle, packed, len(packed, c_int)), stat)
   endsubroutine editor_set_language

   recursive subroutine editor_set_text(self, text, stat)
   !< Replace the text with `text` (UTF-8, lines ended by LF or CR LF): the marks and the undo history go, the cursor
   !< goes to the start. Statuses: `FIG_ERR_STATE` before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self !< Editor.
   character(len=*),          intent(in)            :: text !< Text.
   integer(int32),            intent(out), optional :: stat !< Status.

   if (.not. alive(self, 'set_text', stat)) return
   call figure_check(fig_editor_set_text(self%handle, text, len(text, c_long_long)), stat)
   endsubroutine editor_set_text

   recursive function editor_text(self) result(t)
   !< The text, its lines joined by LF (no LF after the last). `''` before `init` and from a task.
   class(code_editor_object), intent(in) :: self !< Editor.
   character(len=:), allocatable         :: t    !< Text.

   t = editor_string(self, 0_c_int)
   endfunction editor_text

   recursive function editor_line_count(self) result(n)
   !< The number of lines (1 for an empty text; 0 before `init` and from a task).
   class(code_editor_object), intent(in) :: self !< Editor.
   integer(int32)                        :: n    !< Lines.
   integer(c_int)                        :: l, u, r !< Lines, undo, redo.

   n = 0_int32
   if (.not. alive(self, 'line_count', quiet=.true.)) return
   if (fig_editor_info(self%handle, l, u, r) == FIG_OK) n = int(l, int32)
   endfunction editor_line_count

   recursive function editor_draw(self, id, width, height, stat) result(changed)
   !< Draw the editor as a widget at the cursor, inside a window, `width` x `height` pixels (0: the available region;
   !< negative: up to that distance from its edge), in IBM Plex Mono at the current font size with the fallback font's
   !< symbols (they keep their own width: they may overlap the next character), and the style's colours. True on the
   !< frame the user changed the text (typing, a paste, undo, a completion: not `set_text`, `insert` or `replace`).
   !< The mouse and the keyboard as in a code editor (a click places the cursor, a drag selects, ctrl+click adds a
   !< cursor); the wheel scrolls. Statuses: `FIG_ERR_ARGUMENT` for an empty id; `FIG_ERR_STATE` before `init`, with no
   !< frame open, from a task. The same in every mode.
   class(code_editor_object), intent(inout)         :: self    !< Editor.
   character(len=*),          intent(in)            :: id      !< Widget id (unique in the window).
   real(real64),              intent(in),  optional :: width   !< Width [pixels] (default 0: the available width).
   real(real64),              intent(in),  optional :: height  !< Height [pixels] (default 0: the available height).
   integer(int32),            intent(out), optional :: stat    !< Status.
   logical                                          :: changed !< The user changed the text this frame.
   real(c_double)                                   :: w, h    !< Size.
   integer(c_int)                                   :: ch      !< Changed (C).

   changed = .false.
   if (figure_draw_refused('code_editor_object%draw', stat)) return
   if (.not. alive(self, 'draw', stat)) return
   w = 0.0_c_double
   if (present(width)) w = real(width, c_double)
   h = 0.0_c_double
   if (present(height)) h = real(height, c_double)
   ch = 0_c_int
   call figure_check(fig_editor_draw(self%handle, id, len(id, c_int), w, h, ch), stat)
   changed = ch /= 0_c_int
   endfunction editor_draw

   recursive subroutine editor_mark(self, line, severity, message, stat)
   !< Mark `line` with a message: `severity` `'error'`, `'warning'` or `'info'` tints the line and its number
   !< (vermilion, orange, blue) and puts its icon (a crossed circle, a triangle, an "i") beside the number; the
   !< message, after its severity's word, is the line's tooltip. A second mark on a line joins the messages and keeps
   !< the gravest severity. A mark moves with its line as lines are inserted or deleted above it, and goes with it.
   !< Statuses: `FIG_ERR_ARGUMENT` for another severity or a line outside [1, line_count()]; `FIG_ERR_STATE` before
   !< `init` and from a task.
   class(code_editor_object), intent(inout)         :: self     !< Editor.
   integer(int32),            intent(in)            :: line     !< Line, from 1.
   character(len=*),          intent(in)            :: severity !< `'error'`, `'warning'` or `'info'`.
   character(len=*),          intent(in)            :: message  !< Message (UTF-8).
   integer(int32),            intent(out), optional :: stat     !< Status.
   integer(c_int)                                   :: sev      !< Severity code.

   if (.not. alive(self, 'mark', stat)) return
   select case (trim(severity))
   case ('error')
      sev = 1_c_int
   case ('warning')
      sev = 2_c_int
   case ('info')
      sev = 3_c_int
   case default
      sev = 0_c_int
   endselect
   call figure_check(fig_editor_mark(self%handle, int(line, c_int), sev, message, len(message, c_int)), stat)
   endsubroutine editor_mark

   recursive subroutine editor_clear_marks(self, stat)
   !< Remove every mark. Statuses: `FIG_ERR_STATE` before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self !< Editor.
   integer(int32),            intent(out), optional :: stat !< Status.

   if (.not. alive(self, 'clear_marks', stat)) return
   call figure_check(fig_editor_clear_marks(self%handle), stat)
   endsubroutine editor_clear_marks

   recursive function editor_mark_of(self, line, message) result(severity)
   !< The severity of the mark on `line` (`'error'`, `'warning'`, `'info'`; `''` for none, a line out of range, before
   !< `init` and from a task), and its message as its tooltip shows it (each message after its severity's word, LF
   !< between two).
   class(code_editor_object),     intent(in)            :: self     !< Editor.
   integer(int32),                intent(in)            :: line     !< Line, from 1.
   character(len=:), allocatable, intent(out), optional :: message  !< Its message.
   character(len=:), allocatable                        :: severity !< Its severity.
   integer(c_int)                                       :: sev      !< Severity code.
   integer(c_long_long)                                 :: n        !< Message length.
   character(kind=c_char, len=1)                        :: probe    !< Buffer for the length.
   character(kind=c_char, len=:), allocatable           :: buf      !< Message.

   severity = ''
   if (present(message)) message = ''
   if (.not. alive(self, 'mark_of', quiet=.true.)) return
   n = fig_editor_mark_of(self%handle, int(line, c_int), sev, probe, 0_c_long_long)
   select case (sev)
   case (1_c_int)
      severity = 'error'
   case (2_c_int)
      severity = 'warning'
   case (3_c_int)
      severity = 'info'
   endselect
   if (present(message) .and. n > 0_c_long_long) then
      allocate(character(kind=c_char, len=n) :: buf)
      n = fig_editor_mark_of(self%handle, int(line, c_int), sev, buf, n)
      message = buf
   endif
   endfunction editor_mark_of

   recursive subroutine editor_goto(self, line, column, focus, stat)
   !< Move the cursor to `line` (and `column`, default 1), clamped to the text, and scroll it into view at the next
   !< draw; with `focus`, give the editor the keyboard too. Statuses: `FIG_ERR_ARGUMENT` for a line or column below 1;
   !< `FIG_ERR_STATE` before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self   !< Editor.
   integer(int32),            intent(in)            :: line   !< Line, from 1.
   integer(int32),            intent(in),  optional :: column !< Column, from 1 [characters].
   logical,                   intent(in),  optional :: focus  !< Give it the keyboard (default false).
   integer(int32),            intent(out), optional :: stat   !< Status.
   integer(c_int)                                   :: c, f   !< Column, focus (C).

   if (.not. alive(self, 'goto', stat)) return
   c = 1_c_int
   if (present(column)) c = int(column, c_int)
   f = 0_c_int
   if (present(focus)) f = merge(1_c_int, 0_c_int, focus)
   call figure_check(fig_editor_goto(self%handle, int(line, c_int), c, f), stat)
   endsubroutine editor_goto

   recursive subroutine editor_focus(self, stat)
   !< Give the editor the keyboard at the next draw (as a click in it does). Statuses: `FIG_ERR_STATE` before `init`
   !< and from a task.
   class(code_editor_object), intent(inout)         :: self !< Editor.
   integer(int32),            intent(out), optional :: stat !< Status.

   if (.not. alive(self, 'focus', stat)) return
   call figure_check(fig_editor_focus(self%handle), stat)
   endsubroutine editor_focus

   recursive function editor_find(self, text, case_sensitive, whole_word, stat) result(found)
   !< Select the next occurrence of `text` after the cursor, from the start again past the end, and scroll it into view
   !< at the next draw. True when found (the selection is then `text`). Statuses: `FIG_ERR_ARGUMENT` for an empty
   !< text; `FIG_ERR_STATE` before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self           !< Editor.
   character(len=*),          intent(in)            :: text           !< Text to find.
   logical,                   intent(in),  optional :: case_sensitive !< By case (default true).
   logical,                   intent(in),  optional :: whole_word     !< Whole words only (default false).
   integer(int32),            intent(out), optional :: stat           !< Status.
   logical                                          :: found          !< Found.
   integer(c_int)                                   :: cs, ww, f      !< Flags (C).

   found = .false.
   if (.not. alive(self, 'find', stat)) return
   cs = 1_c_int
   if (present(case_sensitive)) cs = merge(1_c_int, 0_c_int, case_sensitive)
   ww = 0_c_int
   if (present(whole_word)) ww = merge(1_c_int, 0_c_int, whole_word)
   f = 0_c_int
   call figure_check(fig_editor_find(self%handle, text, len(text, c_int), cs, ww, f), stat)
   found = f /= 0_c_int
   endfunction editor_find

   recursive function editor_replace(self, text, by, case_sensitive, whole_word, stat) result(count)
   !< Replace every occurrence of `text` by `by`, as one change (one undo), and return how many were replaced. Statuses:
   !< `FIG_ERR_ARGUMENT` for an empty text; `FIG_ERR_STATE` for a read-only editor, before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self           !< Editor.
   character(len=*),          intent(in)            :: text           !< Text to replace.
   character(len=*),          intent(in)            :: by             !< Its replacement.
   logical,                   intent(in),  optional :: case_sensitive !< By case (default true).
   logical,                   intent(in),  optional :: whole_word     !< Whole words only (default false).
   integer(int32),            intent(out), optional :: stat           !< Status.
   integer(int32)                                   :: count          !< Occurrences replaced.
   integer(c_int)                                   :: cs, ww, n      !< Flags, count (C).

   count = 0_int32
   if (.not. alive(self, 'replace', stat)) return
   cs = 1_c_int
   if (present(case_sensitive)) cs = merge(1_c_int, 0_c_int, case_sensitive)
   ww = 0_c_int
   if (present(whole_word)) ww = merge(1_c_int, 0_c_int, whole_word)
   n = 0_c_int
   call figure_check(fig_editor_replace(self%handle, text, len(text, c_int), by, len(by, c_int), cs, ww, n), stat)
   count = int(n, int32)
   endfunction editor_replace

   recursive subroutine editor_cursor(self, line, column)
   !< The cursor's line and column, from 1 (column in characters); 1, 1 before `init` and from a task.
   class(code_editor_object), intent(in)  :: self   !< Editor.
   integer(int32),            intent(out) :: line   !< Line.
   integer(int32),            intent(out) :: column !< Column [characters].
   integer(c_int)                         :: l, c   !< Position (C).

   line = 1_int32
   column = 1_int32
   if (.not. alive(self, 'cursor', quiet=.true.)) return
   if (fig_editor_cursor(self%handle, l, c) /= FIG_OK) return
   line = int(l, int32)
   column = int(c, int32)
   endsubroutine editor_cursor

   recursive function editor_selection(self, first_line, first_column, last_line, last_column, text) result(has)
   !< The selection: true when some text is selected, from (`first_line`, `first_column`) to just before
   !< (`last_line`, `last_column`), from 1, columns in characters, and its `text`; false otherwise (the four positions
   !< are then the cursor's). False before `init` and from a task.
   class(code_editor_object),     intent(in)            :: self         !< Editor.
   integer(int32),                intent(out)           :: first_line   !< First line.
   integer(int32),                intent(out)           :: first_column !< First column [characters].
   integer(int32),                intent(out)           :: last_line    !< Last line.
   integer(int32),                intent(out)           :: last_column  !< Column after the last [characters].
   character(len=:), allocatable, intent(out), optional :: text         !< The selected text.
   logical                                              :: has          !< Some text is selected.
   integer(c_int)                                       :: pos(4), h    !< Positions, selected (C).

   has = .false.
   first_line = 1_int32
   first_column = 1_int32
   last_line = 1_int32
   last_column = 1_int32
   if (present(text)) text = ''
   if (.not. alive(self, 'selection', quiet=.true.)) return
   if (fig_editor_selection(self%handle, pos, h) /= FIG_OK) return
   first_line = int(pos(1), int32)
   first_column = int(pos(2), int32)
   last_line = int(pos(3), int32)
   last_column = int(pos(4), int32)
   has = h /= 0_c_int
   if (present(text)) text = editor_string(self, 2_c_int)
   endfunction editor_selection

   recursive subroutine editor_select(self, first_line, first_column, last_line, last_column, stat)
   !< Select from (`first_line`, `first_column`) to just before (`last_line`, `last_column`) (from 1, clamped to the
   !< text). Statuses: `FIG_ERR_ARGUMENT` for a position below 1; `FIG_ERR_STATE` before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self         !< Editor.
   integer(int32),            intent(in)            :: first_line   !< First line.
   integer(int32),            intent(in)            :: first_column !< First column [characters].
   integer(int32),            intent(in)            :: last_line    !< Last line.
   integer(int32),            intent(in)            :: last_column  !< Column after the last [characters].
   integer(int32),            intent(out), optional :: stat         !< Status.

   if (.not. alive(self, 'select', stat)) return
   call figure_check(fig_editor_select(self%handle, int(first_line, c_int), int(first_column, c_int), &
                                       int(last_line, c_int), int(last_column, c_int)), stat)
   endsubroutine editor_select

   recursive subroutine editor_insert(self, text, stat)
   !< Insert `text` at the cursor, in place of the selection if any, as one change (one undo); the cursor goes after it.
   !< Statuses: `FIG_ERR_STATE` for a read-only editor, before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self !< Editor.
   character(len=*),          intent(in)            :: text !< Text (UTF-8).
   integer(int32),            intent(out), optional :: stat !< Status.

   if (.not. alive(self, 'insert', stat)) return
   call figure_check(fig_editor_insert(self%handle, text, len(text, c_long_long)), stat)
   endsubroutine editor_insert

   recursive function editor_word_at_cursor(self) result(word)
   !< The word (letters, digits, `_`) the cursor is in or just after; `''` when none, before `init` and from a task.
   class(code_editor_object), intent(in) :: self !< Editor.
   character(len=:), allocatable         :: word !< Word.

   word = editor_string(self, 1_c_int)
   endfunction editor_word_at_cursor

   recursive subroutine editor_set_completions(self, words, stat)
   !< The words completion offers (each trimmed of trailing blanks; none: completion off). While the user types a
   !< word, a popup under the cursor lists the words that start with it, then those that contain it, in this order
   !< and in any case; up and down choose, tab or enter inserts, escape closes it. In a key = value language a word
   !< may hold blanks and dashes (`'reynolds number'`): the term is then the line's text up to the cursor, its
   !< indentation kept. Not in comments and strings. Statuses: `FIG_ERR_STATE` before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self     !< Editor.
   character(len=*),          intent(in)            :: words(:) !< Words.
   integer(int32),            intent(out), optional :: stat     !< Status.
   character(len=:), allocatable                    :: all      !< Words, LF-separated.
   integer(int32)                                   :: i        !< Counter.

   if (.not. alive(self, 'set_completions', stat)) return
   all = ''
   do i = 1_int32, size(words, kind=int32)
      if (len_trim(words(i)) == 0) cycle
      if (len(all) > 0) all = all//LF
      all = all//trim(words(i))
   enddo
   call figure_check(fig_editor_completions(self%handle, all, len(all, c_long_long)), stat)
   endsubroutine editor_set_completions

   recursive function editor_completing(self, words) result(open)
   !< True while the completion popup is open (from the frame after the typing that opened it), with the `words` it
   !< offers in its order (blank-padded to the longest). False before `init` and from a task.
   class(code_editor_object),     intent(in)            :: self     !< Editor.
   character(len=:), allocatable, intent(out), optional :: words(:) !< Words offered.
   logical                                              :: open     !< The popup is open.
   integer(c_int)                                       :: a        !< Open (C).

   open = .false.
   if (present(words)) allocate(character(len=0) :: words(0))
   if (.not. alive(self, 'completing', quiet=.true.)) return
   if (fig_editor_completing(self%handle, a) /= FIG_OK) return
   open = a /= 0_c_int
   if (present(words) .and. open) then
      deallocate(words)
      call split_lines(editor_string(self, 3_c_int), words)
   endif
   endfunction editor_completing

   recursive subroutine editor_read_only(self, on, stat)
   !< Make the editor read-only (`on` true: the user moves, selects and copies, nothing changes the text but
   !< `set_text`) or editable again. Statuses: `FIG_ERR_STATE` before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self !< Editor.
   logical,                   intent(in)            :: on   !< Read-only.
   integer(int32),            intent(out), optional :: stat !< Status.
   integer(c_int)                                   :: v    !< Value (C).

   if (.not. alive(self, 'read_only', stat)) return
   v = merge(1_c_int, 0_c_int, on)
   call figure_check(fig_editor_option(self%handle, 0_c_int, 1_c_int, v), stat)
   endsubroutine editor_read_only

   recursive function editor_is_read_only(self) result(on)
   !< Whether the editor is read-only (false before `init` and from a task).
   class(code_editor_object), intent(in) :: self !< Editor.
   logical                               :: on   !< Read-only.
   integer(c_int)                        :: v    !< Value (C).

   on = .false.
   if (.not. alive(self, 'is_read_only', quiet=.true.)) return
   v = 0_c_int
   if (fig_editor_option(self%handle, 0_c_int, 0_c_int, v) == FIG_OK) on = v /= 0_c_int
   endfunction editor_is_read_only

   recursive subroutine editor_set_options(self, line_numbers, tab_size, whitespace, line_highlight, stat)
   !< The editor's options: `line_numbers` shown (default true), `tab_size` [characters] in [1, 16] (default 4),
   !< `whitespace` shown as dots and arrows (default false), the current `line_highlight` (default true). Statuses:
   !< `FIG_ERR_ARGUMENT` for a tab size outside [1, 16]; `FIG_ERR_STATE` before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self           !< Editor.
   logical,                   intent(in),  optional :: line_numbers   !< Line numbers shown.
   integer(int32),            intent(in),  optional :: tab_size       !< Tab size [characters].
   logical,                   intent(in),  optional :: whitespace     !< Blanks and tabs shown.
   logical,                   intent(in),  optional :: line_highlight !< The current line highlighted.
   integer(int32),            intent(out), optional :: stat           !< Status.
   integer(c_int)                                   :: v              !< Value (C).
   integer(int32)                                   :: s              !< Status.

   if (.not. alive(self, 'set_options', stat)) return
   s = FIG_OK
   if (present(tab_size)) then
      if (tab_size < 1_int32 .or. tab_size > 16_int32) then
         call figure_fail(FIG_ERR_ARGUMENT, 'code_editor_object%set_options: tab_size must be in [1, 16]', stat)
         return
      endif
      v = int(tab_size, c_int)
      call figure_check(fig_editor_option(self%handle, 2_c_int, 1_c_int, v), s)
   endif
   if (present(line_numbers)) then
      v = merge(1_c_int, 0_c_int, line_numbers)
      call figure_check(fig_editor_option(self%handle, 1_c_int, 1_c_int, v), s)
   endif
   if (present(whitespace)) then
      v = merge(1_c_int, 0_c_int, whitespace)
      call figure_check(fig_editor_option(self%handle, 3_c_int, 1_c_int, v), s)
   endif
   if (present(line_highlight)) then
      v = merge(1_c_int, 0_c_int, line_highlight)
      call figure_check(fig_editor_option(self%handle, 4_c_int, 1_c_int, v), s)
   endif
   if (present(stat)) stat = s
   endsubroutine editor_set_options

   recursive function editor_undo(self, stat) result(done)
   !< Undo the last change (as ctrl+z): true if there was one. Nothing in a read-only editor. Statuses: `FIG_ERR_STATE`
   !< before `init` and from a task.
   class(code_editor_object), intent(inout)         :: self !< Editor.
   integer(int32),            intent(out), optional :: stat !< Status.
   logical                                          :: done !< A change was undone.
   integer(c_int)                                   :: d    !< Done (C).

   done = .false.
   if (.not. alive(self, 'undo', stat)) return
   d = 0_c_int
   call figure_check(fig_editor_undo(self%handle, 0_c_int, d), stat)
   done = d /= 0_c_int
   endfunction editor_undo

   recursive function editor_redo(self, stat) result(done)
   !< Redo the last undone change (as ctrl+y): true if there was one. Statuses: `FIG_ERR_STATE` before `init` and from
   !< a task.
   class(code_editor_object), intent(inout)         :: self !< Editor.
   integer(int32),            intent(out), optional :: stat !< Status.
   logical                                          :: done !< A change was redone.
   integer(c_int)                                   :: d    !< Done (C).

   done = .false.
   if (.not. alive(self, 'redo', stat)) return
   d = 0_c_int
   call figure_check(fig_editor_undo(self%handle, 1_c_int, d), stat)
   done = d /= 0_c_int
   endfunction editor_redo

   recursive function editor_line_rect(self, line, x0, y0, x1, y1) result(visible)
   !< The rectangle [pixels] of `line`'s text area on the last draw, from the left of the text to the right of the
   !< editor (for a popup beside a line, or a test): true when the line was in view. False before the first draw,
   !< before `init` and from a task.
   class(code_editor_object), intent(in)  :: self    !< Editor.
   integer(int32),            intent(in)  :: line    !< Line, from 1.
   real(real64),              intent(out) :: x0      !< Left [pixels].
   real(real64),              intent(out) :: y0      !< Top [pixels].
   real(real64),              intent(out) :: x1      !< Right [pixels].
   real(real64),              intent(out) :: y1      !< Bottom [pixels].
   logical                                :: visible !< The line was in view.
   real(c_float)                          :: r(4)    !< Rectangle (C).
   integer(c_int)                         :: v       !< Visible (C).

   visible = .false.
   x0 = 0.0_real64
   y0 = 0.0_real64
   x1 = 0.0_real64
   y1 = 0.0_real64
   if (.not. alive(self, 'line_rect', quiet=.true.)) return
   r = 0.0_c_float
   v = 0_c_int
   if (fig_editor_line_rect(self%handle, int(line, c_int), r, v) /= FIG_OK) return
   visible = v /= 0_c_int
   if (.not. visible) return
   x0 = real(r(1), real64)
   y0 = real(r(2), real64)
   x1 = real(r(3), real64)
   y1 = real(r(4), real64)
   endfunction editor_line_rect

   ! ---- the diff ------------------------------------------------------------------------------------------------------
   recursive subroutine code_diff(id, left, right, side_by_side, language, width, height, stat)
   !< Draw the difference of two texts (UTF-8, lines ended by LF or CR LF) as a widget at the cursor, `width` x `height`
   !< pixels (0: the available region; negative: up to that distance from its edge), read-only, in IBM Plex Mono:
   !< one column with each removed line of `left` (tinted red, marked `-`) before the added line of `right` (green,
   !< `+`), or `side_by_side`. Lines compared whole, by the diff's algorithm (dtl, the shortest edit script). Drawn by
   !< id, as a widget: the comparison is made again only when a text or the language changes; a diff not drawn for 600
   !< frames is forgotten. Statuses: `FIG_ERR_ARGUMENT` for an empty id, `FIG_ERR_STATE` with no frame open and from a
   !< task. The same in every mode.
   character(len=*),      intent(in)            :: id           !< Widget id (unique in the window).
   character(len=*),      intent(in)            :: left         !< The old text.
   character(len=*),      intent(in)            :: right        !< The new text.
   logical,               intent(in),  optional :: side_by_side !< Two columns (default false: one).
   type(language_object), intent(in),  optional :: language     !< Highlighting (default plain text).
   real(real64),          intent(in),  optional :: width        !< Width [pixels] (default 0: the available width).
   real(real64),          intent(in),  optional :: height       !< Height [pixels] (default 0: the available height).
   integer(int32),        intent(out), optional :: stat         !< Status.
   character(len=:), allocatable                :: packed       !< The language's definition.
   real(c_double)                               :: w, h         !< Size.
   integer(c_int)                               :: side         !< Two columns (C).

   if (figure_draw_refused('code_diff', stat)) return
   packed = ''
   if (present(language)) packed = pack_language(language)
   side = 0_c_int
   if (present(side_by_side)) side = merge(1_c_int, 0_c_int, side_by_side)
   w = 0.0_c_double
   if (present(width)) w = real(width, c_double)
   h = 0.0_c_double
   if (present(height)) h = real(height, c_double)
   call figure_check(fig_code_diff(id, len(id, c_int), left, len(left, c_long_long), right, len(right, c_long_long), &
                                   packed, len(packed, c_int), side, w, h), stat)
   endsubroutine code_diff

   recursive subroutine code_diff_lines(left, right, added, removed, stat)
   !< The lines that differ between two texts, as `code_diff` shows them: `added`, the lines of `right` not in `left`,
   !< and `removed`, the lines of `left` not in `right` (from 1, ascending; a changed line is one of each). No frame
   !< needed, any mode; a task may call it. Status: always `FIG_OK` (`FIG_ERR_EXCEPTION` if the native layer fails).
   character(len=*),            intent(in)            :: left       !< The old text.
   character(len=*),            intent(in)            :: right      !< The new text.
   integer(int32), allocatable, intent(out)           :: added(:)   !< Lines of `right` added.
   integer(int32), allocatable, intent(out)           :: removed(:) !< Lines of `left` removed.
   integer(int32),              intent(out), optional :: stat       !< Status.
   integer(c_int), allocatable                      :: a(:), r(:) !< Lines (C).
   integer(c_int)                                   :: na, nr     !< Counts.
   integer(c_int)                                   :: s          !< Native status.
   integer(c_int)                                   :: dummy(1)   !< No room, for the counts.

   allocate(added(0), removed(0))
   s = fig_code_diff_lines(left, len(left, c_long_long), right, len(right, c_long_long), dummy, na, dummy, nr, 0_c_int)
   if (s == FIG_OK) then
      allocate(a(max(1_c_int, max(na, nr))), r(max(1_c_int, max(na, nr))))
      s = fig_code_diff_lines(left, len(left, c_long_long), right, len(right, c_long_long), a, na, r, nr, &
                              max(1_c_int, max(na, nr)))
      if (s == FIG_OK) then
         added = int(a(1:na), int32)
         removed = int(r(1:nr), int32)
      endif
   endif
   call figure_check(s, stat)
   endsubroutine code_diff_lines

   ! ---- private -------------------------------------------------------------------------------------------------------
   recursive function alive(self, name, stat, quiet) result(ok)
   !< True when the editor exists and the caller is on the main thread; else the refusal (`FIG_ERR_STATE`), silent for a
   !< query (`quiet`: its default value is the answer).
   class(code_editor_object), intent(in)            :: self  !< Editor.
   character(len=*),          intent(in)            :: name  !< The method.
   integer(int32),            intent(out), optional :: stat  !< Status.
   logical,                   intent(in),  optional :: quiet !< A query: no failure before `init`.
   logical                                          :: ok    !< Go on.
   logical                                          :: q     !< Quiet.

   ok = .false.
   if (figure_refused('code_editor_object%'//name, stat)) return
   q = .false.
   if (present(quiet)) q = quiet
   if (self%handle == 0_c_int) then
      if (.not. q) call figure_fail(FIG_ERR_STATE, 'code_editor_object%'//name//': the editor is not initialized', stat)
      return
   endif
   ok = .true.
   endfunction alive

   recursive function editor_string(self, what) result(t)
   !< One of the editor's texts (fig_editor_string): '' before `init` and from a task.
   class(code_editor_object), intent(in) :: self  !< Editor.
   integer(c_int),            intent(in) :: what  !< 0 text, 1 word, 2 selection, 3 offered.
   character(len=:), allocatable         :: t     !< Text.
   integer(c_long_long)                  :: n     !< Length.
   character(kind=c_char, len=1)         :: probe !< Buffer for the length.

   t = ''
   if (.not. alive(self, 'string', quiet=.true.)) return
   n = fig_editor_string(self%handle, what, probe, 0_c_long_long)
   if (n <= 0_c_long_long) return
   deallocate(t)
   allocate(character(len=n) :: t)
   n = fig_editor_string(self%handle, what, t, n)
   endfunction editor_string

   pure function pack_language(lang) result(packed)
   !< The language's definition for the native layer (fields separated by US; '' for plain text).
   type(language_object), intent(in) :: lang   !< Language.
   character(len=:), allocatable     :: packed !< Definition.
   integer(int32)                    :: flags  !< Single, double, numbers, case, key value.
   character(len=8)                  :: f      !< Flags as digits.

   packed = ''
   if (.not. allocated(lang%name_)) return
   if (lang%fork) then
      packed = lang%name_//US//'1'//repeat(US, 7)//US//'0'
      return
   endif
   flags = 0_int32
   if (lang%single_quotes) flags = flags + 1_int32
   if (lang%double_quotes) flags = flags + 2_int32
   if (lang%numbers) flags = flags + 4_int32
   if (lang%case_sensitive) flags = flags + 8_int32
   if (lang%key_value) flags = flags + 16_int32
   write(f, '(I0)') flags
   packed = lang%name_//US//'0'//US//lang%keywords//US//lang%types//US//lang%comment//US//lang%comment_alt//US// &
            lang%block_start//US//lang%block_end//US//lang%preprocessor//US//trim(f)
   endfunction pack_language

   pure subroutine joined(words, all, ok)
   !< `words`, each trimmed, joined by LF into `all`; false for an empty word or one with a blank, LF or US inside.
   character(len=*),              intent(in)  :: words(:) !< Words.
   character(len=:), allocatable, intent(out) :: all      !< Joined.
   logical,                       intent(out) :: ok       !< All valid.
   integer(int32)                             :: i        !< Counter.

   all = ''
   ok = .true.
   do i = 1_int32, size(words, kind=int32)
      if (len_trim(words(i)) == 0 .or. scan(trim(words(i)), ' '//LF//US//achar(9)) > 0) then
         ok = .false.
         return
      endif
      if (len(all) > 0) all = all//LF
      all = all//trim(words(i))
   enddo
   endsubroutine joined

   pure subroutine split_lines(text, lines)
   !< `text`'s LF-separated parts, blank-padded to the longest.
   character(len=*),              intent(in)  :: text     !< Text.
   character(len=:), allocatable, intent(out) :: lines(:) !< Parts.
   integer(int32)                             :: n, i, a, longest !< Counts, start of a part.

   if (len(text) == 0) then
      allocate(character(len=0) :: lines(0))
      return
   endif
   n = 1_int32
   longest = 0_int32
   a = 1_int32
   do i = 1_int32, len(text, int32)
      if (text(i:i) == LF) then
         n = n + 1_int32
         longest = max(longest, i - a)
         a = i + 1_int32
      endif
   enddo
   longest = max(longest, len(text, int32) + 1_int32 - a)
   allocate(character(len=longest) :: lines(n))
   n = 1_int32
   a = 1_int32
   do i = 1_int32, len(text, int32)
      if (text(i:i) == LF) then
         lines(n) = text(a:i - 1_int32)
         n = n + 1_int32
         a = i + 1_int32
      endif
   enddo
   lines(n) = text(a:)
   endsubroutine split_lines

   pure function lower(s) result(l)
   !< `s` in lower case (ASCII letters).
   character(len=*), intent(in) :: s !< String.
   character(len=len(s))        :: l !< Lower case.
   integer(int32)               :: i, c !< Counter, code.

   l = s
   do i = 1_int32, len(s, int32)
      c = iachar(s(i:i))
      if (c >= iachar('A') .and. c <= iachar('Z')) l(i:i) = achar(c + 32)
   enddo
   endfunction lower

   pure function fortran_keywords() result(k)
   !< Fortran 2023's statements, constructs and operators (the keywords' colour).
   character(len=16), allocatable :: k(:) !< Keywords.

   k = [character(len=16) :: 'abstract', 'all', 'allocate', 'and', 'assign', 'assignment', 'associate', &
        'backspace', 'bind', 'block', 'call', 'case', 'change', 'close', 'common', 'concurrent', 'contains', &
        'continue', 'critical', 'cycle', 'data', 'deallocate', 'default', 'deferred', 'do', 'else', 'elseif', &
        'elsewhere', 'elemental', 'end', 'endassociate', 'endblock', 'endcritical', 'enddo', 'endenum', &
        'endfile', 'endforall', 'endfunction', 'endif', 'endinterface', 'endmodule', 'endprocedure', &
        'endprogram', 'endselect', 'endsubmodule', 'endsubroutine', 'endteam', 'endtype', 'endwhere', 'entry', &
        'enum', 'enumeration', 'enumerator', 'eqv', 'error', 'event', 'exit', 'extends', 'false', 'fail', &
        'final', 'flush', 'forall', 'form', 'format', 'function', 'generic', 'go', 'goto', 'if', 'images', &
        'implicit', 'import', 'impure', 'in', 'include', 'inout', 'inquire', 'interface', 'is', 'local', &
        'local_init', 'lock', 'memory', 'module', 'namelist', 'neqv', 'non_overridable', 'none', 'nopass', &
        'not', 'notify', 'nullify', 'only', 'open', 'operator', 'or', 'out', 'pass', 'pause', 'post', 'print', &
        'private', 'procedure', 'program', 'public', 'pure', 'rank', 'read', 'recursive', 'reduce', 'result', &
        'return', 'rewind', 'select', 'sequence', 'shared', 'simple', 'stop', 'submodule', 'subroutine', &
        'sync', 'team', 'then', 'to', 'true', 'unlock', 'use', 'wait', 'where', 'while', 'write']
   endfunction fortran_keywords

   pure function fortran_types() result(t)
   !< Fortran's intrinsic types and attributes (the types' colour).
   character(len=16), allocatable :: t(:) !< Types and attributes.

   t = [character(len=16) :: 'allocatable', 'asynchronous', 'character', 'class', 'codimension', 'complex', &
        'contiguous', 'dimension', 'double', 'doubleprecision', 'external', 'intent', 'integer', 'intrinsic', &
        'kind', 'len', 'logical', 'optional', 'parameter', 'pointer', 'precision', 'protected', 'real', 'save', &
        'target', 'type', 'typeof', 'classof', 'value', 'volatile']
   endfunction fortran_types
endmodule figure_editor
