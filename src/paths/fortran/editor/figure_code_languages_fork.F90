!< figure_code_languages_fork, ImGuiColorTextEdit's languages: definitions and re2c tokenizers (generated: do not edit).
module figure_code_languages_fork
!< figure_code_languages_fork, ImGuiColorTextEdit's languages: definitions and re2c tokenizers (generated: do not edit).
!<
!< Written by scripts/gen_editor_languages.py from third_party/ImGuiColorTextEdit/languages/ (szaghi/figure#15
!< P16): the re2c state machines as Fortran functions of the same states (a code point past the line's end is 0, as
!< re2c's `i < end ? *i : 0`), and `fork_data`, each language's comments, strings, flags and keyword sets as
!< figure_code_language reads them.
use, intrinsic :: iso_fortran_env, only : int8, int32

implicit none
private
public :: c_number, cs_number, python_number, lua_number, lua_comment_start, lua_comment_end, lua_string_start, &
          lua_string_end, json_token, markdown_token
public :: fork_data, C_PUNCTUATION, JULIA_PUNCTUATION

!< the C languages' ASCII punctuation (TextEditorC::isPunctuation).
logical, parameter :: C_PUNCTUATION(0:127) = [.false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .true., .false., .false., .false., .true., .true., .false., .true., .true., .true., .true., &
   .true., .true., .true., .true., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .true., .true., .true., .true., .true., .true., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .true., .false., .true., &
   .true., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .true., .true., .true., .true., .false.]

!< Julia's ASCII punctuation (TextEditorJulia::isPunctuation).
logical, parameter :: JULIA_PUNCTUATION(0:127) = [.false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .true., .false., .false., .true., .true., .true., .true., .true., .true., .true., .true., &
   .true., .true., .true., .true., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .true., .true., .true., .true., .true., .true., .true., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .true., .true., .true., .true., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., .false., &
   .false., .false., .false., .false., .true., .true., .true., .true., .false.]


contains
   function c_number(cp, s, e) result(t)
   !< `TextEditorC::getNumber` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1003
   case (48_int32)
      go to 1004
   case (49_int32:57_int32)
      go to 1006
   case default
      if (i >= e) go to 1082
      go to 1001
   endselect
1001 continue
   i = i + 1_int32
1002 continue
   t = s
   return
1003 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1008
   case default
      go to 1002
   endselect
1004 continue
   yyaccept = 0_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (0_int32)
      go to 1005
   case (66_int32, 98_int32)
      go to 1016
   case (88_int32, 120_int32)
      go to 1020
   case default
      go to 1013
   endselect
1005 continue
   t = i
   return
1006 continue
   yyaccept = 1_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1010
   case (48_int32:57_int32)
      go to 1006
   case (69_int32, 101_int32)
      go to 1017
   case (76_int32)
      go to 1022
   case (85_int32, 117_int32)
      go to 1023
   case (108_int32)
      go to 1024
   case default
      go to 1007
   endselect
1007 continue
   t = i
   return
1008 continue
   yyaccept = 2_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1008
   case (69_int32, 101_int32)
      go to 1025
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1026
   case default
      go to 1009
   endselect
1009 continue
   t = i
   return
1010 continue
   yyaccept = 3_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1008
   case (69_int32, 101_int32)
      go to 1027
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1028
   case default
      go to 1011
   endselect
1011 continue
   t = i
   return
1012 continue
   yyaccept = 0_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
1013 continue
   select case (yych)
   case (46_int32)
      go to 1010
   case (48_int32:55_int32)
      go to 1012
   case (56_int32:57_int32)
      go to 1014
   case (69_int32, 101_int32)
      go to 1017
   case (76_int32)
      go to 1018
   case (85_int32, 117_int32)
      go to 1019
   case (108_int32)
      go to 1021
   case default
      go to 1005
   endselect
1014 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1010
   case (48_int32:57_int32)
      go to 1014
   case (69_int32, 101_int32)
      go to 1017
   case default
      go to 1015
   endselect
1015 continue
   i = marker
   select case (yyaccept)
   case (0_int32)
      go to 1005
   case (1_int32)
      go to 1007
   case (2_int32)
      go to 1009
   case (3_int32)
      go to 1011
   case default
      go to 1040
   endselect
1016 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:49_int32)
      go to 1029
   case default
      go to 1015
   endselect
1017 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1031
   case (48_int32:57_int32)
      go to 1032
   case default
      go to 1015
   endselect
1018 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1034
   case (85_int32, 117_int32)
      go to 1035
   case default
      go to 1005
   endselect
1019 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1036
   case (108_int32)
      go to 1037
   case default
      go to 1005
   endselect
1020 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1038
   case (48_int32:57_int32, 65_int32:70_int32, 97_int32:102_int32)
      go to 1039
   case default
      go to 1015
   endselect
1021 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1035
   case (108_int32)
      go to 1034
   case default
      go to 1005
   endselect
1022 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1041
   case (85_int32, 117_int32)
      go to 1042
   case default
      go to 1007
   endselect
1023 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1043
   case (108_int32)
      go to 1044
   case default
      go to 1007
   endselect
1024 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1042
   case (108_int32)
      go to 1041
   case default
      go to 1007
   endselect
1025 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1045
   case (48_int32:57_int32)
      go to 1046
   case default
      go to 1015
   endselect
1026 continue
   i = i + 1_int32
   go to 1009
1027 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1047
   case (48_int32:57_int32)
      go to 1048
   case default
      go to 1015
   endselect
1028 continue
   i = i + 1_int32
   go to 1011
1029 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:49_int32)
      go to 1029
   case (76_int32)
      go to 1049
   case (85_int32, 117_int32)
      go to 1050
   case (108_int32)
      go to 1051
   case default
      go to 1030
   endselect
1030 continue
   t = i
   return
1031 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1032
   case default
      go to 1015
   endselect
1032 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1032
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1052
   case default
      go to 1033
   endselect
1033 continue
   t = i
   return
1034 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1035
   case default
      go to 1005
   endselect
1035 continue
   i = i + 1_int32
   go to 1005
1036 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1035
   case default
      go to 1005
   endselect
1037 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1035
   case default
      go to 1005
   endselect
1038 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (0_int32, 80_int32, 112_int32)
      go to 1015
   case default
      go to 1054
   endselect
1039 continue
   yyaccept = 4_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1055
   case (48_int32:57_int32, 65_int32:70_int32, 97_int32:102_int32)
      go to 1039
   case (76_int32)
      go to 1056
   case (80_int32, 112_int32)
      go to 1057
   case (85_int32, 117_int32)
      go to 1058
   case (108_int32)
      go to 1059
   case default
      go to 1040
   endselect
1040 continue
   t = i
   return
1041 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1042
   case default
      go to 1007
   endselect
1042 continue
   i = i + 1_int32
   go to 1007
1043 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1042
   case default
      go to 1007
   endselect
1044 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1042
   case default
      go to 1007
   endselect
1045 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1046
   case default
      go to 1015
   endselect
1046 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1046
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1026
   case default
      go to 1009
   endselect
1047 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1048
   case default
      go to 1015
   endselect
1048 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1048
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1028
   case default
      go to 1011
   endselect
1049 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1060
   case (85_int32, 117_int32)
      go to 1061
   case default
      go to 1030
   endselect
1050 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1062
   case (108_int32)
      go to 1063
   case default
      go to 1030
   endselect
1051 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1061
   case (108_int32)
      go to 1060
   case default
      go to 1030
   endselect
1052 continue
   i = i + 1_int32
   go to 1033
1053 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
1054 continue
   select case (yych)
   case (48_int32:57_int32, 65_int32:70_int32, 97_int32:102_int32)
      go to 1053
   case (80_int32, 112_int32)
      go to 1064
   case default
      go to 1015
   endselect
1055 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (0_int32)
      go to 1015
   case (80_int32, 112_int32)
      go to 1065
   case default
      go to 1054
   endselect
1056 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1066
   case (85_int32, 117_int32)
      go to 1067
   case default
      go to 1040
   endselect
1057 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1068
   case (48_int32:57_int32)
      go to 1069
   case default
      go to 1015
   endselect
1058 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1071
   case (108_int32)
      go to 1072
   case default
      go to 1040
   endselect
1059 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1067
   case (108_int32)
      go to 1066
   case default
      go to 1040
   endselect
1060 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1061
   case default
      go to 1030
   endselect
1061 continue
   i = i + 1_int32
   go to 1030
1062 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1061
   case default
      go to 1030
   endselect
1063 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1061
   case default
      go to 1030
   endselect
1064 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1073
   case (48_int32:57_int32)
      go to 1074
   case default
      go to 1015
   endselect
1065 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1076
   case (48_int32:57_int32)
      go to 1077
   case default
      go to 1015
   endselect
1066 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1067
   case default
      go to 1040
   endselect
1067 continue
   i = i + 1_int32
   go to 1040
1068 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1069
   case default
      go to 1015
   endselect
1069 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1069
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1079
   case default
      go to 1070
   endselect
1070 continue
   t = i
   return
1071 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1067
   case default
      go to 1040
   endselect
1072 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1067
   case default
      go to 1040
   endselect
1073 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1074
   case default
      go to 1015
   endselect
1074 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1074
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1080
   case default
      go to 1075
   endselect
1075 continue
   t = i
   return
1076 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1077
   case default
      go to 1015
   endselect
1077 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1077
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1081
   case default
      go to 1078
   endselect
1078 continue
   t = i
   return
1079 continue
   i = i + 1_int32
   go to 1070
1080 continue
   i = i + 1_int32
   go to 1075
1081 continue
   i = i + 1_int32
   go to 1078
1082 continue
   t = s
   return
   endfunction c_number

   function cs_number(cp, s, e) result(t)
   !< `TextEditorCs::getNumber` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1003
   case (48_int32)
      go to 1004
   case (49_int32:57_int32)
      go to 1006
   case default
      if (i >= e) go to 1049
      go to 1001
   endselect
1001 continue
   i = i + 1_int32
1002 continue
   t = s
   return
1003 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1008
   case default
      go to 1002
   endselect
1004 continue
   yyaccept = 0_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (0_int32)
      go to 1005
   case (66_int32, 98_int32)
      go to 1012
   case (88_int32, 120_int32)
      go to 1015
   case default
      go to 1007
   endselect
1005 continue
   t = i
   return
1006 continue
   yyaccept = 0_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
1007 continue
   select case (yych)
   case (46_int32)
      go to 1010
   case (48_int32:57_int32, 95_int32)
      go to 1006
   case (76_int32)
      go to 1013
   case (85_int32, 117_int32)
      go to 1014
   case (108_int32)
      go to 1016
   case default
      go to 1005
   endselect
1008 continue
   yyaccept = 1_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 95_int32)
      go to 1008
   case (69_int32, 101_int32)
      go to 1017
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1018
   case default
      go to 1009
   endselect
1009 continue
   t = i
   return
1010 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1019
   case default
      go to 1011
   endselect
1011 continue
   i = marker
   select case (yyaccept)
   case (0_int32)
      go to 1005
   case (1_int32)
      go to 1009
   case default
      go to 1020
   endselect
1012 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:49_int32)
      go to 1021
   case default
      go to 1011
   endselect
