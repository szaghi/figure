call app%switch_layout('Input')                            ! as View/Input does; as the user left it: not built again
call draw(60_int32)
write(output_unit, '(A)') 'layout: '//app%layout()
call app%reset_layout()                                    ! as View/Reset layout does
call draw(60_int32)
