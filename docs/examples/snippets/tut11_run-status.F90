if (ig_begin_side_bar('status', 'bottom', 30.0_real64)) then ! left out of the dock space, as the tools' bar
   if (solver%running()) then
      fraction = -1.0_real64                      ! indeterminate until two residuals are known
      if (size(res) > 1) fraction = min(1.0_real64, max(0.0_real64, &
                                        log(res(1) / res(size(res))) / log(res(1) / inp%tolerance)))
      call ig_progress_bar(fraction, width=200.0_real64)
      call ig_same_line()
      if (size(res) > 0) write(run_status, '(A,I0,A,ES8.2)') 'running: iteration ', nint(iters(size(iters))), &
                                                              ', residual ', res(size(res))
   endif
   call ig_text(trim(run_status))
endif
call ig_end()
