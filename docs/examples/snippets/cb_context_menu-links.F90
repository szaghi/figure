call ig_separator()
if (ig_text_link('What is a patch?')) help = .not. help
if (help) call ig_text_wrapped('A patch is a set of faces of the grid that share one boundary condition.')
call ig_text_link_url('Documentation', 'https://szaghi.github.io/figure/')
