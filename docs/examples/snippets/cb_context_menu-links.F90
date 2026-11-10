call ig_separator()
if (ig_text_link('What is a patch?')) help = .not. help
if (check) call test_item_center(link_at(1), link_at(2))
if (help) call ig_text_wrapped('A patch is a set of faces of the grid that share one boundary condition.')
call ig_text_link_url('Documentation', 'https://szaghi.github.io/figure/')
if (check) call test_item_center(docs_at(1), docs_at(2))
