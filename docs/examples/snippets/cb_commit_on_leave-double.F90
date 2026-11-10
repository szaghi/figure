if (ig_selectable(trim(cases(k)), k == sel)) sel = k
s = ig_last_item()
if (s%double_clicked(1)) call open_case(k)          ! a double click opens the row
