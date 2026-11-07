open(newunit=u, file='ocean.csv', status='replace', action='write') ! a user map: r, g, b rows in [0, 255]
write(u, '(A)') '# deep to shallow', '8,29,88', '37,52,148', '34,94,168', '29,145,192', '65,182,196', '161,218,180'
close(u)
call ip_load_colormap('ocean', 'ocean.csv', stat=stat)
if (stat /= FIG_OK) write(output_unit, '(A)') figure_last_error()
