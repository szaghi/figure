!< figure_md4c, md4c's C API in Fortran: the Markdown parser of the Fortran path's renderer (C, K1).
module figure_md4c
!< figure_md4c, md4c's C API in Fortran: the Markdown parser of the Fortran path's renderer (C, K1).
!<
!< szaghi/figure#15 P15. md4c (MIT, third_party/md4c, compiled into the native layer) stays C by the ADR's K1: the
!< renderer (figure_markdown_render) hands it a text and is called back as it enters and leaves each block and span, and
!< for each piece of text. The types and constants are md4c.h's (release 0.5.3): the enumerations as `integer(c_int)`,
!< `MD_SIZE` and `MD_OFFSET` (unsigned) as `integer(c_int)` (a Markdown text is far below 2**31 bytes), `MD_CHAR` as
!< `character(kind=c_char)`, the detail structures `bind(C)` with md4c's layout; a pointer of a detail (the callbacks'
!< `void* detail`) is read with `c_f_pointer`.
use, intrinsic :: iso_c_binding, only : c_char, c_funptr, c_int, c_null_funptr, c_null_ptr, c_ptr

implicit none
private
public :: md_attribute, md_block_ul_detail, md_block_ol_detail, md_block_li_detail, md_block_h_detail
public :: md_block_code_detail, md_block_table_detail, md_block_td_detail, md_span_a_detail, md_span_img_detail
public :: md_parser, md_parse
public :: MD_BLOCK_DOC, MD_BLOCK_QUOTE, MD_BLOCK_UL, MD_BLOCK_OL, MD_BLOCK_LI, MD_BLOCK_HR, MD_BLOCK_H, MD_BLOCK_CODE
public :: MD_BLOCK_HTML, MD_BLOCK_P, MD_BLOCK_TABLE, MD_BLOCK_THEAD, MD_BLOCK_TBODY, MD_BLOCK_TR, MD_BLOCK_TH, MD_BLOCK_TD
public :: MD_SPAN_EM, MD_SPAN_STRONG, MD_SPAN_A, MD_SPAN_IMG, MD_SPAN_CODE, MD_SPAN_DEL, MD_SPAN_LATEXMATH
public :: MD_SPAN_LATEXMATH_DISPLAY, MD_SPAN_WIKILINK, MD_SPAN_U
public :: MD_TEXT_NORMAL, MD_TEXT_NULLCHAR, MD_TEXT_BR, MD_TEXT_SOFTBR, MD_TEXT_ENTITY, MD_TEXT_CODE, MD_TEXT_HTML
public :: MD_TEXT_LATEXMATH
public :: MD_ALIGN_DEFAULT, MD_ALIGN_LEFT, MD_ALIGN_CENTER, MD_ALIGN_RIGHT
public :: MD_FLAG_PERMISSIVEURLAUTOLINKS, MD_FLAG_PERMISSIVEEMAILAUTOLINKS, MD_FLAG_TABLES, MD_FLAG_STRIKETHROUGH
public :: MD_FLAG_PERMISSIVEWWWAUTOLINKS, MD_FLAG_TASKLISTS, MD_FLAG_UNDERLINE

