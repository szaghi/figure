rgba = 0_int8
rgba(4,:,:) = -1_int8                       ! alpha 255 (int8 bit pattern of 255)
rgba(1,:,1) = -1_int8                       ! row 1: red
rgba(3,:,4) = -1_int8                       ! row 4: blue
call tex%init(4_int32, 4_int32)             ! after app%init: textures live on the GPU of the window
call tex%update(rgba)                       ! one upload; redo it only when the pixels change
