if (figure_last_error() /= last_report) call app%notify(figure_last_error(), kind='error', seconds=0.0_real64)
last_report = figure_last_error()                 ! one line per error, naming the Fortran calls
