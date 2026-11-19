threshold = env_int('GOLDEN_THRESHOLD', 2_int32)  ! test_compare_image's defaults where the goldens are made
max_failed = env_int('GOLDEN_MAX_FAILED', 0_int32)
same = test_compare_image('panel.png', trim(golden), threshold=threshold, max_failed=max_failed)
if (.not. same) then
   write(output_unit, '(A)') figure_last_error() ! how many pixels failed, by how much, where
   error stop 1                                  ! panel.new.png and panel.diff.png are beside the golden
endif
