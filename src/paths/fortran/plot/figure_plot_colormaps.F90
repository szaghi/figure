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
!< ImPlot's maps, a bundled one (figure_plot_colormaps_bundled, generated from `third_party/colormaps/<name>.csv`), or the
!< reverse of either (`<name>_r`), cut into `levels` bands (`<name>|<levels>`, qualitative, each band the map's
!< colour at its centre); registered at its first use under that name, its keys packed as Dear ImGui packs a float
!< colour (`ColorConvertFloat4ToU32`). User maps (`cm_load`, as `fig_load_colormap`: a CSV table or a ParaView preset,
!< figure_plot_colormap_files) are kept for the program's life, in load order, and resolve as the others; `cm_list_count`
!< and `cm_list_name` list the names as `fig_colormap_count` and `fig_colormap_name` (the bundled maps, ImPlot's, the
!< user's); `cm_stops` gives a map's stops as `fig_colormap_stops` (`stops_of`: every key of a table of up to 16, else
!< the keys taken greedily while the map is linear within 2/255 between them). An edited map (`cm_edit_stops`, what
!< `ig_gradient_edit` does to a map: `resample_from_stops`) keeps its stops; its table (or ImPlot's keys) is resampled
!< from them, linearly and constant beyond the ends, and every variant registered (`_r`, levels) rewritten;
!< `cm_generation` counts the edits (a field coloured with a map is coloured again).
!<
!< The style's map (`ImPlotStyle::Colormap`, the automatic colours of the plot items): `cm_style_refresh` reads the
!< line colours of FIGURE's style in effect (`fig_style_lines`, FIGURE's own state, not ImPlot's) when they changed,
!< registers them as a qualitative map (named by its colours, so a style used again reuses it) and makes it current;
!< none: ImPlot's Deep. `cm_push` and `cm_pop` (`PushColormap`, `PopColormap`) stack the current map. Sums of
!< products in statements of their own (nvfortran -O2 fuses `a*b + c`, ImPlot's build does not).
use, intrinsic :: iso_c_binding, only : c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_c_native, only : fig_style_lines, FIG_OK, FIG_ERR_ARGUMENT, FIG_ERR_FAILED
use figure_plot_colormap_files, only : cmf_csv, cmf_paraview
use figure_plot_colormaps_bundled, only : BUNDLED_COUNT, BUNDLED_NAMES, BUNDLED_SAMPLES, bundled_map

implicit none
private
public :: cm_colormap, cm_count, cm_current, cm_index, cm_is_qual, cm_key, cm_lookup, cm_pop, cm_push, cm_register
public :: cm_sample
public :: cm_size, cm_style_refresh, mix_u32, pack_float4
public :: cm_load, cm_list_count, cm_list_name, cm_stops, cm_edit_stops, cm_generation
public :: cm_gradient_slot, cm_gradient_size, cm_gradient_get, cm_stops_at
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
integer(int32),   allocatable, target :: tables(:)  !< Tables of all the maps (`cm_lookup` points into them).
integer(int32)                :: n_tab = 0_int32    !< ... in use.
character(len=:), allocatable :: names              !< Names of all the maps.
integer(int32)                :: n_names = 0_int32  !< ... characters in use.
! the style's map and its stack (ImPlotStyle::Colormap, ColormapModifiers)
integer(int32)                :: current = CM_DEEP  !< The map in effect.
integer(int32),   allocatable :: stack(:)           !< Maps pushed over.
integer(int32)                :: n_stack = 0_int32  !< ... their number.
logical                       :: style_read = .false. !< The style's lines read once.
integer(c_int)                :: style_gen = 0_c_int  !< Their generation then.
! the user's maps (`user_maps` of native/figure_colormap.cpp), in load order
integer(int32)                :: n_user = 0_int32     !< Maps loaded.
integer(int32),   allocatable :: user_off(:)          !< A map's first row in `user_rows`.
integer(int32),   allocatable :: user_cnt(:)          !< ... its rows.
integer(int32),   allocatable :: user_noff(:)         !< ... its name's start in `user_names`.
integer(int32),   allocatable :: user_nlen(:)         !< ... its length.
real(real64),     allocatable :: user_rows(:,:)       !< Their tables (3, rows), components in [0, 1].
integer(int32)                :: n_user_rows = 0_int32 !< ... rows in use.
character(len=:), allocatable :: user_names           !< Their names.
integer(int32)                :: n_user_names = 0_int32 !< ... characters in use.

type :: gradient
   !< A map edited (`gradient_t`): its stops in the editor's order and, for a bundled map, its table as edited.
   character(len=:), allocatable :: name      !< The map (its base name).
   real(real32),     allocatable :: stops(:,:) !< (r, g, b, position) each, as `ImVec4`.
   real(real64),     allocatable :: table(:,:) !< A bundled map's table as edited (3, 256).
endtype gradient
type(gradient),   allocatable :: grads(:)            !< The maps edited.
integer(int32)                :: n_grads = 0_int32   !< ... their number.
integer(int32)                :: generation = 0_int32 !< Edits made (`fig_colormap_generation`).

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

   subroutine cm_lookup(id, tab, qual)
   !< A map's table and kind, for a renderer that samples it per element (szaghi/figure#16 S3): `cm_sample(id, t)` is
   !< `tab(idx + 1)`, idx computed from `size(tab)` and t as there. The table is valid until a map is registered.
   integer(int32),                      intent(in)  :: id     !< Map.
   integer(int32), pointer, contiguous, intent(out) :: tab(:) !< Its table (`LerpTable`'s).
   logical,                             intent(out) :: qual   !< Qualitative.
   integer(int32)                                   :: k      !< Slot.

   call init()
   k = id + 1_int32
   tab => tables(tab_off(k) + 1_int32:tab_off(k) + tab_size(k))
   qual = quals(k)
   endsubroutine cm_lookup

   ! FIGURE's names (ip_colormap)

   function cm_colormap(name, levels) result(id)
   !< The id of a map by FIGURE's name (`fig_colormap`): ImPlot's, a bundled one, a user's, `<name>_r` reversed, cut into
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
      call base_table(base, rgb, qual)
      n = size(rgb, 2, kind=int32)
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
   !< A name of ImPlot's maps, of the bundled ones or of the user's (`known`).
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
   yes = user_index(name) > 0_int32
   endfunction known

   function user_index(name) result(u)
   !< A user map's slot by name (`user_map`); 0 if none.
   character(len=*), intent(in) :: name !< Name.
   integer(int32)               :: u    !< Slot.

   do u = 1_int32, n_user
      if (user_nlen(u) /= len(name, kind=int32)) cycle
      if (user_names(user_noff(u):user_noff(u) + user_nlen(u) - 1_int32) == name) return
   enddo
   u = 0_int32
   endfunction user_index

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

   subroutine base_table(base, rgb, qual)
   !< `base_keys` of a map not ImPlot's: a bundled map's samples or a user map's table (continuous).
   character(len=*),          intent(in)  :: base     !< Name (bundled or user).
   real(real64), allocatable, intent(out) :: rgb(:,:) !< Table (3, n).
   logical,                   intent(out) :: qual     !< Qualitative (never).
   integer(int32)                         :: k, u     !< Bundled map, user map.

   qual = .false.
   do k = 1_int32, BUNDLED_COUNT
      if (trim(BUNDLED_NAMES(k)) == base) then
         allocate(rgb(3, BUNDLED_SAMPLES))
         u = grad_index(base)
         if (u > 0_int32) then
            if (allocated(grads(u)%table)) then ! edited
               rgb = grads(u)%table
               return
            endif
         endif
         rgb = bundled_map(k)
         return
      endif
   enddo
   u = user_index(base)
   allocate(rgb(3, user_cnt(u)))
   rgb = user_rows(:, user_off(u):user_off(u) + user_cnt(u) - 1_int32)
   endsubroutine base_table

   subroutine keys_of(base, rgb, qual)
   !< `base_keys`: a map's keys as doubles (ImPlot's: its packed keys as floats, `GetColormapColor`), qualitative or
   !< not.
   character(len=*),          intent(in)  :: base     !< Name (known).
   real(real64), allocatable, intent(out) :: rgb(:,:) !< Keys (3, n).
   logical,                   intent(out) :: qual     !< Qualitative.
   integer(int32)                         :: b, n, k, j !< ImPlot's map, keys, counters.

   b = builtin(base)
   if (b < 0_int32) then
      call base_table(base, rgb, qual)
      return
   endif
   qual = quals(b + 1_int32)
   n = key_cnt(b + 1_int32)
   allocate(rgb(3, n))
   do k = 1_int32, n
      do j = 0_int32, 2_int32
         rgb(j + 1_int32, k) = real(real(channel(cm_key(b, k - 1_int32), j), real32) * (1.0_real32 / 255.0_real32), &
                                    real64)
      enddo
   enddo
   endsubroutine keys_of

   ! the user's maps and the lists

   subroutine cm_load(name, file, status, err)
   !< A user map read from `file` and kept under `name` (`fig_load_colormap`; `ip_load_colormap`): a ParaView preset
   !< if the text starts with '[' or '{' (blanks skipped), else a CSV table (figure_plot_colormap_files). `status`:
   !< FIG_OK; FIG_ERR_ARGUMENT for a name not allowed (empty, with '|', starting with 'FIGURE '), taken (a map or the
   !< reverse of one) or a malformed file; FIG_ERR_FAILED for a file that cannot be read; `err` the message.
   character(len=*),              intent(in)  :: name   !< Name (its trailing blanks dropped, as `ip_load_colormap`).
   character(len=*),              intent(in)  :: file   !< CSV table or ParaView JSON preset (trailing blanks dropped).
   integer(int32),                intent(out) :: status !< Status.
   character(len=:), allocatable, intent(out) :: err    !< Message ('' on success).
   character(len=:), allocatable :: n, f, text, where  !< Name, file, its text, the messages' start.
   real(real64),     allocatable :: rows(:,:), more(:,:) !< The table, a grown store.
   integer(int32),   allocatable :: a(:), b(:), c(:), d(:) !< Grown columns.
   character(len=:), allocatable :: grown              !< Grown names.
   integer(int32)                :: unit, ios, sz, k, m, first !< Unit, status, size, counters.
   logical                       :: json, reversed     !< A preset, the reverse of a map.

   call init()
   status = FIG_OK
   err = ''
   n = name(1:len_trim(name))
   f = file(1:len_trim(file))
   where = 'ip_load_colormap: '//f
   if (len(n) == 0 .or. index(n, '|') > 0 .or. starts(n, 'FIGURE ')) then
      status = FIG_ERR_ARGUMENT
      err = "ip_load_colormap: the name '"//n//"' is not allowed (empty, with '|', or starting with 'FIGURE ')"
      return
   endif
   reversed = .false.
   if (.not. known(n) .and. len(n) > 2) then
      if (n(len(n) - 1:) == '_r') reversed = known(n(1:len(n) - 2))
   endif
   if (known(n) .or. reversed) then
      status = FIG_ERR_ARGUMENT
      if (reversed) then
         err = "ip_load_colormap: the name '"//n//"' is taken (the reverse of '"//n(1:len(n) - 2)// &
               "'): ImPlot cannot replace a colormap"
      else
         err = "ip_load_colormap: the name '"//n//"' is taken (a colormap): ImPlot cannot replace a colormap"
      endif
      return
   endif
   open(newunit=unit, file=f, access='stream', form='unformatted', status='old', action='read', iostat=ios)
   if (ios == 0) inquire(unit=unit, size=sz, iostat=ios)
   if (ios /= 0) then
      status = FIG_ERR_FAILED
      err = where//': cannot be read'
      return
   endif
   allocate(character(len=max(sz, 0)) :: text)
   if (sz > 0) read(unit, iostat=ios) text
   close(unit)
   if (ios /= 0) then
      status = FIG_ERR_FAILED
      err = where//': cannot be read'
      return
   endif
   first = verify(text, ' '//achar(9)//achar(13)//achar(10))
   json = .false.
   if (first > 0) json = text(first:first) == '[' .or. text(first:first) == '{'
   if (json) then
      call cmf_paraview(text, where, n, rows, err)
   else
      call cmf_csv(text, where, rows, err)
   endif
   if (len(err) > 0) then
      status = FIG_ERR_ARGUMENT
      return
   endif
   m = size(rows, 2, kind=int32)
   if (.not. allocated(user_off)) then
      allocate(user_off(8), user_cnt(8), user_noff(8), user_nlen(8), user_rows(3, max(1024_int32, m)))
      allocate(character(len=256) :: user_names)
   endif
   if (n_user == size(user_off, kind=int32)) then
      allocate(a(2_int32 * n_user), b(2_int32 * n_user), c(2_int32 * n_user), d(2_int32 * n_user))
      a(1:n_user) = user_off(1:n_user)
      b(1:n_user) = user_cnt(1:n_user)
      c(1:n_user) = user_noff(1:n_user)
      d(1:n_user) = user_nlen(1:n_user)
      call move_alloc(a, user_off)
      call move_alloc(b, user_cnt)
      call move_alloc(c, user_noff)
      call move_alloc(d, user_nlen)
   endif
   if (n_user_rows + m > size(user_rows, 2, kind=int32)) then
      allocate(more(3, max(2_int32 * size(user_rows, 2, kind=int32), n_user_rows + m)))
      more(:, 1:n_user_rows) = user_rows(:, 1:n_user_rows)
      call move_alloc(more, user_rows)
   endif
   if (n_user_names + len(n) > len(user_names)) then
      allocate(character(len=max(2 * len(user_names), n_user_names + len(n))) :: grown)
      grown(1:n_user_names) = user_names(1:n_user_names)
      call move_alloc(grown, user_names)
   endif
   n_user = n_user + 1_int32
   k = n_user
   user_off(k) = n_user_rows + 1_int32
   user_cnt(k) = m
   user_rows(:, n_user_rows + 1_int32:n_user_rows + m) = rows
   n_user_rows = n_user_rows + m
   user_noff(k) = n_user_names + 1_int32
   user_nlen(k) = len(n, kind=int32)
   user_names(n_user_names + 1_int32:n_user_names + len(n)) = n
   n_user_names = n_user_names + len(n, kind=int32)
   endsubroutine cm_load

   pure function starts(s, head) result(yes)
   !< `s` starts with `head`.
   character(len=*), intent(in) :: s, head !< Texts.
   logical                      :: yes     !< Starts so.

   yes = len(s) >= len(head)
   if (yes) yes = s(1:len(head)) == head
   endfunction starts

   function cm_list_count() result(n)
   !< The names `cm_colormap` knows (`fig_colormap_count`): the bundled maps, ImPlot's, the user's.
   integer(int32) :: n !< Names.

   n = BUNDLED_COUNT + 16_int32 + n_user
   endfunction cm_list_count

   function cm_list_name(i) result(name)
   !< The i-th name of the list (`fig_colormap_name`): the bundled maps (alphabetical), ImPlot's (in ImPlot's order),
   !< the user's (in load order); '' out of range.
   integer(int32), intent(in)    :: i    !< Index (1-based).
   character(len=:), allocatable :: name !< Name.

   name = ''
   if (i >= 1_int32 .and. i <= BUNDLED_COUNT) then
      name = trim(BUNDLED_NAMES(i))
   elseif (i > BUNDLED_COUNT .and. i <= BUNDLED_COUNT + 16_int32) then
      name = trim(IMPLOT_NAMES(i - BUNDLED_COUNT))
   elseif (i > BUNDLED_COUNT + 16_int32 .and. i <= cm_list_count()) then
      associate(u => i - BUNDLED_COUNT - 16_int32)
         name = user_names(user_noff(u):user_noff(u) + user_nlen(u) - 1_int32)
      endassociate
   endif
   endfunction cm_list_name

   subroutine cm_stops(name, pos, rgb, status, err)
   !< A map's stops (`fig_colormap_stops`; `ip_colormap_stops`), sorted by position: `stops_of` its keys (as floats,
   !< `ImVec4`). `status`: FIG_OK; FIG_ERR_ARGUMENT for an unknown name, a reversed map, a table not readable, a
   !< qualitative map (`editable`); `err` the message. Arrays of size 0 on a failure.
   character(len=*),              intent(in)  :: name     !< Name (trailing blanks dropped).
   real(real64),     allocatable, intent(out) :: pos(:)   !< Positions in [0, 1].
   real(real64),     allocatable, intent(out) :: rgb(:,:) !< Colours (3, n).
   integer(int32),                intent(out) :: status   !< Status.
   character(len=:), allocatable, intent(out) :: err      !< Message.
   character(len=:), allocatable :: n                     !< Name.
   real(real64),     allocatable :: keys(:,:)             !< The map's keys.
   integer(int32),   allocatable :: idx(:)                !< The keys kept.
   integer(int32)                :: nk, ns, a, b, c, k, j !< Keys, stops, the segment, counters.
   real(real64)                  :: w, e                  !< A weight, a deviation.
   logical                       :: qual, ok              !< Qualitative, within the tolerance.
   real(real32),     allocatable :: sst(:,:)              !< An edited map's stops, sorted.
   real(real64),     parameter   :: TOL = 2.0_real64 / 255.0_real64 !< STOP_TOLERANCE.

   call init()
   allocate(pos(0), rgb(3, 0))
   status = FIG_ERR_ARGUMENT
   n = name(1:len_trim(name))
   if (.not. known(n)) then
      err = "ip_colormap_stops: unknown colormap '"//n//"' (ip_colormap_names lists them)"
      if (len(n) > 2) then
         if (n(len(n) - 1:) == '_r' .and. known(n(1:max(len(n) - 2, 0)))) &
            err = "ip_colormap_stops: '"//n//"' is a reversed map: edit '"//n(1:len(n) - 2)//"'"
      endif
      return
   endif
   call keys_of(n, keys, qual)
   nk = size(keys, 2, kind=int32)
   if (nk < 2_int32) then
      err = "ip_colormap_stops: the table of '"//n//"' cannot be read"
      return
   endif
   if (qual) then
      err = "ip_colormap_stops: '"//n//"' is qualitative (a list of colours, not a scale): it has no gradient"
      return
   endif
   k = grad_index(n)
   if (k > 0_int32) then ! edited: its stops, sorted by position (stable)
      call sorted_stops(grads(k)%stops, sst)
      deallocate(pos, rgb)
      allocate(pos(size(sst, 2)), rgb(3, size(sst, 2)))
      do j = 1_int32, size(sst, 2, kind=int32)
         pos(j) = real(sst(4, j), real64)
         rgb(:, j) = real(sst(1:3, j), real64)
      enddo
      status = FIG_OK
      err = ''
      return
   endif
   allocate(idx(nk))
   if (nk <= 16_int32) then
      ns = nk
      do k = 1_int32, nk
         idx(k) = k - 1_int32
      enddo
   else
      ns = 1_int32
      idx(1) = 0_int32
      a = 0_int32
      do while (a + 1_int32 < nk)
         b = a + 1_int32
         do while (b + 1_int32 < nk) ! the segment extended to b + 1 while every key between stays within the tolerance
            ok = .true.
            c = b + 1_int32
            do k = a + 1_int32, c - 1_int32
               if (.not. ok) exit
               w = real(k - a, real64) / real(c - a, real64)
               do j = 1_int32, 3_int32
                  e = w * (keys(j, c + 1_int32) - keys(j, a + 1_int32))
                  e = keys(j, a + 1_int32) + e
                  e = e - keys(j, k + 1_int32)
                  if (abs(e) > TOL) ok = .false.
               enddo
            enddo
            if (.not. ok) exit
            b = c
         enddo
         ns = ns + 1_int32
         idx(ns) = b
         a = b
      enddo
   endif
   deallocate(pos, rgb)
   allocate(pos(ns), rgb(3, ns))
   do k = 1_int32, ns ! as ImVec4 (floats)
      pos(k) = real(real(real(idx(k), real64) / real(nk - 1_int32, real64), real32), real64)
      do j = 1_int32, 3_int32
         rgb(j, k) = real(real(keys(j, idx(k) + 1_int32), real32), real64)
      enddo
   enddo
   status = FIG_OK
   err = ''
   endsubroutine cm_stops

   ! edited maps (ig_gradient_edit's)

   function grad_index(name) result(g)
   !< An edited map's slot by its base name; 0 if none.
   character(len=*), intent(in) :: name !< Name.
   integer(int32)               :: g    !< Slot.

   do g = 1_int32, n_grads
      if (len(grads(g)%name) /= len(name)) cycle
      if (grads(g)%name == name) return
   enddo
   g = 0_int32
   endfunction grad_index

   function cm_generation() result(n)
   !< The edits made to the maps (`fig_colormap_generation`): a field coloured with a map is coloured again.
   integer(int32) :: n !< Generation.

   n = generation
   endfunction cm_generation

   subroutine sorted_stops(s, out)
   !< `sorted_stops`: the stops by position, a stable sort.
   real(real32),              intent(in)  :: s(:,:)   !< Stops (4, n).
   real(real32), allocatable, intent(out) :: out(:,:) !< Sorted.
   real(real32)                           :: t(4)     !< A stop moved.
   integer(int32)                         :: i, j     !< Counters.

   allocate(out(4, size(s, 2)))
   out = s
   do i = 2_int32, size(s, 2, kind=int32)
      t = out(:, i)
      j = i - 1_int32
      do while (j >= 1_int32)
         if (.not. out(4, j) > t(4)) exit
         out(:, j + 1_int32) = out(:, j)
         j = j - 1_int32
      enddo
      out(:, j + 1_int32) = t
   enddo
   endsubroutine sorted_stops

   pure function stops_at(s, t) result(c)
   !< `stops_at`: the colour of sorted stops at t, linear between them, the ends' beyond them. The differences of two
   !< stops are taken in single precision, as C++ takes `b.w - a.w` and `b.x - a.x` of two floats.
   real(real32), intent(in) :: s(:,:) !< Sorted stops (4, n).
   real(real64), intent(in) :: t      !< Position.
   real(real64)             :: c(3)   !< Colour.
   real(real64)             :: w, d   !< Weight, a term.
   integer(int32)           :: i, j, n !< Counters, stops.

   n = size(s, 2, kind=int32)
   c = 0.0_real64
   if (n == 0_int32) return
   if (t <= real(s(4, 1), real64)) then
      c = real(s(1:3, 1), real64)
      return
   endif
   do i = 2_int32, n
      if (t <= real(s(4, i), real64)) then
         if (s(4, i) > s(4, i - 1_int32)) then
            w = (t - real(s(4, i - 1_int32), real64)) / real(s(4, i) - s(4, i - 1_int32), real64)
         else
            w = 1.0_real64
         endif
         do j = 1_int32, 3_int32
            d = w * real(s(j, i) - s(j, i - 1_int32), real64)
            c(j) = real(s(j, i - 1_int32), real64) + d
         enddo
         return
      endif
   enddo
   c = real(s(1:3, n), real64)
   endfunction stops_at

   subroutine cm_edit_stops(name, pos, rgb, status, err, changed)
   !< A map's stops set (what `ig_gradient_edit` does on an edit: `gradient_of`, the stops changed, then
   !< `resample_from_stops`): kept in the order given (the editor's); the map's table (256 colours for a bundled or a
   !< user's map, ImPlot's keys for one of its own) resampled from them, sorted (linearly between, constant beyond the
   !< ends), and every variant registered (`<name>_r`, levels) rewritten; `cm_generation` raised. Nothing done when
   !< the stops are those it has (`same_stops`). `status`: FIG_OK; FIG_ERR_ARGUMENT for a name `editable` refuses
   !< (unknown, reversed, qualitative) or stops not (positions, colours) of the same count; `err` the message.
   character(len=*),              intent(in)            :: name     !< Map (its base name, trailing blanks dropped).
   real(real64),                  intent(in)            :: pos(:)   !< Positions in [0, 1].
   real(real64),                  intent(in)            :: rgb(:,:) !< Colours (3, n).
   integer(int32),                intent(out)           :: status   !< Status.
   character(len=:), allocatable, intent(out)           :: err      !< Message.
   logical,                       intent(out), optional :: changed  !< The stops changed (the map resampled).
   character(len=:), allocatable :: n                     !< Name.
   real(real64),     allocatable :: p0(:), c0(:,:), keys(:,:) !< Its stops now, its keys.
   real(real32),     allocatable :: st(:,:), sst(:,:)     !< The stops given, sorted.
   integer(int32)                :: g, k, nk, b, u, ns    !< Slots, counters.
   logical                       :: qual, same            !< Qualitative, the same stops.

   call init()
   if (present(changed)) changed = .false.
   n = name(1:len_trim(name))
   ns = size(pos, kind=int32)
   if (size(rgb, 1) /= 3 .or. size(rgb, 2) /= ns) then
      status = FIG_ERR_ARGUMENT
      err = 'ig_gradient_edit: stops need a colour (3 components) per position'
      return
   endif
   call cm_stops(n, p0, c0, status, err) ! `editable`, and the stops it has (`gradient_of`)
   if (status /= FIG_OK) then
      err = 'ig_gradient_edit'//err(len('ip_colormap_stops') + 1:)
      return
   endif
   allocate(st(4, ns))
   do k = 1_int32, ns
      st(1:3, k) = real(rgb(:, k), real32)
      st(4, k) = real(pos(k), real32)
   enddo
   g = grad_index(n)
   if (g == 0_int32) g = new_gradient(n, p0, c0) ! `gradient_of`: the stops it had, before this edit
   same = size(grads(g)%stops, 2) == ns
   if (same) same = all(grads(g)%stops == st)
   if (same) return
   call move_alloc(st, grads(g)%stops)
   ! resample_from_stops
   call keys_of(n, keys, qual)
   nk = size(keys, 2, kind=int32)
   call sorted_stops(grads(g)%stops, sst)
   do k = 1_int32, nk
      if (nk > 1_int32) then
         keys(:, k) = stops_at(sst, real(k - 1_int32, real64) / real(nk - 1_int32, real64))
      else
         keys(:, k) = stops_at(sst, 0.0_real64)
      endif
   enddo
   b = builtin(n)
   if (b >= 0_int32) then
      call write_keys(b, keys)
   elseif (user_index(n) > 0_int32) then
      u = user_index(n)
      user_rows(:, user_off(u):user_off(u) + user_cnt(u) - 1_int32) = keys
   else
      if (allocated(grads(g)%table)) deallocate(grads(g)%table)
      allocate(grads(g)%table(3, nk))
      grads(g)%table = keys
   endif
   call rewrite_variants(n, keys, qual, b >= 0_int32)
   generation = generation + 1_int32
   if (present(changed)) changed = .true.
   status = FIG_OK
   err = ''
   endsubroutine cm_edit_stops

   function new_gradient(n, p0, c0) result(g)
   !< `gradient_of` for a map not edited yet: its slot, holding the stops it has (`cm_stops`'s).
   character(len=*), intent(in) :: n        !< Base name.
   real(real64),     intent(in) :: p0(:)    !< Its stops' positions.
   real(real64),     intent(in) :: c0(:,:)  !< Their colours (3, n).
   integer(int32)               :: g        !< Slot.
   type(gradient),   allocatable :: more(:) !< Grown table.
   integer(int32)               :: k        !< Counter.

   if (.not. allocated(grads)) allocate(grads(4))
   if (n_grads == size(grads, kind=int32)) then
      allocate(more(2_int32 * n_grads))
      do k = 1_int32, n_grads ! element by element (nvfortran: no section of a type with deferred-length parts)
         call move_alloc(grads(k)%name, more(k)%name)
         call move_alloc(grads(k)%stops, more(k)%stops)
         if (allocated(grads(k)%table)) call move_alloc(grads(k)%table, more(k)%table)
      enddo
      call move_alloc(more, grads)
   endif
   n_grads = n_grads + 1_int32
   g = n_grads
   grads(g)%name = n
   allocate(grads(g)%stops(4, size(p0)))
   do k = 1_int32, size(p0, kind=int32)
      grads(g)%stops(1:3, k) = real(c0(:, k), real32)
      grads(g)%stops(4, k) = real(p0(k), real32)
   enddo
   endfunction new_gradient

   function cm_gradient_slot(name, status, err) result(g)
   !< The slot of the map `name` (trimmed) as the gradient editor holds it (`editable`, then `gradient_of`): its stops in
   !< the editor's order, those `cm_stops` gives until it is edited. 0, with `status` and `err` as `cm_stops`'s (named
   !< `ig_gradient_edit`), for a map `editable` refuses. No allocation for a map that has its slot already.
   character(len=*),              intent(in)  :: name    !< Name (trimmed).
   integer(int32),                intent(out) :: status  !< Status.
   character(len=:), allocatable, intent(out) :: err     !< Message.
   integer(int32)                             :: g       !< Slot.
   real(real64),     allocatable              :: p0(:), c0(:,:) !< Its stops.

   call init()
   status = FIG_OK
   g = grad_index(name)
   if (g > 0_int32) return
   call cm_stops(name, p0, c0, status, err)
   if (status /= FIG_OK) then
      err = 'ig_gradient_edit'//err(len('ip_colormap_stops') + 1:)
      return
   endif
   g = new_gradient(name, p0, c0)
   endfunction cm_gradient_slot

   function cm_gradient_size(g) result(n)
   !< The stops of an edited map's slot.
   integer(int32), intent(in) :: g !< Slot (`cm_gradient_slot`).
   integer(int32)             :: n !< Stops.

   n = size(grads(g)%stops, 2, kind=int32)
   endfunction cm_gradient_size

   subroutine cm_gradient_get(g, s)
   !< An edited map's stops, in the editor's order, into `s(:, 1:cm_gradient_size(g))`.
   integer(int32), intent(in)    :: g      !< Slot (`cm_gradient_slot`).
   real(real32),   intent(inout) :: s(:,:) !< Stops (r, g, b, position), at least `cm_gradient_size(g)` of them.
   integer(int32)                :: k      !< Counter.

   do k = 1_int32, size(grads(g)%stops, 2, kind=int32)
      s(:, k) = grads(g)%stops(:, k)
   enddo
   endsubroutine cm_gradient_get

   pure function cm_stops_at(s, t) result(c)
   !< `stops_at`: the colour of sorted stops at t, linear between them, the ends' beyond them.
   real(real32), intent(in) :: s(:,:) !< Sorted stops (4, n).
   real(real64), intent(in) :: t      !< Position.
   real(real64)             :: c(3)   !< Colour.

   c = stops_at(s, t)
   endfunction cm_stops_at

   subroutine rewrite_variants(base, keys, qual, builtin_base)
   !< Every registered variant of an edited map (`<base>`, `<base>_r`, with 0 or 2-256 levels) rewritten from its keys
   !< (`variant_keys`), the base itself skipped when ImPlot's (written already).
   character(len=*), intent(in) :: base         !< Base name.
   real(real64),     intent(in) :: keys(:,:)    !< Its keys as edited (3, n).
   logical,          intent(in) :: qual         !< Qualitative.
   logical,          intent(in) :: builtin_base !< ImPlot's own map.
   real(real64),     allocatable :: v(:,:)      !< A variant's keys.
   character(len=:), allocatable :: nm, reg     !< A variant's name, registered name.
   character(len=8)              :: tag         !< Levels, printed.
   integer(int32)                :: r, lv, id, n, k !< Reversed, levels, its id, keys, counter.
   logical                       :: q           !< Its kind.

   n = size(keys, 2, kind=int32)
   do r = 0_int32, 1_int32
      nm = base
      if (r == 1_int32) nm = base//'_r'
      lv = 0_int32
      do while (lv <= MAX_LEVELS)
         if (.not. (lv == 0_int32 .and. r == 0_int32 .and. builtin_base)) then
            if (lv > 0_int32) then
               write(tag, '(I0)') lv
               reg = nm//'|'//trim(tag)
            else
               reg = nm
            endif
            id = cm_index(reg)
            if (id >= 0_int32) then
               q = qual
               if (r == 1_int32) then
                  allocate(v(3, n))
                  do k = 1_int32, n
                     v(:, k) = keys(:, n + 1_int32 - k)
                  enddo
               else
                  allocate(v(3, n))
                  v = keys
               endif
               if (lv > 0_int32) then
                  call write_band_keys(id, v, n, lv, q)
               else
                  call write_keys(id, v)
               endif
               deallocate(v)
            endif
         endif
         lv = merge(2_int32, lv + 1_int32, lv == 0_int32)
      enddo
   enddo
   endsubroutine rewrite_variants

   subroutine write_band_keys(id, rgb, n, lv, qual)
   !< A variant of `lv` bands rewritten: a band each, the map's colour at its centre (`variant_keys`).
   integer(int32), intent(in) :: id       !< Map.
   real(real64),   intent(in) :: rgb(:,:) !< Keys (3, n).
   integer(int32), intent(in) :: n, lv    !< Keys, bands.
   logical,        intent(in) :: qual     !< The map qualitative.
   real(real64)               :: c(3, MAX_LEVELS) !< The bands' colours.
   integer(int32)             :: k        !< Band.

   do k = 0_int32, lv - 1_int32
      c(:, k + 1_int32) = band(rgb, n, (real(k, real64) + 0.5_real64) / real(lv, real64), qual)
   enddo
   call write_keys(id, c(:, 1:lv))
   endsubroutine write_band_keys

   subroutine write_keys(id, rgb)
   !< `write_keys` and `RebuildTables` of one map: its keys replaced (the same count, packed as
   !< `ColorConvertFloat4ToU32`), its table rebuilt.
   integer(int32), intent(in) :: id       !< Map.
   real(real64),   intent(in) :: rgb(:,:) !< Keys (3, n).
   integer(int32)             :: k, n, i, s !< Slot, keys, counters.

   k = id + 1_int32
   n = size(rgb, 2, kind=int32)
   if (id < 0_int32 .or. id >= n_maps .or. key_cnt(k) /= n) return
   do i = 1_int32, n
      keys(key_off(k) + i) = pack_float4(rgb(:, i), 1.0_real64)
   enddo
   if (quals(k)) then
      tables(tab_off(k) + 1_int32:tab_off(k) + n) = keys(key_off(k) + 1_int32:key_off(k) + n)
   else
      do i = 1_int32, n - 1_int32
         do s = 0_int32, 254_int32
            tables(tab_off(k) + (i - 1_int32) * 255_int32 + s + 1_int32) = &
               mix_u32(keys(key_off(k) + i), keys(key_off(k) + i + 1_int32), s)
         enddo
      enddo
      tables(tab_off(k) + tab_size(k)) = keys(key_off(k) + n)
   endif
   endsubroutine write_keys

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