! MD_BLOCKTYPE
integer(c_int), parameter :: MD_BLOCK_DOC   = 0_c_int  !< The document.
integer(c_int), parameter :: MD_BLOCK_QUOTE = 1_c_int  !< A block quote.
integer(c_int), parameter :: MD_BLOCK_UL    = 2_c_int  !< A bullet list (`md_block_ul_detail`).
integer(c_int), parameter :: MD_BLOCK_OL    = 3_c_int  !< An ordered list (`md_block_ol_detail`).
integer(c_int), parameter :: MD_BLOCK_LI    = 4_c_int  !< A list item (`md_block_li_detail`).
integer(c_int), parameter :: MD_BLOCK_HR    = 5_c_int  !< A thematic break.
integer(c_int), parameter :: MD_BLOCK_H     = 6_c_int  !< A heading (`md_block_h_detail`).
integer(c_int), parameter :: MD_BLOCK_CODE  = 7_c_int  !< A code block (`md_block_code_detail`).
integer(c_int), parameter :: MD_BLOCK_HTML  = 8_c_int  !< A raw HTML block.
integer(c_int), parameter :: MD_BLOCK_P     = 9_c_int  !< A paragraph.
integer(c_int), parameter :: MD_BLOCK_TABLE = 10_c_int !< A table (`md_block_table_detail`).
integer(c_int), parameter :: MD_BLOCK_THEAD = 11_c_int !< Its head.
integer(c_int), parameter :: MD_BLOCK_TBODY = 12_c_int !< Its body.
integer(c_int), parameter :: MD_BLOCK_TR    = 13_c_int !< A row.
integer(c_int), parameter :: MD_BLOCK_TH    = 14_c_int !< A head cell (`md_block_td_detail`).
integer(c_int), parameter :: MD_BLOCK_TD    = 15_c_int !< A cell (`md_block_td_detail`).
! MD_SPANTYPE
integer(c_int), parameter :: MD_SPAN_EM                = 0_c_int !< Emphasis.
integer(c_int), parameter :: MD_SPAN_STRONG            = 1_c_int !< Strong emphasis.
integer(c_int), parameter :: MD_SPAN_A                 = 2_c_int !< A link (`md_span_a_detail`).
integer(c_int), parameter :: MD_SPAN_IMG               = 3_c_int !< An image (`md_span_img_detail`).
integer(c_int), parameter :: MD_SPAN_CODE              = 4_c_int !< A code span.
integer(c_int), parameter :: MD_SPAN_DEL               = 5_c_int !< A strikethrough.
integer(c_int), parameter :: MD_SPAN_LATEXMATH         = 6_c_int !< An inline formula.
integer(c_int), parameter :: MD_SPAN_LATEXMATH_DISPLAY = 7_c_int !< A display formula.
integer(c_int), parameter :: MD_SPAN_WIKILINK          = 8_c_int !< A wiki link.
integer(c_int), parameter :: MD_SPAN_U                 = 9_c_int !< An underline.
! MD_TEXTTYPE
integer(c_int), parameter :: MD_TEXT_NORMAL    = 0_c_int !< Text.
integer(c_int), parameter :: MD_TEXT_NULLCHAR  = 1_c_int !< A NUL character.
integer(c_int), parameter :: MD_TEXT_BR        = 2_c_int !< A hard line break.
integer(c_int), parameter :: MD_TEXT_SOFTBR    = 3_c_int !< A soft line break.
integer(c_int), parameter :: MD_TEXT_ENTITY    = 4_c_int !< An entity, as written (`&nbsp;`).
integer(c_int), parameter :: MD_TEXT_CODE      = 5_c_int !< Code, in a code span or block.
integer(c_int), parameter :: MD_TEXT_HTML      = 6_c_int !< Raw HTML.
integer(c_int), parameter :: MD_TEXT_LATEXMATH = 7_c_int !< A formula's text.
! MD_ALIGN
integer(c_int), parameter :: MD_ALIGN_DEFAULT = 0_c_int !< Unspecified.
integer(c_int), parameter :: MD_ALIGN_LEFT    = 1_c_int !< Left.
integer(c_int), parameter :: MD_ALIGN_CENTER  = 2_c_int !< Centre.
integer(c_int), parameter :: MD_ALIGN_RIGHT   = 3_c_int !< Right.
! MD_FLAG_*
integer(c_int), parameter :: MD_FLAG_PERMISSIVEURLAUTOLINKS   = int(z'0004', c_int) !< URLs as autolinks.
integer(c_int), parameter :: MD_FLAG_PERMISSIVEEMAILAUTOLINKS = int(z'0008', c_int) !< E-mails as autolinks.
integer(c_int), parameter :: MD_FLAG_TABLES                   = int(z'0100', c_int) !< Tables.
integer(c_int), parameter :: MD_FLAG_STRIKETHROUGH            = int(z'0200', c_int) !< Strikethrough.
integer(c_int), parameter :: MD_FLAG_PERMISSIVEWWWAUTOLINKS   = int(z'0400', c_int) !< `www.` autolinks.
integer(c_int), parameter :: MD_FLAG_TASKLISTS                = int(z'0800', c_int) !< Task lists.
integer(c_int), parameter :: MD_FLAG_UNDERLINE                = int(z'4000', c_int) !< Underline (`_` no emphasis).

type, bind(C) :: md_attribute
   !< `MD_ATTRIBUTE`: a string of the source (not NUL-terminated).
   type(c_ptr)    :: text = c_null_ptr           !< `const MD_CHAR*`.
   integer(c_int) :: size = 0_c_int              !< `MD_SIZE`.
   type(c_ptr)    :: substr_types = c_null_ptr   !< `const MD_TEXTTYPE*`.
   type(c_ptr)    :: substr_offsets = c_null_ptr !< `const MD_OFFSET*`.
endtype md_attribute

