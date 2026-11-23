!< figure_plot_time_picker, a time axis's date and time pickers in the Fortran frame's axis menu, as ImPlot's.
module figure_plot_time_picker
!< figure_plot_time_picker, a time axis's date and time pickers in the Fortran frame's axis menu, as ImPlot's.
!<
!< szaghi/figure#15: `ShowAxisContextMenu`'s branch of a time axis (implot.cpp): in place of the Min and Max drags, the
!< menus "Min Time" and "Max Time", each a time picker (`ShowTimePicker`: hour, minute and second combos, am/pm) over
!< a date picker (`ShowDatePicker`: a month of days, a year of months, twenty years). The frame calls
!< `pf_time_picker_menu` for each end, between its lock box and the end's disabled scope, and sets the axis's range
!< when it returns true (`SetRange`).
!<
!< Times are UTC (the frame's time axes: `UseLocalTime` false) on a 12-hour clock (`Use24HourClock` false: ImPlot's
!< default, the frame's), through figure_plot_locators' ImPlotTime helpers. ImPlot keeps an axis's picker state
!< (`PickerLevel`, `PickerTimeMin`, `PickerTimeMax`) in the axis and resets the picker times on every `SetMin`,
!< `SetMax` and `SetRange`; here the state is kept per plot and axis, and the picker times are reset when the axis's
!< range differs from the one last seen (a range set again to the same values does not reset a month browsed to).
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_cimgui_enums, only : ImGuiCol_Button, ImGuiCol_ButtonHovered, ImGuiCol_Text, ImGuiCol_TextDisabled, &
                                ImGuiComboFlags_NoArrowButton, ImGuiDir_Down, ImGuiDir_Up, ImGuiItemFlags_Disabled, &
                                ImGuiStyleVar_Alpha, ImGuiStyleVar_ItemSpacing, ImGuiStyleVar_ScrollbarSize
use figure_core, only : core_arrow_button, core_begin_combo, core_end_combo, core_frame_height, core_pop_id, &
                        core_pop_item_flag, core_pop_style_var, core_push_id, core_push_id_int, core_push_item_flag, &
                        core_push_style_var, core_style_color_rgba, core_style_var, core_text_size,                 &
                        core_text_unformatted
use figure_group, only : ig_begin_group, ig_end_group
use figure_imgui, only : ig_button, ig_dummy, ig_same_line, ig_selectable, ig_separator, ig_set_next_item_width
use figure_menu, only : ig_begin_menu, ig_end_menu
use figure_style, only : ig_pop_style_color, ig_push_style_color
use figure_plot_locators, only : plot_time, time_from_double, time_to_double, time_lt, gm_time, mk_time, make_time, &
                                 time_year, days_in_month, leap_year, add_time, floor_time, TU_S, TU_DAY, TU_MO, TU_YR

implicit none
private
public :: pf_time_picker_menu

integer(int32), parameter :: NSTATE = 32_int32   !< Axes whose picker state is kept.
integer(int32), parameter :: MIN_YR = 1970_int32 !< The date picker's first year.
integer(int32), parameter :: MAX_YR = 2999_int32 !< ... its last.
character(len=*), parameter :: MONTH_NAMES(12) = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', &
                                                  'June     ', 'July     ', 'August   ', 'September', 'October  ', &
                                                  'November ', 'December '] !< MONTH_NAMES.
character(len=*), parameter :: MONTH_ABRVS(12) = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', &
                                                  'Oct', 'Nov', 'Dec'] !< MONTH_ABRVS.
character(len=*), parameter :: WD_ABRVS(7) = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'] !< WD_ABRVS.

