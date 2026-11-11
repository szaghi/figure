call source%init(code_language('fortran'))       ! a namelist is Fortran: names, strings, numbers, ! comments
call source%set_completions(NAMES)                ! typing "tol" offers "tolerance"
call help%init()                                  ! a table of contents and a find bar
call help%set_text(help_text())