1013 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1023
   case (85_int32, 117_int32)
      go to 1024
   case default
      go to 1005
   endselect
1014 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1025
   case (108_int32)
      go to 1026
   case default
      go to 1005
   endselect
1015 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 65_int32:70_int32, 97_int32:102_int32)
      go to 1027
   case default
      go to 1011
   endselect
1016 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1024
   case (108_int32)
      go to 1023
   case default
      go to 1005
   endselect
1017 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1029
   case (48_int32:57_int32, 95_int32)
      go to 1030
   case default
      go to 1011
   endselect
1018 continue
   i = i + 1_int32
   go to 1009
1019 continue
   yyaccept = 2_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 95_int32)
      go to 1019
   case (69_int32, 101_int32)
      go to 1031
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1032
   case default
      go to 1020
   endselect
1020 continue
   t = i
   return
1021 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:49_int32, 95_int32)
      go to 1021
   case (76_int32)
      go to 1033
   case (85_int32, 117_int32)
      go to 1034
   case (108_int32)
      go to 1035
   case default
      go to 1022
   endselect
1022 continue
   t = i
   return
1023 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1024
   case default
      go to 1005
   endselect
1024 continue
   i = i + 1_int32
   go to 1005
1025 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1024
   case default
      go to 1005
   endselect
1026 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1024
   case default
      go to 1005
   endselect
1027 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 65_int32:70_int32, 95_int32, 97_int32:102_int32)
      go to 1027
   case (76_int32)
      go to 1036
   case (85_int32, 117_int32)
      go to 1037
   case (108_int32)
      go to 1038
   case default
      go to 1028
   endselect
1028 continue
   t = i
   return
1029 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 95_int32)
      go to 1030
   case default
      go to 1011
   endselect
1030 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 95_int32)
      go to 1030
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1018
   case default
      go to 1009
   endselect
1031 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1039
   case (48_int32:57_int32, 95_int32)
      go to 1040
   case default
      go to 1011
   endselect
1032 continue
   i = i + 1_int32
   go to 1020
1033 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1041
   case (85_int32, 117_int32)
      go to 1042
   case default
      go to 1022
   endselect
1034 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1043
   case (108_int32)
      go to 1044
   case default
      go to 1022
   endselect
1035 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1042
   case (108_int32)
      go to 1041
   case default
      go to 1022
   endselect
1036 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1045
   case (85_int32, 117_int32)
      go to 1046
   case default
      go to 1028
   endselect
1037 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1047
   case (108_int32)
      go to 1048
   case default
      go to 1028
   endselect
1038 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1046
   case (108_int32)
      go to 1045
   case default
      go to 1028
   endselect
1039 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 95_int32)
      go to 1040
   case default
      go to 1011
   endselect
1040 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 95_int32)
      go to 1040
   case (70_int32, 76_int32, 102_int32, 108_int32)
      go to 1032
   case default
      go to 1020
   endselect
1041 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1042
   case default
      go to 1022
   endselect
1042 continue
   i = i + 1_int32
   go to 1022
1043 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1042
   case default
      go to 1022
   endselect
1044 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1042
   case default
      go to 1022
   endselect
1045 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (85_int32, 117_int32)
      go to 1046
   case default
      go to 1028
   endselect
1046 continue
   i = i + 1_int32
   go to 1028
1047 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (76_int32)
      go to 1046
   case default
      go to 1028
   endselect
1048 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1046
   case default
      go to 1028
   endselect
1049 continue
   t = s
   return
   endfunction cs_number

   function python_number(cp, s, e) result(t)
   !< `TextEditorPython::getNumber` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32)
      go to 1002
   case (49_int32:57_int32)
      go to 1004
   case default
      if (i >= e) go to 1018
      go to 1001
   endselect
1001 continue
   i = i + 1_int32
   t = s
   return
1002 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (0_int32)
      go to 1003
   case (66_int32, 98_int32)
      go to 1009
   case (79_int32, 111_int32)
      go to 1011
   case (88_int32, 120_int32)
      go to 1012
   case default
      go to 1005
   endselect
1003 continue
   t = i
   return
1004 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
1005 continue
   select case (yych)
   case (43_int32, 45_int32, 69_int32, 101_int32)
      go to 1006
   case (46_int32)
      go to 1008
   case (48_int32:57_int32, 95_int32)
      go to 1004
   case (74_int32, 106_int32)
      go to 1010
   case default
      go to 1003
   endselect
1006 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1013
   case default
      go to 1007
   endselect
1007 continue
   i = marker
   go to 1003
1008 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1014
   case default
      go to 1007
   endselect
1009 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:49_int32, 95_int32)
      go to 1015
   case default
      go to 1007
   endselect
1010 continue
   i = i + 1_int32
   go to 1003
1011 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:55_int32, 95_int32)
      go to 1016
   case default
      go to 1007
   endselect
1012 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 65_int32:70_int32, 95_int32, 97_int32:102_int32)
      go to 1017
   case default
      go to 1007
   endselect
1013 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 95_int32)
      go to 1013
   case (74_int32, 106_int32)
      go to 1010
   case default
      go to 1003
   endselect
1014 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32, 69_int32, 101_int32)
      go to 1006
   case (48_int32:57_int32, 95_int32)
      go to 1014
   case (74_int32, 106_int32)
      go to 1010
   case default
      go to 1003
   endselect
1015 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:49_int32, 95_int32)
      go to 1015
   case default
      go to 1003
   endselect
1016 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:55_int32, 95_int32)
      go to 1016
   case default
      go to 1003
   endselect
1017 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 65_int32:70_int32, 95_int32, 97_int32:102_int32)
      go to 1017
   case default
      go to 1003
   endselect
1018 continue
   t = s
   return
   endfunction python_number

   function lua_number(cp, s, e) result(t)
   !< `TextEditorLua::getNumber` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1004
   case (48_int32)
      go to 1005
   case (49_int32:57_int32)
      go to 1006
   case default
      if (i >= e) go to 1001
      go to 1002
   endselect
1001 continue
   t = i
   return
1002 continue
   i = i + 1_int32
1003 continue
   t = s
   return
1004 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1008
   case default
      go to 1003
   endselect
1005 continue
   yyaccept = 0_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (0_int32)
      go to 1001
   case (88_int32, 120_int32)
      go to 1010
   case default
      go to 1007
   endselect
1006 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
1007 continue
   select case (yych)
   case (46_int32)
      go to 1008
   case (48_int32:57_int32)
      go to 1006
   case default
      go to 1001
   endselect
1008 continue
   yyaccept = 1_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1008
   case (69_int32, 101_int32)
      go to 1012
   case default
      go to 1009
   endselect
1009 continue
   t = i
   return
1010 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 65_int32:70_int32, 97_int32:102_int32)
      go to 1013
   case default
      go to 1011
   endselect
1011 continue
   i = marker
   if (yyaccept == 0_int32) go to 1001
   go to 1009
1012 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1015
   case (48_int32:57_int32)
      go to 1016
   case default
      go to 1011
   endselect
1013 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1017
   case (48_int32:57_int32, 65_int32:70_int32, 97_int32:102_int32)
      go to 1013
   case (80_int32, 112_int32)
      go to 1018
   case default
      go to 1014
   endselect
1014 continue
   t = i
   return
1015 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1016
   case default
      go to 1011
   endselect
1016 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1016
   case default
      go to 1009
   endselect
1017 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32, 65_int32:70_int32, 97_int32:102_int32)
      go to 1017
   case (80_int32, 112_int32)
      go to 1018
   case default
      go to 1014
   endselect
1018 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (0_int32)
      go to 1014
   case (43_int32, 45_int32)
      go to 1019
   case default
      go to 1020
   endselect
1019 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
1020 continue
   select case (yych)
   case (48_int32:57_int32, 65_int32:70_int32, 97_int32:102_int32)
      go to 1019
   case default
      go to 1014
   endselect
   endfunction lua_number

   function lua_comment_start(cp, s, e, level) result(t)
   !< `TextEditorLua::commentLevelStart` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int32), intent(out)   :: level !< The bracket's level.
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   level = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (45_int32)
      go to 1024
   case default
      if (i >= e) go to 1029
      go to 1022
   endselect
1022 continue
   i = i + 1_int32
1023 continue
   t = s
   return
1024 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (45_int32)
      go to 1025
   case default
      go to 1023
   endselect
1025 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (91_int32)
      go to 1027
   case default
      go to 1026
   endselect
1026 continue
   i = marker
   go to 1023
1027 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (61_int32)
      go to 1027
   case (91_int32)
      go to 1028
   case default
      go to 1026
   endselect
1028 continue
   i = i + 1_int32
   level = i - s - 4_int32
   t = i
   return
1029 continue
   t = s
   return
   endfunction lua_comment_start

   function lua_comment_end(cp, s, e, level) result(t)
   !< `TextEditorLua::commentLevelEnd` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int32), intent(out)   :: level !< The bracket's level.
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   level = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (93_int32)
      go to 1033
   case default
      if (i >= e) go to 1037
      go to 1031
   endselect
1031 continue
   i = i + 1_int32
1032 continue
   t = s
   return
1033 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (61_int32)
      go to 1034
   case (93_int32)
      go to 1036
   case default
      go to 1032
   endselect
1034 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (61_int32)
      go to 1034
   case (93_int32)
      go to 1036
   case default
      go to 1035
   endselect
1035 continue
   i = marker
   go to 1032
1036 continue
   i = i + 1_int32
   level = i - s - 2_int32
   t = i
   return
1037 continue
   t = s
   return
   endfunction lua_comment_end

   function lua_string_start(cp, s, e, level) result(t)
   !< `TextEditorLua::stringLevelStart` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int32), intent(out)   :: level !< The bracket's level.
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   level = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (91_int32)
      go to 1041
   case default
      if (i >= e) go to 1045
      go to 1039
   endselect
1039 continue
   i = i + 1_int32
1040 continue
   t = s
   return
1041 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (61_int32)
      go to 1042
   case (91_int32)
      go to 1044
   case default
      go to 1040
   endselect
1042 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (61_int32)
      go to 1042
   case (91_int32)
      go to 1044
   case default
      go to 1043
   endselect
1043 continue
   i = marker
   go to 1040
1044 continue
   i = i + 1_int32
   level = i - s - 2_int32
   t = i
   return
1045 continue
   t = s
   return
   endfunction lua_string_start

   function lua_string_end(cp, s, e, level) result(t)
   !< `TextEditorLua::stringLevelEnd` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int32), intent(out)   :: level !< The bracket's level.
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   level = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (93_int32)
      go to 1049
   case default
      if (i >= e) go to 1053
      go to 1047
   endselect
1047 continue
   i = i + 1_int32
1048 continue
   t = s
   return
1049 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (61_int32)
      go to 1050
   case (93_int32)
      go to 1052
   case default
      go to 1048
   endselect
1050 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (61_int32)
      go to 1050
   case (93_int32)
      go to 1052
   case default
      go to 1051
   endselect
1051 continue
   i = marker
   go to 1048
1052 continue
   i = i + 1_int32
   level = i - s - 2_int32
   t = i
   return
