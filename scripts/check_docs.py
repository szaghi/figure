"""Check that the documentation is complete: the feature map, the doc comments, the examples, the name map, the media.

Default checks (exit 1 and a list of what is missing):

- **Feature map:** docs/guide/features.md lists every public procedure of FIGURE. The public API is what
  ``use figure`` and ``use figure_testing`` export: the module procedures and types named in their ``public``
  statements (constants, the ``ImGui*``/``ImPlot*``/``FIG_*``/``ICON_*`` names, are documented by family), and the
  type-bound procedures of the public types (``app%init``, ``tex%update``, ...). Each must appear in the feature map
  as code (``name`` or ``app%name``).
- **Doc comments:** every public entity has a ``!<`` doc comment on the line after its statement (a procedure, a
  generic interface, a derived type; the specific procedures of a generic and the procedures bound to a public type
  included), every public component of a public type and every dummy argument of those procedures has a ``!<``
  comment on its declaration.
- **Tags:** no doc comment (``!<``) of the library's sources, both paths, holds a bare HTML-like tag (``<name>``)
  outside backticks: the API pages are generated from them and VitePress reads such a tag as HTML (an unclosed one
  breaks the site's build).
- **Examples:** every section a feature-map row links to (``[text](page#anchor)``, or a whole page) includes a
  compiled example (``<<< @/examples/snippets/...``); a row marked ``<!-- visual -->`` also needs a ``<Media`` in
  each section it links to.
- **Code:** no hand-written ```fortran block in docs/index.md, docs/guide, docs/manual and docs/adr (#6 §4.4), and every
  ``<<< @/examples/...`` include names a file that exists.
- **Tables:** every row of a table in docs/index.md, docs/guide, docs/manual and docs/adr has its header's cell count (GFM
  drops the cells beyond it, and their links with them).
- **Links:** every internal link ``[text](page#anchor)`` of those pages names a page that exists and, with an anchor,
  a heading of it (VitePress's slugs, a repeated heading's ``-1``, ``{#id}``), or a file docs/public serves.
- **Generated tables:** docs/guide/_generated/*.md (the modules, the native layer, a recording's header lines) equal
  what scripts/gen_doc_tables.py writes now, and each studio chapter's "What this chapter adds" and run regions what
  scripts/gen_tutorial_adds.py writes.
- **Prose:** every public name (a procedure, or a type-bound one as ``var%proc``) is named by a sentence: a line
  outside tables, fenced blocks and headings of the page its feature-map row links to, or of a page the linked section
  links to (a type-bound name counts as ``%proc`` or as code starting with ``proc``).
- **Example calls:** every public name is called by a program of docs/examples/src (``use`` statements and comments
  left out); ``EXAMPLE_EXEMPT`` lists the names no docs program can sensibly call, each with its reason.
- **README:** README.md's first ```fortran block equals docs/examples/src/readme.F90, which docs/examples/build.sh
  compiles.
- **Version:** the version strings of the docs (``VERSIONED``: the status lines of README.md, docs/index.md and
  docs/guide/index.md, the fpm tags of README.md and docs/guide/install.md, contributing.md's "FIGURE is at", the
  CMake ``find_package`` minimum of docs/guide/install.md and scripts/cmake_consumer, the roadmap's section) say the
  version in VERSION. scripts/release_hook.sh, run by scripts/release.sh after it writes VERSION, calls ``--bump``, so a
  release commit carries them.

Options:

- ``--names``: regenerate the name map (scripts/gen_names.py) in memory and fail if docs/guide/imgui-names.md differs.
- ``--media``: fail if the media a page shows (``<Media name>``: docs/public/media/<name>.png, .mp4, .gif) weigh more
  than 5 MB in all on that page, or if a ``<Media>`` names a recording that does not exist.

- ``--bump vX.Y.Z [--dry-run]``: write that version and today's date into the version strings (the roadmap's
  ``## vX.Y.Z — in progress`` or ``— planned`` becomes ``— released <date>``), print the files changed, run no
  check; ``--dry-run`` writes nothing. Fails if a string is not found (a section of the roadmap for the version
  included).

Usage: python3 scripts/check_docs.py [--names] [--media] | --bump vX.Y.Z [--dry-run]. Standard library only; run
from anywhere.
"""

from __future__ import annotations

import datetime
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "src" / "lib"
GUIDE = ROOT / "docs" / "guide"
FEATURES = GUIDE / "features.md"
MEDIA = ROOT / "docs" / "public" / "media"
MEDIA_LIMIT = 5 * 1024 * 1024  # bytes of media on one page (#6 §4.5)
CONSTANT = re.compile(r"^(ImGui|ImPlot|FIG_|ICON_)")
TYPES = {
    "app_object": "app",
    "texture_object": "tex",
    "list_clipper_object": "clip",
    "process_object": "p",
    "log_view_object": "log",
    "task_object": "t",
    "task_handle_object": "h",
    "text_buffer_object": "buf",
    "view3d_object": "v",
    "code_editor_object": "ed",
    "language_object": "lang",
    "markdown_view_object": "md",
}  # public types with type-bound procedures, and the variable name the docs use
INCLUDE = "<<< @/examples/snippets/"


