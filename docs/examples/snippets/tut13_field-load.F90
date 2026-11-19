open(newunit=u, file=case_dir//'/field.dat', status='old', action='read', iostat=ios)
if (ios /= 0) return                              ! not run yet
read(u, *, iostat=ios)                            ! the comment line
read(u, *, iostat=ios) nx, ny, flx, fly
if (ios == 0) then
   deallocate(field)
   allocate(field(nx, ny))
   read(u, *, iostat=ios) field                   ! row after row: field(:, 1), field(:, 2), ...
endif
close(u)
if (ios /= 0) then
   deallocate(field)
   allocate(field(0, 0))
   call app%notify('field.dat does not read', kind='error')
   return
endif
