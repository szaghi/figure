"""Generate the name map, docs/guide/imgui-names.md: each Dear ImGui, ImPlot and ImPlot3D function, and the FIGURE call
that exposes it, or "raw only".

The upstream functions are the public free functions of Dear ImGui (``namespace ImGui`` in imgui.h), ImPlot
(``namespace ImPlot`` in implot.h) and ImPlot3D (``namespace ImPlot3D`` in implot3d.h) in cimgui's, cimplot's and
cimplot3d's metadata (``definitions.json``, the input of scripts/gen_bindings.py), less the ones behind
``IMGUI_DISABLE_OBSOLETE_FUNCTIONS`` / ``IMPLOT_DISABLE_OBSOLETE_FUNCTIONS`` / ``IMPLOT3D_DISABLE_OBSOLETE_FUNCTIONS``.
Each links to its line in the header at the vendored commit: the commits are the submodules of the cimgui, cimplot
and cimplot3d tags pinned in native/CMakeLists.txt, as fetched by the native build (build/native/_deps); ImPlot3D's
header is read from its vendored copy (third_party/implot3d, the submodule's commit, its header unpatched).

A FIGURE call exposes an upstream function when the call reaches it: the public procedures of ``use figure`` (the
testing module left out), the specific procedures of its generics and the procedures bound to its types are followed
through the library's private procedures (src/lib) down to the raw bindings they call (``ig*`` of figure_cimgui:
Dear ImGui; ``ImPlot_*`` of figure_cimplot: ImPlot) and to the native functions (``fig_*`` of figure_c_native),
whose C++ bodies (native/*.cpp) are searched for ``ImGui::Name(`` and ``ImPlot::Name(``. Helpers every drawing call
goes through (the threading and scope checks, the C strings) are not followed: they would list every FIGURE call
against the few functions they use. A function no public call reaches is "raw only": bound in figure_cimgui or
figure_cimplot (internal modules) with its C name, or not bound at all (variadic, a callback: "not bound").

Usage: python3 scripts/gen_names.py            (writes docs/guide/imgui-names.md)
       python3 scripts/check_docs.py --names   (regenerates in memory and compares)
Needs: the native build's sources (scripts/build_native.sh fetches them). Standard library only.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "src" / "lib"
NATIVE = ROOT / "native"
DEPS = ROOT / "build" / "native" / "_deps"
PAGE = ROOT / "docs" / "guide" / "imgui-names.md"
sys.path.insert(0, str(ROOT / "scripts"))
from check_docs import TYPES, parse, public_names, strip_comment, used_from  # noqa: E402

UPSTREAM = {  # library: (cimgui-like source dir, submodule, header, namespace, obsolete macro, GitHub repository)
    "Dear ImGui": ("cimgui-src", "imgui", "imgui.h", "ImGui", "IMGUI_DISABLE_OBSOLETE_FUNCTIONS", "ocornut/imgui"),
    "ImPlot": ("cimplot-src", "implot", "implot.h", "ImPlot", "IMPLOT_DISABLE_OBSOLETE_FUNCTIONS", "epezent/implot"),
    "ImPlot3D": ("cimplot3d-src", "implot3d", "implot3d.h", "ImPlot3D", "IMPLOT3D_DISABLE_OBSOLETE_FUNCTIONS",
                 "brenocq/implot3d"),
}
VENDORED = {"ImPlot3D": ROOT / "third_party" / "implot3d"}  # libraries whose header is read from the repository
NOT_FOLLOWED = {  # helpers of every drawing call: checks and conversions, not features
    "figure_draw_refused", "figure_task_refused", "c_string", "c_str", "f_string", "set_stat", "fail",
    "scope_push", "scope_pop", "scope_check", "format_ok", "format_refused", "alive",
}
NATIVE_NOT_FOLLOWED = {"frame_bar_open", "frame_bar_close", "draw_notifications"}  # FIGURE's own furniture, drawn
# by every frame: the title bar of decorations='figure' and the notifications (app%next_frame does not expose them)
NATIVE_SHARED = 4  # a native helper called by more native entry points than this is not followed
SHARED = 3  # a private helper reached by more FIGURE calls than this is not followed
IGNORED = {  # upstream accessors FIGURE uses for its own bookkeeping, exposed by no call
    "GetCurrentContext", "GetIO", "GetPlatformIO", "GetStyle", "GetMainViewport", "GetFrameCount", "GetColorU32",
    "SetupLock", "GetCurrentPlot", "GetCurrentWindow", "GetCurrentWindowRead",
}
GENERATED = {"figure_cimgui", "figure_cimplot", "figure_cimplot3d", "figure_cimgui_enums", "figure_cimplot_enums",
             "figure_cimplot3d_enums", "figure_icons"}


class NamesError(Exception):
    """The inputs of the name map are missing."""


def upstream_functions(lib: str) -> tuple[dict[str, list[tuple[int, str]]], str, str]:
    """The public functions of a library (name: [(header line, C name), ...]), its version and the header's URL."""
    src, sub, header, ns, obsolete, repo = UPSTREAM[lib]
    defs = DEPS / src / "generator" / "output" / "definitions.json"
    hdr = VENDORED[lib] / header if lib in VENDORED else DEPS / src / sub / header
    if not defs.is_file() or not hdr.is_file():
        msg = f"{defs.relative_to(ROOT)} or {hdr.relative_to(ROOT)} missing: run scripts/build_native.sh"
        raise NamesError(msg)
    tree = subprocess.run(["git", "-C", str(DEPS / src), "ls-tree", "HEAD", sub], capture_output=True, text=True,
                          check=False).stdout.split()
    if len(tree) < 3:
        msg = f"the {sub} submodule of {src} has no commit (git ls-tree): run scripts/build_native.sh"
        raise NamesError(msg)
    commit = tree[2]
    lines = hdr.read_text().splitlines()
    version = next(re.search(r'"([^"]+)"', ln).group(1) for ln in lines if re.match(r"#define (IMGUI|IMPLOT|IMPLOT3D)_VERSION ", ln))
    hidden: set[int] = set()  # header lines behind the obsolete macro
    depth: list[bool] = []
    for n, line in enumerate(lines, 1):
        s = line.strip()
        if s.startswith("#if"):
            depth.append(obsolete in s and ("ifndef" in s or "!defined" in s))
        elif s.startswith("#endif") and depth:
            depth.pop()
        elif s.startswith(("#else", "#elif")) and depth:
            depth[-1] = False
        if any(depth):
            hidden.add(n)
    out: dict[str, list[tuple[int, str]]] = {}
    for overloads in json.loads(defs.read_text()).values():
        for ov in overloads:
            where, _, line = ov.get("location", "").partition(":")
            if (ov.get("namespace") != ns or ov.get("stname") or where != header.removesuffix(".h")
                    or int(line) in hidden):
                continue
            out.setdefault(ov["funcname"], []).append((int(line), ov["ov_cimguiname"]))
    return out, version, f"https://github.com/{repo}/blob/{commit}/{header}"


