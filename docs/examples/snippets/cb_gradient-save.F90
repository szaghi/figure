subroutine save(name, file)
!< The map's stops as a CSV table of `x, r, g, b` rows, which `ip_load_colormap` reads back as the same map.
character(len=*), intent(in) :: name          !< Colormap.
character(len=*), intent(in) :: file          !< CSV file.
real(real64), allocatable    :: positions(:)  !< Stops: positions in [0, 1].
real(real64), allocatable    :: colours(:,:)  !< ... their colours, RGB in [0, 1].
integer(int32)               :: u, k          !< Unit, counter.

call ip_colormap_stops(name, positions, colours)
open(newunit=u, file=file, status='replace', action='write')
write(u, '(A)') 'x, r, g, b'
do k = 1_int32, size(positions, kind=int32)
   write(u, '(F9.6,3(", ",F9.6))') positions(k), colours(:, k)
enddo
close(u)
endsubroutine save
