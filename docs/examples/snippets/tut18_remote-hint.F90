if (remote) then                               ! a browser gives no paths of the server: no drops
   call ig_text_wrapped('Open one with File > Open case: the browser lists the files of the machine the '// &
                        'studio runs on.')
else
   call ig_text_wrapped('Open one with File > Open case, or drop its folder (or its heat.inp) on the window.')
endif
