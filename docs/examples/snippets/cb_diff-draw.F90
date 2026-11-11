call ig_text(trim(summary))
call ig_separator()
call code_diff('diff', OLD, NEW, side_by_side=.true., language=input)
