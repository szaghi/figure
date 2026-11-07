type :: field_t
   !< A field of values, given to the task and given back smoothed.
   real(real64), allocatable :: v(:) !< Values.
endtype field_t

contains
   recursive subroutine smooth_field(h, data)
   !< Smooth the field 200 times, reporting each pass.
   type(task_handle_object), intent(inout) :: h    !< The task's handle.
   class(*),                 intent(inout) :: data !< A field_t.
   integer                                 :: pass !< Pass.
   integer                                 :: n    !< Values.

   select type (data)
   type is (field_t)
      n = size(data%v)
      do pass = 1, 200
         if (h%cancelled()) return                         ! a safe point, between two passes
         data%v(2:n - 1) = 0.25_real64 * (data%v(1:n - 2) + 2.0_real64 * data%v(2:n - 1) + data%v(3:n))
         call h%report(real(pass, real64) / 200.0_real64, 'smoothing')
      enddo
   endselect
   endsubroutine smooth_field
