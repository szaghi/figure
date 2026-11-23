!< figure_plot_hash, the plot frame's IDs: Dear ImGui's string hash with a given seed, computed in place.
module figure_plot_hash
!< figure_plot_hash, the plot frame's IDs: Dear ImGui's string hash with a given seed, computed in place.
!<
!< szaghi/figure#15 P10. ImPlot keys a plot's items by `ImGui::GetID(label)` under the override ID `plot.ID - 1`
!< (`SetupFinish` pushes it): the hash of the label seeded with that ID. figure_core gives the ID of a label in the
!< current ID stack only (`core_get_id`), so the frame hashes an item's label itself, with the seed it chooses:
!< `plot_hash(label, seed)` is Dear ImGui's `ImHashStr(label, 0, seed)` bit for bit (imgui.cpp, 1.93: CRC32c,
!< the reflected Castagnoli polynomial 0x82F63B78, of the table `GCrc32LookupTable` computed bit by bit; `###` resets
!< the hash to the seed, so `"a###b"` and `"c###b"` have the same ID; the label read up to its end or its first NUL).
!< No allocation: the label is read in place. Unsigned 32-bit values are held in 64-bit integers and returned as the
!< `int32` of the same bits (ADR 0001, "Unsigned arithmetic made explicit").
use, intrinsic :: iso_fortran_env, only : int32, int64

implicit none
private
public :: plot_hash, plot_id_offset

integer(int64), parameter :: POLY = int(z'82F63B78', int64) !< CRC32c's reflected polynomial.
integer(int64), parameter :: MASK = int(z'FFFFFFFF', int64) !< The low 32 bits.

contains
   pure function plot_hash(label, seed) result(id)
   !< `ImHashStr(label, 0, seed)`: the ID of `label` in an ID stack whose top is `seed`.
   character(len=*), intent(in) :: label !< Label (`###` as Dear ImGui reads it).
   integer(int32),   intent(in) :: seed  !< Seed (an `ImGuiID`'s bits).
   integer(int32)               :: id    !< ID (an `ImGuiID`'s bits).
   integer(int64)               :: s     !< The seed complemented.
   integer(int64)               :: crc   !< Running CRC.
   integer(int32)               :: i, n  !< Byte, bytes.
   integer(int32)               :: b     !< Bit.
   integer(int32)               :: c     !< Byte value.

   s = iand(not(iand(int(seed, int64), MASK)), MASK)
   crc = s
   n = len(label, kind=int32)
   i = 1_int32
   do while (i <= n)
      c = iand(ichar(label(i:i), kind=int32), 255_int32)
      if (c == 0_int32) exit
      if (c == 35_int32 .and. i + 2_int32 <= n) then ! '#'
         if (label(i + 1_int32:i + 2_int32) == '##') then
            crc = s
            i = i + 3_int32
            cycle
         endif
      endif
      crc = ieor(crc, int(c, int64))
      do b = 1_int32, 8_int32
         if (iand(crc, 1_int64) /= 0_int64) then
            crc = ieor(ishft(crc, -1), POLY)
         else
            crc = ishft(crc, -1)
         endif
      enddo
      i = i + 1_int32
   enddo
   id = to_int32(iand(not(crc), MASK))
   endfunction plot_hash

   pure function plot_id_offset(id, offset) result(o)
   !< An ID plus an offset modulo 2**32 (ImPlot's `plot.ID - 1`, `plot.ID + idx + 1`).
   integer(int32), intent(in) :: id     !< ID's bits.
   integer(int32), intent(in) :: offset !< Offset.
   integer(int32)             :: o      !< The sum's bits.

   o = to_int32(iand(iand(int(id, int64), MASK) + int(offset, int64), MASK))
   endfunction plot_id_offset

   pure function to_int32(u) result(v)
   !< An unsigned 32-bit value (0 <= u < 2**32) as the `int32` of the same bits.
   integer(int64), intent(in) :: u !< Unsigned value.
   integer(int32)             :: v !< Its bits.

   if (u >= 2147483648_int64) then
      v = int(u - 4294967296_int64, int32)
   else
      v = int(u, int32)
   endif
   endfunction to_int32
endmodule figure_plot_hash