def bound_names() -> set[str]:
    """C names bound by the raw modules (figure_cimgui, figure_cimplot, figure_cimplot3d)."""
    names: set[str] = set()
    for f in ("figure_cimgui.F90", "figure_cimplot.F90", "figure_cimplot3d.F90"):
        names.update(re.findall(r"bind\(C,\s*name='(\w+)'\)", (LIB / f).read_text()))
        names.update(re.findall(r"^\s*(?:function|subroutine)\s+(\w+)", (LIB / f).read_text(), re.M))
    return names


def block_end(code: str, i: int) -> int:
    """The index after the brace closing the block that starts at i (strings, characters and comments skipped)."""
    level = 1
    n = len(code)
    while i < n and level:
        ch = code[i]
        if code.startswith("//", i):
            i = code.find("\n", i)
            i = n if i < 0 else i
        elif code.startswith("/*", i):
            i = code.find("*/", i) + 2 or n
        elif code.startswith('R"(', i):
            i = code.find(')"', i) + 2 or n
        elif ch in "\"'":
            i += 1
            while i < n and code[i] != ch:
                i += 2 if code[i] == "\\" else 1
            i += 1
        else:
            level += {"{": 1, "}": -1}.get(ch, 0)
            i += 1
    return i


def native_calls() -> dict[str, set[str]]:
    """For each native function the Fortran side binds (its Fortran interface name), the upstream calls in its body
    and in the native helpers it calls (one level; a helper called by many native functions is not followed)."""
    cpp = "\n".join(p.read_text() for p in sorted(NATIVE.glob("*.cpp")))
    bodies: dict[str, str] = {}
    for m in re.finditer(r"^(?:[A-Za-z_][\w:<>\*&, ]*?\s|extern \"C\" [\w:<>\*& ]*?)\b(\w+)\s*\([^;{}]*\)\s*(?:const\s*)?\{",
                         cpp, re.M):
        if m.group(1) in ("if", "for", "while", "switch", "return"):
            continue
        bodies[m.group(1)] = bodies.get(m.group(1), "") + cpp[m.end():block_end(cpp, m.end())]
    upstream = {n: {f"ImGui::{c}" for c in re.findall(r"\bImGui::(\w+)\s*\(", b)}
                | {f"ImPlot::{c}" for c in re.findall(r"\bImPlot::(\w+)\s*\(", b)}
                | {f"ImPlot3D::{c}" for c in re.findall(r"\bImPlot3D::(\w+)\s*\(", b)} for n, b in bodies.items()}
    helpers = {n: {c for c in re.findall(r"\b(\w+)\s*\(", b) if c in bodies and c != n and not c.startswith("fig_")}
               for n, b in bodies.items()}
    users: dict[str, int] = {}
    for n, hs in helpers.items():
        if n.startswith("fig_"):
            for h in hs:
                users[h] = users.get(h, 0) + 1
    cname = dict(re.findall(r"(?:function|subroutine)\s+(\w+)\s*\([^)]*\)[^\n]*?bind\(C,\s*name='(\w+)'\)",
                            re.sub(r"&\s*\n\s*", " ", (LIB / "figure_c_native.F90").read_text())))
    calls: dict[str, set[str]] = {}
    for fname, c in cname.items():
        if c not in bodies:
            continue
        reached = set(upstream[c])
        level = {h for h in helpers[c] if users.get(h, 0) <= NATIVE_SHARED and h not in NATIVE_NOT_FOLLOWED}
        for _ in range(1):
            nxt: set[str] = set()
            for h in level:
                reached |= upstream[h]
                nxt |= {g for g in helpers[h] if users.get(g, 0) <= NATIVE_SHARED}
            level = nxt
        calls[fname.lower()] = reached
    return calls