# ----------------------------------------------------------------------------------------------------- Fortran parsing
def strip_comment(line: str) -> str:
    """The code of a line, without its comment (a ``!`` outside a string)."""
    quote = ""
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = ""
        elif ch in "'\"":
            quote = ch
        elif ch == "!":
            return line[:i]
    return line
PATHS = ROOT / "src" / "paths" / "imgui"  # the current path's seams, outside src/lib (szaghi/figure#15 §2)


def library_files() -> list[Path]:
    """The library's sources on the current path: src/lib and the seams over Dear ImGui."""
    return sorted([*LIB.glob("*.F90"), *PATHS.rglob("*.F90")])


def module_file(module: str) -> Path:
    """The source of a library module on the current path (``figure`` or ``figure.F90``)."""
    stem = module.removesuffix(".F90").lower()
    return next((p for p in library_files() if p.stem.lower() == stem), LIB / f"{stem}.F90")



def statement_end(lines: list[str], i: int) -> int:
    """Index of the last physical line of the statement starting at line i (``&`` continuations)."""
    while strip_comment(lines[i]).rstrip().endswith("&") and i + 1 < len(lines):
        i += 1
    return i


def joined(lines: list[str], i: int, j: int) -> str:
    """The code of lines i..j joined into one statement, comments and ``&`` removed."""
    parts = []
    for k in range(i, j + 1):
        code = strip_comment(lines[k]).strip()
        code = code.removesuffix("&").removeprefix("&")
        parts.append(code)
    return " ".join(parts)


def next_code_line(lines: list[str], i: int) -> str:
    """The first non-blank line after line i, stripped."""
    for k in range(i + 1, len(lines)):
        if lines[k].strip():
            return lines[k].strip()
    return ""


def entity_names(spec: str) -> list[str]:
    """The names declared by a declaration statement's entity list (what follows ``::``)."""
    ents = spec.split("::", 1)[1]
    ents = ents.split("=>")[0] if "procedure" in spec.split("::", 1)[0].lower() else ents
    prev = None
    while prev != ents:  # drop array specs, lengths and initialisers in parentheses, innermost first
        prev = ents
        ents = re.sub(r"\([^()]*\)|\[[^\[\]]*\]", "", ents)
    names = []
    for ent in ents.split(","):
        m = re.match(r"\s*(\w+)", ent)
        if m:
            names.append(m.group(1).lower())
    return names


PROC = re.compile(
    r"^\s*(?:(?:recursive|pure|elemental|impure|module|non_recursive)\s+|"
    r"(?:integer|real|logical|character|complex|type|class)\s*(?:\([^)]*\))?\s+)*"
    r"(subroutine|function)\s+(\w+)\s*(?:\(([^)]*)\))?",
    re.I,
)


@dataclass
class Proc:
    """A procedure found in a source file."""

    name: str
    file: Path
    line: int  # 1-based, of its statement
    documented: bool
    undocumented: list[str] = field(default_factory=list)  # dummy arguments without a comment


@dataclass
class Source:
    """What check_docs needs of one Fortran file."""

    procs: dict[str, list[Proc]] = field(default_factory=dict)
    generics: dict[str, tuple[int, bool, list[str]]] = field(default_factory=dict)  # name: line, documented, specifics
    types: dict[str, tuple[int, bool, list[tuple[str, str, bool]]]] = field(default_factory=dict)
    # type name: line, documented, [(binding, implementation, private)]
    components: dict[str, list[str]] = field(default_factory=dict)  # type name: public components without a comment


