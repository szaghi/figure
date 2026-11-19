do while (app%next_frame(stat=stat))                 ! with stat: a usage error is reported, the studio goes on
   if (stat /= FIG_OK) call report_usage()
   call draw_studio()
enddo