1053 continue
   t = s
   return
   endfunction lua_string_end

   function json_token(cp, s, e, color) result(t)
   !< `TextEditorJson::tokenize` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int8),  intent(inout) :: color !< The token's colour.
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (34_int32)
      go to 1003
   case (44_int32, 91_int32, 93_int32, 123_int32, 125_int32)
      go to 1004
   case (45_int32)
      go to 1005
   case (48_int32)
      go to 1006
   case (49_int32:57_int32)
      go to 1008
   case (102_int32)
      go to 1009
   case (110_int32)
      go to 1010
   case (116_int32)
      go to 1011
   case default
      if (i >= e) go to 1031
      go to 1001
   endselect
1001 continue
   i = i + 1_int32
1002 continue
   t = s
   return
1003 continue
   yyaccept = 0_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   if (yych <= 0_int32) then
      if (i >= e) go to 1002
      go to 1012
   endif
   go to 1013
1004 continue
   i = i + 1_int32
   color = 5_int8
   t = i
   return
1005 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32)
      go to 1006
   case (49_int32:57_int32)
      go to 1008
   case default
      go to 1002
   endselect
1006 continue
   yyaccept = 1_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1016
   case (69_int32, 101_int32)
      go to 1018
   case default
      go to 1007
   endselect
1007 continue
   color = 3_int8
   t = i
   return
1008 continue
   yyaccept = 1_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1016
   case (48_int32:57_int32)
      go to 1008
   case (69_int32, 101_int32)
      go to 1018
   case default
      go to 1007
   endselect
1009 continue
   yyaccept = 0_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (97_int32)
      go to 1019
   case default
      go to 1002
   endselect
1010 continue
   yyaccept = 0_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (117_int32)
      go to 1020
   case default
      go to 1002
   endselect
1011 continue
   yyaccept = 0_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (114_int32)
      go to 1021
   case default
      go to 1002
   endselect
1012 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
1013 continue
   select case (yych)
   case (34_int32)
      go to 1014
   case default
      if (i >= e) go to 1017
      go to 1012
   endselect
1014 continue
   yyaccept = 2_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (8_int32:9_int32, 11_int32:12_int32, 32_int32)
      go to 1022
   case (58_int32)
      go to 1023
   case default
      go to 1015
   endselect
1015 continue
   color = 4_int8
   t = i
   return
1016 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1024
   case default
      go to 1017
   endselect
1017 continue
   i = marker
   select case (yyaccept)
   case (0_int32)
      go to 1002
   case (1_int32)
      go to 1007
   case default
      go to 1015
   endselect
1018 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (43_int32, 45_int32)
      go to 1025
   case (48_int32:57_int32)
      go to 1026
   case default
      go to 1017
   endselect
1019 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1027
   case default
      go to 1017
   endselect
1020 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1028
   case default
      go to 1017
   endselect
1021 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (117_int32)
      go to 1029
   case default
      go to 1017
   endselect
1022 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (8_int32:9_int32, 11_int32:12_int32, 32_int32)
      go to 1022
   case (58_int32)
      go to 1023
   case default
      go to 1017
   endselect
1023 continue
   i = i + 1_int32
   color = 7_int8
   t = i
   return
1024 continue
   yyaccept = 1_int32
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1024
   case (69_int32, 101_int32)
      go to 1018
   case default
      go to 1007
   endselect
1025 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1026
   case default
      go to 1017
   endselect
1026 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (48_int32:57_int32)
      go to 1026
   case default
      go to 1007
   endselect
1027 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (115_int32)
      go to 1029
   case default
      go to 1017
   endselect
1028 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (108_int32)
      go to 1030
   case default
      go to 1017
   endselect
1029 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (101_int32)
      go to 1030
   case default
      go to 1017
   endselect
1030 continue
   i = i + 1_int32
   color = 8_int8
   t = i
   return
1031 continue
   t = s
   return
   endfunction json_token

   function markdown_token(cp, s, e, color) result(t)
   !< `TextEditorMarkdown::tokenize` (re2c's state machine, translated): the end of the token from glyph `s` (`s`: none).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end (past the line's last glyph).
   integer(int8),  intent(inout) :: color !< The token's colour.
   integer(int32)                :: t     !< End of the token.
   integer(int32)                :: i, marker, yych, yyaccept !< re2c's state.

   i = s
   marker = s
   yyaccept = 0_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (33_int32)
      go to 1003
   case (35_int32)
      go to 1004
   case (42_int32)
      go to 1006
   case (43_int32)
      go to 1007
   case (45_int32)
      go to 1008
   case (48_int32:57_int32)
      go to 1010
   case (58_int32, 124_int32)
      go to 1011
   case (60_int32)
      go to 1012
   case (91_int32)
      go to 1013
   case (96_int32)
      go to 1014
   case (126_int32)
      go to 1015
   case default
      if (i >= e) go to 1037
      go to 1001
   endselect
1001 continue
   i = i + 1_int32
1002 continue
   t = s
   return
1003 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (91_int32)
      go to 1016
   case default
      go to 1002
   endselect
1004 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (10_int32)
      go to 1005
   case default
      if (i >= e) go to 1005
      go to 1004
   endselect
1005 continue
   color = 2_int8
   t = i
   return
1006 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (32_int32)
      go to 1011
   case (42_int32)
      go to 1020
   case default
      if (i >= e) go to 1002
      go to 1018
   endselect
1007 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (32_int32)
      go to 1011
   case default
      go to 1002
   endselect
1008 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (32_int32)
      go to 1011
   case default
      go to 1009
   endselect
1009 continue
   color = 5_int8
   t = i
   return
1010 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1021
   case (48_int32:57_int32)
      go to 1022
   case default
      go to 1002
   endselect
1011 continue
   i = i + 1_int32
   go to 1009
1012 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (65_int32:90_int32, 97_int32:122_int32)
      go to 1023
   case default
      go to 1002
   endselect
1013 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   if (yych <= 0_int32) then
      if (i >= e) go to 1002
      go to 1016
   endif
   go to 1017
1014 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   if (yych <= 0_int32) then
      if (i >= e) go to 1002
      go to 1025
   endif
   go to 1026
1015 continue
   i = i + 1_int32
   marker = i
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (126_int32)
      go to 1028
   case default
      go to 1002
   endselect
1016 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
1017 continue
   select case (yych)
   case (93_int32)
      go to 1024
   case default
      if (i >= e) go to 1019
      go to 1016
   endselect
1018 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (32_int32)
      go to 1019
   case (42_int32)
      go to 1029
   case default
      if (i >= e) go to 1019
      go to 1018
   endselect
1019 continue
   i = marker
   go to 1002
1020 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (42_int32)
      go to 1019
   case default
      if (i >= e) go to 1019
      go to 1030
   endselect
1021 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (32_int32)
      go to 1011
   case default
      go to 1019
   endselect
1022 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (46_int32)
      go to 1021
   case (48_int32:57_int32)
      go to 1022
   case default
      go to 1019
   endselect
1023 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (62_int32)
      go to 1031
   case (65_int32:90_int32, 97_int32:122_int32)
      go to 1023
   case default
      go to 1019
   endselect
1024 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (40_int32)
      go to 1032
   case default
      go to 1019
   endselect
1025 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
1026 continue
   select case (yych)
   case (96_int32)
      go to 1027
   case default
      if (i >= e) go to 1019
      go to 1025
   endselect
1027 continue
   i = i + 1_int32
   color = 4_int8
   t = i
   return
1028 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (126_int32)
      go to 1019
   case default
      if (i >= e) go to 1019
      go to 1033
   endselect
1029 continue
   i = i + 1_int32
   color = 3_int8
   t = i
   return
1030 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (42_int32)
      go to 1034
   case default
      if (i >= e) go to 1019
      go to 1030
   endselect
1031 continue
   i = i + 1_int32
   color = 1_int8
   t = i
   return
1032 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (41_int32)
      go to 1035
   case default
      if (i >= e) go to 1019
      go to 1032
   endselect
1033 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (126_int32)
      go to 1036
   case default
      if (i >= e) go to 1019
      go to 1033
   endselect
1034 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (42_int32)
      go to 1029
   case default
      go to 1019
   endselect
1035 continue
   i = i + 1_int32
   color = 7_int8
   t = i
   return
1036 continue
   i = i + 1_int32
   yych = 0_int32
   if (i < e) yych = cp(i)
   select case (yych)
   case (126_int32)
      go to 1029
   case default
      go to 1019
   endselect
