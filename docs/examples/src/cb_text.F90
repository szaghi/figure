!< cb_text, cookbook: edit a text file in a multi-line field, in the monospace font, and save it.
program cb_text
!< cb_text, cookbook: edit a text file in a multi-line field, in the monospace font, and save it.
!<
!< `cb_text [FILE]` first writes an example input file (default `figure-overset.input` in the working directory), so
!< that its pictures are the same at every run; then it shows the file as text, editable, with a button that saves it.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ICON_SAVE, ig_begin, ig_button, ig_end, ig_input_text_multiline, ig_pop_font, &
                   ig_push_font, ig_same_line, ig_set_next_window, ig_text, text_buffer_object

implicit none
type(app_object)         :: app      !< Application.
type(text_buffer_object) :: buffer   !< The file's text.
character(len=512)       :: file     !< The file edited.
logical                  :: modified !< Edited since the last save.

call get_command_argument(1, file)
if (len_trim(file) == 0) file = 'figure-overset.input'
call write_example(trim(file))
call app%init('FIGURE: edit a text file', 760_int32, 430_int32)
!region load
call buffer%set(read_text(trim(file)))  ! any length; CRLF line ends become LF
modified = .false.
!endregion load
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 740.0_real64, 410.0_real64)
   if (ig_begin('Input file')) then
      !region edit
      if (ig_button(ICON_SAVE//' Save')) then
         call write_text(trim(file), buffer%text())
         modified = .false.
      endif
      call ig_same_line()
      if (modified) then
         call ig_text('(!) modified: '//trim(file))
      else
         call ig_text('saved: '//trim(file))
      endif
      call ig_push_font('plex-mono')         ! columns line up: every character as wide
      if (ig_input_text_multiline('##text', buffer, width=-1.0_real64, height=-1.0_real64, tab_input=.true.)) &
         modified = .true.
      call ig_pop_font()
      !endregion edit
   endif
   call ig_end()
enddo
call app%destroy()

contains
   function read_text(name) result(text)
   !< The whole content of a file ('' if it cannot be read).
   character(len=*), intent(in)  :: name !< File.
   character(len=:), allocatable :: text !< Its bytes.
   integer(int32)                :: u    !< Unit.
   integer(int32)                :: n    !< Size [bytes].
   integer(int32)                :: ios  !< Status.

   text = ''
   open(newunit=u, file=name, access='stream', form='unformatted', status='old', action='read', iostat=ios)
   if (ios /= 0) return
   inquire(unit=u, size=n)
   if (n > 0) then
      deallocate(text)
      allocate(character(len=n) :: text)
      read(u, iostat=ios) text
   endif
   close(u)
   endfunction read_text

   subroutine write_text(name, text)
   !< Write `text` as the whole content of a file.
   character(len=*), intent(in) :: name !< File.
   character(len=*), intent(in) :: text !< Its bytes.
   integer(int32)               :: u    !< Unit.
   integer(int32)               :: ios  !< Status.

   open(newunit=u, file=name, access='stream', form='unformatted', status='replace', action='write', iostat=ios)
   if (ios /= 0) return
   write(u, iostat=ios) text
   close(u)
   endsubroutine write_text

   subroutine write_example(name)
   !< An input file of an overset case, in columns.
   character(len=*), intent(in) :: name     !< File.
   character(len=1), parameter  :: LF = char(10) !< Line feed.

   call write_text(name, &
      '# overset case: a cylinder at Re = 100'//LF// &
      ''//LF// &
      '[grid]'//LF// &
      'file        = CC/cc'//LF// &
      'blocks      = 4'//LF// &
      'overlap     = 2'//LF// &
      ''//LF// &
      '[fluid]'//LF// &
      'reynolds    = 100.0'//LF// &
      'mach        = 0.1'//LF// &
      'scheme      = weno5'//LF// &
      ''//LF// &
      '[time]'//LF// &
      'dt          = 1.0e-3'//LF// &
      'iterations  = 20000'//LF// &
      ''//LF// &
      '[output]'//LF// &
      'dir         = OUT/'//LF// &
      'every       = 500'//LF)
   endsubroutine write_example
endprogram cb_text
