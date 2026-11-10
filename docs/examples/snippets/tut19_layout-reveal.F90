if (reveal == n) then                             ! picked from a problem: the node scrolls into view
   call ig_scroll_here()                          ! its line to the centre of the region, on the next frame
   reveal = 0_int32
endif
