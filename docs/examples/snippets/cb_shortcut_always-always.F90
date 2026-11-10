if (ig_shortcut('ctrl+p', scope='always')) then ! fires here and in Plot, a text field edited or not
   paused = .not. paused
   call did('Run: '//merge('paused ', 'resumed', paused))
endif
