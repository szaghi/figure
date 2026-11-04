"""Generate FIGURE's raw Fortran layer from the cimgui and cimplot generator metadata.

Inputs: ``definitions.json`` and ``structs_and_enums.json`` of the pinned cimgui and cimplot, as fetched by the
native build (``build/native/_deps/{cimgui,cimplot}-src/generator/output``). Outputs, committed to the repository:

  - ``src/lib/figure_cimgui.F90``, ``src/lib/figure_cimplot.F90``: ``bind(C)`` interfaces of the public free
    functions that Fortran can call directly;
  - ``src/lib/figure_cimgui_enums.F90``, ``src/lib/figure_cimplot_enums.F90``: every public enumerator as an
    ``integer(c_int)`` parameter, values taken from the metadata, never hand-copied;
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
# Callback types the typedef tables omit (cimplot defines ImPlotPoint_getter in its own wrapper header).
CALLBACKS = {"ImPlotPoint_getter"}
GLUE_STRUCTS = {
    "ImVec4",
    "ImVec4_c",
    "ImPlotSpec",
    "ImPlotPoint",
    "ImPlotPoint_c",
    "ImPlotRange",
    "ImPlotRange_c",
    "ImPlotRect",
    "ImPlotRect_c",
    "ImTextureRef",
    "ImTextureRef_c",
}


@dataclass
class Library:
    """One C library to bind (cimgui or cimplot)."""

    name: str  # cimgui | cimplot
    header: str  # public header location tag in the metadata: imgui | implot
    title: str  # human name for comments
    namespace: str  # C++ namespace of the free functions
    uses: list[str] = field(
        default_factory=list
    )  # extra `use` lines of the function module


LIBRARIES = [
    Library("cimgui", "imgui", "Dear ImGui", "ImGui"),
    Library(
        "cimplot", "implot", "ImPlot", "ImPlot", ["use figure_cimgui, only : im_vec2"]
    ),
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
        Typedef map of the library (cimplot's includes cimgui's).

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
            if plain == "constchar*" and default not in ("NULL", "nullptr"):
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
        elif base in GLUE_STRUCTS:
            return _set(fn, "glue", f"`{ctype}` by value")
        elif base in SCALARS:
            ftype, kind = SCALARS[base]
            fn.args.append(Argument(name, ctype, f"{ftype}, value", kind, note))
        else:
            msg = f"{fn.cname}: unmapped argument type {ctype!r} (resolved {base!r})"
            raise GenerationError(msg)
    ret = fn.ret
    if ret == "void":
        return fn
    rbase = resolve(ret, typedefs)
    if "*" in ret:
        fn.result = ("type(c_ptr)", "c_ptr")
    elif rbase in VEC2:
        fn.result = ("type(im_vec2)", "")
    elif rbase in GLUE_STRUCTS:
        return _set(fn, "glue", f"returns `{ret}` by value")
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


def function_module(lib: Library, fns: list[Function]) -> str:
    """Render the bind(C) interface module of a library."""
    module = f"figure_{lib.name}"
    direct = [f for f in fns if f.status == "direct"]
    kinds = sorted(
        {a.kind for f in direct for a in f.args if a.kind}
        | {f.result[1] for f in direct if f.result and f.result[1]}
    )
    lines = header(
        module,
        f"raw {lib.title} interfaces (generated by scripts/gen_bindings.py: do not edit).",
        [
            f"The {len(direct)} public free functions of {lib.name} that Fortran calls directly (`bind(C)`), out of "
            f"{len(fns)}; the others need the C++ glue or are skipped: see docs/guide/raw-bindings.md. Private to the "
            "library: applications use the figure_* wrapper modules. Each dummy documents its C type and default.",
        ],
    )
    lines.append(f"use, intrinsic :: iso_c_binding, only : {', '.join(kinds)}")
    lines += lib.uses
    lines += ["", "implicit none", "private"]
    if lib.name == "cimgui":
        lines.append("public :: im_vec2")
    for chunk in _chunks([f.cname for f in direct], "public :: "):
        lines.append(chunk)
    if lib.name == "cimgui":
        lines += [
            "",
            "type, bind(C) :: im_vec2",
            "   !< ImVec2_c: a 2D vector of floats, passed by value.",
            "   real(c_float) :: x = 0.0_c_float !< Abscissa.",
            "   real(c_float) :: y = 0.0_c_float !< Ordinate.",
            "endtype im_vec2",
        ]
    lines += ["", "interface"]
    for i, f in enumerate(direct):
        if i:
            lines.append("")
        lines += interface(f, lib)
    lines += ["endinterface", f"endmodule {module}"]
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
    tail = f"{res} bind(C, name='{f.cname}')"
    first = f"   {kind} {f.cname}({dummies}){tail}"
    if len(first) <= MAX_LINE:
        lines = [first]
    else:  # dummies wrapped at commas, the result and binding label kept whole on the last line
        lines = wrap(f"   {kind} {f.cname}({dummies}) &", "      ")
        lines.append(f"      {tail.lstrip()}")
    lines += doc(f"{f.cpp}{f.signature}, {lib.header}.h.", "   !< ")
    kinds = sorted(
        {a.kind for a in f.args if a.kind}
        | ({f.result[1]} if f.result and f.result[1] else set())
    )
    needs_vec2 = any("im_vec2" in a.decl for a in f.args) or (
        f.result is not None and "im_vec2" in f.result[0]
    )
    imports = kinds + (["im_vec2"] if needs_vec2 else [])
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
        "The raw layer is generated from the cimgui and cimplot metadata by `scripts/gen_bindings.py`. A public free",
        "function is **direct** when every argument is a scalar, a pointer or an `ImVec2` by value (and so is its",
        "result): it is bound with `bind(C)` in `figure_cimgui` / `figure_cimplot`. Functions passing a larger struct",
        "by value need the C++ **glue**; variadic functions and functions taking callbacks are **skipped**. Enumerators",
        "are in `figure_cimgui_enums` / `figure_cimplot_enums`. These modules are private to the library: programs use",
        "the wrappers (`ig_*`, `ip_*`).",
        "",
        "| Library | Public functions | Direct | Glue | Skipped |",
        "|---|---|---|---|---|",
    ]
    for lib, fns in results:
        n = {s: sum(f.status == s for f in fns) for s in ("direct", "glue", "skipped")}
        out.append(
            f"| {lib.name} | {len(fns)} | {n['direct']} | {n['glue']} | {n['skipped']} |"
        )
    for lib, fns in results:
        for status, title in (("glue", "Need the glue"), ("skipped", "Skipped")):
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
    for lib in LIBRARIES:
        definitions, structs_enums, typedefs = load(lib)
        typedefs_all.update(typedefs)
        # typed enums (`enum ImGuiDir : int`) are not typedefs: map them to their underlying type, plain ones to int
        typedefs_all.update(structs_enums.get("enumtypes") or {})
        for enum in structs_enums["enums"]:
            typedefs_all.setdefault(enum.rstrip("_"), "int")
        fns = public_functions(lib, definitions, typedefs_all)
        results.append((lib, fns))
        outputs[ROOT / "src" / "lib" / f"figure_{lib.name}.F90"] = function_module(
            lib, fns
        )
        outputs[ROOT / "src" / "lib" / f"figure_{lib.name}_enums.F90"] = enum_module(
            lib, structs_enums["enums"], structs_enums.get("locations", {})
        )
    outputs[ROOT / "docs" / "guide" / "raw-bindings.md"] = report(results)
    for path, text in outputs.items():
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
        Static library holding cimgui and cimplot (``lib/libfigure_native.a``).

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
        description="Generate FIGURE's raw cimgui/cimplot Fortran layer."
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
