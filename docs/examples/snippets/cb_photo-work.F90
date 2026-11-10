type :: photo_job
   !< What the task is given (the file) and gives back (the pixels, or why there are none).
   character(len=256)         :: file = ''        !< The photograph: PNG or JPEG.
   integer(int8), allocatable :: rgba(:,:,:)      !< Its pixels, rgba(4, width, height), row 1 at the top.
   integer(int32)             :: stat = -1_int32  !< Status of the read.
   character(len=256)         :: message = ''     !< Its message on a failure.
endtype photo_job

contains
   recursive subroutine read_photo(h, data)
   !< Decode the file: fig_read_image draws nothing, so a task may call it.
   type(task_handle_object), intent(inout) :: h    !< The task's handle.
   class(*),                 intent(inout) :: data !< A photo_job.

   if (h%cancelled()) return
   select type (data)
   type is (photo_job)
      call fig_read_image(trim(data%file), data%rgba, data%stat)
      if (data%stat /= FIG_OK) data%message = figure_last_error()
   endselect
   endsubroutine read_photo