def parse(path: Path) -> Source:
    """Procedures, generic interfaces and derived types of a Fortran source file."""
    lines = path.read_text().splitlines()
    src = Source()
    i = 0
    while i < len(lines):
        code = strip_comment(lines[i]).strip()
        low = code.lower()
        j = statement_end(lines, i)
        stmt = joined(lines, i, j)
        m = PROC.match(stmt)
        if m and not re.match(r"\s*end", low):
            name = m.group(2).lower()
            args = [a.strip().lower() for a in (m.group(3) or "").split(",") if a.strip()]
            documented = next_code_line(lines, j).startswith("!<")
            end = re.compile(rf"^\s*end\s*(subroutine|function)\s*{name}\b|^\s*end\s*$", re.I)
            k = j + 1
            declared: set[str] = set()
            while k < len(lines) and not end.match(strip_comment(lines[k])):
                if re.match(r"^\s*contains\b", strip_comment(lines[k]), re.I):
                    break
                ke = statement_end(lines, k)
                decl = joined(lines, k, ke)
                if "::" in decl and not decl.lower().lstrip().startswith(("use ", "import")):
                    comment = any("!<" in lines[n] for n in range(k, ke + 1))
                    if comment:
                        declared.update(entity_names(decl))
                k = ke + 1
            proc = Proc(name, path, i + 1, documented, [a for a in args if a not in declared and a != "*"])
            src.procs.setdefault(name, []).append(proc)
            i = j + 1
            continue
        gm = re.match(r"^interface\s+(\w+)\s*$", code, re.I)
        if gm:
            name = gm.group(1).lower()
            documented = next_code_line(lines, i).startswith("!<")
            specifics: list[str] = []
            k = i + 1
            while k < len(lines) and not re.match(r"^\s*end\s*interface", lines[k], re.I):
                ke = statement_end(lines, k)
                decl = joined(lines, k, ke)
                pm = re.match(r"^\s*(?:module\s+)?procedure\s*(?:::)?\s*(.*)", decl, re.I)
                if pm:
                    specifics += [s.strip().lower() for s in pm.group(1).split(",") if s.strip()]
                k = ke + 1
            src.generics[name] = (i + 1, documented, specifics)
            i = k + 1
            continue
        tm = re.match(r"^type\s*(?:,[^:]*)?::\s*(\w+)", code, re.I)
        if tm:
            name = tm.group(1).lower()
            documented = "!<" in lines[i] or next_code_line(lines, i).startswith("!<")
            bindings: list[tuple[str, str, bool]] = []
            components: list[str] = []  # public components without a comment
            k = i + 1
            in_contains = False
            while k < len(lines) and not re.match(r"^\s*end\s*type", lines[k], re.I):
                decl = strip_comment(lines[k])
                in_contains = in_contains or bool(re.match(r"^\s*contains\b", decl, re.I))
                if (not in_contains and "::" in decl and "private" not in decl.split("::")[0].lower()
                        and "!<" not in lines[k]):
                    components += entity_names(decl)
                pm = re.match(r"^\s*procedure\s*(,[^:]*)?::\s*(\w+)\s*(?:=>\s*(\w+))?", decl, re.I)
                if pm:
                    private = "private" in (pm.group(1) or "").lower()
                    bindings.append((pm.group(2).lower(), (pm.group(3) or pm.group(2)).lower(), private))
                gm2 = re.match(r"^\s*generic\s*(,[^:]*)?::\s*(\w+)\s*=>\s*(.*)", decl, re.I)
                if gm2 and "private" not in (gm2.group(1) or "").lower():
                    for spec in gm2.group(3).split(","):
                        bindings.append((f"{gm2.group(2).lower()}:{spec.strip().lower()}", spec.strip().lower(), False))
                k += 1
            src.types[name] = (i + 1, documented, bindings)
            src.components[name] = components
            i = k + 1
            continue
        i = j + 1
    return src


def public_names(module: Path) -> list[str]:
    """Names in a module's public statements (continuation lines joined)."""
    text = re.sub(r"&\s*\n\s*", " ", module.read_text())
    names: list[str] = []
    for line in text.splitlines():
        m = re.match(r"\s*public\s*::\s*(.*)", line, re.I)
        if m:
            names += [n.strip() for n in m.group(1).split("!")[0].split(",") if n.strip()]
    return names


def used_from(module: Path) -> dict[str, str]:
    """For each name a module takes with ``use M, only : ...``, the module M."""
    text = re.sub(r"&\s*\n\s*", " ", module.read_text())
    origin: dict[str, str] = {}
    for m in re.finditer(r"^\s*use\s+(\w+)\s*,\s*only\s*:\s*(.*)$", text, re.M | re.I):
        for n in strip_comment(m.group(2)).split(","):
            if n.strip():
                origin[n.strip().split("=>")[0].strip().lower()] = m.group(1).lower()
    return origin


def type_bound(module: Path, type_name: str) -> list[str]:
    """The public type-bound procedures of a derived type (procedure statements inside its definition)."""
    text = module.read_text()
    m = re.search(rf"type\s*(?:,[^:]*)?::\s*{type_name}\b(.*?)endtype", text, re.S | re.I)
    if not m:
        return []
    return [
        b.group(1)
        for b in re.finditer(r"^\s*procedure[^:]*::\s*(\w+)", m.group(1), re.M | re.I)
        if "private" not in b.group(0).lower()
    ]


TAG = re.compile(r"</?[A-Za-z][\w.:-]*(?:\s[^<>]*)?/?>")  # an HTML-like tag, as VitePress would read it


def check_tags() -> list[str]:
    """Doc comments of the library (src/lib, src/paths: both paths) with a bare tag outside backticks."""
    missing: list[str] = []
    for path in sorted([*LIB.rglob("*.F90"), *(ROOT / "src" / "paths").rglob("*.F90")]):
        for n, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
            at = line.find("!<")
            if at < 0:
                continue
            text = re.sub(r"`[^`]*`", "", line[at + 2:])
            for m in TAG.finditer(text):
                missing.append(f"{path.relative_to(ROOT)}:{n}: a bare tag {m.group(0)} in a doc comment (write it in "
                               "backticks: VitePress reads it as HTML)")
    return missing


