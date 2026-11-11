call code_diff_lines(OLD, NEW, added, removed)     ! no frame needed: a task may call it
write(summary, '(I0,A,I0,A)') size(removed), ' line(s) removed, ', size(added), ' added'