1037 continue
   t = s
   return
   endfunction markdown_token

   subroutine fork_data(name, field, value, words)
   !< A language's definition: `field` 1 singleLineComment, 2 singleLineCommentAlt, 3 commentStart, 4 commentEnd,
   !< 5 otherStringStart, 6 otherStringEnd, 7 otherStringAltStart, 8 otherStringAltEnd, 9 the flags (preprocess,
   !< escape, single and double quotes, case, nested comments, indentation blocks as digits `p e s d c n i`, the
   !< characters' codes for p and e, 0 none), 10 keywords, 11 declarations, 12 identifiers, 13 the tokenizers (punctuation,
   !< identifier, number, custom, comment levels, string levels as `TOK_*` names); `words` for 10 to 12, LF-separated.
   character(len=*),              intent(in)  :: name  !< The language (as registered).
   integer(int32),                intent(in)  :: field !< Which.
   character(len=:), allocatable, intent(out) :: value !< Its text.
   logical,                       intent(out) :: words !< A list of words.

   value = ''
   words = field >= 10_int32 .and. field <= 12_int32
   select case (name)
   case ('AngelScript')
      select case (field)
      case (1_int32)
         value = '//'
      case (3_int32)
         value = '/*'
      case (4_int32)
         value = '*/'
      case (9_int32)
         value = '35 92 1 1 1 0 0'
      case (10_int32)
         value = 'and'//achar(10)// 'abstract'//achar(10)// 'auto'//achar(10)// 'bool'//achar(10)// 'break'//achar(10)// &
                 'case'//achar(10)// 'cast'//achar(10)// 'class'//achar(10)// 'const'//achar(10)// &
                 'continue'//achar(10)// 'default'//achar(10)// 'do'//achar(10)// 'double'//achar(10)// &
                 'else'//achar(10)// 'enum'//achar(10)// 'false'//achar(10)// 'final'//achar(10)// 'float'//achar(10)// &
                 'for'//achar(10)// 'from'//achar(10)// 'funcdef'//achar(10)// 'function'//achar(10)// &
                 'get'//achar(10)// 'if'//achar(10)// 'import'//achar(10)// 'in'//achar(10)// 'inout'//achar(10)// &
                 'int'//achar(10)// 'interface'//achar(10)// 'int8'//achar(10)// 'int16'//achar(10)// &
                 'int32'//achar(10)// 'int64'//achar(10)// 'is'//achar(10)// 'mixin'//achar(10)// &
                 'namespace'//achar(10)// 'not'//achar(10)// 'null'//achar(10)// 'or'//achar(10)// 'out'//achar(10)// &
                 'override'//achar(10)// 'private'//achar(10)// 'protected'//achar(10)// 'return'//achar(10)// &
                 'set'//achar(10)// 'shared'//achar(10)// 'super'//achar(10)// 'switch'//achar(10)// &
                 'this '//achar(10)// 'true'//achar(10)// 'typedef'//achar(10)// 'uint'//achar(10)// &
                 'uint8'//achar(10)// 'uint16'//achar(10)// 'uint32'//achar(10)// 'uint64'//achar(10)// &
                 'void'//achar(10)// 'while'//achar(10)// 'xor'
      case (13_int32)
         value = 'C:isPunctuation C:getIdentifier C:getNumber - - -'
      endselect
   case ('C')
      select case (field)
      case (1_int32)
         value = '//'
      case (3_int32)
         value = '/*'
      case (4_int32)
         value = '*/'
      case (9_int32)
         value = '35 92 1 1 1 0 0'
      case (10_int32)
         value = 'break'//achar(10)// 'case'//achar(10)// 'continue'//achar(10)// 'default'//achar(10)// &
                 'do'//achar(10)// 'else'//achar(10)// 'for'//achar(10)// 'goto'//achar(10)// 'if'//achar(10)// &
                 'return'//achar(10)// 'sizeof'//achar(10)// 'switch'//achar(10)// 'while'//achar(10)// &
                 '_Alignas'//achar(10)// '_Alignof'//achar(10)// '_Atomic'//achar(10)// '_Bool'//achar(10)// &
                 '_Complex'//achar(10)// '_Generic'//achar(10)// '_Imaginary'//achar(10)// '_Noreturn'//achar(10)// &
                 '_Static_assert'//achar(10)// '_Thread_local'
      case (11_int32)
         value = 'auto'//achar(10)// 'char'//achar(10)// 'const'//achar(10)// 'double'//achar(10)// 'enum'//achar(10)// &
                 'extern'//achar(10)// 'float'//achar(10)// 'inline'//achar(10)// 'int'//achar(10)// 'long'//achar(10)// &
                 'register'//achar(10)// 'restrict'//achar(10)// 'short'//achar(10)// 'signed'//achar(10)// &
                 'static'//achar(10)// 'struct'//achar(10)// 'typedef'//achar(10)// 'union'//achar(10)// &
                 'unsigned'//achar(10)// 'void'//achar(10)// 'volatile'
      case (13_int32)
         value = 'isPunctuation getIdentifier getNumber - - -'
      endselect
   case ('C#')
      select case (field)
      case (1_int32)
         value = '//'
      case (3_int32)
         value = '/*'
      case (4_int32)
         value = '*/'
      case (9_int32)
         value = '35 92 1 1 1 0 0'
      case (10_int32)
         value = 'abstract'//achar(10)// 'as'//achar(10)// 'base'//achar(10)// 'bool'//achar(10)// 'break'//achar(10)// &
                 'byte'//achar(10)// 'case'//achar(10)// 'catch'//achar(10)// 'char'//achar(10)// 'checked'//achar(10)// &
                 'class'//achar(10)// 'const'//achar(10)// 'continue'//achar(10)// 'decimal'//achar(10)// &
                 'default'//achar(10)// 'delegate'//achar(10)// 'do'//achar(10)// 'double'//achar(10)// &
                 'else'//achar(10)// 'enum'//achar(10)// 'event'//achar(10)// 'explicit'//achar(10)// &
                 'extern'//achar(10)// 'false'//achar(10)// 'finally'//achar(10)// 'fixed'//achar(10)// &
                 'float'//achar(10)// 'for'//achar(10)// 'foreach'//achar(10)// 'goto'//achar(10)// 'if'//achar(10)// &
                 'implicit'//achar(10)// 'in'//achar(10)// 'in (generic modifier)'//achar(10)// 'int'//achar(10)// &
                 'interface'//achar(10)// 'internal'//achar(10)// 'is'//achar(10)// 'lock'//achar(10)// &
                 'long'//achar(10)// 'namespace'//achar(10)// 'new'//achar(10)// 'null'//achar(10)// &
                 'object'//achar(10)// 'operator'//achar(10)// 'out'//achar(10)// 'override'//achar(10)// &
                 'params'//achar(10)// 'private'//achar(10)// 'protected'//achar(10)// 'public'//achar(10)// &
                 'readonly'//achar(10)// 'ref'//achar(10)// 'return'//achar(10)// 'sbyte'//achar(10)// &
                 'sealed'//achar(10)// 'short'//achar(10)// 'sizeof'//achar(10)// 'stackalloc'//achar(10)// &
                 'static'//achar(10)// 'string'//achar(10)// 'struct'//achar(10)// 'switch'//achar(10)// &
                 'this'//achar(10)// 'throw'//achar(10)// 'true'//achar(10)// 'try'//achar(10)// 'typeof'//achar(10)// &
                 'uint'//achar(10)// 'ulong'//achar(10)// 'unchecked'//achar(10)// 'unsafe'//achar(10)// &
                 'ushort'//achar(10)// 'using'//achar(10)// 'using static'//achar(10)// 'void'//achar(10)// &
                 'volatile'//achar(10)// 'while'
      case (13_int32)
         value = 'C:isPunctuation C:getIdentifier getNumber - - -'
      endselect
   case ('C++')
      select case (field)
      case (1_int32)
         value = '//'
      case (3_int32)
         value = '/*'
      case (4_int32)
         value = '*/'
      case (9_int32)
         value = '35 92 1 1 1 0 0'
      case (10_int32)
         value = 'alignas'//achar(10)// 'alignof'//achar(10)// 'and'//achar(10)// 'and_eq'//achar(10)// &
                 'asm'//achar(10)// 'atomic_cancel'//achar(10)// 'atomic_commit'//achar(10)// &
                 'atomic_noexcept'//achar(10)// 'bitand'//achar(10)// 'bitor'//achar(10)// 'break'//achar(10)// &
                 'case'//achar(10)// 'catch'//achar(10)// 'compl'//achar(10)// 'const_cast'//achar(10)// &
                 'continue'//achar(10)// 'default'//achar(10)// 'delete'//achar(10)// 'do'//achar(10)// &
                 'dynamic_cast'//achar(10)// 'else'//achar(10)// 'explicit'//achar(10)// 'export'//achar(10)// &
                 'extern'//achar(10)// 'false'//achar(10)// 'for'//achar(10)// 'goto'//achar(10)// 'if'//achar(10)// &
                 'import'//achar(10)// 'new'//achar(10)// 'noexcept'//achar(10)// 'not'//achar(10)// &
                 'not_eq'//achar(10)// 'nullptr'//achar(10)// 'operator'//achar(10)// 'or'//achar(10)// &
                 'or_eq'//achar(10)// 'reinterpret_cast'//achar(10)// 'requires'//achar(10)// 'return'//achar(10)// &
                 'sizeof'//achar(10)// 'static_assert'//achar(10)// 'static_cast'//achar(10)// 'switch'//achar(10)// &
                 'synchronized'//achar(10)// 'this'//achar(10)// 'thread_local'//achar(10)// 'throw'//achar(10)// &
                 'true'//achar(10)// 'try'//achar(10)// 'while'//achar(10)// 'xor'//achar(10)// 'xor_eq'
      case (11_int32)
         value = 'auto'//achar(10)// 'bool'//achar(10)// 'char'//achar(10)// 'char8_t'//achar(10)// &
                 'char16_t'//achar(10)// 'char32_t'//achar(10)// 'class'//achar(10)// 'concept'//achar(10)// &
                 'const'//achar(10)// 'constexpr'//achar(10)// 'decltype'//achar(10)// 'double'//achar(10)// &
                 'explicit'//achar(10)// 'export'//achar(10)// 'extern'//achar(10)// 'enum'//achar(10)// &
                 'extern'//achar(10)// 'float'//achar(10)// 'friend'//achar(10)// 'inline'//achar(10)// &
                 'int'//achar(10)// 'long'//achar(10)// 'module'//achar(10)// 'mutable'//achar(10)// &
                 'namespace'//achar(10)// 'private'//achar(10)// 'protected'//achar(10)// 'public'//achar(10)// &
                 'register'//achar(10)// 'restrict'//achar(10)// 'short'//achar(10)// 'signed'//achar(10)// &
                 'static'//achar(10)// 'struct'//achar(10)// 'template'//achar(10)// 'typedef'//achar(10)// &
                 'typeid'//achar(10)// 'typename'//achar(10)// 'union'//achar(10)// 'using'//achar(10)// &
                 'unsigned'//achar(10)// 'virtual'//achar(10)// 'void'//achar(10)// 'volatile'//achar(10)// 'wchar_t'
      case (13_int32)
         value = 'C:isPunctuation C:getIdentifier C:getNumber - - -'
      endselect
   case ('GLSL')
      select case (field)
      case (1_int32)
         value = '//'
      case (3_int32)
         value = '/*'
      case (4_int32)
         value = '*/'
      case (9_int32)
         value = '35 92 1 1 1 0 0'
      case (10_int32)
         value = 'atomic_uint'//achar(10)// 'attribute'//achar(10)// 'bool'//achar(10)// 'break'//achar(10)// &
                 'buffer'//achar(10)// 'bvec2'//achar(10)// 'bvec3'//achar(10)// 'bvec4'//achar(10)// &
                 'case'//achar(10)// 'centroid'//achar(10)// 'coherent'//achar(10)// 'const'//achar(10)// &
                 'continue'//achar(10)// 'default'//achar(10)// 'discard'//achar(10)// 'dmat2'//achar(10)// &
                 'dmat2x2'//achar(10)// 'dmat2x3'//achar(10)// 'dmat2x4'//achar(10)// 'dmat3'//achar(10)// &
                 'dmat3x2'//achar(10)// 'dmat3x3'//achar(10)// 'dmat3x4'//achar(10)// 'dmat4'//achar(10)// &
                 'dmat4x2'//achar(10)// 'dmat4x3'//achar(10)// 'dmat4x4'//achar(10)// 'do'//achar(10)// &
                 'double'//achar(10)// 'dvec2'//achar(10)// 'dvec3'//achar(10)// 'dvec4'//achar(10)// &
                 'else'//achar(10)// 'false'//achar(10)// 'flat'//achar(10)// 'float'//achar(10)// 'for'//achar(10)// &
                 'highp'//achar(10)// 'if'//achar(10)// 'iimage1D'//achar(10)// 'iimage1DArray'//achar(10)// &
                 'iimage2D'//achar(10)// 'iimage2DArray'//achar(10)// 'iimage2DMS'//achar(10)// &
                 'iimage2DMSArray'//achar(10)// 'iimage2DRect'//achar(10)// 'iimage3D'//achar(10)// &
                 'iimageBuffer'//achar(10)// 'iimageCube'//achar(10)// 'iimageCubeArray'//achar(10)// &
                 'image1D'//achar(10)// 'image1DArray'//achar(10)// 'image2D'//achar(10)// 'image2DArray'//achar(10)// &
                 'image2DMS'//achar(10)// 'image2DMSArray'//achar(10)// 'image2DRect'//achar(10)// &
                 'image3D'//achar(10)// 'imageBuffer'//achar(10)// 'imageCube'//achar(10)// &
                 'imageCubeArray'//achar(10)// 'in'//achar(10)// 'inout'//achar(10)// 'int'//achar(10)// &
                 'invariant'//achar(10)// 'isampler1D'//achar(10)// 'isampler1DArray'//achar(10)// &
                 'isampler2D'//achar(10)// 'isampler2DArray'//achar(10)// 'isampler2DMS'//achar(10)// &
                 'isampler2DMSArray'//achar(10)// 'isampler2DRect'//achar(10)// 'isampler3D'//achar(10)// &
                 'isamplerBuffer'//achar(10)// 'isamplerCube'//achar(10)// 'isamplerCubeArray'//achar(10)// &
                 'ivec2'//achar(10)// 'ivec3'//achar(10)// 'ivec4'//achar(10)// 'layout'//achar(10)// &
                 'lowp'//achar(10)// 'mat2'//achar(10)// 'mat2x2'//achar(10)// 'mat2x3'//achar(10)// &
                 'mat2x4'//achar(10)// 'mat3'//achar(10)// 'mat3x2'//achar(10)// 'mat3x3'//achar(10)// &
                 'mat3x4'//achar(10)// 'mat4'//achar(10)// 'mat4x2'//achar(10)// 'mat4x3'//achar(10)// &
                 'mat4x4'//achar(10)// 'mediump'//achar(10)// 'noperspective'//achar(10)// 'out'//achar(10)// &
                 'patch'//achar(10)// 'precise'//achar(10)// 'precision'//achar(10)// 'readonly'//achar(10)// &
                 'restrict'//achar(10)// 'return'//achar(10)// 'sample'//achar(10)// 'sampler1D'//achar(10)// &
                 'sampler1DArray'//achar(10)// 'sampler1DArrayShadow'//achar(10)// 'sampler1DShadow'//achar(10)// &
                 'sampler2D'//achar(10)// 'sampler2DArray'//achar(10)// 'sampler2DArrayShadow'//achar(10)// &
                 'sampler2DMS'//achar(10)// 'sampler2DMSArray'//achar(10)// 'sampler2DRect'//achar(10)// &
                 'sampler2DRectShadow'//achar(10)// 'sampler2DShadow'//achar(10)// 'sampler3D'//achar(10)// &
                 'samplerBuffer'//achar(10)// 'samplerCube'//achar(10)// 'samplerCubeArray'//achar(10)// &
                 'samplerCubeArrayShadow'//achar(10)// 'samplerCubeShadow'//achar(10)// 'shared'//achar(10)// &
                 'smooth'//achar(10)// 'struct'//achar(10)// 'subroutine'//achar(10)// 'switch'//achar(10)// &
                 'true'//achar(10)// 'uimage1D'//achar(10)// 'uimage1DArray'//achar(10)// 'uimage2D'//achar(10)// &
                 'uimage2DArray'//achar(10)// 'uimage2DMS'//achar(10)// 'uimage2DMSArray'//achar(10)// &
                 'uimage2DRect'//achar(10)// 'uimage3D'//achar(10)// 'uimageBuffer'//achar(10)// &
                 'uimageCube'//achar(10)// 'uimageCubeArray'//achar(10)// 'uint'//achar(10)// 'uniform'//achar(10)// &
                 'usampler1D'//achar(10)// 'usampler1DArray'//achar(10)// 'usampler2D'//achar(10)// &
                 'usampler2DArray'//achar(10)// 'usampler2DMS'//achar(10)// 'usampler2DMSArray'//achar(10)// &
                 'usampler2DRect'//achar(10)// 'usampler3D'//achar(10)// 'usamplerBuffer'//achar(10)// &
                 'usamplerCube'//achar(10)// 'usamplerCubeArray'//achar(10)// 'uvec2'//achar(10)// 'uvec3'//achar(10)// &
                 'uvec4'//achar(10)// 'varying'//achar(10)// 'vec2'//achar(10)// 'vec3'//achar(10)// 'vec4'//achar(10)// &
                 'void'//achar(10)// 'volatile'//achar(10)// 'while'//achar(10)// 'writeonly'
      case (13_int32)
         value = 'C:isPunctuation C:getIdentifier C:getNumber - - -'
      endselect
   case ('HLSL')
      select case (field)
      case (1_int32)
         value = '//'
      case (3_int32)
         value = '/*'
      case (4_int32)
         value = '*/'
      case (9_int32)
         value = '35 92 1 1 1 0 0'
      case (10_int32)
         value = 'AppendStructuredBuffer'//achar(10)// 'asm'//achar(10)// 'asm_fragment'//achar(10)// &
                 'BlendState'//achar(10)// 'bool'//achar(10)// 'break'//achar(10)// 'Buffer'//achar(10)// &
                 'ByteAddressBuffer'//achar(10)// 'case'//achar(10)// 'cbuffer'//achar(10)// 'centroid'//achar(10)// &
                 'class'//achar(10)// 'column_major'//achar(10)// 'compile'//achar(10)// &
                 'compile_fragment'//achar(10)// 'CompileShader'//achar(10)// 'const'//achar(10)// &
                 'continue'//achar(10)// 'ComputeShader'//achar(10)// 'ConsumeStructuredBuffer'//achar(10)// &
                 'default'//achar(10)// 'DepthStencilState'//achar(10)// 'DepthStencilView'//achar(10)// &
                 'discard'//achar(10)// 'do'//achar(10)// 'double'//achar(10)// 'DomainShader'//achar(10)// &
                 'dword'//achar(10)// 'else'//achar(10)// 'export'//achar(10)// 'extern'//achar(10)// &
                 'false'//achar(10)// 'float'//achar(10)// 'for'//achar(10)// 'fxgroup'//achar(10)// &
                 'GeometryShader'//achar(10)// 'groupshared'//achar(10)// 'half'//achar(10)// 'Hullshader'//achar(10)// &
                 'if'//achar(10)// 'in'//achar(10)// 'inline'//achar(10)// 'inout'//achar(10)// &
                 'InputPatch'//achar(10)// 'int'//achar(10)// 'interface'//achar(10)// 'line'//achar(10)// &
                 'lineadj'//achar(10)// 'linear'//achar(10)// 'LineStream'//achar(10)// 'matrix'//achar(10)// &
                 'min16float'//achar(10)// 'min10float'//achar(10)// 'min16int'//achar(10)// 'min12int'//achar(10)// &
                 'min16uint'//achar(10)// 'namespace'//achar(10)// 'nointerpolation'//achar(10)// &
                 'noperspective'//achar(10)// 'NULL'//achar(10)// 'out'//achar(10)// 'OutputPatch'//achar(10)// &
                 'packoffset'//achar(10)// 'pass'//achar(10)// 'pixelfragment'//achar(10)// 'PixelShader'//achar(10)// &
                 'point'//achar(10)// 'PointStream'//achar(10)// 'precise'//achar(10)// 'RasterizerState'//achar(10)// &
                 'RenderTargetView'//achar(10)// 'return'//achar(10)// 'register'//achar(10)// 'row_major'//achar(10)// &
                 'RWBuffer'//achar(10)// 'RWByteAddressBuffer'//achar(10)// 'RWStructuredBuffer'//achar(10)// &
                 'RWTexture1D'//achar(10)// 'RWTexture1DArray'//achar(10)// 'RWTexture2D'//achar(10)// &
                 'RWTexture2DArray'//achar(10)// 'RWTexture3D'//achar(10)// 'sample'//achar(10)// &
                 'sampler'//achar(10)// 'SamplerState'//achar(10)// 'SamplerComparisonState'//achar(10)// &
                 'shared'//achar(10)// 'snorm'//achar(10)// 'stateblock'//achar(10)// 'stateblock_state'//achar(10)// &
                 'static'//achar(10)// 'string'//achar(10)// 'struct'//achar(10)// 'switch'//achar(10)// &
                 'StructuredBuffer'//achar(10)// 'tbuffer'//achar(10)// 'technique'//achar(10)// &
                 'technique10'//achar(10)// 'technique11'//achar(10)// 'texture'//achar(10)// 'Texture1D'//achar(10)// &
                 'Texture1DArray'//achar(10)// 'Texture2D'//achar(10)// 'Texture2DArray'//achar(10)// &
                 'Texture2DMS'//achar(10)// 'Texture2DMSArray'//achar(10)// 'Texture3D'//achar(10)// &
                 'TextureCube'//achar(10)// 'TextureCubeArray'//achar(10)// 'true'//achar(10)// 'typedef'//achar(10)// &
                 'triangle'//achar(10)// 'triangleadj'//achar(10)// 'TriangleStream'//achar(10)// 'uint'//achar(10)// &
                 'uniform'//achar(10)// 'unorm'//achar(10)// 'unsigned'//achar(10)// 'vector'//achar(10)// &
                 'vertexfragment'//achar(10)// 'VertexShader'//achar(10)// 'void'//achar(10)// 'volatile'//achar(10)// &
                 'while'//achar(10)// 'bool1'//achar(10)// 'bool2'//achar(10)// 'bool3'//achar(10)// &
                 'bool4'//achar(10)// 'double1'//achar(10)// 'double2'//achar(10)// 'double3'//achar(10)// &
                 'double4'//achar(10)// 'float1'//achar(10)// 'float2'//achar(10)// 'float3'//achar(10)// &
                 'float4'//achar(10)// 'int1'//achar(10)// 'int2'//achar(10)// 'int3'//achar(10)// 'int4'//achar(10)// &
                 'in'//achar(10)// 'out'//achar(10)// 'inout'//achar(10)// 'uint1'//achar(10)// 'uint2'//achar(10)// &
                 'uint3'//achar(10)// 'uint4'//achar(10)// 'dword1'//achar(10)// 'dword2'//achar(10)// &
                 'dword3'//achar(10)// 'dword4'//achar(10)// 'half1'//achar(10)// 'half2'//achar(10)// &
                 'half3'//achar(10)// 'half4'//achar(10)// 'float1x1'//achar(10)// 'float2x1'//achar(10)// &
                 'float3x1'//achar(10)// 'float4x1'//achar(10)// 'float1x2'//achar(10)// 'float2x2'//achar(10)// &
                 'float3x2'//achar(10)// 'float4x2'//achar(10)// 'float1x3'//achar(10)// 'float2x3'//achar(10)// &
                 'float3x3'//achar(10)// 'float4x3'//achar(10)// 'float1x4'//achar(10)// 'float2x4'//achar(10)// &
                 'float3x4'//achar(10)// 'float4x4'//achar(10)// 'half1x1'//achar(10)// 'half2x1'//achar(10)// &
                 'half3x1'//achar(10)// 'half4x1'//achar(10)// 'half1x2'//achar(10)// 'half2x2'//achar(10)// &
                 'half3x2'//achar(10)// 'half4x2'//achar(10)// 'half1x3'//achar(10)// 'half2x3'//achar(10)// &
                 'half3x3'//achar(10)// 'half4x3'//achar(10)// 'half1x4'//achar(10)// 'half2x4'//achar(10)// &
                 'half3x4'//achar(10)// 'half4x4'
      case (13_int32)
         value = 'C:isPunctuation C:getIdentifier C:getNumber - - -'
      endselect
   case ('JSON')
      select case (field)
      case (9_int32)
         value = '0 0 0 0 1 0 0'
      case (10_int32)
         value = 'false'//achar(10)// 'null'//achar(10)// 'true'
      case (13_int32)
         value = '- - - tokenize - -'
      endselect
   case ('Julia')
      select case (field)
      case (1_int32)
         value = '#'
      case (3_int32)
         value = '#='
      case (4_int32)
         value = '=#'
      case (5_int32)
         value = '"""'
      case (6_int32)
         value = '"""'
      case (7_int32)
         value = '```'
      case (8_int32)
         value = '```'
      case (9_int32)
         value = '0 92 0 1 1 1 0'
      case (10_int32)
         value = 'begin'//achar(10)// 'break'//achar(10)// 'catch'//achar(10)// 'continue'//achar(10)// &
                 'do'//achar(10)// 'else'//achar(10)// 'elseif'//achar(10)// 'end'//achar(10)// 'export'//achar(10)// &
                 'false'//achar(10)// 'finally'//achar(10)// 'for'//achar(10)// 'if'//achar(10)// 'import'//achar(10)// &
                 'in'//achar(10)// 'isa'//achar(10)// 'let'//achar(10)// 'quote'//achar(10)// 'return'//achar(10)// &
                 'true'//achar(10)// 'try'//achar(10)// 'using'//achar(10)// 'where'//achar(10)// 'while'
      case (11_int32)
         value = 'baremodule'//achar(10)// 'const'//achar(10)// 'function'//achar(10)// 'global'//achar(10)// &
                 'local'//achar(10)// 'macro'//achar(10)// 'module'//achar(10)// 'struct'//achar(10)// &
                 'AbstractArray'//achar(10)// 'AbstractChar'//achar(10)// 'AbstractDict'//achar(10)// &
                 'AbstractFloat'//achar(10)// 'AbstractMatrix'//achar(10)// 'AbstractRange'//achar(10)// &
                 'AbstractSet'//achar(10)// 'AbstractString'//achar(10)// 'AbstractVector'//achar(10)// &
                 'Any'//achar(10)// 'Array'//achar(10)// 'BigFloat'//achar(10)// 'BigInt'//achar(10)// &
                 'Bool'//achar(10)// 'Char'//achar(10)// 'Complex'//achar(10)// 'ComplexF32'//achar(10)// &
                 'ComplexF64'//achar(10)// 'DataType'//achar(10)// 'Dict'//achar(10)// 'Exception'//achar(10)// &
                 'Expr'//achar(10)// 'Float16'//achar(10)// 'Float32'//achar(10)// 'Float64'//achar(10)// &
                 'Function'//achar(10)// 'Int'//achar(10)// 'Int128'//achar(10)// 'Int16'//achar(10)// &
                 'Int32'//achar(10)// 'Int64'//achar(10)// 'Int8'//achar(10)// 'Integer'//achar(10)// 'IO'//achar(10)// &
                 'Matrix'//achar(10)// 'Missing'//achar(10)// 'Module'//achar(10)// 'NamedTuple'//achar(10)// &
                 'Nothing'//achar(10)// 'Number'//achar(10)// 'Pair'//achar(10)// 'Ptr'//achar(10)// &
                 'Rational'//achar(10)// 'Real'//achar(10)// 'Ref'//achar(10)// 'Set'//achar(10)// 'Signed'//achar(10)// &
                 'String'//achar(10)// 'Symbol'//achar(10)// 'Tuple'//achar(10)// 'Type'//achar(10)// &
                 'UInt'//achar(10)// 'UInt128'//achar(10)// 'UInt16'//achar(10)// 'UInt32'//achar(10)// &
                 'UInt64'//achar(10)// 'UInt8'//achar(10)// 'Union'//achar(10)// 'UnionAll'//achar(10)// &
                 'Unsigned'//achar(10)// 'Vector'//achar(10)// 'Val'
      case (12_int32)
         value = 'ARGS'//achar(10)// 'C_NULL'//achar(10)// 'ENV'//achar(10)// 'Inf'//achar(10)// 'Inf16'//achar(10)// &
                 'Inf32'//achar(10)// 'Inf64'//achar(10)// 'NaN'//achar(10)// 'NaN16'//achar(10)// 'NaN32'//achar(10)// &
                 'NaN64'//achar(10)// 'VERSION'//achar(10)// 'im'//achar(10)// 'missing'//achar(10)// &
                 'nothing'//achar(10)// 'pi'//achar(10)// 'stderr'//achar(10)// 'stdin'//achar(10)// &
                 'stdout'//achar(10)// char(207)//char(128)//achar(10)// char(226)//char(132)//char(175)//achar(10)// &
                 'abs'//achar(10)// 'all'//achar(10)// 'any'//achar(10)// 'append!'//achar(10)// 'collect'//achar(10)// &
                 'convert'//achar(10)// 'copy'//achar(10)// 'deepcopy'//achar(10)// 'delete!'//achar(10)// &
                 'eachindex'//achar(10)// 'eltype'//achar(10)// 'empty!'//achar(10)// 'enumerate'//achar(10)// &
                 'error'//achar(10)// 'filter'//achar(10)// 'findall'//achar(10)// 'findfirst'//achar(10)// &
                 'first'//achar(10)// 'get'//achar(10)// 'getfield'//achar(10)// 'getindex'//achar(10)// &
                 'haskey'//achar(10)// 'isempty'//achar(10)// 'isnothing'//achar(10)// 'keys'//achar(10)// &
                 'last'//achar(10)// 'length'//achar(10)// 'map'//achar(10)// 'max'//achar(10)// 'maximum'//achar(10)// &
                 'min'//achar(10)// 'minimum'//achar(10)// 'ndims'//achar(10)// 'pairs'//achar(10)// 'pop!'//achar(10)// &
                 'print'//achar(10)// 'println'//achar(10)// 'promote'//achar(10)// 'push!'//achar(10)// &
                 'reduce'//achar(10)// 'repr'//achar(10)// 'resize!'//achar(10)// 'reverse'//achar(10)// &
                 'setfield!'//achar(10)// 'setindex!'//achar(10)// 'show'//achar(10)// 'similar'//achar(10)// &
                 'size'//achar(10)// 'sort'//achar(10)// 'sort!'//achar(10)// 'string'//achar(10)// 'sum'//achar(10)// &
                 'throw'//achar(10)// 'typeof'//achar(10)// 'values'//achar(10)// 'zeros'//achar(10)// &
                 'ones'//achar(10)// 'zip'
      case (13_int32)
         value = 'isPunctuation getIdentifier getNumber tokenize - -'
      endselect
   case ('Lua')
      select case (field)
      case (1_int32)
         value = '--'
      case (9_int32)
         value = '0 92 1 1 1 0 0'
      case (10_int32)
         value = 'and'//achar(10)// 'break'//achar(10)// 'do'//achar(10)// 'else'//achar(10)// 'elseif'//achar(10)// &
                 'end'//achar(10)// 'false'//achar(10)// 'for'//achar(10)// 'function'//achar(10)// 'goto'//achar(10)// &
                 'if'//achar(10)// 'in'//achar(10)// 'local'//achar(10)// 'nil'//achar(10)// 'not'//achar(10)// &
                 'or'//achar(10)// 'repeat'//achar(10)// 'return'//achar(10)// 'then'//achar(10)// 'true'//achar(10)// &
                 'until'//achar(10)// 'while'
      case (12_int32)
         value = '_G'//achar(10)// '_VERSION'//achar(10)// 'abs'//achar(10)// 'acos'//achar(10)// 'asin'//achar(10)// &
                 'assert'//achar(10)// 'atan'//achar(10)// 'atan2'//achar(10)// 'byte'//achar(10)// 'ceil'//achar(10)// &
                 'char'//achar(10)// 'clock'//achar(10)// 'close'//achar(10)// 'collectgarbage'//achar(10)// &
                 'concat'//achar(10)// 'coroutine'//achar(10)// 'cos'//achar(10)// 'cosh'//achar(10)// &
                 'cpath'//achar(10)// 'create'//achar(10)// 'date'//achar(10)// 'debug'//achar(10)// 'deg'//achar(10)// &
                 'difftime'//achar(10)// 'dofile'//achar(10)// 'dump'//achar(10)// 'error'//achar(10)// &
                 'execute'//achar(10)// 'exit'//achar(10)// 'exp'//achar(10)// 'find'//achar(10)// 'floor'//achar(10)// &
                 'flush'//achar(10)// 'fmod'//achar(10)// 'format'//achar(10)// 'frexp'//achar(10)// &
                 'getenv'//achar(10)// 'getfenv'//achar(10)// 'gethook'//achar(10)// 'getinfo'//achar(10)// &
                 'getlocal'//achar(10)// 'getmetatable'//achar(10)// 'getregistry'//achar(10)// &
                 'getupvalue'//achar(10)// 'gmatch'//achar(10)// 'gsub'//achar(10)// 'huge'//achar(10)// &
                 'input'//achar(10)// 'insert'//achar(10)// 'io'//achar(10)// 'ipairs'//achar(10)// 'ldexp'//achar(10)// &
                 'len'//achar(10)// 'lines'//achar(10)// 'load'//achar(10)// 'loaded'//achar(10)// &
                 'loaders'//achar(10)// 'loadfile'//achar(10)// 'loadlib'//achar(10)// 'loadstring'//achar(10)// &
                 'log'//achar(10)// 'log10'//achar(10)// 'lower'//achar(10)// 'match'//achar(10)// 'math'//achar(10)// &
                 'max'//achar(10)// 'maxn'//achar(10)// 'min'//achar(10)// 'modf'//achar(10)// 'module'//achar(10)// &
                 'next'//achar(10)// 'open'//achar(10)// 'os'//achar(10)// 'output'//achar(10)// 'package'//achar(10)// &
                 'pairs'//achar(10)// 'path'//achar(10)// 'pcall'//achar(10)// 'pi'//achar(10)// 'popen'//achar(10)// &
                 'pow'//achar(10)// 'preload'//achar(10)// 'print'//achar(10)// 'rad'//achar(10)// 'random'//achar(10)// &
                 'randomseed'//achar(10)// 'rawequal'//achar(10)// 'rawget'//achar(10)// 'rawset'//achar(10)// &
                 'read'//achar(10)// 'remove'//achar(10)// 'rename'//achar(10)// 'rep'//achar(10)// &
                 'require'//achar(10)// 'resume'//achar(10)// 'reverse'//achar(10)// 'running'//achar(10)// &
                 'seeall'//achar(10)// 'seek'//achar(10)// 'select'//achar(10)// 'setfenv'//achar(10)// &
                 'sethook'//achar(10)// 'setlocal'//achar(10)// 'setlocale'//achar(10)// 'setmetatable'//achar(10)// &
                 'setupvalue'//achar(10)// 'setvbuf'//achar(10)// 'sin'//achar(10)// 'sinh'//achar(10)// &
                 'sort'//achar(10)// 'sqrt'//achar(10)// 'status'//achar(10)// 'stderr'//achar(10)// &
                 'stdin'//achar(10)// 'stdout'//achar(10)// 'string'//achar(10)// 'sub'//achar(10)// &
                 'table'//achar(10)// 'tan'//achar(10)// 'tanh'//achar(10)// 'time'//achar(10)// 'tmpfile'//achar(10)// &
                 'tmpname'//achar(10)// 'tonumber'//achar(10)// 'tostring'//achar(10)// 'traceback'//achar(10)// &
                 'type'//achar(10)// 'unpack'//achar(10)// 'upper'//achar(10)// 'wrap'//achar(10)// 'write'//achar(10)// &
                 'xpcall'//achar(10)// 'yield'
      case (13_int32)
         value = 'C:isPunctuation C:getIdentifier getNumber - commentLevelStart stringLevelStart'
      endselect
   case ('Markdown')
      select case (field)
      case (3_int32)
         value = '<!--'
      case (4_int32)
         value = '-->'
      case (9_int32)
         value = '0 0 0 0 1 0 0'
      case (13_int32)
         value = '- - - tokenize - -'
      endselect
   case ('Python')
      select case (field)
      case (1_int32)
         value = '#'
      case (5_int32)
         value = '"""'
      case (6_int32)
         value = '"""'
      case (7_int32)
         value = achar(39)//achar(39)//achar(39)
      case (8_int32)
         value = achar(39)//achar(39)//achar(39)
      case (9_int32)
         value = '0 92 1 1 1 0 1'
      case (10_int32)
         value = 'False'//achar(10)// 'await'//achar(10)// 'else'//achar(10)// 'import'//achar(10)// 'pass'//achar(10)// &
                 'None'//achar(10)// 'break'//achar(10)// 'except'//achar(10)// 'in'//achar(10)// 'raise'//achar(10)// &
                 'True'//achar(10)// 'class'//achar(10)// 'finally'//achar(10)// 'is'//achar(10)// 'return'//achar(10)// &
                 'and'//achar(10)// 'continue'//achar(10)// 'for'//achar(10)// 'lambda'//achar(10)// 'try'//achar(10)// &
                 'as'//achar(10)// 'def'//achar(10)// 'from'//achar(10)// 'nonlocal'//achar(10)// 'while'//achar(10)// &
                 'assert'//achar(10)// 'del'//achar(10)// 'global'//achar(10)// 'not'//achar(10)// 'with'//achar(10)// &
                 'async'//achar(10)// 'elif'//achar(10)// 'if'//achar(10)// 'or'//achar(10)// 'yield'
      case (13_int32)
         value = 'C:isPunctuation C:getIdentifier getNumber - - -'
      endselect
   case ('SQL')
      select case (field)
      case (1_int32)
         value = '--'
      case (3_int32)
         value = '/*'
      case (4_int32)
         value = '*/'
      case (9_int32)
         value = '0 92 1 1 0 0 0'
      case (10_int32)
         value = 'abs'//achar(10)// 'absent'//achar(10)// 'acos'//achar(10)// 'all'//achar(10)// 'allocate'//achar(10)// &
                 'alter'//achar(10)// 'and'//achar(10)// 'any'//achar(10)// 'any_value'//achar(10)// 'are'//achar(10)// &
                 'array'//achar(10)// 'array_agg'//achar(10)// 'array_max_cardinality'//achar(10)// 'as'//achar(10)// &
                 'asensitive'//achar(10)// 'asin'//achar(10)// 'asymmetric'//achar(10)// 'at'//achar(10)// &
                 'atan'//achar(10)// 'atomic'//achar(10)// 'authorization'//achar(10)// 'avg'//achar(10)// &
                 'begin'//achar(10)// 'begin_frame'//achar(10)// 'begin_partition'//achar(10)// 'between'//achar(10)// &
                 'bigint'//achar(10)// 'binary'//achar(10)// 'blob'//achar(10)// 'boolean'//achar(10)// &
                 'both'//achar(10)// 'btrim'//achar(10)// 'by'//achar(10)// 'call'//achar(10)// 'called'//achar(10)// &
                 'cardinality'//achar(10)// 'cascaded'//achar(10)// 'case'//achar(10)// 'cast'//achar(10)// &
                 'ceil'//achar(10)// 'ceiling'//achar(10)// 'char'//achar(10)// 'character'//achar(10)// &
                 'character_length'//achar(10)// 'char_length'//achar(10)// 'check'//achar(10)// &
                 'classifier'//achar(10)// 'clob'//achar(10)// 'close'//achar(10)// 'coalesce'//achar(10)// &
                 'collate'//achar(10)// 'collect'//achar(10)// 'column'//achar(10)// 'commit'//achar(10)// &
                 'condition'//achar(10)// 'connect'//achar(10)// 'constraint'//achar(10)// 'contains'//achar(10)// &
                 'convert'//achar(10)// 'copy'//achar(10)// 'corr'//achar(10)// 'corresponding'//achar(10)// &
                 'cos'//achar(10)// 'cosh'//achar(10)// 'count'//achar(10)// 'covar_pop'//achar(10)// &
                 'covar_samp'//achar(10)// 'create'//achar(10)// 'cross'//achar(10)// 'cube'//achar(10)// &
                 'cume_dist'//achar(10)// 'current'//achar(10)// 'current_catalog'//achar(10)// &
                 'current_date'//achar(10)// 'current_default_transform_group'//achar(10)// &
                 'current_path'//achar(10)// 'current_role'//achar(10)// 'current_row'//achar(10)// &
                 'current_schema'//achar(10)// 'current_time'//achar(10)// 'current_timestamp'//achar(10)// &
                 'current_transform_group_for_type'//achar(10)// 'current_user'//achar(10)// 'cursor'//achar(10)// &
                 'cycle'//achar(10)// 'date'//achar(10)// 'day'//achar(10)// 'deallocate'//achar(10)// &
                 'dec'//achar(10)// 'decfloat'//achar(10)// 'decimal'//achar(10)// 'declare'//achar(10)// &
                 'default'//achar(10)// 'define'//achar(10)// 'delete'//achar(10)// 'dense_rank'//achar(10)// &
                 'deref'//achar(10)// 'describe'//achar(10)// 'deterministic'//achar(10)// 'disconnect'//achar(10)// &
                 'distinct'//achar(10)// 'double'//achar(10)// 'drop'//achar(10)// 'dynamic'//achar(10)// &
                 'each'//achar(10)// 'element'//achar(10)// 'else'//achar(10)// 'empty'//achar(10)// 'end'//achar(10)// &
                 'end-exec'//achar(10)// 'end_frame'//achar(10)// 'end_partition'//achar(10)// 'equals'//achar(10)// &
                 'escape'//achar(10)// 'every'//achar(10)// 'except'//achar(10)// 'exec'//achar(10)// &
                 'execute'//achar(10)// 'exists'//achar(10)// 'exp'//achar(10)// 'external'//achar(10)// &
                 'extract'//achar(10)// 'false'//achar(10)// 'fetch'//achar(10)// 'filter'//achar(10)// &
                 'first_value'//achar(10)// 'float'//achar(10)// 'floor'//achar(10)// 'for'//achar(10)// &
                 'foreign'//achar(10)// 'frame_row'//achar(10)// 'free'//achar(10)// 'from'//achar(10)// &
                 'full'//achar(10)// 'function'//achar(10)// 'fusion'//achar(10)// 'get'//achar(10)// &
                 'global'//achar(10)// 'grant'//achar(10)// 'greatest'//achar(10)// 'group'//achar(10)// &
                 'grouping'//achar(10)// 'groups'//achar(10)// 'having'//achar(10)// 'hold'//achar(10)// &
                 'hour'//achar(10)// 'identity'//achar(10)// 'in'//achar(10)// 'indicator'//achar(10)// &
                 'initial'//achar(10)// 'inner'//achar(10)// 'inout'//achar(10)// 'insensitive'//achar(10)// &
                 'insert'//achar(10)// 'int'//achar(10)// 'integer'//achar(10)// 'intersect'//achar(10)// &
                 'intersection'//achar(10)// 'interval'//achar(10)// 'into'//achar(10)// 'is'//achar(10)// &
                 'join'//achar(10)// 'json'//achar(10)// 'json_array'//achar(10)// 'json_arrayagg'//achar(10)// &
                 'json_exists'//achar(10)// 'json_object'//achar(10)// 'json_objectagg'//achar(10)// &
                 'json_query'//achar(10)// 'json_scalar'//achar(10)// 'json_serialize'//achar(10)// &
                 'json_table'//achar(10)// 'json_table_primitive'//achar(10)// 'json_value'//achar(10)// &
                 'lag'//achar(10)// 'language'//achar(10)// 'large'//achar(10)// 'last_value'//achar(10)// &
                 'lateral'//achar(10)// 'lead'//achar(10)// 'leading'//achar(10)// 'least'//achar(10)// &
                 'left'//achar(10)// 'like'//achar(10)// 'like_regex'//achar(10)// 'limit'//achar(10)// &
                 'listagg'//achar(10)// 'ln'//achar(10)// 'local'//achar(10)// 'localtime'//achar(10)// &
                 'localtimestamp'//achar(10)// 'log'//achar(10)// 'log10'//achar(10)// 'lower'//achar(10)// &
                 'lpad'//achar(10)// 'ltrim'//achar(10)// 'match'//achar(10)// 'matches'//achar(10)// &
                 'match_number'//achar(10)// 'match_recognize'//achar(10)// 'max'//achar(10)// 'member'//achar(10)// &
                 'merge'//achar(10)// 'method'//achar(10)// 'min'//achar(10)// 'minute'//achar(10)// 'mod'//achar(10)// &
                 'modifies'//achar(10)// 'module'//achar(10)// 'month'//achar(10)// 'multiset'//achar(10)// &
                 'national'//achar(10)// 'natural'//achar(10)// 'nchar'//achar(10)// 'nclob'//achar(10)// &
                 'new'//achar(10)// 'no'//achar(10)// 'none'//achar(10)// 'normalize'//achar(10)// 'not'//achar(10)// &
                 'nth_value'//achar(10)// 'ntile'//achar(10)// 'null'//achar(10)// 'nullif'//achar(10)// &
                 'numeric'//achar(10)// 'occurrences_regex'//achar(10)// 'octet_length'//achar(10)// 'of'//achar(10)// &
                 'offset'//achar(10)// 'old'//achar(10)// 'omit'//achar(10)// 'on'//achar(10)// 'one'//achar(10)// &
                 'only'//achar(10)// 'open'//achar(10)// 'or'//achar(10)// 'order'//achar(10)// 'out'//achar(10)// &
                 'outer'//achar(10)// 'over'//achar(10)// 'overlaps'//achar(10)// 'overlay'//achar(10)// &
                 'parameter'//achar(10)// 'partition'//achar(10)// 'pattern'//achar(10)// 'per'//achar(10)// &
                 'percent'//achar(10)// 'percentile_cont'//achar(10)// 'percentile_disc'//achar(10)// &
                 'percent_rank'//achar(10)// 'period'//achar(10)// 'portion'//achar(10)// 'position'//achar(10)// &
                 'position_regex'//achar(10)// 'power'//achar(10)// 'precedes'//achar(10)// 'precision'//achar(10)// &
                 'prepare'//achar(10)// 'primary'//achar(10)// 'procedure'//achar(10)// 'ptf'//achar(10)// &
                 'range'//achar(10)// 'rank'//achar(10)// 'reads'//achar(10)// 'real'//achar(10)// &
                 'recursive'//achar(10)// 'ref'//achar(10)// 'references'//achar(10)// 'referencing'//achar(10)// &
                 'regr_avgx'//achar(10)// 'regr_avgy'//achar(10)// 'regr_count'//achar(10)// &
                 'regr_intercept'//achar(10)// 'regr_r2'//achar(10)// 'regr_slope'//achar(10)// 'regr_sxx'//achar(10)// &
                 'regr_sxy'//achar(10)// 'regr_syy'//achar(10)// 'release'//achar(10)// 'result'//achar(10)// &
                 'return'//achar(10)// 'returns'//achar(10)// 'revoke'//achar(10)// 'right'//achar(10)// &
                 'rollback'//achar(10)// 'rollup'//achar(10)// 'row'//achar(10)// 'rows'//achar(10)// &
                 'row_number'//achar(10)// 'rpad'//achar(10)// 'running'//achar(10)// 'savepoint'//achar(10)// &
                 'scope'//achar(10)// 'scroll'//achar(10)// 'search'//achar(10)// 'second'//achar(10)// &
                 'seek'//achar(10)// 'select'//achar(10)// 'sensitive'//achar(10)// 'session_user'//achar(10)// &
                 'set'//achar(10)// 'show'//achar(10)// 'similar'//achar(10)// 'sin'//achar(10)// 'sinh'//achar(10)// &
                 'skip'//achar(10)// 'smallint'//achar(10)// 'some'//achar(10)// 'specific'//achar(10)// &
                 'specifictype'//achar(10)// 'sql'//achar(10)// 'sqlexception'//achar(10)// 'sqlstate'//achar(10)// &
                 'sqlwarning'//achar(10)// 'sqrt'//achar(10)// 'start'//achar(10)// 'static'//achar(10)// &
                 'stddev_pop'//achar(10)// 'stddev_samp'//achar(10)// 'submultiset'//achar(10)// 'subset'//achar(10)// &
                 'substring'//achar(10)// 'substring_regex'//achar(10)// 'succeeds'//achar(10)// 'sum'//achar(10)// &
                 'symmetric'//achar(10)// 'system'//achar(10)// 'system_time'//achar(10)// 'system_user'//achar(10)// &
                 'table'//achar(10)// 'tablesample'//achar(10)// 'tan'//achar(10)// 'tanh'//achar(10)// &
                 'then'//achar(10)// 'time'//achar(10)// 'timestamp'//achar(10)// 'timezone_hour'//achar(10)// &
                 'timezone_minute'//achar(10)// 'to'//achar(10)// 'trailing'//achar(10)// 'translate'//achar(10)// &
                 'translate_regex'//achar(10)// 'translation'//achar(10)// 'treat'//achar(10)// 'trigger'//achar(10)// &
                 'trim'//achar(10)// 'trim_array'//achar(10)// 'true'//achar(10)// 'truncate'//achar(10)// &
                 'uescape'//achar(10)// 'union'//achar(10)// 'unique'//achar(10)// 'unknown'//achar(10)// &
                 'unnest'//achar(10)// 'update'//achar(10)// 'upper'//achar(10)// 'user'//achar(10)// &
                 'using'//achar(10)// 'value'//achar(10)// 'values'//achar(10)// 'value_of'//achar(10)// &
                 'varbinary'//achar(10)// 'varchar'//achar(10)// 'varying'//achar(10)// 'var_pop'//achar(10)// &
                 'var_samp'//achar(10)// 'versioning'//achar(10)// 'when'//achar(10)// 'whenever'//achar(10)// &
                 'where'//achar(10)// 'width_bucket'//achar(10)// 'window'//achar(10)// 'with'//achar(10)// &
                 'within'//achar(10)// 'without'//achar(10)// 'year'
      case (13_int32)
         value = 'C:isPunctuation C:getIdentifier C:getNumber - - -'
      endselect
   case ('WGSL')
      select case (field)
      case (1_int32)
         value = '//'
      case (3_int32)
         value = '/*'
      case (4_int32)
         value = '*/'
      case (9_int32)
         value = '0 92 0 1 1 0 0'
      case (10_int32)
         value = 'alias'//achar(10)// 'break'//achar(10)// 'case'//achar(10)// 'const'//achar(10)// &
                 'const_assert'//achar(10)// 'continue'//achar(10)// 'continuing'//achar(10)// 'default'//achar(10)// &
                 'diagnostic'//achar(10)// 'discard'//achar(10)// 'else'//achar(10)// 'enable'//achar(10)// &
                 'false'//achar(10)// 'fn'//achar(10)// 'for'//achar(10)// 'if'//achar(10)// 'let'//achar(10)// &
                 'loop'//achar(10)// 'override'//achar(10)// 'requires'//achar(10)// 'return'//achar(10)// &
                 'struct'//achar(10)// 'switch'//achar(10)// 'true'//achar(10)// 'type'//achar(10)// 'var'//achar(10)// &
                 'while'//achar(10)// 'asm'//achar(10)// 'do'//achar(10)// 'enum'//achar(10)// 'goto'//achar(10)// &
                 'inline'//achar(10)// 'noinline'//achar(10)// 'precedence'//achar(10)// 'read_only'//achar(10)// &
                 'self'//achar(10)// 'sizeof'//achar(10)// 'static'//achar(10)// 'target'//achar(10)// &
                 'typeof'//achar(10)// 'using'//achar(10)// '@align'//achar(10)// '@binding'//achar(10)// &
                 '@builtin'//achar(10)// '@compute'//achar(10)// '@const'//achar(10)// '@fragment'//achar(10)// &
                 '@group'//achar(10)// '@id'//achar(10)// '@interpolate'//achar(10)// '@invariant'//achar(10)// &
                 '@location'//achar(10)// '@must_use'//achar(10)// '@size'//achar(10)// '@vertex'//achar(10)// &
                 '@workgroup_size'//achar(10)// 'bool'//achar(10)// 'f16'//achar(10)// 'f32'//achar(10)// &
                 'i32'//achar(10)// 'u32'//achar(10)// 'array'//achar(10)// 'atomic'//achar(10)// 'mat2x2'//achar(10)// &
                 'mat2x3'//achar(10)// 'mat2x4'//achar(10)// 'mat3x2'//achar(10)// 'mat3x3'//achar(10)// &
                 'mat3x4'//achar(10)// 'mat4x2'//achar(10)// 'mat4x3'//achar(10)// 'mat4x4'//achar(10)// &
                 'ptr'//achar(10)// 'sampler'//achar(10)// 'sampler_comparison'//achar(10)// 'texture_1d'//achar(10)// &
                 'texture_2d'//achar(10)// 'texture_2d_array'//achar(10)// 'texture_3d'//achar(10)// &
                 'texture_cube'//achar(10)// 'texture_cube_array'//achar(10)// 'texture_multisampled_2d'//achar(10)// &
                 'texture_storage_1d'//achar(10)// 'texture_storage_2d'//achar(10)// &
                 'texture_storage_2d_array'//achar(10)// 'texture_storage_3d'//achar(10)// &
                 'texture_depth_2d'//achar(10)// 'texture_depth_2d_array'//achar(10)// &
                 'texture_depth_cube'//achar(10)// 'texture_depth_cube_array'//achar(10)// &
                 'texture_depth_multisampled_2d'//achar(10)// 'vec2'//achar(10)// 'vec3'//achar(10)// &
                 'vec4'//achar(10)// 'vec2i'//achar(10)// 'vec3i'//achar(10)// 'vec4i'//achar(10)// 'vec2u'//achar(10)// &
                 'vec3u'//achar(10)// 'vec4u'//achar(10)// 'vec2f'//achar(10)// 'vec3f'//achar(10)// &
                 'vec4f'//achar(10)// 'vec2h'//achar(10)// 'vec3h'//achar(10)// 'vec4h'//achar(10)// &
                 'mat2x2f'//achar(10)// 'mat2x3f'//achar(10)// 'mat2x4f'//achar(10)// 'mat3x2f'//achar(10)// &
                 'mat3x3f'//achar(10)// 'mat3x4f'//achar(10)// 'mat4x2f'//achar(10)// 'mat4x3f'//achar(10)// &
                 'mat4x4f'//achar(10)// 'mat2x2h'//achar(10)// 'mat3x3h'//achar(10)// 'mat4x4h'//achar(10)// &
                 'abs'//achar(10)// 'acos'//achar(10)// 'acosh'//achar(10)// 'all'//achar(10)// 'any'//achar(10)// &
                 'arrayLength'//achar(10)// 'asin'//achar(10)// 'asinh'//achar(10)// 'atan'//achar(10)// &
                 'atanh'//achar(10)// 'atan2'//achar(10)// 'bitcast'//achar(10)// 'ceil'//achar(10)// &
                 'clamp'//achar(10)// 'cos'//achar(10)// 'cosh'//achar(10)// 'countLeadingZeros'//achar(10)// &
                 'countOneBits'//achar(10)// 'countTrailingZeros'//achar(10)// 'cross'//achar(10)// &
                 'degrees'//achar(10)// 'determinant'//achar(10)// 'distance'//achar(10)// 'dot'//achar(10)// &
                 'exp'//achar(10)// 'exp2'//achar(10)// 'faceForward'//achar(10)// 'firstLeadingBit'//achar(10)// &
                 'firstTrailingBit'//achar(10)// 'floor'//achar(10)// 'fma'//achar(10)// 'fract'//achar(10)// &
                 'frexp'//achar(10)// 'fwidth'//achar(10)// 'fwidthCoarse'//achar(10)// 'fwidthFine'//achar(10)// &
                 'inverseSqrt'//achar(10)// 'ldexp'//achar(10)// 'length'//achar(10)// 'log'//achar(10)// &
                 'log2'//achar(10)// 'max'//achar(10)// 'min'//achar(10)// 'mix'//achar(10)// 'modf'//achar(10)// &
                 'normalize'//achar(10)// 'pow'//achar(10)// 'quantizeToF16'//achar(10)// 'radians'//achar(10)// &
                 'reflect'//achar(10)// 'refract'//achar(10)// 'reverseBits'//achar(10)// 'round'//achar(10)// &
                 'saturate'//achar(10)// 'select'//achar(10)// 'sign'//achar(10)// 'sin'//achar(10)// &
                 'sinh'//achar(10)// 'smoothstep'//achar(10)// 'sqrt'//achar(10)// 'step'//achar(10)// &
                 'storageBarrier'//achar(10)// 'tan'//achar(10)// 'tanh'//achar(10)// 'transpose'//achar(10)// &
                 'trunc'//achar(10)// 'workgroupBarrier'//achar(10)// 'textureDimensions'//achar(10)// &
                 'textureGather'//achar(10)// 'textureGatherCompare'//achar(10)// 'textureLoad'//achar(10)// &
                 'textureSample'//achar(10)// 'textureSampleBias'//achar(10)// 'textureSampleCompare'//achar(10)// &
                 'textureSampleCompareLevel'//achar(10)// 'textureSampleGrad'//achar(10)// &
                 'textureSampleLevel'//achar(10)// 'textureStore'
      case (13_int32)
         value = 'C:isPunctuation C:getIdentifier C:getNumber - - -'
      endselect
   endselect
   endsubroutine fork_data
endmodule figure_code_languages_fork