def check_comments() -> list[str]:
    """Public entities and dummy arguments without a ``!<`` doc comment."""
    sources = {p.stem.lower(): parse(p) for p in library_files()}
    missing: list[str] = []
    seen: set[tuple[str, str]] = set()

    def rel(path: Path, line: int) -> str:
        return f"{path.relative_to(ROOT)}:{line}"

    def check_proc(mod: str, name: str, what: str) -> None:
        procs = sources.get(mod, Source()).procs.get(name) or [
            p for s in sources.values() for p in s.procs.get(name, [])
        ]
        if not procs:
            missing.append(f"no definition found for {what}")
            return
        p = procs[0]
        if (str(p.file), p.name) in seen:
            return
        seen.add((str(p.file), p.name))
        if not p.documented:
            missing.append(f"{rel(p.file, p.line)}: {what} has no !< doc comment")
        for a in p.undocumented:
            missing.append(f"{rel(p.file, p.line)}: {what}: dummy argument {a} has no !< comment")

    def check_type(mod: str, name: str) -> None:
        src = sources[mod]
        line, documented, bindings = src.types[name]
        path = module_file(mod)
        if not documented:
            missing.append(f"{rel(path, line)}: type {name} has no !< doc comment")
        for comp in src.components.get(name, []):
            missing.append(f"{rel(path, line)}: type {name}: component {comp} has no !< comment")
        for binding, impl, private in bindings:
            if not private or any(b.endswith(f":{binding}") for b, _, _ in bindings):
                check_proc(mod, impl, f"{name}%{binding.split(':')[0]} ({impl})")

    for module in ("figure", "figure_testing"):
        origin = used_from(module_file(module))
        for pub in public_names(module_file(module)):
            if CONSTANT.match(pub):
                continue
            name = pub.lower()
            mod = origin.get(name, module)
            src = sources.get(mod)
            if src is None:
                missing.append(f"module {mod} of {name} not found in src/lib")
                continue
            if name in src.types:
                check_type(mod, name)
            elif name in src.generics:
                line, documented, specifics = src.generics[name]
                if not documented:
                    missing.append(f"{rel(module_file(mod), line)}: generic {name} has no !< doc comment")
                for s in specifics:
                    check_proc(mod, s, f"{name} (specific {s})")
            else:
                check_proc(mod, name, f"procedure {name}")
    return missing


# ------------------------------------------------------------------------------------------------------ the feature map
def slugify(text: str) -> str:
    """VitePress's heading anchor (@mdit-vue/shared slugify)."""
    text = re.sub(r"`", "", text)
    text = unicodedata.normalize("NFKD", text)
    text = re.sub(r"[̀-ͯ]", "", text)
    text = re.sub(r"[\u0000-\u001f]", "", text)
    text = re.sub(r"[\s~`!@#$%^&*()\-_+=\[\]{}|\\;:\"'“”‘’<>,.?/]+", "-", text)
    text = re.sub(r"-{2,}", "-", text).strip("-")
    text = re.sub(r"^(\d)", r"_\1", text)
    return text.lower()


def sections(page: Path) -> dict[str, str]:
    """Each heading's anchor and its section's text (to the next heading of the same or a higher level)."""
    lines = page.read_text().splitlines()
    heads: list[tuple[int, int, str]] = []
    fence = False
    for n, line in enumerate(lines):
        if line.startswith("```"):
            fence = not fence
        m = None if fence else re.match(r"^(#{1,6})\s+(.*?)\s*$", line)
        if m:
            heads.append((n, len(m.group(1)), slugify(m.group(2))))
    out: dict[str, str] = {"": "\n".join(lines)}
    for k, (n, level, slug) in enumerate(heads):
        end = next((h[0] for h in heads[k + 1 :] if h[1] <= level), len(lines))
        out.setdefault(slug, "\n".join(lines[n:end]))
    return out


def check_rows() -> list[str]:
    """Feature-map rows whose linked sections have no compiled example (or, visual rows, no picture or video)."""
    missing: list[str] = []
    cache: dict[str, dict[str, str]] = {}
    for n, row in enumerate(FEATURES.read_text().splitlines(), 1):
        if row.startswith("## Environment variables"):  # not procedures: the rest of the page is left out
            break
        if not row.startswith("| `"):
            continue
        visual = "<!-- visual -->" in row
        links = re.findall(r"\]\(([a-z0-9-]+)(?:#([^)]*))?\)", row)
        if not links:
            missing.append(f"docs/guide/features.md:{n}: a row with no link to its section")
        for page, anchor in links:
            path = GUIDE / f"{page}.md"
            if not path.is_file():
                missing.append(f"docs/guide/features.md:{n}: link to a missing page {page}")
                continue
            secs = cache.setdefault(page, sections(path))
            text = secs.get(anchor or "")
            where = f"{page}#{anchor}" if anchor else page
            if text is None:
                missing.append(f"docs/guide/features.md:{n}: link to a missing section {where}")
                continue
            if INCLUDE not in text:
                missing.append(f"docs/guide/features.md:{n}: section {where} has no compiled example ({INCLUDE}...)")
            if visual and "<Media" not in text:
                missing.append(f"docs/guide/features.md:{n}: section {where} (a visual row) has no <Media>")
    return missing