type :: picker_state
   !< An axis's picker state (ImPlotAxis' PickerLevel, PickerTimeMin, PickerTimeMax) and the range last seen.
   integer(int32)  :: plot = 0_int32       !< The plot's ID.
   integer(int32)  :: axis = 0_int32       !< The axis.
   logical         :: used = .false.       !< In use.
   integer(int64)  :: stamp = 0_int64      !< Last use.
   integer(int32)  :: level = 0_int32      !< PickerLevel: 0 days, 1 months, 2 years.
   type(plot_time) :: pick_min             !< PickerTimeMin.
   type(plot_time) :: pick_max             !< PickerTimeMax.
   real(real64)    :: seen_min = 0.0_real64 !< The axis's range when last seen.
   real(real64)    :: seen_max = 0.0_real64 !< ...
endtype picker_state

type(picker_state) :: states(NSTATE) !< Kept states.
integer(int64)     :: clock = 0_int64 !< Uses, for the oldest state's replacement.

contains
   function pf_time_picker_menu(plot_id, axis, is_max, rmin, rmax, vmin, vmax) result(changed)
   !< The menu "Min Time" (or "Max Time", `is_max`) of a time axis of range [rmin, rmax]: a time picker, a separator, a
   !< date picker. True when a pick changed the range: the new one is [vmin, vmax] (to `SetRange`).
   integer(int32), intent(in)  :: plot_id    !< The plot's ID.
   integer(int32), intent(in)  :: axis       !< The axis (the frame's index).
   logical,        intent(in)  :: is_max     !< The menu of the range's max.
   real(real64),   intent(in)  :: rmin, rmax !< The axis's range.
   real(real64),   intent(out) :: vmin, vmax !< The range picked.
   logical                     :: changed    !< Picked.
   type(plot_time)             :: tmin, tmax !< The range's ends.
   integer(int32)              :: k          !< State.

   changed = .false.
   vmin = rmin
   vmax = rmax
   k = state_of(plot_id, axis, rmin, rmax)
   tmin = time_from_double(rmin)
   tmax = time_from_double(rmax)
   if (.not. is_max) then
      if (.not. ig_begin_menu('Min Time')) return
      if (time_picker('mintime', tmin)) then
         if (.not. time_lt(tmin, tmax)) tmax = add_time(tmin, TU_S, 1_int32)
         call set_range()
      endif
      call ig_separator()
      if (date_picker('mindate', states(k)%level, states(k)%pick_min, tmin, tmax)) then
         tmin = combine_date_time(states(k)%pick_min, tmin)
         if (.not. time_lt(tmin, tmax)) tmax = add_time(tmin, TU_S, 1_int32)
         call set_range()
      endif
   else
      if (.not. ig_begin_menu('Max Time')) return
      if (time_picker('maxtime', tmax)) then
         if (.not. time_lt(tmin, tmax)) tmin = time_add_seconds(tmax, -1_int64)
         call set_range()
      endif
      call ig_separator()
      if (date_picker('maxdate', states(k)%level, states(k)%pick_max, tmin, tmax)) then
         tmax = combine_date_time(states(k)%pick_max, tmax)
         if (.not. time_lt(tmin, tmax)) tmin = time_add_seconds(tmax, -1_int64)
         call set_range()
      endif
   endif
   call ig_end_menu()
   contains
      subroutine set_range()
      !< `SetRange(tmin, tmax)`: the range picked, and the picker times reset to it.
      vmin = min(time_to_double(tmin), time_to_double(tmax))
      vmax = max(time_to_double(tmin), time_to_double(tmax))
      states(k)%pick_min = time_from_double(vmin)
      states(k)%pick_max = time_from_double(vmax)
      changed = .true.
      endsubroutine set_range
   endfunction pf_time_picker_menu

   ! private: the pickers

   function date_picker(id, level, t, t1, t2) result(clk)
   !< `ShowDatePicker`: the days of a month (level 0), the months of a year (1) or twenty years (2); `t` the time
   !< browsed; t1 and t2 highlighted. True when a day is clicked (`t` then that day).
   character(len=*), intent(in)    :: id     !< ID.
   integer(int32),   intent(inout) :: level  !< Level.
   type(plot_time),  intent(inout) :: t      !< Time browsed.
   type(plot_time),  intent(in)    :: t1, t2 !< The range's ends.
   logical                         :: clk    !< A day clicked.
   real(real64)                    :: col_txt(4), col_dis(4), col_btn(4) !< Style colours.
   real(real32)                    :: ht, cx, cy !< Frame height, a cell.
   character(len=32)               :: buff   !< A label.
   integer(int32)                  :: t1_mo, t1_md, t1_yr, t2_mo, t2_md, t2_yr !< The ends' dates.
   integer(int32)                  :: yr, mo, md, hr, mi, se !< A calendar.
   integer(int32)                  :: this_year, last_year, next_year, this_mon, last_mon, next_mon !< The month.
   integer(int32)                  :: days_this_mo, days_last_mo, first_wd, day, now_yr, now_mo, now_md !< Days.
   integer(int32)                  :: i, j   !< Cells.
   logical                         :: off_mo, hl, b, dis !< A cell's state.
   type(plot_time)                 :: t_first_mo !< The month's first day.

   call core_push_id(id)
   call ig_begin_group()
   call core_style_color_rgba(ImGuiCol_Text, col_txt)
   call core_style_color_rgba(ImGuiCol_TextDisabled, col_dis)
   call core_style_color_rgba(ImGuiCol_Button, col_btn)
   call ig_push_style_color('Button', [0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64])
   call core_push_style_var(ImGuiStyleVar_ItemSpacing, 0.0_real64, 0.0_real64)
   ht = real(core_frame_height(), real32)
   cx = ht * 1.25_real32
   cy = ht
   clk = .false.
   call gm_time(t1%s, t1_yr, t1_mo, t1_md, hr, mi, se)
   call gm_time(t2%s, t2_yr, t2_mo, t2_md, hr, mi, se)
   select case (level)
   case (0_int32) ! day widget
      t = floor_time(t, TU_DAY)
      call gm_time(t%s, yr, mo, md, hr, mi, se)
      this_year = yr
      last_year = this_year - 1_int32
      next_year = this_year + 1_int32
      this_mon = mo
      last_mon = merge(11_int32, this_mon - 1_int32, this_mon == 0_int32)
      next_mon = merge(0_int32, this_mon + 1_int32, this_mon == 11_int32)
      days_this_mo = days_in_month(this_year, this_mon)
      days_last_mo = days_in_month(merge(last_year, this_year, this_mon == 0_int32), last_mon)
      t_first_mo = floor_time(t, TU_MO)
      first_wd = week_day(t_first_mo)
      write(buff, '(A,1X,I0)') trim(MONTH_NAMES(this_mon + 1_int32)), this_year
      if (ig_button(trim(buff))) level = 1_int32
      call ig_same_line(real(5.0_real32 * cx, real64))
      dis = this_year <= MIN_YR .and. this_mon == 0_int32
      call begin_disabled(dis)
      if (core_arrow_button('##Up', int(ImGuiDir_Up, int32), real(cx, real64), real(cy, real64))) &
         t = add_months(t, -1_int32)
      call end_disabled(dis)
      call ig_same_line()
      dis = this_year >= MAX_YR .and. this_mon == 11_int32
      call begin_disabled(dis)
      if (core_arrow_button('##Down', int(ImGuiDir_Down, int32), real(cx, real64), real(cy, real64))) &
         t = add_months(t, 1_int32)
      call end_disabled(dis)
      call core_push_item_flag(int(ImGuiItemFlags_Disabled, int32), .true.)
      do i = 1_int32, 7_int32
         if (ig_button(WD_ABRVS(i), real(cx, real64), real(cy, real64))) continue
         if (i /= 7_int32) call ig_same_line()
      enddo
      call core_pop_item_flag()
      mo = merge(0_int32, 1_int32, first_wd > 0_int32) ! 0 last month, 1 this month, 2 next month
      day = merge(1_int32, days_last_mo - first_wd + 1_int32, mo == 1_int32)
      do i = 0_int32, 5_int32
         do j = 0_int32, 6_int32
            if (mo == 0_int32 .and. day > days_last_mo) then
               mo = 1_int32
               day = 1_int32
            elseif (mo == 1_int32 .and. day > days_this_mo) then
               mo = 2_int32
               day = 1_int32
            endif
            if (mo == 0_int32 .and. this_mon == 0_int32) then
               now_yr = last_year
            elseif (mo == 2_int32 .and. this_mon == 11_int32) then
               now_yr = next_year
            else
               now_yr = this_year
            endif
            if (mo == 0_int32) then
               now_mo = last_mon
            elseif (mo == 1_int32) then
               now_mo = this_mon
            else
               now_mo = next_mon
            endif
            now_md = day
            off_mo = mo == 0_int32 .or. mo == 2_int32
            hl = (t1_mo == now_mo .and. t1_yr == now_yr .and. t1_md == now_md) .or. &
                 (t2_mo == now_mo .and. t2_yr == now_yr .and. t2_md == now_md)
            if (off_mo) call ig_push_style_color('Text', col_dis)
            if (hl) then
               call ig_push_style_color('Button', col_btn)
               call ig_push_style_color('Text', col_txt)
            endif
            call core_push_id_int(i * 7_int32 + j)
            write(buff, '(I0)') day
            if (now_yr == MIN_YR - 1_int32 .or. now_yr == MAX_YR + 1_int32) then
               call ig_dummy(real(cx, real64), real(cy, real64))
            else
               b = ig_button(trim(buff), real(cx, real64), real(cy, real64))
               if (b .and. .not. clk) then
                  t = make_time(now_yr, now_mo, now_md, 0_int32, 0_int32, 0_int32, 0_int32)
                  clk = .true.
               endif
            endif
            call core_pop_id()
            if (hl) call ig_pop_style_color(2_int32)
            if (off_mo) call ig_pop_style_color()
            if (j /= 6_int32) call ig_same_line()
            day = day + 1_int32
         enddo
      enddo
   case (1_int32) ! month widget
      t = floor_time(t, TU_MO)
      call gm_time(t%s, yr, mo, md, hr, mi, se)
      this_year = yr
      write(buff, '(I0)') this_year
      if (ig_button(trim(buff))) level = 2_int32
      dis = this_year <= MIN_YR
      call begin_disabled(dis)
      call ig_same_line(real(5.0_real32 * cx, real64))
      if (core_arrow_button('##Up', int(ImGuiDir_Up, int32), real(cx, real64), real(cy, real64))) &
         t = add_years(t, -1_int32)
      call end_disabled(dis)
      call ig_same_line()
      dis = this_year >= MAX_YR
      call begin_disabled(dis)
      if (core_arrow_button('##Down', int(ImGuiDir_Down, int32), real(cx, real64), real(cy, real64))) &
         t = add_years(t, 1_int32)
      call end_disabled(dis)
      cx = cx * (7.0_real32 / 4.0_real32)
      cy = cy * (7.0_real32 / 3.0_real32)
      mo = 0_int32
      do i = 0_int32, 2_int32
         do j = 0_int32, 3_int32
            hl = (t1_yr == this_year .and. t1_mo == mo) .or. (t2_yr == this_year .and. t2_mo == mo)
            if (hl) call ig_push_style_color('Button', col_btn)
            b = ig_button(MONTH_ABRVS(mo + 1_int32), real(cx, real64), real(cy, real64))
            if (b .and. .not. clk) then
               t = make_time(this_year, mo, 1_int32, 0_int32, 0_int32, 0_int32, 0_int32)
               level = 0_int32
            endif
            if (hl) call ig_pop_style_color()
            if (j /= 3_int32) call ig_same_line()
            mo = mo + 1_int32
         enddo
      enddo
   case (2_int32) ! year widget
      t = floor_time(t, TU_YR)
      this_year = time_year(t)
      yr = this_year - mod(this_year, 20_int32)
      call core_push_item_flag(int(ImGuiItemFlags_Disabled, int32), .true.)
      write(buff, '(I0,A,I0)') yr, '-', yr + 19_int32
      if (ig_button(trim(buff))) continue
      call core_pop_item_flag()
      call ig_same_line(real(5.0_real32 * cx, real64))
      dis = yr <= MIN_YR
      call begin_disabled(dis)
      if (core_arrow_button('##Up', int(ImGuiDir_Up, int32), real(cx, real64), real(cy, real64))) &
         t = make_time(yr - 20_int32, 0_int32, 1_int32, 0_int32, 0_int32, 0_int32, 0_int32)
      call end_disabled(dis)
      call ig_same_line()
      dis = yr + 20_int32 >= MAX_YR
      call begin_disabled(dis)
      if (core_arrow_button('##Down', int(ImGuiDir_Down, int32), real(cx, real64), real(cy, real64))) &
         t = make_time(yr + 20_int32, 0_int32, 1_int32, 0_int32, 0_int32, 0_int32, 0_int32)
      call end_disabled(dis)
      cx = cx * (7.0_real32 / 4.0_real32)
      cy = cy * (7.0_real32 / 5.0_real32)
      do i = 0_int32, 4_int32
         do j = 0_int32, 3_int32
            hl = t1_yr == yr .or. t2_yr == yr
            if (hl) call ig_push_style_color('Button', col_btn)
            write(buff, '(I0)') yr
            if (yr < 1970_int32 .or. yr > 3000_int32) then
               call ig_dummy(real(cx, real64), real(cy, real64))
            elseif (ig_button(trim(buff), real(cx, real64), real(cy, real64))) then
               t = make_time(yr, 0_int32, 1_int32, 0_int32, 0_int32, 0_int32, 0_int32)
               level = 1_int32
            endif
            if (hl) call ig_pop_style_color()
            if (j /= 3_int32) call ig_same_line()
            yr = yr + 1_int32
         enddo
      enddo
   case default
   endselect
   call core_pop_style_var()
   call ig_pop_style_color()
   call ig_end_group()
   call core_pop_id()
   endfunction date_picker

   function time_picker(id, t) result(changed)
   !< `ShowTimePicker` on a 12-hour clock: hour, minute and second combos and the am/pm button. True when changed
   !< (`t` then the new time of the same day).
   character(len=*), intent(in)    :: id      !< ID.
   type(plot_time),  intent(inout) :: t       !< Time.
   logical                         :: changed !< Changed.
   character(len=2), parameter     :: AM_PM(0:1) = ['am', 'pm'] !< am_pm.
   integer(int32)                  :: yr, mo, md, h, mi, se, hr, ap, i !< Calendar, clock, counter.
   real(real64)                    :: sp(2)   !< ItemSpacing.
   integer(int32)                  :: n       !< Its values.
   real(real64)                    :: width, w0, height, hov(4) !< Combo width, a height, ButtonHovered.

   call core_push_id(id)
   call gm_time(t%s, yr, mo, md, h, mi, se)
   hr = merge(12_int32, mod(h, 12_int32), h == 0_int32 .or. h == 12_int32)
   ap = merge(0_int32, 1_int32, h < 12_int32)
   changed = .false.
   call core_style_var('ItemSpacing', sp, n)
   call core_text_size('888', width, w0)
   width = real(real(width, real32), real64)
   height = real(real(core_frame_height(), real32), real64)
   call core_push_style_var(ImGuiStyleVar_ItemSpacing, 0.0_real64, sp(2))
   call core_push_style_var(ImGuiStyleVar_ScrollbarSize, 2.0_real64)
   call core_style_color_rgba(ImGuiCol_ButtonHovered, hov)
   call ig_push_style_color('FrameBg', [0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64])
   call ig_push_style_color('Button', [0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64])
   call ig_push_style_color('FrameBgHovered', hov)
   call ig_set_next_item_width(width)
   if (core_begin_combo('##hr', two(hr), int(ImGuiComboFlags_NoArrowButton, int32))) then
      do i = 1_int32, 12_int32
         if (ig_selectable(two(i), i == hr)) then
            hr = i
            changed = .true.
         endif
      enddo
      call core_end_combo()
   endif
   call ig_same_line()
   call core_text_unformatted(':')
   call ig_same_line()
   call ig_set_next_item_width(width)
   if (core_begin_combo('##min', two(mi), int(ImGuiComboFlags_NoArrowButton, int32))) then
      do i = 0_int32, 59_int32
         if (ig_selectable(two(i), i == mi)) then
            mi = i
            changed = .true.
         endif
      enddo
      call core_end_combo()
   endif
   call ig_same_line()
   call core_text_unformatted(':')
   call ig_same_line()
   call ig_set_next_item_width(width)
   if (core_begin_combo('##sec', two(se), int(ImGuiComboFlags_NoArrowButton, int32))) then
      do i = 0_int32, 59_int32
         if (ig_selectable(two(i), i == se)) then
            se = i
            changed = .true.
         endif
      enddo
      call core_end_combo()
   endif
   call ig_same_line()
   if (ig_button(AM_PM(ap), 0.0_real64, height)) then
      ap = 1_int32 - ap
      changed = .true.
   endif
   call ig_pop_style_color(3_int32)
   call core_pop_style_var(2_int32)
   call core_pop_id()
   if (changed) then
      hr = mod(hr, 12_int32) + ap * 12_int32
      t = mk_time(yr, mo, md, hr, mi, se)
   endif
   endfunction time_picker

   ! private: helpers

   pure function two(v) result(s)
   !< `nums[v]`: two digits.
   integer(int32), intent(in) :: v !< 0-59.
   character(len=2)           :: s !< Digits.

   write(s, '(I2.2)') v
   endfunction two

   subroutine begin_disabled(cond)
   !< `BeginDisabledControls`: the items disabled and faded (Alpha x 0.25) while `cond`.
   logical, intent(in) :: cond !< Disabled.
   real(real64)        :: v(2) !< The style's Alpha.
   integer(int32)      :: n    !< Its values.

   if (.not. cond) return
   call core_push_item_flag(int(ImGuiItemFlags_Disabled, int32), .true.)
   call core_style_var('Alpha', v, n)
   call core_push_style_var(ImGuiStyleVar_Alpha, real(real(v(1), real32) * 0.25_real32, real64))
   endsubroutine begin_disabled

   subroutine end_disabled(cond)
   !< `EndDisabledControls`.
   logical, intent(in) :: cond !< Disabled.

   if (.not. cond) return
   call core_pop_item_flag()
   call core_pop_style_var()
   endsubroutine end_disabled

   pure function week_day(t) result(wd)
   !< `tm_wday` of a UTC time: 0 Sunday (1970-01-01 a Thursday).
   type(plot_time), intent(in) :: t  !< Time.
   integer(int32)              :: wd !< Weekday.

   wd = int(modulo(t%s / 86400_int64 + 4_int64, 7_int64), int32)
   endfunction week_day

   pure function time_add_seconds(t, count) result(r)
   !< `AddTime(t, ImPlotTimeUnit_S, count)`.
   type(plot_time), intent(in) :: t     !< Time.
   integer(int64),  intent(in) :: count !< Seconds.
   type(plot_time)             :: r     !< Time.

   r = t
   r%s = r%s + count
   endfunction time_add_seconds

   pure function add_months(t, count) result(r)
   !< `AddTime(t, ImPlotTimeUnit_Mo, count)`, ImPlot's arithmetic (a month's days added, or the previous month's
   !< taken off).
   type(plot_time), intent(in) :: t     !< Time.
   integer(int32),  intent(in) :: count !< Months.
   type(plot_time)             :: r     !< Time.
   integer(int32)              :: i, yr, mo, md, hr, mi, se !< Counter, calendar.

   if (count > 0_int32) then
      r = add_time(t, TU_MO, count)
      return
   endif
   r = t
   do i = 1_int32, abs(count)
      call gm_time(r%s, yr, mo, md, hr, mi, se)
      r%s = r%s - 86400_int64 * int(days_in_month(yr - merge(1_int32, 0_int32, mo == 0_int32), &
                                                  merge(11_int32, mo - 1_int32, mo == 0_int32)), int64)
   enddo
   endfunction add_months

   pure function add_years(t, count) result(r)
   !< `AddTime(t, ImPlotTimeUnit_Yr, count)`, ImPlot's arithmetic (365 or 366 days a year).
   type(plot_time), intent(in) :: t     !< Time.
   integer(int32),  intent(in) :: count !< Years.
   type(plot_time)             :: r     !< Time.
   integer(int32)              :: i     !< Counter.

   if (count > 0_int32) then
      r = add_time(t, TU_YR, count)
      return
   endif
   r = t
   do i = 1_int32, abs(count)
      r%s = r%s - 86400_int64 * int(365_int32 + merge(1_int32, 0_int32, leap_year(time_year(r) - 1_int32)), int64)
   enddo
   endfunction add_years

   pure function combine_date_time(date_part, tod_part) result(r)
   !< `CombineDateTime`: the date of one time and the time of day of another.
   type(plot_time), intent(in) :: date_part, tod_part !< Times.
   type(plot_time)             :: r                   !< Time.
   integer(int32)              :: y, m, d, yr, mo, md, hr, mi, se !< Calendars.

   call gm_time(date_part%s, y, m, d, hr, mi, se)
   call gm_time(tod_part%s, yr, mo, md, hr, mi, se)
   r = mk_time(y, m, d, hr, mi, se)
   r%us = tod_part%us
   endfunction combine_date_time

   function state_of(plot_id, axis, rmin, rmax) result(k)
   !< An axis's picker state, made when new (the oldest replaced); its picker times reset to the range when the range
   !< differs from the one last seen.
   integer(int32), intent(in) :: plot_id, axis !< The plot's ID, the axis.
   real(real64),   intent(in) :: rmin, rmax    !< The axis's range.
   integer(int32)             :: k             !< State.
   integer(int32)             :: i             !< Counter.

   clock = clock + 1_int64
   k = 0_int32
   do i = 1_int32, NSTATE
      if (states(i)%used .and. states(i)%plot == plot_id .and. states(i)%axis == axis) then
         k = i
         exit
      endif
   enddo
   if (k == 0_int32) then
      k = 1_int32
      do i = 1_int32, NSTATE
         if (.not. states(i)%used) then
            k = i
            exit
         endif
         if (states(i)%stamp < states(k)%stamp) k = i
      enddo
      states(k)%used = .true.
      states(k)%plot = plot_id
      states(k)%axis = axis
      states(k)%level = 0_int32
      states(k)%seen_min = rmin
      states(k)%seen_max = rmax
      states(k)%pick_min = time_from_double(rmin)
      states(k)%pick_max = time_from_double(rmax)
   endif
   states(k)%stamp = clock
   if (states(k)%seen_min /= rmin .or. states(k)%seen_max /= rmax) then
      states(k)%pick_min = time_from_double(rmin)
      states(k)%pick_max = time_from_double(rmax)
      states(k)%seen_min = rmin
      states(k)%seen_max = rmax
   endif
   endfunction state_of
endmodule figure_plot_time_picker
