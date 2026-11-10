!< cb_prefs, reference example: the user's settings kept between runs, read at the start with defaults, saved when they
!< change; two runs in one program (a restart: destroy, then init with the same file), headless.
program cb_prefs
!< cb_prefs, reference example: the user's settings kept between runs, read at the start with defaults, saved when
!< they change; two runs in one program (a restart: destroy, then init with the same file), headless.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object

implicit none
type(app_object)   :: app       !< Application.
character(len=256) :: case_file !< A setting: the case last opened.
real(real64)       :: cfl       !< A setting: the CFL number.
logical            :: grid      !< A setting: the grid drawn.
integer(int32)     :: run       !< Run.
integer(int32)     :: u, ios    !< Unit, I/O status.
character(len=256) :: line      !< A line of the file.
logical            :: found     !< A setting kept.
!run cb_prefs ./cb_prefs

open(newunit=u, file='cb_prefs.ini', status='replace')     ! a first run: no preferences yet
close(u, status='delete')
do run = 1_int32, 2_int32
   call app%init_headless(800_int32, 600_int32)
   call app%set_style('seal')                              ! the program's default, before the user's
   !region limits
   call app%set_size_limits(640_int32, 400_int32)          ! a window no smaller than this (headless: nothing)
   !endregion limits
   !region open
   call app%open_prefs('cb-prefs', file='cb_prefs.ini')    ! in a window: app%open_prefs('cb-prefs'), the platform's folder
   !endregion open
   !region load
   found = app%load_pref('case', case_file, default='naca0012.inp')
   found = app%load_pref('cfl', cfl, default=0.8_real64)
   found = app%load_pref('grid', grid, default=.true.)
   !endregion load
   write(output_unit, '(A,I0,A,F4.2,A,L1)') 'run ', run, ': case '//trim(case_file)//', cfl ', cfl, ', grid ', grid
   if (.not. app%next_frame()) exit
   if (run == 1_int32) then                                ! the user changes them
      case_file = 'rae2822.inp'
      cfl = 1.2_real64
      grid = .false.
      call app%set_style(palette='nord')
      !region save
      call app%save_pref('case', trim(case_file))          ! kept: written within 30 s and at destroy
      call app%save_pref('cfl', cfl)
      call app%save_pref('grid', grid)
      !endregion save
   endif
   call app%destroy()                                      ! writes the file
enddo
write(output_unit, '(A)') 'cb_prefs.ini, without the arrangement:'
open(newunit=u, file='cb_prefs.ini', status='old', action='read')
do
   read(u, '(A)', iostat=ios) line
   if (ios /= 0) exit
   if (index(line, '[arrangement') == 1) exit               ! Dear ImGui's settings follow
   if (line(1:1) /= '#') write(output_unit, '(A)') '  '//trim(line)
enddo
close(u, status='delete')
if (abs(cfl - 1.2_real64) > 0.0_real64 .or. grid) error stop 'cb_prefs: the settings were not kept'
endprogram cb_prefs
