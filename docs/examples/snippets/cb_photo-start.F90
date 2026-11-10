call t%start(read_photo, photo_job(file=arg))  ! the window draws while the file is decoded
status = 'reading '//trim(arg)//' ...'
