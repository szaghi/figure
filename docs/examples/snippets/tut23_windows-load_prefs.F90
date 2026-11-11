do k = MAX_RECENT, 1_int32, -1_int32              ! the oldest first: add_recent puts each in front
   write(key, '(A,I0)') 'recent.', k
   if (app%load_pref(trim(key), dir)) call add_recent(trim(dir))
enddo
if (app%load_pref('larger text', large_text)) call set_text_size()
