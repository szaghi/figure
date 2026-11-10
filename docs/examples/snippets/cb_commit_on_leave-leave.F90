if (ig_input_text('CFL', cfl_text)) continue           ! the text changes on every key
s = ig_last_item()
if (s%deactivated_after_edit) call commit_cfl()         ! once, when the user leaves the field
