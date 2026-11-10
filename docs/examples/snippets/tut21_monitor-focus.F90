if (show_result .and. .not. laid_out .and. .not. ig_any_item_active()) then ! not while the user types or drags
   show_result = .not. ig_focus_window('Result')          ! a result read comes forward (not while a popup is open)
endif
