cmap = ip_colormap('jet', stat=stat)                ! names are case-sensitive: ImPlot's is 'Jet'
if (stat /= FIG_OK) write(output_unit, '(A)') figure_last_error()
