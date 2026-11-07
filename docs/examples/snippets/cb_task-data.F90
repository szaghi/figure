type :: field_stats
   !< What the task is given (the file) and what it gives back (the statistics).
   character(len=256) :: file = ''                 !< The field's file: real64 values, stream access.
   integer(int64)     :: values = 0_int64          !< Values read.
   real(real64)       :: vmin = huge(1.0_real64)   !< Smallest value.
   real(real64)       :: vmax = -huge(1.0_real64)  !< Largest value.
   real(real64)       :: mean = 0.0_real64         !< Mean value.
endtype field_stats