def library_calls() -> tuple[dict[tuple[str, str], set[str]], dict]:
    """For each procedure of src/lib, (module, name): the identifiers its body calls (lower case); and the sources."""
    calls: dict[tuple[str, str], set[str]] = {}
    sources = {}
    for path in sorted(LIB.glob("*.F90")):
        if path.stem in GENERATED:
            continue
        mod = path.stem.lower()
        sources[mod] = parse(path)
        lines = path.read_text().splitlines()
        for name, procs in sources[mod].procs.items():
            p = procs[0]
            end = re.compile(rf"^\s*end\s*(subroutine|function)\s*{name}\b", re.I)
            body = []
            for line in lines[p.line:]:
                if end.match(line):
                    break
                body.append(strip_comment(line))
            calls[(mod, name)] = {n.lower() for n in re.findall(r"\b([A-Za-z]\w*)\s*\(", "\n".join(body))}
    return calls, sources


def public_calls(sources: dict) -> dict[tuple[str, str], str]:
    """The implementations of ``use figure``'s procedures, (module, name): the FIGURE call a reader writes."""
    public: dict[tuple[str, str], str] = {}
    origin = used_from(LIB / "figure.F90")
    for pub in public_names(LIB / "figure.F90"):
        name = pub.lower()
        mod = origin.get(name, "figure")
        src = sources.get(mod)
        if src is None or re.match(r"^(imgui|implot|fig_|icon_)", name):
            continue
        if name in src.types:
            bindings = src.types[name][2]
            for binding, impl, private in bindings:
                generic = [b.split(":")[0] for b, _, _ in bindings if b.endswith(f":{binding}")]
                if ":" in binding or (private and not generic):
                    continue
                shown = generic[0] if generic else binding
                public[(mod, impl)] = f"{TYPES.get(name, name.removesuffix('_object'))}%{shown}"
        elif name in src.generics:
            for s in src.generics[name][2]:
                public[(mod, s)] = name
        else:
            public[(mod, name)] = name
    return public


def exposures() -> dict[str, set[str]]:
    """For each upstream call (``ImGui::Name``, ``ImPlot::Name``, or a raw C name), the FIGURE calls that reach it."""
    calls, sources = library_calls()
    native = native_calls()
    public = public_calls(sources)
    where: dict[str, list[str]] = {}  # procedure name: the modules defining it
    for mod, name in calls:
        where.setdefault(name, []).append(mod)

    def resolve(mod: str, name: str) -> tuple[str, str] | None:
        """The procedure a call names, from module mod: its own first, else the only other one."""
        if (mod, name) in calls:
            return mod, name
        mods = where.get(name, [])
        return (mods[0], name) if len(mods) == 1 else None

    # a private helper reached by several FIGURE calls is a shared check or conversion, not a feature: not followed
    users: dict[tuple[str, str], set[str]] = {}
    for key, shown in public.items():
        for c in calls[key]:
            r = resolve(key[0], c)
            if r and r not in public:
                users.setdefault(r, set()).add(shown)
    shared = {k for k, v in users.items() if len(v) > SHARED}

    def upstream_of(key: tuple[str, str]) -> set[str]:
        out: set[str] = set()
        seen: set[tuple[str, str]] = set()
        todo = [key]
        while todo:
            k = todo.pop()
            if k in seen:
                continue
            seen.add(k)
            for c in calls.get(k, ()):
                if c in native:
                    out |= native[c]
                elif re.match(r"ig[a-z]", c) and c not in where:  # a raw binding of figure_cimgui: igsetscrollherey
                    out.add(c)
                elif c.startswith(("implot_", "implot3d_")) and c not in where:  # of figure_cimplot, figure_cimplot3d
                    out.add(c)
                else:
                    r = resolve(k[0], c)
                    if r and r not in public and r not in shared and r[1] not in NOT_FOLLOWED:
                        todo.append(r)  # a private helper; another FIGURE call is not followed
        return out

    result: dict[str, set[str]] = {}
    for key, shown in public.items():
        for c in upstream_of(key):
            if c.split("::")[-1] not in IGNORED:
                result.setdefault(c, set()).add(shown)
    return result


