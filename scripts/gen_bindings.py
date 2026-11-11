"""Generate FIGURE's raw Fortran layer from the cimgui, cimplot and cimplot3d generator metadata.

Inputs: ``definitions.json`` and ``structs_and_enums.json`` of the pinned cimgui, cimplot and cimplot3d, as fetched by
the native build (``build/native/_deps/{cimgui,cimplot,cimplot3d}-src/generator/output``). Outputs, committed to the
repository:

  - ``src/lib/figure_cimgui.F90``, ``src/lib/figure_cimplot.F90``, ``src/lib/figure_cimplot3d.F90``: ``bind(C)``
    interfaces of the public free functions that Fortran can call directly;
  - ``src/lib/figure_cimgui_enums.F90``, ``src/lib/figure_cimplot_enums.F90``, ``src/lib/figure_cimplot3d_enums.F90``:
    every public enumerator as an ``integer(c_int)`` parameter, values taken from the metadata, never hand-copied;
  - ``docs/guide/raw-bindings.md``: the classification of every public function (direct, glue, skipped) and why.

A function is **direct** when every argument is a scalar (numbers, ``bool``, enums and flags), a pointer, or an
``ImVec2`` by value, and its result is ``void``, a scalar, a pointer or ``ImVec2``. Functions taking or returning a
larger struct by value (``ImVec4``, ``ImPlotSpec``, ``ImPlotPoint``, ...) need the C++ glue; variadic functions and
functions taking callbacks are skipped (each variadic one has an ``Unformatted``/``V`` sibling or a non-variadic
alternative).

Type mapping: ``const char*`` without a ``NULL`` default is a NUL-terminated ``character(kind=c_char)`` array;
every other pointer (``NULL``-able strings, outputs, arrays, opaque structs) is ``type(c_ptr), value``, filled by the
wrapper modules with ``c_loc``/``c_null_ptr``. Unsigned C integers map to the signed Fortran kind of the same size.

Usage::

    python3 scripts/gen_bindings.py          # regenerate the outputs
    python3 scripts/gen_bindings.py --check  # exit 1 if a committed output differs from what would be generated

Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import textwrap
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEPS = ROOT / "build" / "native" / "_deps"
MAX_LINE = 132

# Scalar C types (after typedef resolution) -> (Fortran type, iso_c_binding kind it needs).
SCALARS: dict[str, tuple[str, str]] = {
    "int": ("integer(c_int)", "c_int"),
    "unsigned int": ("integer(c_int)", "c_int"),
    "short": ("integer(c_short)", "c_short"),
    "unsigned short": ("integer(c_short)", "c_short"),
    "signed char": ("integer(c_signed_char)", "c_signed_char"),
    "unsigned char": ("integer(c_signed_char)", "c_signed_char"),
    "char": ("character(kind=c_char)", "c_char"),
    "long long": ("integer(c_long_long)", "c_long_long"),
    "unsigned long long": ("integer(c_long_long)", "c_long_long"),
    "signed long long": ("integer(c_long_long)", "c_long_long"),
    "size_t": ("integer(c_size_t)", "c_size_t"),
    "float": ("real(c_float)", "c_float"),
    "double": ("real(c_double)", "c_double"),
    "bool": ("logical(c_bool)", "c_bool"),
}
VEC2 = {"ImVec2", "ImVec2_c"}
# `const char*` arguments that accept NULL although their default is a string: ImPlot's per-cell label formats,
# where NULL means no labels (an empty format would still format and measure a string per cell).
NULLABLE_STRINGS = {"label_fmt"}
# Callback types the typedef tables omit (cimplot defines ImPlotPoint_getter in its own wrapper header).
CALLBACKS = {"ImPlotPoint_getter"}
# Structs passed by value that need the glue -> Fortran mirror type (bind(C)) and the module defining it.
MIRRORS: dict[str, tuple[str, str]] = {
    "ImVec4": ("im_vec4", "cimgui"),
    "ImTextureRef": ("im_texture_ref", "cimgui"),
    "ImPlotPoint": ("im_plot_point", "cimplot"),
    "ImPlotRange": ("im_plot_range", "cimplot"),
    "ImPlotRect": ("im_plot_rect", "cimplot"),
    "ImPlotSpec": ("im_plot_spec", "cimplot"),
    "ImPlot3DPoint": ("im_plot3d_point", "cimplot3d"),
    "ImPlot3DQuat": ("im_plot3d_quat", "cimplot3d"),
    "ImPlot3DSpec": ("im_plot3d_spec", "cimplot3d"),
}
# Structs by value the mirrors do not cover -> why their functions are skipped (each has a sibling or an alternative).
UNMIRRORED = {
    "ImPlot3DRay": "`ImPlot3DRay` by value (no `_c` type in the C API)",
    "ImPlot3DStyle": "`ImPlot3DStyle` by value (an array field; `ImPlot3D_GetStyle` gives a pointer)",
}
# Spec structs whose C++ defaults the glue exports (`figure_<struct>_default`): struct -> library.
SPEC_DEFAULTS = {"ImPlotSpec": "cimplot", "ImPlot3DSpec": "cimplot3d"}


@dataclass
class Library:
    """One C library to bind (cimgui, cimplot or cimplot3d)."""

    name: str  # cimgui | cimplot | cimplot3d
    header: str  # public header location tag in the metadata: imgui | implot
    title: str  # human name for comments
    namespace: str  # C++ namespace of the free functions


LIBRARIES = [
    Library("cimgui", "imgui", "Dear ImGui", "ImGui"),
    Library("cimplot", "implot", "ImPlot", "ImPlot"),
    Library("cimplot3d", "implot3d", "ImPlot3D", "ImPlot3D"),
]


@dataclass
class Argument:
    """A function argument mapped to Fortran."""

    name: str
    ctype: str
    decl: str  # Fortran declaration up to `::`
    kind: str  # iso_c_binding entity it needs
    note: str  # trailing doc comment


@dataclass
class Function:
    """A public free function and its classification."""

    cname: str
    signature: str
    cpp: str
    location: str
    status: str  # direct | glue | skipped
    reason: str = ""
    args: list[Argument] = field(default_factory=list)
    result: tuple[str, str] | None = None  # (Fortran type, kind) or None for void
    ret: str = ""
    c_args: str = ""  # C-form argument list of the C API, `(...)`
    ret_struct: str = (
        ""  # glue: C struct the function returns by value (written through `res`)
    )

    @property
    def bind_name(self) -> str:
        """Name of the C function Fortran binds: the C API one, or its generated glue wrapper."""
        return f"figure_{self.cname}" if self.status == "glue" else self.cname


class GenerationError(Exception):
    """The metadata cannot be mapped (an unknown type, a name Fortran cannot hold)."""


def load(lib: Library) -> tuple[dict, dict, dict]:
    """Load the metadata of a library.

    Parameters
    ----------
    lib : Library
        The library.

    Returns
    -------
    tuple[dict, dict, dict]
        ``definitions``, ``structs_and_enums`` and ``typedefs_dict``.

    Raises
    ------
    GenerationError
        If the metadata is missing (the native layer has not been built).
    """
    out = DEPS / f"{lib.name}-src" / "generator" / "output"
    try:
        return tuple(  # type: ignore[return-value]
            json.loads((out / f"{n}.json").read_text())
            for n in ("definitions", "structs_and_enums", "typedefs_dict")
        )
    except FileNotFoundError as err:
        msg = f"{err.filename} missing: build the native layer first (scripts/build_native.sh)"
        raise GenerationError(msg) from err


def resolve(ctype: str, typedefs: dict[str, str]) -> str:
    """Resolve typedef chains of a C type (``ImGuiWindowFlags`` -> ``int``), keeping qualifiers and pointers.

    Parameters
    ----------
    ctype : str
        C type as written in the metadata.
    typedefs : dict[str, str]
        Typedef map of the library (cimplot's and cimplot3d's include cimgui's).

    Returns
    -------
    str
        The resolved type.
    """
    base = ctype.replace("const ", "").strip()
    seen: set[str] = set()
    while base in typedefs and base not in seen and base not in SCALARS:
        seen.add(base)
        target = typedefs[base].strip()
        if "(" in target:  # function pointer typedef
            return target
        if target.startswith("struct "):  # a struct tag: the struct itself
            return target.removeprefix("struct ").strip()
        base = target
    return base


def fortran_name(name: str, taken: set[str]) -> str:
    """Return a valid, unique (case-insensitively) Fortran name for a C argument name."""
    fname = name.lstrip("_") or "arg"
    if not fname[0].isalpha():
        fname = "a" + fname
    while fname.lower() in taken:
        fname += "_"
    taken.add(fname.lower())
    return fname


def classify(ov: dict, typedefs: dict[str, str]) -> Function:
    """Classify one overload and map its arguments and result.

    Parameters
    ----------
    ov : dict
        The overload entry of ``definitions.json``.
    typedefs : dict[str, str]
        Typedef map.

    Returns
    -------
    Function
        The function, with ``status`` direct, glue or skipped.
    """
    fn = Function(
        cname=ov["ov_cimguiname"],
        signature=ov["signature"],
        cpp=f"{ov.get('namespace', '')}::{ov['funcname']}",
        location=ov["location"],
        status="direct",
        ret=ov.get("ret", "void"),
        c_args=ov.get("args", "()"),
    )
    if ov.get(
        "isVARG0"
    ):  # declared only #ifdef CIMGUI_VARGS0, and `fmt` would still be a printf format
        return _set(
            fn,
            "skipped",
            "variadic (`...0` variant: not compiled, `fmt` still a printf format)",
        )
    defaults: dict[str, str] = ov.get("defaults", {})
    taken = {"res"}
    for a in ov["argsT"]:
        ctype = a["type"]
        if ctype in ("...", "va_list") or "va_list" in ctype:
            return _set(fn, "skipped", "variadic")
        if "(*)" in ctype:
            return _set(fn, "skipped", "callback argument")
        base = resolve(ctype, typedefs)
        if "(" in base or base in CALLBACKS:
            return _set(fn, "skipped", f"callback argument (`{ctype}`)")
        is_ptr = "*" in ctype or "[" in ctype
        name = fortran_name(a["name"], taken)
        default = defaults.get(a["name"])
        note = f"C `{ctype}`" + (
            f", default `{default}`" if default is not None else ""
        )
        if is_ptr:
            plain = ctype.replace(" ", "")
            # ImPlot's label formats (label_fmt) accept NULL for "no labels": keep them nullable
            nullable = default in ("NULL", "nullptr") or a["name"] in NULLABLE_STRINGS
            if plain == "constchar*" and not nullable:
                fn.args.append(
                    Argument(
                        name,
                        ctype,
                        "character(kind=c_char), intent(in)",
                        "c_char",
                        note,
                    )
                )
            else:
                fn.args.append(
                    Argument(name, ctype, "type(c_ptr), value", "c_ptr", note)
                )
        elif base in VEC2:
            fn.args.append(Argument(name, ctype, "type(im_vec2), value", "", note))
        elif base.removesuffix("_c") in MIRRORS:
            mirror = MIRRORS[base.removesuffix("_c")][0]
            fn.args.append(
                Argument(
                    name,
                    ctype,
                    f"type({mirror}), intent(in)",
                    "",
                    note + ", by value in C",
                )
            )
            fn.status, fn.reason = "glue", f"`{ctype}` by value"
        elif base in SCALARS:
            ftype, kind = SCALARS[base]
            fn.args.append(Argument(name, ctype, f"{ftype}, value", kind, note))
        elif base.removesuffix("_c") in UNMIRRORED:
            return _set(fn, "skipped", UNMIRRORED[base.removesuffix("_c")])
        else:
            msg = f"{fn.cname}: unmapped argument type {ctype!r} (resolved {base!r})"
            raise GenerationError(msg)
    ret = fn.ret
    if ret == "void":
        return fn
    if resolve(ret, typedefs).removesuffix("_c") in MIRRORS and "*" not in ret:
        mirror = MIRRORS[resolve(ret, typedefs).removesuffix("_c")][0]
        fn.ret_struct = resolve(ret, typedefs).removesuffix("_c") + "_c"
        fn.args.append(
            Argument(
                "res",
                ret,
                f"type({mirror}), intent(out)",
                "",
                f"Result, C `{ret}` by value",
            )
        )
        fn.status = "glue"
        fn.reason = (
            fn.reason + "; " if fn.reason else ""
        ) + f"returns `{ret}` by value"
        return fn
    rbase = resolve(ret, typedefs)
    if "*" not in ret and rbase.removesuffix("_c") in UNMIRRORED:
        return _set(fn, "skipped", "returns " + UNMIRRORED[rbase.removesuffix("_c")])
    if "*" in ret:
        fn.result = ("type(c_ptr)", "c_ptr")
    elif rbase in VEC2:
        fn.result = ("type(im_vec2)", "")
    elif rbase in SCALARS:
        fn.result = SCALARS[rbase]
    else:
        msg = f"{fn.cname}: unmapped result type {ret!r} (resolved {rbase!r})"
        raise GenerationError(msg)
    return fn


def _set(fn: Function, status: str, reason: str) -> Function:
    fn.status, fn.reason, fn.args, fn.result = status, reason, [], None
    return fn


def public_functions(
    lib: Library, definitions: dict, typedefs: dict[str, str]
) -> list[Function]:
    """Classify every public free function of a library, sorted by C name."""
    fns = [
        classify(ov, typedefs)
        for overloads in definitions.values()
        for ov in overloads
        if not ov.get("stname")
        and not ov.get("constructor")
        and not ov.get("destructor")
        and ov.get("location", "").split(":")[0] == lib.header
    ]
    return sorted(fns, key=lambda f: f.cname.lower())


def wrap(line: str, indent: str) -> list[str]:
    """Split a long Fortran statement at `, ` boundaries with `&` continuations."""
    if len(line) <= MAX_LINE:
        return [line]
    out: list[str] = []
    rest = line
    while len(rest) > MAX_LINE:
        cut = rest.rfind(", ", 0, MAX_LINE - 2)
        if cut <= len(indent):
            msg = f"cannot wrap: {line}"
            raise GenerationError(msg)
        out.append(rest[: cut + 1] + " &")
        rest = indent + rest[cut + 2 :]
    out.append(rest)
    return out


def doc(text: str, prefix: str) -> list[str]:
    """Doc comment lines, the text split after commas when a line would exceed the limit."""
    lines: list[str] = []
    cur = prefix
    for piece in text.split(","):
        sep = "," if cur != prefix else ""
        if len(cur) + len(sep) + len(piece) > MAX_LINE and cur != prefix:
            lines.append(cur + ",")
            cur = prefix + piece.lstrip()
        else:
            cur += sep + piece
    lines.append(cur)
    return lines


def header(module: str, summary: str, details: list[str]) -> list[str]:
    """Module header lines in the house style: the doc line repeated around `module`, then paragraphs wrapped."""
    lines = [f"!< {module}, {summary}", f"module {module}", f"!< {module}, {summary}"]
    for paragraph in details:
        lines.append("!<")
        lines += textwrap.wrap(
            paragraph,
            width=MAX_LINE - 16,
            initial_indent="!< ",
            subsequent_indent="!< ",
        )
    return lines


def mirror_type(
    cname: str, fields: list[dict], typedefs: dict[str, str]
) -> tuple[list[str], set[str]]:
    """Render the bind(C) Fortran mirror of a C struct, fields in metadata order (zero-initialized).

    Parameters
    ----------
    cname : str
        C++ struct name (``ImPlotSpec``); the C API type is ``<cname>_c``.
    fields : list[dict]
        Struct fields from ``structs_and_enums.json``.
    typedefs : dict[str, str]
        Typedef map.

    Returns
    -------
    tuple[list[str], set[str]]
        The lines and the iso_c_binding entities they need.
    """
    fname = MIRRORS[cname][0]
    rows: list[tuple[str, str, str]] = []
    kinds: set[str] = set()
    taken: set[str] = set()
    for fld in fields:
        ctype, name = fld["type"], fortran_name(fld["name"], taken)
        base = resolve(ctype, typedefs)
        if "*" in ctype:
            rows.append(("type(c_ptr)", f"{name} = c_null_ptr", ctype))
            kinds |= {"c_ptr", "c_null_ptr"}
        elif base in VEC2:
            rows.append(("type(im_vec2)", name, ctype))
        elif base in MIRRORS:
            rows.append((f"type({MIRRORS[base][0]})", name, ctype))
        elif base in SCALARS:
            ftype, kind = SCALARS[base]
            zero = "0.0_" + kind if ftype.startswith("real") else "0_" + kind
            rows.append((ftype, f"{name} = {zero}", ctype))
            kinds.add(kind)
        else:
            msg = f"{cname}.{fld['name']}: unmapped field type {ctype!r} (resolved {base!r})"
            raise GenerationError(msg)
    w1 = max(len(r[0]) for r in rows)
    w2 = max(len(r[1]) for r in rows)
    lines = [
        f"type, bind(C) :: {fname}",
        f"   !< `{cname}_c`, the C layout of `{cname}`, zero-initialized (not the C++ defaults).",
    ]
    lines += [f"   {t.ljust(w1)} :: {n.ljust(w2)} !< C `{c}`." for t, n, c in rows]
    lines.append(f"endtype {fname}")
    return lines, kinds


def function_module(
    lib: Library, fns: list[Function], structs: dict, typedefs: dict[str, str]
) -> str:
    """Render the bind(C) interface module of a library: mirror types, direct and glue interfaces."""
    module = f"figure_{lib.name}"
    bound = [f for f in fns if f.status in ("direct", "glue")]
    direct = [f for f in fns if f.status == "direct"]
    glue = [f for f in fns if f.status == "glue"]
    mirrors = [c for c, (_, owner) in MIRRORS.items() if owner == lib.name]
    type_lines: list[str] = []
    kinds = {a.kind for f in bound for a in f.args if a.kind} | {
        f.result[1] for f in bound if f.result and f.result[1]
    }
    if lib.name == "cimgui":
        kinds.add("c_float")
    for c in mirrors:
        lines_, kinds_ = mirror_type(c, structs[c], typedefs)
        type_lines += ["", *lines_]
        kinds |= kinds_
    if mirrors:
        kinds.add("c_size_t")
    lines = header(
        module,
        f"raw {lib.title} interfaces (generated by scripts/gen_bindings.py: do not edit).",
        [
            f"Of the {len(fns)} public free functions of {lib.name}, {len(direct)} are bound directly (`bind(C)`) and "
            f"{len(glue)} through the generated C++ glue (native/figure_glue_generated.cpp: `figure_<name>`, structs "
            "passed by reference instead of by value, struct results through `res`); the rest are skipped: see "
            "docs/guide/raw-bindings.md. Private to the library: applications use the figure_* wrapper modules. Each "
            "dummy documents its C type and default.",
        ],
    )
    lines.append(f"use, intrinsic :: iso_c_binding, only : {', '.join(sorted(kinds))}")
    if lib.name != "cimgui":  # the cimgui-owned types this module references
        body = "\n".join(type_lines) + "".join(a.decl for f in bound for a in f.args)
        body += "".join(f.result[0] for f in bound if f.result)
        owned = ["im_vec2"] + [m for m, owner in MIRRORS.values() if owner == "cimgui"]
        used = [t for t in owned if f"type({t})" in body]
        if used:
            lines.append(f"use figure_cimgui, only : {', '.join(used)}")
    lines += ["", "implicit none", "private"]
    types = (["im_vec2"] if lib.name == "cimgui" else []) + [
        MIRRORS[c][0] for c in mirrors
    ]
    if types:
        lines.append(f"public :: {', '.join(types)}")
    specs = [s for s, owner in SPEC_DEFAULTS.items() if owner == lib.name]
    probes = [f"figure_sizeof_{c}_c" for c in mirrors] + [f"figure_{s}_default" for s in specs]
    lines += _chunks([f.cname for f in bound] + probes, "public :: ")
    if lib.name == "cimgui":
        lines += [
            "",
            "type, bind(C) :: im_vec2",
            "   !< ImVec2_c: a 2D vector of floats, passed by value.",
            "   real(c_float) :: x = 0.0_c_float !< Abscissa.",
            "   real(c_float) :: y = 0.0_c_float !< Ordinate.",
            "endtype im_vec2",
        ]
    lines += type_lines
    lines += ["", "interface"]
    for i, f in enumerate(bound):
        if i:
            lines.append("")
        lines += interface(f, lib)
    for c in mirrors:
        lines += [
            "",
            f"   function figure_sizeof_{c}_c() result(res) bind(C, name='figure_sizeof_{c}_c')",
            f"   !< `sizeof({c}_c)` as compiled by the glue (layout check of `{MIRRORS[c][0]}`).",
            "   import :: c_size_t",
            "   implicit none",
            "   integer(c_size_t) :: res !< Size [bytes].",
            f"   endfunction figure_sizeof_{c}_c",
        ]
    for s in specs:
        m = MIRRORS[s][0]
        lines += [
            "",
            f"   subroutine figure_{s}_default(res) bind(C, name='figure_{s}_default')",
            f"   !< An `{s}` with the C++ constructor's defaults (automatic colours, markers, sizes, stride).",
            f"   import :: {m}",
            "   implicit none",
            f"   type({m}), intent(out) :: res !< Default spec.",
            f"   endsubroutine figure_{s}_default",
        ]
    lines += ["endinterface", f"endmodule {module}"]
    return "\n".join(lines) + "\n"


def c_arguments(f: Function) -> list[tuple[str, str, bool]]:
    """Split the C-form argument list of a glue function.

    Returns
    -------
    list[tuple[str, str, bool]]
        (declaration, name, struct passed by value) per argument.
    """
    inner = f.c_args.strip()[1:-1].strip()
    if not inner:
        return []
    if "(" in inner:
        msg = f"{f.cname}: unexpected parenthesis in the arguments of a glue function: {f.c_args}"
        raise GenerationError(msg)
    out = []
    for decl in inner.split(","):
        m = re.match(r"^(.*?)(\w+)\s*(\[\d*\])?$", decl.strip())
        if not m:
            msg = f"{f.cname}: cannot parse argument {decl!r}"
            raise GenerationError(msg)
        ctype, name = m.group(1).strip(), m.group(2)
        base = ctype.replace("const ", "").strip()
        out.append(
            (
                decl.strip(),
                name,
                "*" not in ctype and base.removesuffix("_c") in MIRRORS,
            )
        )
    return out


def glue_cpp(glue: list[Function], structs: dict) -> str:
    """Render the generated C++ glue: wrappers of the struct-by-value functions, layout probes, ImPlotSpec defaults."""
    out = [
        "// FIGURE generated glue (scripts/gen_bindings.py: do not edit).",
        "//",
        "// C wrappers of the cimgui/cimplot/cimplot3d functions that pass structs by value, which Fortran cannot call directly:",
        "// `figure_<name>` takes each such struct by pointer and returns a struct result through `res`. Every wrapper",
        "// is noexcept: Dear ImGui and ImPlot do not throw, and an exception must not unwind through Fortran frames,",
        "// so one would terminate the program. Also: the size of each struct Fortran mirrors (checked by",
        "// src/tests/figure_test_layout.F90) and the C++ defaults of ImPlotSpec.",
        "// Same includes, in the same order, as cimplot.cpp: cimgui.h's internal section needs the internal headers.",
        '#include "implot.h"',
        '#include "implot_internal.h"',
        '#include "cimplot.h"',
        "// ... and as cimplot3d.cpp",
        '#include "implot3d.h"',
        '#include "implot3d_internal.h"',
        '#include "cimplot3d.h"',
        "",
        "#include <cstddef>",
        "#include <cstring>",
        "",
        'extern "C" {',
        "",
    ]
    for f in glue:
        params = []
        call = []
        for decl, name, by_value in c_arguments(f):
            if by_value:
                ctype = decl[: decl.rfind(name)].replace("const ", "").strip()
                params.append(f"const {ctype}* {name}")
                call.append(f"*{name}")
            else:
                params.append(decl)
                call.append(name)
        if f.ret_struct:
            params.append(f"{f.ret_struct}* res")
            body = f"*res = {f.cname}({', '.join(call)});"
            ret = "void"
        else:
            ret = f.ret
            body = f"{'' if ret == 'void' else 'return '}{f.cname}({', '.join(call)});"
        out.append(
            f"{ret} figure_{f.cname}({', '.join(params) or 'void'}) noexcept {{ {body} }}"
        )
    out.append("")
    for c in MIRRORS:
        out.append(
            f"size_t figure_sizeof_{c}_c(void) noexcept {{ return sizeof({c}_c); }}"
        )
    for s in SPEC_DEFAULTS:
        fields = [fld["name"] for fld in structs[s]]
        auto = "IMPLOT_AUTO, IMPLOT_AUTO_COL" if s == "ImPlotSpec" else "IMPLOT3D_AUTO, IMPLOT3D_AUTO_COL"
        out += [
            "",
            f"// {s}'s defaults from its C++ constructor ({auto}, ...), never copied by hand: the",
            "// C++ and C layouts are checked equal field by field, then the bytes are copied.",
            f'static_assert(sizeof({s}) == sizeof({s}_c), "{s} and {s}_c differ in size");',
        ]
        out += [
            f'static_assert(offsetof({s}, {n}) == offsetof({s}_c, {n}), "{s}.{n} misplaced");'
            for n in fields
        ]
        out += [
            f"void figure_{s}_default({s}_c* res) noexcept {{",
            f"   const {s} spec;",
            "   std::memcpy(res, &spec, sizeof(spec));",
            "}",
        ]
    out += [
        "",
        '} // extern "C"',
    ]
    return "\n".join(out) + "\n"


# Style fields reachable by name (figure_style): plain values of ImGuiStyle and ImPlotStyle. Colours are reached
# through each library's own colour names; fonts belong to the font API; private fields (`_x`) are not public.
STYLE_KINDS = {
    "float": "FIG_STYLE_FLOAT",
    "ImVec2": "FIG_STYLE_VEC2",
    "bool": "FIG_STYLE_BOOL",
}
STYLE_INT_TYPES = {"ImGuiDir", "ImGuiHoveredFlags", "ImGuiTreeNodeFlags"}


def style_tables(structs: dict) -> str:
    """Render native/figure_style_generated.cpp: name, offset and kind of every plain style field."""
    out = [
        "// FIGURE generated style tables (scripts/gen_bindings.py: do not edit).",
        "//",
        "// Every plain field of ImGuiStyle and ImPlotStyle (float, ImVec2, bool, enumeration), by name, offset and kind:",
        "// what figure_style reads and writes by name. Colours (the Colors arrays) are reached through each library's",
        "// colour names, the font fields through the font API; private fields (leading underscore) are left out.",
        '#include "figure_style.h"',
        '#include "imgui.h"',
        '#include "implot.h"',
        "",
        "#include <cstddef>",
        "",
        "namespace figure_style {",
        "",
    ]
    for struct, table in (
        ("ImGuiStyle", "IMGUI_FIELDS"),
        ("ImPlotStyle", "IMPLOT_FIELDS"),
    ):
        rows = []
        for f in structs[struct]:
            name, ctype = f["name"], f["type"]
            if name.startswith(("_", "Font", "Colors")):
                continue
            if ctype in STYLE_KINDS:
                kind = STYLE_KINDS[ctype]
            elif ctype in STYLE_INT_TYPES:
                kind = "FIG_STYLE_INT"
            else:
                continue
            rows.append(f'   {{"{name}", offsetof({struct}, {name}), {kind}}},')
        out += [
            f"const field {table}[] = {{",
            *rows,
            "};",
            f"const int {table}_COUNT = {len(rows)};",
            "",
        ]
    out += ["} // namespace figure_style", ""]
    return "\n".join(out)


def layout_test() -> str:
    """Render the test program comparing the Fortran mirror sizes with the C sizes."""
    pairs = [(MIRRORS[c][0], f"figure_sizeof_{c}_c", MIRRORS[c][1]) for c in MIRRORS]
    n = len(pairs)
    lines = [
        "!< figure_test_layout, the Fortran mirrors of the C structs have the C size (generated: do not edit).",
        "program figure_test_layout",
        "!< figure_test_layout, the Fortran mirrors of the C structs have the C size (generated: do not edit).",
        "!<",
        "!< Generated by scripts/gen_bindings.py: `c_sizeof` of each bind(C) mirror against `sizeof` of the C struct as",
        "!< compiled by the glue. A mismatch means the mirror and the C struct disagree: every call passing it is wrong.",
        "use, intrinsic :: iso_c_binding, only : c_sizeof",
        "use, intrinsic :: iso_fortran_env, only : error_unit, output_unit",
    ]
    for owner in ("cimgui", "cimplot", "cimplot3d"):
        names = [x for t, f, o in pairs if o == owner for x in (t, f)]
        lines += wrap(
            f"use figure_{owner}, only : {', '.join(names)}", "                    "
        )
    lines += ["", "implicit none"]
    w = max(len(t) for t, _, _ in pairs) + 6
    lines += [
        f"{('type(' + t + ')').ljust(w)} :: {t}_v{' ' * (w - 6 - len(t))}       !< Mirror instance."
        for t, _, _ in pairs
    ]
    lines += [f"{'logical'.ljust(w)} :: test_passed({n}) !< Per-check outcome.", ""]
    for k, (t, f, _) in enumerate(pairs, 1):
        lines.append(f"test_passed({k}) = c_sizeof({t}_v) == {f}()")
    lines += [
        "",
        f"write(output_unit, '(A,{n}L2)') 'figure_test_layout checks:', test_passed",
        "write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)",
        "if (.not. all(test_passed)) then",
    ]
    for t, f, _ in pairs:
        lines += wrap(
            f"   write(error_unit, '(A,I0,A,I0)') '{t}: Fortran ', c_sizeof({t}_v), ', C ', {f}()",
            "                                     ",
        )
    lines += ["   error stop 1", "endif", "endprogram figure_test_layout"]
    return "\n".join(lines) + "\n"


def _chunks(names: list[str], prefix: str) -> list[str]:
    out, cur = [], prefix
    for n in names:
        piece = (", " if cur != prefix else "") + n
        if len(cur) + len(piece) > MAX_LINE:
            out.append(cur)
            cur = prefix + n
        else:
            cur += piece
    if cur != prefix:
        out.append(cur)
    return out


def interface(f: Function, lib: Library) -> list[str]:
    """Render one interface body."""
    kind = "function" if f.result else "subroutine"
    dummies = ", ".join(a.name for a in f.args)
    res = " result(res)" if f.result else ""
    tail = f"{res} bind(C, name='{f.bind_name}')"
    first = f"   {kind} {f.cname}({dummies}){tail}"
    if len(first) <= MAX_LINE:
        lines = [first]
    else:  # dummies wrapped at commas, the result and binding label kept whole on the last line
        lines = wrap(f"   {kind} {f.cname}({dummies}) &", "      ")
        lines.append(f"      {tail.lstrip()}")
    via = (
        f" Bound to the generated glue wrapper `{f.bind_name}`."
        if f.status == "glue"
        else ""
    )
    lines += doc(f"{f.cpp}{f.signature}, {lib.header}.h.{via}", "   !< ")
    kinds = sorted(
        {a.kind for a in f.args if a.kind}
        | ({f.result[1]} if f.result and f.result[1] else set())
    )
    types = sorted(
        {t for a in f.args for t in re.findall(r"type\((im_\w+)\)", a.decl)}
        | set(re.findall(r"type\((im_\w+)\)", f.result[0] if f.result else ""))
    )
    imports = kinds + types
    if imports:
        lines.append(f"   import :: {', '.join(imports)}")
    lines.append("   implicit none")
    decls: list[tuple[str, str, str]] = [
        (a.decl, a.name + ("(*)" if a.decl.startswith("character") else ""), a.note)
        for a in f.args
    ]
    if f.result:
        decls.append((f.result[0], "res", f"Result, C `{f.ret}`."))
    if decls:
        w1 = max(len(d[0]) for d in decls)
        w2 = max(len(d[1]) for d in decls)
        for decl, name, note in decls:
            text = note if note.endswith(".") else note + "."
            lines.append(f"   {decl.ljust(w1)} :: {name.ljust(w2)} !< {text}")
    lines.append(f"   end{kind} {f.cname}")
    return lines


def enum_module(lib: Library, enums: dict, locations: dict[str, str]) -> str:
    """Render the enumerator parameters of a library (public enums only)."""
    module = f"figure_{lib.name}_enums"
    public = {
        e: vs
        for e, vs in enums.items()
        if locations.get(e, "").split(":")[0] == lib.header
    }
    count = sum(len(vs) for vs in public.values())
    lines = header(
        module,
        f"{lib.title} enumerators (generated by scripts/gen_bindings.py: do not edit).",
        [
            f"The {count} enumerators of the {len(public)} public {lib.title} enums, values from the {lib.name} "
            "metadata. Names are the C names; combine flags with `ior`.",
        ],
    )
    lines += [
        "use, intrinsic :: iso_c_binding, only : c_int",
        "",
        "implicit none",
        "private",
    ]
    names = [v["name"] for e in sorted(public, key=str.lower) for v in public[e]]
    lines += _chunks(names, "public :: ")
    lines.append("")
    for e in sorted(public, key=str.lower):
        vs = public[e]
        lines.append(f"! {e} ({locations[e]})")
        width = max(len(v["name"]) for v in vs)
        for v in vs:
            lines.append(
                f"integer(c_int), parameter :: {v['name'].ljust(width)} = {v['calc_value']}_c_int"
            )
    lines.append(f"endmodule {module}")
    return "\n".join(lines) + "\n"


def report(results: list[tuple[Library, list[Function]]]) -> str:
    """Render the classification page of the documentation."""
    out = [
        "---",
        "title: Raw bindings",
        "---",
        "",
        "# Raw bindings",
        "",
        "<!-- generated by scripts/gen_bindings.py: do not edit -->",
        "",
        "The raw layer is generated from the cimgui, cimplot and cimplot3d metadata by `scripts/gen_bindings.py`. A",
        "public free function is **direct** when every argument is a scalar, a pointer or an `ImVec2` by value (and so",
        "is its result): it is bound with `bind(C)` in `figure_cimgui` / `figure_cimplot` / `figure_cimplot3d`. A",
        "function passing a larger struct by value (`ImVec4`, `ImPlotSpec`, `ImPlot3DSpec`, ...) goes through the",
        "generated **glue**",
        "(`native/figure_glue_generated.cpp`): a C wrapper `figure_<name>` takes the struct by pointer and returns a",
        "struct result through `res`; the Fortran interface keeps the C API name, with the struct as a `bind(C)` mirror",
        "type (`im_vec4`, `im_plot_spec`, ...) passed by reference. `src/tests/figure_test_layout.F90` checks that each",
        "mirror has the size of its C struct. Variadic functions and functions taking callbacks are **skipped**.",
        "Enumerators are in `figure_cimgui_enums` / `figure_cimplot_enums` / `figure_cimplot3d_enums`. These modules",
        "are private to the library: programs use the wrappers (`ig_*`, `ip_*`, `ip3_*`).",
        "",
        "| Library | Public functions | Direct | Glue (generated) | Skipped |",
        "|---|---|---|---|---|",
    ]
    for lib, fns in results:
        n = {s: sum(f.status == s for f in fns) for s in ("direct", "glue", "skipped")}
        out.append(
            f"| {lib.name} | {len(fns)} | {n['direct']} | {n['glue']} | {n['skipped']} |"
        )
    for lib, fns in results:
        for status, title in (
            ("glue", "Through the generated glue"),
            ("skipped", "Skipped"),
        ):
            sel = [f for f in fns if f.status == status]
            out += [
                "",
                f"## {lib.name}: {title.lower()} ({len(sel)})",
                "",
                "| Function | Reason |",
                "|---|---|",
            ]
            out += [f"| `{f.cname}` | {f.reason} |" for f in sel]
    return "\n".join(out) + "\n"


def generate() -> dict[Path, str]:
    """Generate every output.

    Returns
    -------
    dict[Path, str]
        Output path -> content.
    """
    outputs: dict[Path, str] = {}
    results: list[tuple[Library, list[Function]]] = []
    typedefs_all: dict[str, str] = {}
    structs_all: dict = {}
    for lib in LIBRARIES:
        definitions, structs_enums, typedefs = load(lib)
        typedefs_all.update(typedefs)
        # typed enums (`enum ImGuiDir : int`) are not typedefs: map them to their underlying type, plain ones to int
        typedefs_all.update(structs_enums.get("enumtypes") or {})
        for enum in structs_enums["enums"]:
            typedefs_all.setdefault(enum.rstrip("_"), "int")
        fns = public_functions(lib, definitions, typedefs_all)
        results.append((lib, fns))
        structs_all.update(structs_enums["structs"])
        outputs[ROOT / "src" / "lib" / f"figure_{lib.name}.F90"] = function_module(
            lib, fns, structs_all, typedefs_all
        )
        outputs[ROOT / "src" / "lib" / f"figure_{lib.name}_enums.F90"] = enum_module(
            lib, structs_enums["enums"], structs_enums.get("locations", {})
        )
    outputs[ROOT / "docs" / "guide" / "raw-bindings.md"] = report(results)
    glue = [f for _, fns in results for f in fns if f.status == "glue"]
    outputs[ROOT / "native" / "figure_glue_generated.cpp"] = glue_cpp(glue, structs_all)
    outputs[ROOT / "native" / "figure_style_generated.cpp"] = style_tables(structs_all)
    outputs[ROOT / "src" / "tests" / "figure_test_layout.F90"] = layout_test()
    for path, text in outputs.items():
        if path.suffix == ".F90":
            for name in re.findall(
                r"^\s*(?:function|subroutine|module|program)\s+(\w+)", text, re.M
            ):
                if len(name) > 63:
                    msg = f"{path.name}: Fortran name longer than 63 characters: {name}"
                    raise GenerationError(msg)
        for n, line in enumerate(text.splitlines(), 1):
            if path.suffix == ".F90" and len(line) > MAX_LINE:
                msg = f"{path.name}:{n}: line longer than {MAX_LINE} characters"
                raise GenerationError(msg)
    return outputs


def symbols_defined(outputs: dict[Path, str], library: Path) -> bool:
    """Check that every function bound in the generated modules is defined in a static library.

    Parameters
    ----------
    outputs : dict[Path, str]
        Generated outputs.
    library : Path
        Static library holding cimgui, cimplot and cimplot3d (``lib/libfigure_native.a``).

    Returns
    -------
    bool
        True if every bound name is a defined text symbol of the library.
    """
    try:
        nm = subprocess.run(
            ["nm", "--defined-only", str(library)],
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError) as err:
        print(
            f"gen_bindings: cannot list the symbols of {library}: {err}",
            file=sys.stderr,
        )
        return False
    defined = {
        f[2]
        for f in (line.split() for line in nm.stdout.splitlines())
        if len(f) == 3 and f[1] == "T"
    }
    bound = {
        m
        for text in outputs.values()
        for m in re.findall(r"bind\(C, name='(\w+)'\)", text)
    }
    missing = sorted(bound - defined)
    for name in missing:
        print(
            f"gen_bindings: {name} is bound but not defined in {library}",
            file=sys.stderr,
        )
    if not missing:
        print(
            f"gen_bindings: all {len(bound)} bound functions are defined in {library}"
        )
    return not missing


def main(argv: list[str]) -> int:
    """Generate, or check the committed outputs against the metadata.

    Parameters
    ----------
    argv : list[str]
        Arguments, without the script name.

    Returns
    -------
    int
        0 on success; 1 if ``--check`` finds a difference or the generation fails.
    """
    parser = argparse.ArgumentParser(
        description="Generate FIGURE's raw cimgui/cimplot/cimplot3d Fortran layer."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="only check that the committed outputs are current",
    )
    parser.add_argument(
        "--check-symbols",
        metavar="LIB",
        type=Path,
        help="also check that every bound function is defined in the static library LIB (needs nm)",
    )
    args = parser.parse_args(argv)
    try:
        outputs = generate()
    except GenerationError as err:
        print(f"gen_bindings: {err}", file=sys.stderr)
        return 1
    if args.check_symbols and not symbols_defined(outputs, args.check_symbols):
        return 1
    stale = [
        p for p, text in outputs.items() if not p.exists() or p.read_text() != text
    ]
    if args.check:
        for p in stale:
            print(
                f"gen_bindings: {p.relative_to(ROOT)} is stale: run python3 scripts/gen_bindings.py"
            )
        if not stale:
            print("gen_bindings: generated bindings are current")
        return 1 if stale else 0
    for p in stale:
        p.write_text(outputs[p])
        print(f"gen_bindings: wrote {p.relative_to(ROOT)}")
    if not stale:
        print("gen_bindings: nothing to do")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
