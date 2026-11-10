if (t%done()) then                          ! once: the pixels to the GPU, on the main thread
   call t%result(data)
   select type (data)
   type is (photo_job)
      if (data%stat == FIG_OK) then
         call photo%init(int(size(data%rgba, 2), int32), int(size(data%rgba, 3), int32), smooth=.true.)
         call photo%update(data%rgba)
         status = trim(data%file)
      else
         status = trim(data%message)
      endif
      job = data
      frame = 0_int32
   endselect
endif
