!< figure_plot_colormaps, the plot frame's colormaps: ImPlot's, FIGURE's bundled ones and the style's line colours.
module figure_plot_colormaps
!< figure_plot_colormaps, the plot frame's colormaps: ImPlot's, FIGURE's bundled ones and the style's line colours.
!<
!< szaghi/figure#15 P10, step 7. A registry of colormaps as ImPlot keeps them (`ImPlotColormapData`), integer ids in
!< ImPlot's order: 0-15 ImPlot's own maps (`Initialize`, their keys copied from implot.cpp: Deep, Dark, Pastel,
!< Paired qualitative; Viridis ... Greys continuous), then the maps registered at run time (`cm_register`, as
!< `AddColormap`: a name taken is refused). Each map keeps its keys and its table (`_AppendTable`: a qualitative
!< map's table is its keys; a continuous one's 255 steps between each two keys, `ImMixU32`, then the last key);
!< `cm_key` (`GetColormapColorU32`: the key `idx` modulo the count), `cm_sample` (`SampleColormapU32`,
!< `LerpTable`), `cm_size`, `cm_is_qual`.
!<
!< `cm_colormap(name, levels)` resolves a name as FIGURE's `ip_colormap` does (native/figure_colormap.cpp): one of
!< ImPlot's maps, a bundled one (figure_plot_colormaps_bundled, generated from third_party/colormaps/<name>.csv), or the
!< reverse of either (`<name>_r`), cut into `levels` bands (`<name>|<levels>`, qualitative, each band the map's
!< colour at its centre); registered at its first use under that name, its keys packed as Dear ImGui packs a float
!< colour (`ColorConvertFloat4ToU32`). User maps (`ip_load_colormap`) and edited ones (`ig_gradient_edit`) are not
!< here yet.
!<
!< The style's map (`ImPlotStyle::Colormap`, the automatic colours of the plot items): `cm_style_refresh` reads the
!< line colours of FIGURE's style in effect (`fig_style_lines`, FIGURE's own state, not ImPlot's) when they changed,
!< registers them as a qualitative map (named by its colours, so a style used again reuses it) and makes it current;
!< none: ImPlot's Deep. `cm_push` and `cm_pop` (`PushColormap`, `PopColormap`) stack the current map. Sums of
!< products in statements of their own (nvfortran -O2 fuses `a*b + c`, ImPlot's build does not).
use, intrinsic :: iso_c_binding, only : c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_c_native, only : fig_style_lines
use figure_plot_colormaps_bundled, only : BUNDLED_COUNT, BUNDLED_NAMES, BUNDLED_SAMPLES, bundled_map

implicit none
private
public :: cm_colormap, cm_count, cm_current, cm_index, cm_is_qual, cm_key, cm_pop, cm_push, cm_register, cm_sample
public :: cm_size, cm_style_refresh, mix_u32, pack_float4
public :: CM_DEEP, CM_VIRIDIS

integer(int32), parameter :: CM_DEEP = 0_int32    !< ImPlotColormap_Deep.
integer(int32), parameter :: CM_VIRIDIS = 4_int32 !< ImPlotColormap_Viridis.
integer(int32), parameter :: MAX_LINES = 256_int32 !< The style's line colours read at most.
integer(int32), parameter :: MAX_LEVELS = 256_int32 !< Bands of a discrete map at most.
! ImPlot's maps (implot.cpp, Initialize): their keys (IM_RGB, map after map), counts, names, kinds
integer(int32), parameter :: IMPLOT_RGB(3, 163) = reshape([76_int32, 114_int32, 176_int32, 221_int32, 132_int32, &
                                                       82_int32, 85_int32, 168_int32, 104_int32, 196_int32, 78_int32, &
                                                       82_int32, 129_int32, 114_int32, 179_int32, 147_int32, &
                                                       120_int32, 96_int32, 218_int32, 139_int32, 195_int32, &
                                                       140_int32, 140_int32, 140_int32, 204_int32, 185_int32, &
                                                       116_int32, 100_int32, 181_int32, 205_int32, 228_int32, &
                                                       26_int32, 28_int32, 55_int32, 126_int32, 184_int32, 77_int32, &
                                                       175_int32, 74_int32, 152_int32, 78_int32, 163_int32, 255_int32, &
                                                       127_int32, 0_int32, 255_int32, 255_int32, 51_int32, 166_int32, &
                                                       86_int32, 40_int32, 247_int32, 129_int32, 191_int32, 153_int32, &
                                                       153_int32, 153_int32, 251_int32, 180_int32, 174_int32, &
                                                       179_int32, 205_int32, 227_int32, 204_int32, 235_int32, &
                                                       197_int32, 222_int32, 203_int32, 228_int32, 254_int32, &
                                                       217_int32, 166_int32, 255_int32, 255_int32, 204_int32, &
                                                       229_int32, 216_int32, 189_int32, 253_int32, 218_int32, &
                                                       236_int32, 242_int32, 242_int32, 242_int32, 66_int32, &
                                                       206_int32, 227_int32, 31_int32, 120_int32, 180_int32, &
                                                       178_int32, 223_int32, 138_int32, 51_int32, 160_int32, 44_int32, &
                                                       251_int32, 154_int32, 153_int32, 227_int32, 26_int32, 28_int32, &
                                                       253_int32, 191_int32, 111_int32, 255_int32, 127_int32, 0_int32, &
                                                       202_int32, 178_int32, 214_int32, 106_int32, 61_int32, &
                                                       154_int32, 255_int32, 255_int32, 153_int32, 177_int32, &
                                                       89_int32, 40_int32, 68_int32, 1_int32, 84_int32, 72_int32, &
                                                       36_int32, 117_int32, 65_int32, 68_int32, 135_int32, 53_int32, &
                                                       95_int32, 141_int32, 42_int32, 120_int32, 142_int32, 33_int32, &
                                                       145_int32, 140_int32, 34_int32, 168_int32, 132_int32, 68_int32, &
                                                       191_int32, 112_int32, 122_int32, 209_int32, 81_int32, &
                                                       189_int32, 223_int32, 38_int32, 253_int32, 231_int32, 37_int32, &
                                                       13_int32, 8_int32, 135_int32, 65_int32, 4_int32, 157_int32, &
                                                       106_int32, 0_int32, 168_int32, 143_int32, 13_int32, 164_int32, &
                                                       177_int32, 42_int32, 144_int32, 204_int32, 71_int32, 120_int32, &
                                                       225_int32, 100_int32, 98_int32, 242_int32, 132_int32, 75_int32, &
                                                       252_int32, 166_int32, 54_int32, 252_int32, 206_int32, 37_int32, &
                                                       240_int32, 249_int32, 33_int32, 64_int32, 0_int32, 0_int32, &
                                                       128_int32, 0_int32, 0_int32, 191_int32, 0_int32, 0_int32, &
                                                       255_int32, 0_int32, 0_int32, 255_int32, 64_int32, 0_int32, &
                                                       255_int32, 128_int32, 0_int32, 255_int32, 191_int32, 0_int32, &
                                                       255_int32, 255_int32, 0_int32, 255_int32, 255_int32, 85_int32, &
                                                       255_int32, 255_int32, 170_int32, 255_int32, 255_int32, &
                                                       255_int32, 0_int32, 255_int32, 255_int32, 26_int32, 230_int32, &
                                                       255_int32, 51_int32, 204_int32, 255_int32, 77_int32, 179_int32, &
                                                       255_int32, 102_int32, 153_int32, 255_int32, 128_int32, &
                                                       128_int32, 255_int32, 153_int32, 102_int32, 255_int32, &
                                                       179_int32, 77_int32, 255_int32, 204_int32, 51_int32, 255_int32, &
                                                       230_int32, 26_int32, 255_int32, 255_int32, 0_int32, 255_int32, &
                                                       74_int32, 0_int32, 0_int32, 123_int32, 66_int32, 66_int32, &
                                                       158_int32, 93_int32, 93_int32, 186_int32, 114_int32, 114_int32, &
                                                       198_int32, 151_int32, 132_int32, 208_int32, 180_int32, &
                                                       147_int32, 218_int32, 206_int32, 161_int32, 228_int32, &
                                                       228_int32, 174_int32, 237_int32, 237_int32, 205_int32, &
                                                       246_int32, 246_int32, 231_int32, 255_int32, 255_int32, &
                                                       255_int32, 0_int32, 0_int32, 170_int32, 0_int32, 0_int32, &
                                                       255_int32, 0_int32, 85_int32, 255_int32, 0_int32, 170_int32, &
                                                       255_int32, 0_int32, 255_int32, 255_int32, 85_int32, 255_int32, &
                                                       170_int32, 170_int32, 255_int32, 85_int32, 255_int32, &
                                                       255_int32, 0_int32, 255_int32, 170_int32, 0_int32, 255_int32, &
                                                       85_int32, 0_int32, 255_int32, 0_int32, 0_int32, 226_int32, &
                                                       217_int32, 226_int32, 166_int32, 191_int32, 202_int32, &
                                                       109_int32, 144_int32, 192_int32, 95_int32, 88_int32, 176_int32, &
                                                       83_int32, 30_int32, 124_int32, 47_int32, 20_int32, 54_int32, &
                                                       100_int32, 25_int32, 75_int32, 159_int32, 60_int32, 80_int32, &
                                                       192_int32, 117_int32, 94_int32, 208_int32, 179_int32, &
                                                       158_int32, 226_int32, 217_int32, 226_int32, 103_int32, 0_int32, &
                                                       31_int32, 178_int32, 24_int32, 43_int32, 214_int32, 96_int32, &
                                                       77_int32, 244_int32, 165_int32, 130_int32, 253_int32, &
                                                       219_int32, 199_int32, 247_int32, 247_int32, 247_int32, &
                                                       209_int32, 229_int32, 240_int32, 146_int32, 197_int32, &
                                                       222_int32, 67_int32, 147_int32, 195_int32, 33_int32, 102_int32, &
                                                       172_int32, 5_int32, 48_int32, 97_int32, 84_int32, 48_int32, &
                                                       5_int32, 140_int32, 81_int32, 10_int32, 191_int32, 129_int32, &
                                                       45_int32, 223_int32, 194_int32, 125_int32, 246_int32, &
                                                       232_int32, 195_int32, 245_int32, 245_int32, 245_int32, &
                                                       199_int32, 234_int32, 229_int32, 128_int32, 205_int32, &
                                                       193_int32, 53_int32, 151_int32, 143_int32, 1_int32, 102_int32, &
                                                       94_int32, 0_int32, 60_int32, 48_int32, 142_int32, 1_int32, &
                                                       82_int32, 197_int32, 27_int32, 125_int32, 222_int32, 119_int32, &
                                                       174_int32, 241_int32, 182_int32, 218_int32, 253_int32, &
                                                       224_int32, 239_int32, 247_int32, 247_int32, 247_int32, &
                                                       230_int32, 245_int32, 208_int32, 184_int32, 225_int32, &
                                                       134_int32, 127_int32, 188_int32, 65_int32, 77_int32, 146_int32, &
                                                       33_int32, 39_int32, 100_int32, 25_int32, 158_int32, 1_int32, &
                                                       66_int32, 213_int32, 62_int32, 79_int32, 244_int32, 109_int32, &
                                                       67_int32, 253_int32, 174_int32, 97_int32, 254_int32, 224_int32, &
                                                       139_int32, 255_int32, 255_int32, 191_int32, 230_int32, &
                                                       245_int32, 152_int32, 171_int32, 221_int32, 164_int32, &
                                                       102_int32, 194_int32, 165_int32, 50_int32, 136_int32, &
                                                       189_int32, 94_int32, 79_int32, 162_int32, 255_int32, 255_int32, &
                                                       255_int32, 0_int32, 0_int32, 0_int32], [3, 163]) !< Keys, RGB.
integer(int32), parameter :: IMPLOT_COUNTS(16) = [10_int32, 9_int32, 9_int32, 12_int32, 11_int32, 11_int32, 11_int32, &
                                                       11_int32, 11_int32, 11_int32, 11_int32, 11_int32, 11_int32, &
                                                       11_int32, 11_int32, 2_int32] !< Keys of each.
character(len=8), parameter :: IMPLOT_NAMES(16) = ['Deep    ', 'Dark    ', 'Pastel  ', 'Paired  ', 'Viridis ', &
                                                       'Plasma  ', 'Hot     ', 'Cool    ', 'Pink    ', 'Jet     ', &
                                                       'Twilight', 'RdBu    ', 'BrBG    ', 'PiYG    ', 'Spectral', &
                                                       'Greys   '] !< Names (ImPlotColormap_*).
logical,        parameter :: IMPLOT_QUAL(16) = [.true., .true., .true., .true., .false., .false., .false., .false., &
                                                       .false., .false., .false., .false., .false., .false., .false., &
                                                       .false.] !< Qualitative.

! the registry (ImPlotColormapData), structure of arrays; ids 0-based as ImPlot's, slot id + 1
integer(int32)                :: n_maps = 0_int32   !< Maps registered.
integer(int32),   allocatable :: key_off(:)         !< A map's first key in `keys` (0-based offset).
integer(int32),   allocatable :: key_cnt(:)         !< ... its keys.
integer(int32),   allocatable :: tab_off(:)         !< ... its table's first entry in `tables`.
integer(int32),   allocatable :: tab_size(:)        !< ... its table's size.
integer(int32),   allocatable :: name_off(:)        !< ... its name's start in `names`.
integer(int32),   allocatable :: name_len(:)        !< ... its name's length.
logical,          allocatable :: quals(:)           !< ... qualitative.
integer(int32),   allocatable :: keys(:)            !< Keys of all the maps (packed colours).
integer(int32)                :: n_keys = 0_int32   !< ... in use.
integer(int32),   allocatable :: tables(:)          !< Tables of all the maps.
integer(int32)                :: n_tab = 0_int32    !< ... in use.
character(len=:), allocatable :: names              !< Names of all the maps.
integer(int32)                :: n_names = 0_int32  !< ... characters in use.
! the style's map and its stack (ImPlotStyle::Colormap, ColormapModifiers)
integer(int32)                :: current = CM_DEEP  !< The map in effect.
integer(int32),   allocatable :: stack(:)           !< Maps pushed over.
integer(int32)                :: n_stack = 0_int32  !< ... their number.
logical                       :: style_read = .false. !< The style's lines read once.
integer(c_int)                :: style_gen = 0_c_int  !< Their generation then.

contains
   ! the registry

   subroutine init()
   !< ImPlot's maps registered first, in ImPlot's order (`Initialize`).
   integer(int32) :: k, o, id !< Map, its first key, its id.
   integer(int32) :: packed(16) !< Its keys.
   integer(int32) :: i          !< Key.

   if (n_maps > 0_int32) return
   o = 0_int32
   do k = 1_int32, 16_int32
      do i = 1_int32, IMPLOT_COUNTS(k)
         packed(i) = rgb_u32(IMPLOT_RGB(:, o + i))
      enddo
      id = cm_register(trim(IMPLOT_NAMES(k)), packed(1:IMPLOT_COUNTS(k)), IMPLOT_QUAL(k))
      o = o + IMPLOT_COUNTS(k)
   enddo
   endsubroutine init

   function cm_count() result(n)
   !< Maps registered (`GetColormapCount`).
   integer(int32) :: n !< Maps.

   call init()
   n = n_maps
   endfunction cm_count

   function cm_index(name) result(id)
   !< The id of a map by name (`GetColormapIndex`); -1 if none.
   character(len=*), intent(in) :: name !< Name.
   integer(int32)               :: id   !< Id.
   integer(int32)               :: k    !< Counter.

   call init()
   id = -1_int32
   do k = 1_int32, n_maps
      if (name_len(k) /= len(name, kind=int32)) cycle
      if (names(name_off(k):name_off(k) + name_len(k) - 1_int32) == name) then
         id = k - 1_int32
         return
      endif
   enddo
   endfunction cm_index

   function cm_register(name, colors, qual) result(id)
   !< A map registered (`AddColormap`, `Append`, `_AppendTable`); -1 if the name is taken (ImPlot cannot replace one).
   character(len=*), intent(in) :: name      !< Name.
   integer(int32),   intent(in) :: colors(:) !< Keys (packed colours, at least 1; a continuous map at least 2).
   logical,          intent(in) :: qual      !< Qualitative.
   integer(int32)               :: id        !< Id.
   integer(int32)               :: n, m, k, i, s !< Keys, table size, slot, counters.

   if (n_maps > 0_int32) then
      if (cm_index(name) >= 0_int32) then
         id = -1_int32
         return
      endif
   endif
   n = size(colors, kind=int32)
   if (qual) then
      m = n
   else
      m = 255_int32 * (n - 1_int32) + 1_int32
   endif
   call room(n, m, len(name, kind=int32))
   n_maps = n_maps + 1_int32
   k = n_maps
   key_off(k) = n_keys
   key_cnt(k) = n
   keys(n_keys + 1_int32:n_keys + n) = colors
   n_keys = n_keys + n
   name_off(k) = n_names + 1_int32
   name_len(k) = len(name, kind=int32)
   names(n_names + 1_int32:n_names + len(name, kind=int32)) = name
   n_names = n_names + len(name, kind=int32)
   quals(k) = qual
   tab_off(k) = n_tab
   tab_size(k) = m
   if (qual) then
      tables(n_tab + 1_int32:n_tab + n) = colors
   else
      do i = 1_int32, n - 1_int32
         do s = 0_int32, 254_int32
            tables(n_tab + (i - 1_int32) * 255_int32 + s + 1_int32) = mix_u32(colors(i), colors(i + 1_int32), s)
         enddo
      enddo
      tables(n_tab + m) = colors(n)
   endif
   n_tab = n_tab + m
   id = k - 1_int32
   endfunction cm_register

   subroutine room(nk, nt, nc)
   !< Room for one more map of nk keys, a table of nt entries and a name of nc characters (columns doubled).
   integer(int32), intent(in)    :: nk, nt, nc !< Keys, table entries, characters.
   integer(int32), allocatable   :: a(:), b(:), c(:), d(:), e(:), f(:), t(:) !< Grown columns.
   logical,        allocatable   :: q(:)       !< ...
   character(len=:), allocatable :: more       !< Grown names.
   integer(int32)                :: m          !< Slots.

   if (.not. allocated(key_off)) then
      allocate(key_off(32), key_cnt(32), tab_off(32), tab_size(32), name_off(32), name_len(32), quals(32))
      allocate(keys(256), tables(8192))
      allocate(character(len=512) :: names)
   endif
   if (n_maps == size(key_off, kind=int32)) then
      m = 2_int32 * n_maps
      allocate(a(m), b(m), c(m), d(m), e(m), f(m), q(m))
      a(1:n_maps) = key_off(1:n_maps)
      b(1:n_maps) = key_cnt(1:n_maps)
      c(1:n_maps) = tab_off(1:n_maps)
      d(1:n_maps) = tab_size(1:n_maps)
      e(1:n_maps) = name_off(1:n_maps)
      f(1:n_maps) = name_len(1:n_maps)
      q(1:n_maps) = quals(1:n_maps)
      call move_alloc(a, key_off)
      call move_alloc(b, key_cnt)
      call move_alloc(c, tab_off)
      call move_alloc(d, tab_size)
      call move_alloc(e, name_off)
      call move_alloc(f, name_len)
      call move_alloc(q, quals)
   endif
   if (n_keys + nk > size(keys, kind=int32)) then
      allocate(t(max(2_int32 * size(keys, kind=int32), n_keys + nk)))
      t(1:n_keys) = keys(1:n_keys)
      call move_alloc(t, keys)
   endif
   if (n_tab + nt > size(tables, kind=int32)) then
      allocate(t(max(2_int32 * size(tables, kind=int32), n_tab + nt)))
      t(1:n_tab) = tables(1:n_tab)
      call move_alloc(t, tables)
   endif
   if (n_names + nc > len(names, kind=int32)) then
      allocate(character(len=max(2_int32 * len(names, kind=int32), n_names + nc)) :: more)
      more(1:n_names) = names(1:n_names)
      call move_alloc(more, names)
   endif
   endsubroutine room

   function cm_size(id) result(n)
   !< A map's keys (`GetColormapSize`).
   integer(int32), intent(in) :: id !< Map.
   integer(int32)             :: n  !< Keys.

   call init()
   n = key_cnt(id + 1_int32)
   endfunction cm_size

   function cm_is_qual(id) result(yes)
   !< A map is qualitative.
   integer(int32), intent(in) :: id  !< Map.
   logical                    :: yes !< Qualitative.

   call init()
   yes = quals(id + 1_int32)
   endfunction cm_is_qual

   function cm_key(id, idx) result(col)
   !< A map's key `idx` (0-based) modulo its count (`GetColormapColorU32`).
   integer(int32), intent(in) :: id  !< Map.
   integer(int32), intent(in) :: idx !< Key.
   integer(int32)             :: col !< Packed colour.

   call init()
   col = keys(key_off(id + 1_int32) + mod(idx, key_cnt(id + 1_int32)) + 1_int32)
   endfunction cm_key

   function cm_sample(id, t) result(col)
   !< A map's colour at t (`SampleColormapU32`, `LerpTable`): a qualitative map's key `(int)(size t)` clamped, a
   !< continuous map's table entry `(int)((size - 1) t + 0.5f)`.
   integer(int32), intent(in) :: id  !< Map.
   real(real32),   intent(in) :: t   !< Position in [0, 1].
   integer(int32)             :: col !< Packed colour.
   integer(int32)             :: k, siz, idx !< Slot, table size, entry.
   real(real32)               :: x   !< Entry, unrounded.

   call init()
   k = id + 1_int32
   siz = tab_size(k)
   if (quals(k)) then
      x = real(siz, real32) * t
      idx = min(max(int(x, int32), 0_int32), siz - 1_int32)
   else
      x = real(siz - 1_int32, real32) * t
      x = x + 0.5_real32
      idx = int(x, int32)
   endif
   col = tables(tab_off(k) + idx + 1_int32)
   endfunction cm_sample

   ! FIGURE's names (ip_colormap)

   function cm_colormap(name, levels) result(id)
   !< The id of a map by FIGURE's name (`fig_colormap`): ImPlot's, a bundled one, `<name>_r` reversed, cut into
   !< `levels` bands (2-256; 0 or absent: continuous), registered at its first use; -1 for an unknown name or levels.
   character(len=*), intent(in)           :: name   !< Name.
   integer(int32),   intent(in), optional :: levels !< Bands (0: none).
   integer(int32)                         :: id     !< Id.
   character(len=:), allocatable          :: base, reg !< The map's base name, its registered name.
   real(real64),     allocatable          :: rgb(:,:)  !< Its keys, components in [0, 1].
   integer(int32),   allocatable          :: packed(:) !< ... packed.
   integer(int32)                         :: lv, b, k, n, j !< Bands, ImPlot's map, counters.
   logical                                :: reversed, qual !< `_r`, qualitative.
   character(len=8)                       :: tag    !< Bands, printed.

   call init()
   id = -1_int32
   lv = 0_int32
   if (present(levels)) lv = levels
   if (lv /= 0_int32 .and. (lv < 2_int32 .or. lv > MAX_LEVELS)) return
   base = name
   reversed = .false.
   if (.not. known(base)) then
      if (len(name) <= 2) return
      if (name(len(name) - 1:) /= '_r') return
      base = name(1:len(name) - 2)
      if (.not. known(base)) return
      reversed = .true.
   endif
   b = builtin(base)
   if (b >= 0_int32 .and. .not. reversed .and. lv == 0_int32) then
      id = b
      return
   endif
   if (lv > 0_int32) then
      write(tag, '(I0)') lv
      reg = name//'|'//trim(tag)
   else
      reg = name
   endif
   id = cm_index(reg)
   if (id >= 0_int32) return
   if (b >= 0_int32) then ! ImPlot's map: its keys as floats (ColorConvertU32ToFloat4)
      qual = quals(b + 1_int32)
      n = key_cnt(b + 1_int32)
      allocate(rgb(3, n))
      do k = 1_int32, n
         do j = 0_int32, 2_int32
            rgb(j + 1_int32, k) = real(real(channel(cm_key(b, k - 1_int32), j), real32) * (1.0_real32 / 255.0_real32), &
                                       real64)
         enddo
      enddo
   else
      qual = .false.
      do k = 1_int32, BUNDLED_COUNT
         if (trim(BUNDLED_NAMES(k)) == base) exit
      enddo
      allocate(rgb(3, BUNDLED_SAMPLES))
      rgb = bundled_map(k)
      n = BUNDLED_SAMPLES
   endif
   if (reversed) rgb = rgb(:, n:1:-1)
   if (lv > 0_int32) then ! a band each, the map's colour at its centre
      allocate(packed(lv))
      do k = 0_int32, lv - 1_int32
         packed(k + 1_int32) = pack_float4(band(rgb, n, (real(k, real64) + 0.5_real64) / real(lv, real64), qual), &
                                           1.0_real64)
      enddo
      qual = .true.
   else
      allocate(packed(n))
      do k = 1_int32, n
         packed(k) = pack_float4(rgb(:, k), 1.0_real64)
      enddo
   endif
   id = cm_register(reg, packed, qual)
   endfunction cm_colormap

   function known(name) result(yes)
   !< A name of ImPlot's maps or of the bundled ones.
   character(len=*), intent(in) :: name !< Name.
   logical                      :: yes  !< Known.
   integer(int32)               :: k    !< Counter.

   yes = builtin(name) >= 0_int32
   if (yes) return
   do k = 1_int32, BUNDLED_COUNT
      if (trim(BUNDLED_NAMES(k)) == name) then
         yes = .true.
         return
      endif
   enddo
   endfunction known

   pure function builtin(name) result(id)
   !< The id of one of ImPlot's maps by name; -1 if none.
   character(len=*), intent(in) :: name !< Name.
   integer(int32)               :: id   !< Id.
   integer(int32)               :: k    !< Counter.

   id = -1_int32
   do k = 1_int32, 16_int32
      if (trim(IMPLOT_NAMES(k)) == name) then
         id = k - 1_int32
         return
      endif
   enddo
   endfunction builtin

   pure function band(rgb, n, t, qual) result(c)
   !< A band's colour (`variant_keys`): a qualitative map's key at t, else the table interpolated (`lerp`).
   real(real64),   intent(in) :: rgb(:,:) !< Keys (3, n).
   integer(int32), intent(in) :: n        !< Keys.
   real(real64),   intent(in) :: t        !< Position in [0, 1].
   logical,        intent(in) :: qual     !< Qualitative.
   real(real64)               :: c(3)     !< Colour.
   real(real64)               :: x, w, a, b !< Position among the keys, weight, terms.
   integer(int32)             :: i, j     !< Key, channel.

   if (qual) then
      c = rgb(:, min(int(t * real(n, real64), int32), n - 1_int32) + 1_int32)
      return
   endif
   x = min(max(t, 0.0_real64), 1.0_real64) * real(n - 1_int32, real64)
   i = min(int(x, int32), n - 2_int32)
   w = x - real(i, real64)
   do j = 1_int32, 3_int32
      a = (1.0_real64 - w) * rgb(j, i + 1_int32)
      b = w * rgb(j, i + 2_int32)
      c(j) = a + b
   enddo
   endfunction band

   ! the style's map

   subroutine cm_style_refresh()
   !< The style's line colours (`fig_style_lines`) made the current map when they changed: a qualitative map named
   !< by them (registered once), or ImPlot's Deep when the style has none (`commit_style`).
   integer(c_int) :: cols(MAX_LINES)  !< Packed colours.
   integer(c_int) :: n, gen, status   !< Their number, generation, status.
   integer(int32) :: id, k            !< The map, counter.
   character(len=9 * MAX_LINES + 13) :: name !< Its name.

   call init()
   status = fig_style_lines(cols, int(MAX_LINES, c_int), n, gen)
   if (status /= 0_c_int) return
   if (style_read .and. gen == style_gen) return
   style_read = .true.
   style_gen = gen
   if (n <= 0_c_int) then
      current = CM_DEEP
      return
   endif
   n = min(n, int(MAX_LINES, c_int))
   name = 'FIGURE lines'
   do k = 1_int32, int(n, int32)
      write(name(13_int32 + 9_int32 * (k - 1_int32):), '(A,Z8.8)') ' ', cols(k)
   enddo
   id = cm_index(trim(name))
   if (id < 0_int32) id = cm_register(trim(name), int(cols(1:n), int32), .true.)
   current = id
   endsubroutine cm_style_refresh

   function cm_current() result(id)
   !< The map in effect (`ImPlotStyle::Colormap`).
   integer(int32) :: id !< Map.

   call init()
   id = current
   endfunction cm_current

   subroutine cm_push(id)
   !< `PushColormap`: the map in effect stacked, `id` made current.
   integer(int32), intent(in)  :: id   !< Map.
   integer(int32), allocatable :: more(:) !< Grown stack.

   call init()
   if (.not. allocated(stack)) allocate(stack(8))
   if (n_stack == size(stack, kind=int32)) then
      allocate(more(2_int32 * n_stack))
      more(1:n_stack) = stack(1:n_stack)
      call move_alloc(more, stack)
   endif
   n_stack = n_stack + 1_int32
   stack(n_stack) = current
   current = id
   endsubroutine cm_push

   subroutine cm_pop(count)
   !< `PopColormap`: the maps pushed over restored (`count`, default 1).
   integer(int32), intent(in), optional :: count !< Maps.
   integer(int32)                       :: c     !< Left to pop.

   c = 1_int32
   if (present(count)) c = count
   if (c > n_stack) error stop 'figure_plot_colormaps: cm_pop of more maps than pushed'
   do while (c > 0_int32)
      current = stack(n_stack)
      n_stack = n_stack - 1_int32
      c = c - 1_int32
   enddo
   endsubroutine cm_pop

   ! colours

   pure function pack_float4(rgb, a) result(col)
   !< `ColorConvertFloat4ToU32` of a colour given in double precision as float (`IM_F32_TO_INT8_SAT`).
   real(real64), intent(in) :: rgb(3) !< Red, green, blue in [0, 1].
   real(real64), intent(in) :: a      !< Alpha.
   integer(int32)           :: col    !< Packed colour.
   integer(int64)           :: u      !< Unsigned value.

   u = ior(ior(int(sat8(rgb(1)), int64), ishft(int(sat8(rgb(2)), int64), 8)), &
           ior(ishft(int(sat8(rgb(3)), int64), 16), ishft(int(sat8(a), int64), 24)))
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   col = int(u, int32)
   endfunction pack_float4

   pure function sat8(v) result(c)
   !< `IM_F32_TO_INT8_SAT` of a double taken as float: (int)(saturate(f) 255 + 0.5).
   real(real64), intent(in) :: v !< Component.
   integer(int32)           :: c !< 0-255.
   real(real32)             :: f !< As float.

   f = min(max(real(v, real32), 0.0_real32), 1.0_real32)
   f = f * 255.0_real32
   f = f + 0.5_real32
   c = int(f, int32)
   endfunction sat8

   pure function rgb_u32(rgb) result(col)
   !< An opaque colour packed as `IM_RGB` packs it (red in the low byte).
   integer(int32), intent(in) :: rgb(3) !< Channels 0-255.
   integer(int32)             :: col    !< Packed colour.
   integer(int64)             :: u      !< Unsigned value.

   u = ior(ior(int(rgb(1), int64), ishft(int(rgb(2), int64), 8)), ior(ishft(int(rgb(3), int64), 16), &
                                                                       ishft(255_int64, 24)))
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   col = int(u, int32)
   endfunction rgb_u32

   pure function channel(col, c) result(v)
   !< A channel of a packed colour (0 red, 1 green, 2 blue, 3 alpha), 0-255.
   integer(int32), intent(in) :: col !< Packed colour.
   integer(int32), intent(in) :: c   !< Channel.
   integer(int32)             :: v   !< Value.

   v = int(iand(ishft(int(col, int64), -8 * int(c, int64)), 255_int64), int32)
   endfunction channel

   pure function mix_u32(a, b, s) result(c)
   !< `ImMixU32` (32-bit form): a + (b - a) * s / 256 on each channel.
   integer(int32), intent(in) :: a, b !< Packed colours.
   integer(int32), intent(in) :: s    !< Weight of b, 0-256.
   integer(int32)             :: c    !< Mix.
   integer(int64)             :: ua, ub, al, ah, bl, bh, ml, mh, u !< Unsigned values.
   integer(int64), parameter  :: M32 = 4294967295_int64 !< 32 bits.

   ua = iand(int(a, int64), M32)
   ub = iand(int(b, int64), M32)
   al = iand(ua, 16711935_int64)                 ! 0x00ff00ff
   ah = ishft(iand(ua, 4278255360_int64), -8)    ! 0xff00ff00
   bl = iand(ub, 16711935_int64)
   bh = ishft(iand(ub, 4278255360_int64), -8)
   ml = iand(al * int(256_int32 - s, int64) + bl * int(s, int64), M32)
   mh = iand(ah * int(256_int32 - s, int64) + bh * int(s, int64), M32)
   u = ior(iand(mh, 4278255360_int64), ishft(iand(ml, 4278255360_int64), -8))
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   c = int(u, int32)
   endfunction mix_u32
endmodule figure_plot_colormaps
