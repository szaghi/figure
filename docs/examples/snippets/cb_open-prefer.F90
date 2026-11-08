call ig_same_line()
if (ig_button('Open with FIGURE''s browser...')) call app%open_file_dialog('open', FILTERS, prefer='figure')