def check_feature_map() -> list[str]:
    """Public procedures missing from the feature map."""
    doc = FEATURES.read_text()
    code = set(re.findall(r"`([^`]+)`", doc))
    words = {w for c in code for w in re.findall(r"[\w%]+", c)}
    missing: list[str] = []
    for module in ("figure.F90", "figure_testing.F90"):
        for name in public_names(module_file(module)):
            if not CONSTANT.match(name) and name not in words:
                missing.append(f"not in docs/guide/features.md: {name} ({module})")
    for type_name, var in TYPES.items():
        for f in library_files():
            for proc in type_bound(f, type_name):
                if f"{var}%{proc}" not in words:
                    missing.append(f"not in docs/guide/features.md: {var}%{proc} ({f.name})")
    return missing


def check_code_blocks() -> list[str]:
    """Hand-written blocks of Fortran in the pages (every block of FIGURE calls comes from a compiled example), and
    includes of examples that do not exist."""
    missing: list[str] = []
    pages = [ROOT / "docs" / "index.md", *sorted((ROOT / "docs" / "guide").glob("*.md")),
             *sorted((ROOT / "docs" / "manual").rglob("*.md"))]
    for page in pages:
        for n, line in enumerate(page.read_text().splitlines(), 1):
            if re.match(r"^\s*```\s*(fortran|f90|F90)\b", line):
                missing.append(f"{page.relative_to(ROOT)}:{n}: a hand-written fortran block (include a compiled "
                               f"example: {INCLUDE}<file>-<region>.F90)")
            inc = re.match(r"^<<< @/(examples/[^{\s]+)", line)
            if inc and not (ROOT / "docs" / inc.group(1)).is_file():
                missing.append(f"{page.relative_to(ROOT)}:{n}: {inc.group(1)} does not exist (bash docs/examples/build.sh "
                               "writes the snippets and outputs; a region or a !run marker is missing?)")
    return missing


def check_readme() -> list[str]:
    """README.md's Fortran block against the compiled example."""
    readme = (ROOT / "README.md").read_text()
    block = re.search(r"```fortran\n(.*?)```", readme, re.S)
    example = (ROOT / "docs" / "examples" / "src" / "readme.F90").read_text()
    if not block or block.group(1) != example:
        return ["README.md: its fortran block differs from docs/examples/src/readme.F90 (the compiled one)"]
    return []


# ------------------------------------------------------------------------------------------------- the version strings
_V = r"v\d+\.\d+\.\d+"
_D = r"\d{4}-\d{2}-\d{2}"
# (file, pattern, replacement): the pattern's group "v" is the version (with its v), "d" the date; the replacement is
# formatted with the new version (v), its major.minor without the v (mm: CMake's find_package minimum) and the date
# (d); a replacement with {mm} compares the group "v" with major.minor
_MM = r"\d+\.\d+"
VERSIONED = [
    ("README.md", rf"\*\*Status:\*\* (?P<v>{_V}), released (?P<d>{_D})", "**Status:** {v}, released {d}"),
    ("README.md", rf'tag = "(?P<v>{_V})-fpm"', 'tag = "{v}-fpm"'),
    ("docs/index.md", rf"FIGURE (?P<v>{_V}) is released \((?P<d>{_D})\)", "FIGURE {v} is released ({d})"),
    ("docs/guide/index.md", rf"FIGURE (?P<v>{_V}) is released \((?P<d>{_D})\)", "FIGURE {v} is released ({d})"),
    ("docs/guide/install.md", rf'tag = "(?P<v>{_V})-fpm"', 'tag = "{v}-fpm"'),
    ("docs/guide/contributing.md", rf"FIGURE is at (?P<v>{_V});", "FIGURE is at {v};"),
    ("docs/guide/install.md", rf"find_package\(figure (?P<v>{_MM}) CONFIG", "find_package(figure {mm} CONFIG"),
    ("scripts/cmake_consumer/CMakeLists.txt", rf"find_package\(figure (?P<v>{_MM}) CONFIG",
     "find_package(figure {mm} CONFIG"),
]


def major_minor(version: str) -> str:
    """'v0.7.0' -> '0.7'."""
    return ".".join(version.lstrip("v").split(".")[:2])


def check_version() -> list[str]:
    """The version strings of the docs against VERSION, and the roadmap's section of that version released."""
    version = (ROOT / "VERSION").read_text().strip()
    missing: list[str] = []
    for name, pattern, template in VERSIONED:
        found = [m.group("v") for m in re.finditer(pattern, (ROOT / name).read_text())]
        want = major_minor(version) if "{mm}" in template else version
        if not found:
            missing.append(f"{name}: no version string /{pattern}/")
        missing += [f"{name}: says {v}, VERSION is {version} (python3 scripts/check_docs.py --bump {version})"
                    for v in found if v != want]
    roadmap = GUIDE / "roadmap.md"
    if not re.search(rf"^## {re.escape(version)} — released {_D}$", roadmap.read_text(), re.M):
        missing.append(f"docs/guide/roadmap.md: no section '## {version} — released <date>'")
    return missing


