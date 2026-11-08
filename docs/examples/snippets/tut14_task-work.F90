type :: field_t
   !< A field to read: the file, given to the task; the values and a coarser copy, given back.
   character(len=:), allocatable :: file              !< The solver's field.dat.
   real(real64)                  :: lx = 0.0_real64   !< The plate [m].
   real(real64)                  :: ly = 0.0_real64
   real(real64), allocatable     :: values(:,:)       !< The field, every node.
   real(real64), allocatable     :: coarse(:,:)       !< Every stride-th node, to draw.
   integer(int32)                :: stride = 1_int32  !< The coarse copy's stride.
endtype field_t

contains
   recursive subroutine read_field(h, data)
   !< Read a field.dat row by row, reporting the progress, stopping if asked; then make the coarse copy.
   type(task_handle_object), intent(inout) :: h      !< The task's handle.
   class(*),                 intent(inout) :: data   !< A field_t.
   character(len=256)                      :: iomsg  !< The run time's message.
   integer(int32)                          :: nx, ny !< The grid.
   integer(int32)                          :: j      !< Row.
   integer(int32)                          :: u      !< Unit: the task's own.
   integer(int32)                          :: ios    !< Status.

   select type (data)
   type is (field_t)
      open(newunit=u, file=data%file, status='old', action='read', iostat=ios, iomsg=iomsg)
      if (ios /= 0) then
         call h%fail(trim(iomsg))                    ! t%result gives FIG_ERR_FAILED and this message
         return
      endif
      read(u, *, iostat=ios, iomsg=iomsg)            ! the comment line
      if (ios == 0) read(u, *, iostat=ios, iomsg=iomsg) nx, ny, data%lx, data%ly
      if (ios == 0) then
         allocate(data%values(nx, ny))
         do j = 1_int32, ny
            if (h%cancelled()) exit                  ! a safe point, between two rows
            read(u, *, iostat=ios, iomsg=iomsg) data%values(:, j)
            if (ios /= 0) exit
            if (mod(j, 8_int32) == 0_int32) call h%report(real(j, real64) / ny, 'reading field.dat')
         enddo
      endif
      close(u)
      if (ios /= 0) then
         call h%fail(data%file//': '//trim(iomsg))
         return
      endif
      if (h%cancelled()) return
      data%stride = (max(nx, ny) - 1_int32) / MAX_SHOWN + 1_int32
      data%coarse = data%values(1::data%stride, 1::data%stride) ! what is drawn: at most MAX_SHOWN a side
   endselect
   endsubroutine read_field
