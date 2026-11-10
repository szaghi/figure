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
- **Examples:** every section a feature-map row links to (``[text](page#anchor)``, or a whole page) includes a
  compiled example (``<<< @/examples/snippets/...``); a row marked ``<!-- visual -->`` also needs a ``<Media`` in
  each section it links to.
- **Code:** no hand-written ```fortran block in docs/index.md, docs/guide and docs/manual (#6 §4.4), and every
  ``<<< @/examples/...`` include names a file that exists.
- **README:** README.md's first ```fortran block equals docs/examples/src/readme.F90, which docs/examples/build.sh
  compiles.

Options:

- ``--names``: regenerate the name map (scripts/gen_names.py) in memory and fail if docs/guide/imgui-names.md differs.
- ``--media``: fail if the media a page shows (``<Media name>``: docs/public/media/<name>.png, .mp4, .gif) weigh more
  than 5 MB in all on that page, or if a ``<Media>`` names a recording that does not exist.

Usage: python3 scripts/check_docs.py [--names] [--media]. Standard library only; run from anywhere.
"""

from __future__ import annotations

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


def check_comments() -> list[str]:
    """Public entities and dummy arguments without a ``!<`` doc comment."""
    sources = {p.stem.lower(): parse(p) for p in LIB.glob("*.F90")}
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
        path = LIB / f"{mod}.F90"
        if not documented:
            missing.append(f"{rel(path, line)}: type {name} has no !< doc comment")
        for comp in src.components.get(name, []):
            missing.append(f"{rel(path, line)}: type {name}: component {comp} has no !< comment")
        for binding, impl, private in bindings:
            if not private or any(b.endswith(f":{binding}") for b, _, _ in bindings):
                check_proc(mod, impl, f"{name}%{binding.split(':')[0]} ({impl})")

    for module in ("figure", "figure_testing"):
        origin = used_from(LIB / f"{module}.F90")
        for pub in public_names(LIB / f"{module}.F90"):
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
                    missing.append(f"{rel(LIB / f'{mod}.F90', line)}: generic {name} has no !< doc comment")
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
        for name in public_names(LIB / module):
            if not CONSTANT.match(name) and name not in words:
                missing.append(f"not in docs/guide/features.md: {name} ({module})")
    for type_name, var in TYPES.items():
        for f in LIB.glob("*.F90"):
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


# ---------------------------------------------------------------------------------------------- the name map, the media
def check_names() -> list[str]:
    """The name map regenerated and compared with the committed one."""
    sys.path.insert(0, str(ROOT / "scripts"))
    import gen_names  # noqa: PLC0415 (the generator, imported only for this option)

    try:
        text = gen_names.generate()
    except gen_names.NamesError as err:
        return [f"--names: {err}"]
    page = GUIDE / "imgui-names.md"
    if not page.is_file() or page.read_text() != text:
        return ["docs/guide/imgui-names.md is not current: run python3 scripts/gen_names.py"]
    return []


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
    unknown = [a for a in argv if a not in ("--names", "--media")]
    if unknown:
        print(f"check_docs: unknown option {unknown[0]} (usage: check_docs.py [--names] [--media])", file=sys.stderr)
        return 2
    missing = check_feature_map() + check_comments() + check_rows() + check_code_blocks() + check_readme()
    done = ["the feature map lists every public procedure", "every public entity and argument has a doc comment",
            "every row's section has a compiled example", "no hand-written Fortran block",
            "README.md's example is the compiled one"]
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
