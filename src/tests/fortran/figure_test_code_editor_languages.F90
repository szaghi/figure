!< figure_test_code_editor_languages, the Fortran code editor's languages coloured as the C++ one's: every language.
program figure_test_code_editor_languages
!< figure_test_code_editor_languages, the Fortran code editor's languages coloured as the C++ one's: every language.
!<
!< szaghi/figure#15 P16, step 15. The fork's 13 languages (their re2c tokenizers translated by
!< scripts/gen_editor_languages.py, C's and Julia's ported by hand) and FIGURE's (Fortran, input files, a program's own),
!< each with a text that goes through its tokens (numbers of every form, strings, comments of every kind, Lua's long
!< brackets over lines, Julia's nested comments, macros, symbols and characters, JSON's and Markdown's tokens, a
!< preprocessor line, keywords, declarations, known identifiers, brackets), in four editors per picture: drawn by the
!< C++ editor (`figure_editor_ref`) in one window and by the Fortran one (`figure_editor`) in another at the same
!< place, 40 frames apart, and the pictures compared (threshold 2, no pixel failing): a glyph of another colour fails.
!<
!< The pictures are `figure_test_code_editor_languages.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_end, ig_same_line, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_editor_ref, only : code_editor_object, code_language, language_object
use figure_editor, only : f_code_editor_object => code_editor_object, f_code_language => code_language, &
                          f_language_object => language_object
use figure_testing, only : test_capture, test_compare_image

implicit none
integer(int32),   parameter :: W = 800_int32   !< Display width [pixels].
integer(int32),   parameter :: H = 560_int32   !< Display height [pixels].
integer(int32),   parameter :: NCASE = 4_int32 !< Pictures.
integer(int32),   parameter :: NF = 6_int32    !< Frames per side.
character(len=*), parameter :: LF = achar(10)  !< Line feed.
character(len=*), parameter :: TAB = achar(9)  !< Tab.
character(len=*), parameter :: PI = char(207)//char(128) !< U+03C0.
character(len=12), parameter :: NAMES(16) = [character(len=12) :: 'c', 'c++', 'c#', 'angelscript', 'glsl', 'hlsl', &
                                            'wgsl', 'sql', 'python', 'lua', 'julia', 'json', 'markdown', 'fortran', &
                                            'input', 'own'] !< The languages.
type(app_object)            :: app             !< Application.
type(code_editor_object)    :: c(4)            !< The C++ editors.
type(f_code_editor_object)  :: f(4)            !< The Fortran editors.
logical                     :: test_passed(NCASE) !< Per-picture outcome.
integer(int32)              :: k, side, fr, i, j !< Picture, side, frame, counters.
character(len=16)           :: keep            !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
do k = 1_int32, NCASE
   do j = 1_int32, 4_int32
      call setup(j, trim(NAMES(4 * (k - 1) + j)))
   enddo
   do side = 1_int32, 2_int32
      do fr = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_languages: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin(merge('languages C', 'languages F', side == 1_int32), flags=ImGuiWindowFlags_NoDecoration)) then
            do j = 1_int32, 4_int32
               if (side == 1_int32) then
                  if (c(j)%draw(achar(96 + j), 390.0_real64, 270.0_real64)) continue
               else
                  if (f(j)%draw(achar(96 + j), 390.0_real64, 270.0_real64)) continue
               endif
               if (mod(j, 2_int32) == 1_int32) call ig_same_line()
            enddo
         endif
         call ig_end()
         if (fr == NF) call test_capture(picture(k, side))
      enddo
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_languages: next_frame returned false headless'
      enddo
   enddo
   test_passed(k) = test_compare_image(picture(k, 2), picture(k, 1))
enddo
do j = 1_int32, 4_int32
   call c(j)%destroy()
   call f(j)%destroy()
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_code_editor_languages checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function picture(kk, sd) result(path)
   !< A picture by a side.
   integer(int32), intent(in)    :: kk, sd !< Picture, side.
   character(len=:), allocatable :: path   !< File.
   character(len=64)             :: s      !< Buffer.

   write(s, '(A,I0,A)') 'figure_test_code_editor_languages.', kk, &
                        merge('.cpp.png.tmp    ', '.fortran.png.tmp', sd == 1_int32)
   path = trim(s)
   endfunction picture

   subroutine setup(j, name)
   !< Editor j of both sides: a language and its text.
   integer(int32),   intent(in)  :: j    !< Editor.
   character(len=*), intent(in)  :: name !< Language.
   type(language_object)         :: lc   !< The program's own language, C++ side.
   type(f_language_object)       :: lf_  !< ... Fortran side.
   character(len=:), allocatable :: t    !< Text.

   call c(j)%destroy()
   call f(j)%destroy()
   if (name == 'own') then
      call lc%init('solver log', keywords=['converged', 'diverged '], types=['step', 'time'], comment='#', &
                   block_comment=['/*', '*/'], preprocessor='%', case_sensitive=.false.)
      call lf_%init('solver log', keywords=['converged', 'diverged '], types=['step', 'time'], comment='#', &
                    block_comment=['/*', '*/'], preprocessor='%', case_sensitive=.false.)
      call c(j)%init(lc)
      call f(j)%init(lf_)
   else
      call c(j)%init(code_language(name))
      call f(j)%init(f_code_language(name))
   endif
   t = sample(name)
   call c(j)%set_text(t)
   call f(j)%set_text(t)
   call c(j)%read_only(.true.)
   call f(j)%read_only(.true.)
   endsubroutine setup

   function sample(name) result(t)
   !< A language's text.
   character(len=*), intent(in)  :: name !< Language.
   character(len=:), allocatable :: t    !< Text.

   select case (name)
   case ('c', 'c++', 'angelscript', 'glsl', 'hlsl')
      t = '#include <stdio.h> // pre'//LF//'/* block'//LF//'   comment */ int main(void) {'//LF// &
          '   unsigned x = 0x1Fu + 0b101 + 017 + 1e-3f + .5 + 2.L + 1'//"'"//'000;'//LF// &
          '   const char *s = "a\"b"; char q = '//"'\\''"//';'//LF//'   return x > 1 ? (s[0]) : sizeof(float);'// &
          LF//'}  ] ) // mismatched'//LF//'class A : public B { virtual ~A(); nullptr; };'
   case ('c#')
      t = '#region numbers'//LF//'var x = 0x1F + 0b1010_0101 + 1_000m + 2.5e3d + 3.0f + 4UL;'//LF// &
          '/* block */ string s = "a\"b" + @"c"; // line'//LF//'public class C { int this[int i] => i; }'
   case ('wgsl')
      t = '// wgsl'//LF//'@vertex fn main(@builtin(vertex_index) i : u32) -> @builtin(position) vec4<f32> {'// &
          LF//'   let x = 1.5h + 0x1p3f + 2i + 3u;'//LF//'   return vec4<f32>(0.0, 1.0, 0.5, 1.0);'//LF//'}'
   case ('sql')
      t = '-- query'//LF//'SELECT name, COUNT(*) FROM users /* all */'//LF//"WHERE id > 10 AND name = 'x\'y'"// &
          LF//'GROUP BY name ORDER BY 2 DESC;'
   case ('python')
      t = 'import numpy as np  # comment'//LF//'def f(x: float) -> float:'//LF// &
          '    """Doc'//LF//'    string"""'//LF//"    y = 0x1F + 0o17 + 0b1_01 + 1_000.5e-3 + 2j + .5 + 3."//LF// &
          "    s = 'a\'b' + "//'"c" + '//"'''tri'''"//LF//'    return [y, s, None, True, print(len(s))]'// &
          LF//'class C:'//LF//'    pass'
   case ('lua')
      t = '-- line comment'//LF//'--[==[ long'//LF//'comment ]==] local x = 0x1F + 1e3 + 0x1p4 + .5'//LF// &
          's = [[long'//LF//'string]] .. [=[ x ]=] .. "a\"b" .. '//"'c'"//LF// &
          'function f(t) return #t, nil, true end'
   case ('julia')
      t = '#= nested #= comment =# =# using LinearAlgebra'//LF//'@inline function f(x::Real)::Float64'//LF// &
          '    y = 0x1f + 0b101 + 0o17 + 1_000.5e-3 + 2im + 0x1.8p3 + 1..2'//LF// &
          "    c = 'a' * '\n' * x' * :sym * `ls -l` * "//'"str\"" * '//PI//LF// &
          '    T <: Real && a!=b && abstract type A end'//LF//'    mutable struct S end; return nothing'// &
          LF//'end # done'
   case ('json')
      t = '{'//LF//'   "case": "cavity\"x",'//LF//'   "re": -1.5e+3, "n": 0, "ok": true,'//LF// &
          '   "lid": [1.0, null, false],'//LF//'   bad: 01'//LF//'}'
   case ('markdown')
      t = '# Title'//LF//'Some *emphasis*, **strong**, `code` and a [link](http://x.y).'//LF// &
          '- item one'//LF//'1. first'//LF//'> quote'//LF//'<!-- comment -->'//LF//'```'//LF//'fenced'// &
          LF//'```'
   case ('fortran')
      t = '#ifdef DEBUG'//LF//'module m ! comment'//LF//'   real(real64), parameter :: x = 1.5d-3, y = 2.0_real64'// &
          LF//"   character(*), parameter :: s = 'a''b' // " //'"c"'//LF//'   if (x .and. 1.e5 > 7_int8) then'//LF// &
          'endmodule m'
   case ('input')
      t = '[section] ! comment'//LF//' key one = 1.5e6'//LF//' key-two.x = yes # c'//LF//'[bad = 1'//LF// &
          ' flag = true'
   case default
      t = '% preprocessor line'//LF//'STEP 100 residual 1.2e-3 /* block'//LF//'comment */ converged'//LF// &
          "time 'q' "//'"s" # line'
   endselect
   endfunction sample

   subroutine remove_files()
   !< Remove the pictures.
   integer(int32) :: kk, sd, u, ios !< Picture, side, unit, status.

   do kk = 1_int32, NCASE
      do sd = 1_int32, 2_int32
         open(newunit=u, file=picture(kk, sd), status='old', iostat=ios)
         if (ios == 0_int32) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_code_editor_languages
