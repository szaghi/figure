recursive subroutine read_field(h, data)
!< Read the field block by block: report the progress after each block, stop at a cancel.
type(task_handle_object), intent(inout) :: h          !< The task's handle.
class(*),                 intent(inout) :: data       !< A field_stats.
integer(int64), parameter               :: BLOCK = 65536_int64 !< Values per block.
real(real64)                            :: chunk(BLOCK) !< One block.
integer(int64)                          :: bytes, n, k, blocks, m !< File size, values, block, blocks, values in it.
integer                                 :: u, ios     !< Unit, I/O status.
character(len=40)                       :: msg        !< Progress message.
real(real64)                            :: total      !< Sum of the values.

select type (data)
type is (field_stats)
   open(newunit=u, file=trim(data%file), access='stream', form='unformatted', action='read', status='old', &
        iostat=ios)                                     ! a unit of its own: never shared with the main thread
   if (ios /= 0) then
      call h%fail('cannot open '//trim(data%file))
      return
   endif
   inquire(unit=u, size=bytes)
   n = bytes / 8_int64
   blocks = (n + BLOCK - 1_int64) / BLOCK
   total = 0.0_real64
   do k = 1_int64, blocks
      if (h%cancelled()) exit                           ! a safe point: the statistics so far are consistent
      m = min(BLOCK, n - (k - 1_int64) * BLOCK)
      read(u, iostat=ios) chunk(1:m)
      if (ios /= 0) then
         call h%fail('cannot read '//trim(data%file))
         exit
      endif
      data%values = data%values + m
      data%vmin = min(data%vmin, minval(chunk(1:m)))
      data%vmax = max(data%vmax, maxval(chunk(1:m)))
      total = total + sum(chunk(1:m))
      write(msg, '(A,I0,A,I0)') 'block ', k, ' of ', blocks
      call h%report(real(k, real64) / real(blocks, real64), trim(msg))
      call slow_disk()
   enddo
   close(u)
   if (data%values > 0_int64) data%mean = total / real(data%values, real64)
endselect
endsubroutine read_field