type, bind(C) :: md_block_ul_detail
   !< `MD_BLOCK_UL_DETAIL`.
   integer(c_int)         :: is_tight = 0_c_int !< A tight list.
   character(kind=c_char) :: mark = ' '         !< The bullet character (`-`, `+`, `*`).
endtype md_block_ul_detail

type, bind(C) :: md_block_ol_detail
   !< `MD_BLOCK_OL_DETAIL`.
   integer(c_int)         :: start = 0_c_int       !< The first number (unsigned).
   integer(c_int)         :: is_tight = 0_c_int    !< A tight list.
   character(kind=c_char) :: mark_delimiter = ' '  !< `.` or `)`.
endtype md_block_ol_detail

type, bind(C) :: md_block_li_detail
   !< `MD_BLOCK_LI_DETAIL`.
   integer(c_int)         :: is_task = 0_c_int          !< A task.
   character(kind=c_char) :: task_mark = ' '            !< `x`, `X` or a blank.
   integer(c_int)         :: task_mark_offset = 0_c_int !< `MD_OFFSET`.
endtype md_block_li_detail

type, bind(C) :: md_block_h_detail
   !< `MD_BLOCK_H_DETAIL`.
   integer(c_int) :: level = 1_c_int !< 1 to 6 (unsigned).
endtype md_block_h_detail

type, bind(C) :: md_block_code_detail
   !< `MD_BLOCK_CODE_DETAIL`.
   type(md_attribute)     :: info             !< The info string.
   type(md_attribute)     :: lang             !< Its first word, the language.
   character(kind=c_char) :: fence_char = ' ' !< The fence's character (NUL: an indented block).
endtype md_block_code_detail

type, bind(C) :: md_block_table_detail
   !< `MD_BLOCK_TABLE_DETAIL`.
   integer(c_int) :: col_count = 0_c_int      !< Columns (unsigned).
   integer(c_int) :: head_row_count = 0_c_int !< Rows of the head.
   integer(c_int) :: body_row_count = 0_c_int !< Rows of the body.
endtype md_block_table_detail

type, bind(C) :: md_block_td_detail
   !< `MD_BLOCK_TD_DETAIL`.
   integer(c_int) :: align = MD_ALIGN_DEFAULT !< `MD_ALIGN`.
endtype md_block_td_detail

type, bind(C) :: md_span_a_detail
   !< `MD_SPAN_A_DETAIL`.
   type(md_attribute) :: href                 !< The target.
   type(md_attribute) :: title                !< The title.
   integer(c_int)     :: is_autolink = 0_c_int !< An autolink.
endtype md_span_a_detail

type, bind(C) :: md_span_img_detail
   !< `MD_SPAN_IMG_DETAIL`.
   type(md_attribute) :: src   !< The image.
   type(md_attribute) :: title !< The title.
endtype md_span_img_detail

type, bind(C) :: md_parser
   !< `MD_PARSER`: the flags and the callbacks (`bind(C)` functions: `enter_block(type, detail, userdata)` and the same
   !< for `leave_block`, `enter_span`, `leave_span`; `text(type, text, size, userdata)`), each returning 0 to go on.
   integer(c_int) :: abi_version = 0_c_int       !< Reserved: 0.
   integer(c_int) :: flags = 0_c_int             !< `MD_FLAG_*` (unsigned).
   type(c_funptr) :: enter_block = c_null_funptr !< Entering a block.
   type(c_funptr) :: leave_block = c_null_funptr !< Leaving it.
   type(c_funptr) :: enter_span = c_null_funptr  !< Entering a span.
   type(c_funptr) :: leave_span = c_null_funptr  !< Leaving it.
   type(c_funptr) :: text = c_null_funptr        !< A piece of text.
   type(c_funptr) :: debug_log = c_null_funptr   !< None.
   type(c_funptr) :: syntax = c_null_funptr      !< Reserved: null.
endtype md_parser

interface
   function md_parse(text, size, parser, userdata) result(res) bind(C, name='md_parse')
   !< Parse `size` bytes from `text`, calling the parser's callbacks: 0, -1 on an error, else what a callback returned.
   import :: c_int, c_ptr, md_parser
   implicit none
   type(c_ptr),     value      :: text     !< `const MD_CHAR*`.
   integer(c_int),  value      :: size     !< `MD_SIZE`.
   type(md_parser), intent(in) :: parser   !< `const MD_PARSER*`.
   type(c_ptr),     value      :: userdata !< Passed to the callbacks.
   integer(c_int)              :: res      !< Status.
   endfunction md_parse
endinterface
endmodule figure_md4c