def generate() -> str:
    """The name map page."""
    exposed = exposures()
    bound = {b.lower(): b for b in bound_names()}
    out = [
        "---",
        "title: Dear ImGui and ImPlot names",
        "---",
        "",
        "# Dear ImGui and ImPlot names",
        "",
        "<!-- generated by scripts/gen_names.py: do not edit -->",
        "",
    ]
    sections = []
    totals = []
    for lib in UPSTREAM:
        funcs, version, url = upstream_functions(lib)
        prefix = {"Dear ImGui": "ImGui::", "ImPlot": "ImPlot::", "ImPlot3D": "ImPlot3D::"}[lib]
        rows = []
        n_exposed = 0
        for name in sorted(funcs, key=str.lower):
            overloads = sorted(funcs[name])
            figure: set[str] = set(exposed.get(prefix + name, set()))
            for _, c in overloads:
                figure |= exposed.get(c.lower(), set())
            link = f"[`{name}`]({url}#L{overloads[0][0]})"
            if figure:
                n_exposed += 1
                cell = ", ".join(f"`{f}`" for f in sorted(figure))
            else:
                raw = [bound[c.lower()] for _, c in overloads if c.lower() in bound]
                cell = "raw only: " + (", ".join(f"`{r}`" for r in raw) if raw else "not bound")
            rows.append(f"| {link} | {cell} |")
        totals.append((lib, version, url, n_exposed, len(funcs)))
        sections += [f"## {lib} {version}", "", f"| {lib} | FIGURE |", "|---|---|", *rows, ""]
    (_, v1, u1, e1, n1), (_, v2, u2, e2, n2), (_, v3, u3, e3, n3) = totals
    out += [
        "Each public function of Dear ImGui, ImPlot and ImPlot3D, linked to its declaration in the header FIGURE is "
        f"built with ([imgui.h]({u1}), Dear ImGui {v1}, docking branch; [implot.h]({u2}), ImPlot {v2}; "
        f"[implot3d.h]({u3}), ImPlot3D {v3}), and the FIGURE calls that reach it. FIGURE exposes {e1} of the {n1} "
        f"Dear ImGui functions, {e2} of the {n2} ImPlot functions and {e3} of the {n3} ImPlot3D functions. A reader "
        "of Dear ImGui's, ImPlot's or ImPlot3D's documentation finds here the FIGURE name of what they read about; the [feature map](features) lists FIGURE's calls, and each reference section names the upstream "
        "functions it wraps.",
        "",
        "- A FIGURE call is listed when it calls the function, directly or through the library's own procedures: "
        "`ig_scroll_here` reaches `SetScrollHereY` (and `SetScrollHereX` with `axis='x'`). A call listed against "
        "several functions combines them (`ig_begin_popup_context` is `BeginPopupContextItem`, "
        "`BeginPopupContextWindow` and `BeginPopupContextVoid` by its `on` argument); one that reaches a function "
        "only for its own bookkeeping is listed too.",
        "- **raw only:** no FIGURE call reaches it. The C name is the function's binding in the raw modules "
        "(`figure_cimgui`, `figure_cimplot`, `figure_cimplot3d`), which are internal to the library ([Raw bindings](raw-bindings)): a "
        "program needing one asks for a wrapper. **not bound:** variadic or taking a callback, skipped by the raw "
        "layer.",
        "- Functions behind `IMGUI_DISABLE_OBSOLETE_FUNCTIONS`, `IMPLOT_DISABLE_OBSOLETE_FUNCTIONS` and "
        "`IMPLOT3D_DISABLE_OBSOLETE_FUNCTIONS` are left out: FIGURE does not bind them.",
        "",
        "Generated by `scripts/gen_names.py` from cimgui's, cimplot's and cimplot3d's metadata, the library's sources and the "
        "native glue; `python3 scripts/check_docs.py --names` fails when this page is not current.",
        "",
    ]
    return "\n".join(out + sections).rstrip("\n") + "\n"


def main() -> int:
    """Write the name map."""
    try:
        text = generate()
    except NamesError as err:
        print(f"gen_names.py: {err}", file=sys.stderr)
        return 1
    PAGE.write_text(text)
    print(f"gen_names.py: wrote {PAGE.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