def bump_version(version: str, dry_run: bool) -> int:
    """Write `version` and today's date into the version strings; print the files changed."""
    if not re.fullmatch(_V, version):
        print(f"check_docs: --bump {version}: not vX.Y.Z", file=sys.stderr)
        return 2
    date = datetime.date.today().isoformat()
    texts: dict[str, str] = {}
    errors: list[str] = []
    for name, pattern, template in VERSIONED:
        text = texts.get(name, (ROOT / name).read_text())
        text, n = re.subn(pattern, template.format(v=version, mm=major_minor(version), d=date), text)
        if n == 0:
            errors.append(f"{name}: no version string /{pattern}/")
        texts[name] = text
    name = "docs/guide/roadmap.md"
    text, n = re.subn(rf"^## {re.escape(version)} — (in progress|planned|released {_D})$",
                      f"## {version} — released {date}", (ROOT / name).read_text(), flags=re.M)
    if n != 1:
        errors.append(f"{name}: {n} sections '## {version} — in progress' (or planned), not 1")
    texts[name] = text
    if errors:
        for e in errors:
            print(f"check_docs: --bump: {e}", file=sys.stderr)
        return 1
    for name, text in texts.items():
        if (ROOT / name).read_text() != text:
            if not dry_run:
                (ROOT / name).write_text(text)
            print(name)
    return 0


# ------------------------------------------------------------------------------------------- the pages: tables, links
def pages() -> list[Path]:
    """The documentation's pages under version control (docs/index.md, docs/guide, docs/manual, docs/adr): generated
    pages that are ignored (the coverage reports) left out."""
    import subprocess  # noqa: PLC0415

    out = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "--", "docs/index.md", "docs/guide", "docs/manual", "docs/adr"],
        capture_output=True, text=True, check=False,
    )
    files = [ROOT / f for f in out.stdout.split() if f.endswith(".md")] if out.returncode == 0 else []
    if not files:  # not a git checkout (a sources archive): every page there
        files = [ROOT / "docs" / "index.md", *(ROOT / "docs" / "guide").rglob("*.md"),
                 *(ROOT / "docs" / "manual").rglob("*.md"), *(ROOT / "docs" / "adr").rglob("*.md")]
    return sorted(p for p in files if p.is_file() and "_generated" not in p.parts)


def cells(row: str) -> list[str]:
    """The cells of a table row: split at the bars that are not escaped (``\\|``) nor inside a code span."""
    out, cur, code, i = [], "", False, 0
    s = row.strip()
    s = s[1:] if s.startswith("|") else s
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            cur += s[i : i + 2]
            i += 2
            continue
        if c == "`":
            code = not code
        if c == "|" and not code:
            out.append(cur)
            cur = ""
        else:
            cur += c
        i += 1
    if cur.strip():
        out.append(cur)
    return out


def check_tables() -> list[str]:
    """Table rows with another cell count than their header's (GFM drops the cells beyond it, links included)."""
    missing: list[str] = []
    for page in pages():
        lines = page.read_text().splitlines()
        fence = False
        n = 0
        while n < len(lines):
            if lines[n].startswith("```"):
                fence = not fence
            if (not fence and lines[n].startswith("|") and n + 1 < len(lines)
                    and re.match(r"^\|?\s*:?-{3,}", lines[n + 1])):
                width = len(cells(lines[n]))
                k = n + 2
                while k < len(lines) and lines[k].startswith("|"):
                    got = len(cells(lines[k]))
                    if got != width:
                        missing.append(f"{page.relative_to(ROOT)}:{k + 1}: a row of {got} cells in a table of {width}")
                    k += 1
                n = k
                continue
            n += 1
    return missing


def heading_text(text: str) -> str:
    """A heading's text as VitePress renders it before making its anchor: links as their text, emphasis marks off."""
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    parts = re.split(r"(`[^`]*`)", text)  # emphasis marks outside code spans only
    return "".join(p if p.startswith("`") else re.sub(r"\*+|(?<!\w)_+|_+(?!\w)", "", p) for p in parts)


def anchors(page: Path) -> set[str]:
    """The anchors of a page: its headings' slugs (a repeated one with -1, -2, ...), {#custom} ids, id= attributes."""
    seen: dict[str, int] = {}
    out: set[str] = set()
    fence = False
    for line in page.read_text().splitlines():
        if line.startswith("```"):
            fence = not fence
        if fence:
            continue
        m = re.match(r"^#{1,6}\s+(.*?)\s*$", line)
        if m:
            custom = re.search(r"\{#([\w-]+)\}\s*$", m.group(1))
            if custom:
                out.add(custom.group(1))
                continue
            slug = slugify(heading_text(m.group(1)))
            k = seen.get(slug, 0)
            out.add(slug if k == 0 else f"{slug}-{k}")
            seen[slug] = k + 1
        out.update(re.findall(r"\bid=\"([\w-]+)\"", line))
    return out


LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


def check_links() -> list[str]:
    """Internal links ``[text](page#anchor)`` whose page or anchor does not exist."""
    missing: list[str] = []
    docs = ROOT / "docs"
    cache: dict[Path, set[str]] = {}
    for page in pages():
        fence = False
        for n, line in enumerate(page.read_text().splitlines(), 1):
            if line.startswith("```"):
                fence = not fence
            if fence:
                continue
            for target in LINK.findall(re.sub(r"`[^`]*`", "", line)):
                if re.match(r"^[a-z]+:", target):  # http:, mailto:
                    continue
                path, _, anchor = target.partition("#")
                path = path.split("?")[0]
                if path.startswith("/api/") or path == "/api" or path.startswith("/media/"):
                    continue  # generated reference (formal), media files
                if not path:
                    dest = page
                else:
                    base = docs / path.lstrip("/") if path.startswith("/") else page.parent / path
                    if path.endswith("/"):
                        base = base / "index.md"
                    elif base.suffix == ".html":
                        base = base.with_suffix(".md")
                    elif base.suffix != ".md":
                        base = base.with_name(base.name + ".md") if base.suffix == "" else base
                    dest = base.resolve()
                    if dest.suffix != ".md":  # a file the site serves (docs/public)
                        if not (docs / "public" / path.lstrip("/")).is_file() and not dest.is_file():
                            missing.append(f"{page.relative_to(ROOT)}:{n}: {target}: no such file")
                        continue
                    if not dest.is_file():
                        missing.append(f"{page.relative_to(ROOT)}:{n}: {target}: no such page")
                        continue
                if anchor and anchor not in cache.setdefault(dest, anchors(dest)):
                    missing.append(f"{page.relative_to(ROOT)}:{n}: {target}: no such anchor")
    return missing


# ------------------------------------------------------------------------------- the public names: prose and examples
def api_names() -> list[str]:
    """The public procedures as the docs write them: the names ``use figure`` and ``use figure_testing`` export
    (constants left out) and the type-bound procedures as ``var%proc`` (``app%init``)."""
    names: list[str] = []
    for module in ("figure.F90", "figure_testing.F90"):
        names += [n for n in public_names(module_file(module)) if not CONSTANT.match(n) and n not in TYPES]
    for type_name, var in TYPES.items():
        for f in library_files():
            names += [f"{var}%{proc}" for proc in type_bound(f, type_name)]
    return sorted(set(names))


def name_pattern(name: str) -> re.Pattern[str]:
    """A name as code or prose writes it: ``ig_begin`` as a word; ``app%init`` as ``%init`` after any variable, or as
    code starting with ``init`` (a page on one type writes `` `init(...)` ``)."""
    if "%" in name:
        proc = re.escape(name.split("%")[1])
        return re.compile(rf"%{proc}\b|`{proc}\b", re.I)
    return re.compile(rf"(?<![\w%]){re.escape(name)}\b", re.I)


def prose(text: str) -> str:
    """The sentences of a page's text: table rows, fenced blocks, includes, <Media> tags and headings left out."""
    out, fence = [], False
    for line in text.splitlines():
        if line.startswith("```") or line.startswith(":::"):
            fence = not fence if line.startswith("```") else fence
            continue
        if fence or line.lstrip().startswith(("|", "<<<", "<Media", "#")):
            continue
        out.append(line)
    return "\n".join(out)


def feature_rows() -> dict[str, list[tuple[str, str]]]:
    """For each name of the feature map's first cells, the (page, anchor) its rows link to."""
    rows: dict[str, list[tuple[str, str]]] = {}
    for row in FEATURES.read_text().splitlines():
        if row.startswith("## Environment variables"):
            break
        if not row.startswith("| `"):
            continue
        first = cells(row)[0]
        links = re.findall(r"\]\(([a-z0-9-]+)(?:#([^)]*))?\)", row)
        for code in re.findall(r"`([^`]+)`", first):
            for w in re.findall(r"[\w%]+", code):
                rows.setdefault(w.lower(), []).extend(links)
    return rows


def check_prose() -> list[str]:
    """Public names never written in a sentence (a non-table line) of the page their feature-map row links to, or of a
    page that the linked section links to."""
    rows = feature_rows()
    cache: dict[str, dict[str, str]] = {}
    missing: list[str] = []
    for name in api_names():
        links = rows.get(name.lower(), [])
        texts: list[str] = []
        for page, anchor in links:
            path = GUIDE / f"{page}.md"
            if not path.is_file():
                continue
            secs = cache.setdefault(page, sections(path))
            sec = secs.get(anchor or "", "")
            texts.append(prose(secs[""]))  # the whole page
            for linked in set(re.findall(r"\]\(([a-z0-9-]+)(?:#[^)]*)?\)", prose(sec))):
                lp = GUIDE / f"{linked}.md"
                if lp.is_file() and linked != page:
                    texts.append(prose(lp.read_text()))
        pat = name_pattern(name)
        if not any(pat.search(t) for t in texts):
            where = ", ".join(f"{p}#{a}" if a else p for p, a in dict.fromkeys(links)) or "no feature-map row"
            missing.append(f"--prose: {name} is in no sentence of {where}")
    return missing


