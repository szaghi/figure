if (ip_begin_plot("ip_histogram")) then
   call ip_histogram('samples', g, bins=30_int32)
   call ip_end_plot()
endif
if (ip_begin_plot("ip_histogram2d")) then
   call ip_histogram2d('pairs', g, g2, xbins=40_int32, ybins=40_int32)
   call ip_end_plot()
endif
