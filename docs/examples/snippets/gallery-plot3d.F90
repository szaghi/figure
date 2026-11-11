px = cos(s) * exp(-0.12_real64 * s)                   ! a particle spiralling in as it rises
py = sin(s) * exp(-0.12_real64 * s)
pz = 0.1_real64 * s
probes = reshape([0.8_real64, 0.0_real64, 0.2_real64,  -0.3_real64, 0.5_real64, 0.5_real64, &
                  0.1_real64, -0.2_real64, 0.9_real64], [3, 3])
call ig_set_next_window(10.0_real64, 10.0_real64, 1180.0_real64, 440.0_real64)
if (ig_begin('3-D plots')) then
   w = 380.0_real64
   if (ip3_begin_plot('ip3_line, ip3_scatter, ip3_text', width=w, height=-1.0_real64)) then
      call ip3_setup_axes('x [m]', 'y [m]', 'z [m]', elevation=20.0_real64, azimuth=-50.0_real64)
      call ip3_line('particle', px, py, pz, spec=ip3_spec(line_color=RED, line_weight=2.0_real64))
      call ip3_scatter('probes', probes(1, :), probes(2, :), probes(3, :), &          ! rows: read in place
                       spec=ip3_spec(marker=ImPlot3DMarker_Diamond, marker_size=5.0_real64))
      call ip3_text('release', px(1), py(1), pz(1), offset=[0.0_real64, -14.0_real64])
      call ip3_end_plot()
   endif