# names a docs program cannot sensibly call, each with its reason
EXAMPLE_EXEMPT: dict[str, str] = {
    "task_work": "the abstract interface a task's procedure has: a program writes one, it never calls the interface",
}


def check_examples() -> list[str]:
    """Public names called by no program of docs/examples/src (``use`` statements and comments left out)."""
    code = []
    for f in sorted((ROOT / "docs" / "examples" / "src").glob("*.[Ff]90")):
        text = re.sub(r"&\s*\n\s*&?", " ", f.read_text())
        code += [strip_comment(line) for line in text.splitlines() if not re.match(r"\s*use\b", line, re.I)]
    joined_code = "\n".join(code)
    return [f"--examples: {name} is called by no program of docs/examples/src" for name in api_names()
            if name not in EXAMPLE_EXEMPT and not name_pattern(name).search(joined_code)]


# ---------------------------------------------------------------------------------------------- the name map, the media
def check_generated() -> list[str]:
    """The generated tables (scripts/gen_doc_tables.py) and the tutorial's "What this chapter adds" and run regions
    (scripts/gen_tutorial_adds.py) regenerated and compared with the committed ones."""
    sys.path.insert(0, str(ROOT / "scripts"))
    import gen_doc_tables  # noqa: PLC0415
    import gen_tutorial_adds  # noqa: PLC0415

    pages = gen_tutorial_adds.generated()
    stale = [f"{p.relative_to(ROOT)}: its generated regions are not current: run python3 scripts/gen_tutorial_adds.py"
             for p, t in pages.items() if p.read_text() != t]
    return gen_doc_tables.problems() + stale


def check_names() -> list[str]:
    """The name map regenerated and compared with the committed one."""
    sys.path.insert(0, str(ROOT / "scripts"))
    import gen_names  # noqa: PLC0415 (the generator, imported only for this option)

    try:
        text = gen_names.generate()
    except gen_names.NamesError as err:
        return [f"--names: {err}"]
    page = GUIDE / "imgui-names.md"
    problems = gen_names.pinned_problems()
    if not page.is_file() or page.read_text() != text:
        problems.append("docs/guide/imgui-names.md is not current: run python3 scripts/gen_names.py")
    return problems


def check_media() -> list[str]:
    """Pages whose media weigh more than 5 MB in all, and <Media> tags naming a missing recording."""
    missing: list[str] = []
    for page in sorted((ROOT / "docs").rglob("*.md")):
        if "node_modules" in page.parts or page.parts[-2:-1] == ("api",):
            continue
        total = 0
        for name in sorted(set(re.findall(r"<Media\s[^>]*?name=\"([^\"]+)\"", page.read_text()))):
            files = [MEDIA / f"{name}{ext}" for ext in (".png", ".mp4", ".gif")]
            if not files[0].is_file():
                missing.append(f"{page.relative_to(ROOT)}: <Media name=\"{name}\"> has no docs/public/media/{name}.png")
            total += sum(f.stat().st_size for f in files if f.is_file())
        if total > MEDIA_LIMIT:
            missing.append(f"{page.relative_to(ROOT)}: {total / 2**20:.1f} MB of media, over 5 MB")
    return missing


def main(argv: list[str]) -> int:
    """Run the checks asked for; print what is missing."""
    usage = "usage: check_docs.py [--names] [--media] | --bump vX.Y.Z [--dry-run]"
    if argv[:1] == ["--bump"]:
        if len(argv) not in (2, 3) or argv[2:] not in ([], ["--dry-run"]):
            print(f"check_docs: {usage}", file=sys.stderr)
            return 2
        return bump_version(argv[1], argv[2:] == ["--dry-run"])
    unknown = [a for a in argv if a not in ("--names", "--media")]
    if unknown:
        print(f"check_docs: unknown option {unknown[0]} ({usage})", file=sys.stderr)
        return 2
    missing = (check_feature_map() + check_comments() + check_rows() + check_code_blocks() + check_readme()
               + check_version() + check_tables() + check_links() + check_generated() + check_prose()
               + check_examples() + check_tags())
    done = ["the feature map lists every public procedure", "every public entity and argument has a doc comment",
            "every row's section has a compiled example", "no hand-written Fortran block",
            "README.md's example is the compiled one", "the docs say the version in VERSION",
            "every table row has its header's cells", "every internal link and anchor exists",
            "the generated tables are current", "every public name is in a sentence of its page",
            "every public name is called by a docs program", "no bare tag in a doc comment"]
    if "--names" in argv:
        missing += check_names()
        done.append("the name map is current")
    if "--media" in argv:
        missing += check_media()
        done.append("every page's media under 5 MB")
    for m in missing:
        print(f"check_docs: {m}", file=sys.stderr)
    if not missing:
        print("check_docs: " + "; ".join(done))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
