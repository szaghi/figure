"""Map each public name and each interaction class of FIGURE to the checks that exercise it: the oracle's coverage.

The oracle (#15 §4) is what must hold when a layer under FIGURE is replaced: the pictures (``test_compare_image``
against a golden of src/tests/data, and the recordings docs/media/*.rec that ``docs_media.py --check`` renders and
compares) and the behaviour (the test programs of src/tests, which drive the GUI with figure_testing's scripted input
and check what it did). What no check exercises can regress silently; this script measures it (#15 P1).

**Public names** are check_docs.py's: what ``use figure`` and ``use figure_testing`` export (constants left out) and
the type-bound procedures as ``var%proc``. A name is

- checked **by picture** when a program that calls it is pictured: a test of src/tests that compares a capture with a
  golden of src/tests/data, or the program of a recording that ``--check`` compares on Linux (not a remote one, not
  ``#! check.linux skip``, with a committed poster);
- checked **by behaviour** when a test program of src/tests calls it.

A program calls a name when its code (comments and ``use`` statements left out; a recording's program with the local
modules it uses) names it; a type-bound ``var%proc`` when it is called on a variable declared of its type. The measure
is static and per program: a name called in a pictured program counts even if the frame captured does not draw it.

**Interaction classes** (#15 P1: click, drag, wheel, keys, text editing, keyboard navigation, scrolling and the list
clipper, popups, menus, tables, docking, plot interaction, the 3-D view) are claimed by the checks themselves, with a
comment that names them, and the claim is verified against the code:

- a test program: a line ``! oracle: <class> <class>:picture ...``; the claim holds when the program's code has the
  class's evidence (``CLASSES``: the scripted input and the API the class needs). It is a behaviour check; with
  ``:picture`` (the golden it compares is captured after the interaction) a picture check too, which holds when the
  program compares a capture with a golden of src/tests/data;
- a recording: a line ``# oracle: <class> ...``; the claim holds when the input script, up to the poster's frame (the
  input after it is not in the picture), has the class's input evidence and the program the class's code evidence. It
  is a picture check.

A claim without its evidence, an unknown class, an exemption that matches no public name or only names checked after
all are errors. ``NO_PICTURE`` and ``NO_BEHAVIOUR`` hold the exemptions, each with its reason.

    python3 scripts/oracle_coverage.py              write the matrix, docs/guide/_generated/oracle-coverage.md, and
                                                    print the gaps (exit 0)
    python3 scripts/oracle_coverage.py --check      write nothing; exit 1 on a gap, an error, or a committed matrix
                                                    that is not current
    python3 scripts/oracle_coverage.py --candidates also list, for each class, the programs and recordings whose code
                                                    has its evidence but that do not claim it (to review and tag)

Standard library only; run from anywhere.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import check_docs  # noqa: E402 (the public names and the Fortran parsing are check_docs.py's)
import docs_media  # noqa: E402 (the recordings' header and script)

TESTS = ROOT / "src" / "tests"
GOLDENS = "src/tests/data/"
RECS = ROOT / "docs" / "media"
POSTERS = ROOT / "docs" / "public" / "media"
OUT = ROOT / "docs" / "guide" / "_generated" / "oracle-coverage.md"
TAG_TEST = re.compile(r"^\s*!\s*oracle:\s*(.*)$", re.M | re.I)
TAG_REC = re.compile(r"^#\s*oracle:\s*(.*)$", re.M | re.I)
VAR_OF = {var: type_name for type_name, var in check_docs.TYPES.items()}  # app -> app_object


# ----------------------------------------------------------------------------------------------- the interaction classes
@dataclass(frozen=True)
class Interaction:
    """An interaction class and the evidence that a check exercises it.

    ``test``: alternatives, each a list of patterns that must all match a test program's code. ``rec``: alternatives,
    each a pair (pattern over the recording's input tokens up to the poster, patterns over its program's code). The
    input tokens are the script's events in order, one word each: ``move``, ``down:left``, ``up:right``, ``wheel``,
    ``text`` (``text:utf8`` with a character beyond ASCII), ``key:z``, ``key:shortcut:down``, ``drop``, ``close``.
    """

    key: str
    what: str
    test: tuple[tuple[str, ...], ...]
    rec: tuple[tuple[str, tuple[str, ...]], ...] = ()


HELD = r"down:\w+ (?:(?!up:)\S+ )*?move\b"  # a pointer moved while a button is held: a drag
CHORD = r"key:(?:shortcut|ctrl|super):down (?:\S+ )*?key:{k}\b"  # a key pressed with the shortcut key held
CLASSES: tuple[Interaction, ...] = (
    Interaction("click", "a click on a widget",
                ((r"\btest_(?:click|item_click|menu_click)\b",), (r"\btest_mouse_button\b",)),
                ((r"\bdown:left\b", ()),)),
    Interaction("drag", "a drag with the pointer",
                ((r"\btest_drag\b",), (r"\btest_mouse_button\b", r"\btest_mouse_move\b")),
                ((HELD, ()),)),
    Interaction("wheel", "the mouse wheel", ((r"\btest_wheel\b",),), ((r"\bwheel\b", ()),)),
    Interaction("keys", "keys and shortcuts (ig_shortcut, a menu item's shortcut)",
                ((r"\btest_key\b", r"\big_shortcut\b|\big_set_next_item_shortcut\b|\bshortcut\s*="),),
                ((r"\bkey:", (r"\big_shortcut\b|\big_set_next_item_shortcut\b|\bshortcut\s*=",)),)),
    Interaction("text-typing", "characters typed into a text field",
                ((r"\btest_type\b|\btest_item_type_text\b", r"\big_input|\bed\s*%|\bcode_editor_object\b"),),
                ((r"\btext\b", (r"\big_input|code_editor_object",)),)),
    Interaction("text-selection", "a selection in a text field (shift and arrows, select all, a drag)",
                ((r"\btest_type\b|\btest_item_type_text\b", r"\btest_key\s*\(\s*'(?:shift|shortcut)'"),
                 (r"\btest_type\b|\btest_item_type_text\b", r"\btest_drag\b", r"\big_input_text_multiline\b")),
                ((r"key:shift:down (?:\S+ )*?key:(?:left|right|up|down|home|end)\b|" + CHORD.format(k="a"),
                  (r"\big_input|code_editor_object",)),)),
    Interaction("text-undo", "undo and redo of an edit by the keyboard",
                ((r"\btest_type\b|\btest_item_type_text\b", r"\btest_key\b", r"\(\s*'[zy]'\s*\)"),),
                ((CHORD.format(k="[zy]"), (r"\big_input|code_editor_object",)),)),
    Interaction("text-utf8", "UTF-8 text typed and edited (a character of several bytes)",
                ((r"\btest_type\b|\btest_item_type_text\b", r"[^\x00-\x7f]|achar\s*\(\s*int\s*\(\s*z'[cdef]"),),
                ((r"\btext:utf8\b", (r"\big_input|code_editor_object",)),)),
    Interaction("text-clipboard", "copy, cut and paste through the clipboard",
                ((r"\big_get_clipboard\b|\big_set_clipboard\b|ClipboardText\b", r"\btest_key\b", r"\(\s*'[cvx]'\s*\)"),),
                ((CHORD.format(k="[cvx]"), (r"\big_input|code_editor_object",)),)),
    Interaction("keyboard-nav", "keyboard navigation: focus moved by tab and the arrows, activation by enter or space",
                ((r"\btest_key\b", r"\(\s*'(?:tab|up|down|left|right)'\s*\)", r"\big_(?:button|checkbox|selectable|radio|combo)"
                  r"|\big_tree_node\b|\big_menu_item\b|\big_begin_table\b"),),
                ((r"key:(?:tab|up|down|left|right)\b", (r"\big_(?:button|checkbox|selectable|radio|tree_node)",)),)),
    Interaction("scrolling", "a region scrolled by the wheel or by the program",
                ((r"\big_(?:set_scroll|scroll_here|scroll_to_pos|get_scroll)\b",),
                 (r"\btest_wheel\b", r"\big_begin_child\b|\big_begin_table\b|\big_input_text_multiline\b|\big_list_box\b")),
                ((r"\bwheel\b", (r"\big_begin_child\b|\big_begin_table\b|\big_input_text_multiline\b|\big_list_box\b",)),)),
    Interaction("list-clipper", "a long list drawn through the list clipper",
                ((r"\blist_clipper_object\b",),), ((r".", (r"\blist_clipper_object\b",)),)),
    Interaction("popups", "a popup opened, used and closed (context menus included)",
                ((r"\big_begin_popup(?:_context)?\b", r"\btest_(?:click|item_click|mouse_button|key)\b"),),
                ((r"\bdown:", (r"\big_begin_popup(?:_context)?\b",)),)),
    Interaction("modals", "a modal popup: it blocks the rest of the window until closed",
                ((r"\big_begin_popup_modal\b|\bmessage_box\b|\bset_confirm_quit\b",
                  r"\btest_(?:click|item_click|mouse_button|key)\b"),),
                ((r"\bdown:|\bkey:|\bclose\b", (r"\big_begin_popup_modal\b|\bmessage_box\b|\bset_confirm_quit\b",)),)),
    Interaction("menus", "a menu opened and an item chosen (main menu bar, a window's menu bar)",
                ((r"\big_begin_menu\b|\bview_menu\b", r"\btest_(?:menu_click|click|item_click)\b"),),
                ((r"\bdown:left\b", (r"\big_begin_menu\b|\bview_menu\b",)),)),
    Interaction("table-sort", "a table sorted by a click on a column's header",
                ((r"\big_table_sort\b", r"\btest_(?:click|item_click)\b"),),
                ((r"\bdown:left\b", (r"\big_table_sort\b",)),)),
    Interaction("table-resize", "a table's column resized by dragging its border",
                ((r"\big_begin_table\b", r"\btest_drag\b|\btest_mouse_move\b"),),
                ((HELD, (r"\big_begin_table\b",)),)),
    Interaction("table-reorder", "a table's columns reordered by dragging a header",
                ((r"\big_begin_table\b", r"\btest_drag\b|\btest_mouse_move\b"),),
                ((HELD, (r"\big_begin_table\b",)),)),
    Interaction("dock-split", "windows docked into the nodes of a split",
                ((r"\big_dock_split\b", r"\big_dock_window\b|\big_set_next_window_dock\b"),),
                ((r".", (r"\big_dock_split\b",)),)),
    Interaction("dock-tab", "two windows docked in one node, chosen by their tabs",
                ((r"\big_dock_window\b|\big_set_next_window_dock\b", r"\btest_(?:click|item_click|mouse_button)\b"),),
                ((r"\bdown:left\b", (r"\big_dock_window\b|\big_set_next_window_dock\b",)),)),
    Interaction("dock-in", "a floating window dragged by its title bar into a node",
                ((r"\big_dock_space\b", r"\btest_drag\b|\btest_mouse_move\b"),),
                ((HELD, (r"\big_dock_space\b",)),)),
    Interaction("dock-undock", "a docked window dragged out of its node by its tab",
                ((r"\big_dock_space\b|\big_dock_window\b", r"\btest_drag\b|\btest_mouse_move\b"),),
                ((HELD, (r"\big_dock_space\b|\big_dock_window\b",)),)),
    Interaction("dock-layout", "the layout saved and loaded (app%save_layout, the settings file)",
                ((r"\bsave_layout\b|\bload_layout\b|\btest_settings_file\b|\bswitch_layout\b",),),
                ((r".", (r"\bsave_layout\b|\bload_layout\b|\bswitch_layout\b",)),)),
    Interaction("plot-pan", "a plot panned by dragging it",
                ((r"\bip_begin_plot\b", r"\btest_drag\b|\btest_mouse_move\b", r"\bip_plot_limits\b|PlotLimits"),),
                ((HELD, (r"\bip_begin_plot\b",)),)),
    Interaction("plot-zoom", "a plot zoomed by the wheel",
                ((r"\bip_begin_plot\b", r"\btest_wheel\b", r"\bip_plot_limits\b|PlotLimits"),),
                ((r"\bwheel\b", (r"\bip_begin_plot\b",)),)),
    Interaction("plot-box-select", "a box selection made with the right button",
                ((r"\bip_plot_selection\b", r"\btest_mouse_button\b|\btest_drag\b"),),
                ((r"down:right (?:\S+ )*?move\b", (r"\bip_plot_selection\b",)),)),
    Interaction("plot-drag-tools", "drag lines, points and rectangles moved by the pointer",
                ((r"\bip_drag_(?:line_x|line_y|point|rect)\b", r"\btest_drag\b|\btest_mouse_move\b"),),
                ((HELD, (r"\bip_drag_(?:line_x|line_y|point|rect)\b",)),)),
    Interaction("plot-legend", "a plot's legend: an item hidden by a click on its entry, the legend's popup",
                ((r"\bip_(?:setup_legend|legend_hovered|begin_legend_popup)\b|\bip_line\b",
                  r"\btest_(?:click|item_click|mouse_button)\b", r"\bip_legend_hovered\b|\blegend\b"),),
                ((r"\bdown:", (r"\bip_(?:legend_hovered|begin_legend_popup)\b",)),)),
    Interaction("plot-zoom-levels", "a line plot pictured at three or four zoom levels (§4: one where P4's "
                "decimation switches off)",
                ((r"\bip_line\b", r"\bip_setup_ax\w*limits\b", r"\btest_compare_image\b"),)),
    Interaction("view3d-orbit", "a 3-D view or plot turned by dragging it",
                ((r"\bview3d_object\b|\bip3_begin_plot\b", r"\btest_drag\b|\btest_mouse_move\b"),),
                ((HELD, (r"\bview3d_object\b|\bip3_begin_plot\b",)),)),
    Interaction("view3d-gizmo", "a 3-D view's gizmo dragged", ((r"%\s*gizmo\b", r"\btest_drag\b|\btest_mouse_move\b"),),
                ((HELD, (r"%\s*gizmo\b",)),)),
    Interaction("view3d-cube", "a 3-D view's view cube clicked", ((r"%\s*view_cube\b", r"\btest_click\b|"
                                                                  r"\btest_mouse_button\b"),),
                ((r"\bdown:left\b", (r"%\s*view_cube\b",)),)),
)
CLASS_KEYS = {c.key for c in CLASSES}

# ---------------------------------------------------------------------------------------------------------- exemptions
# names that need no picture check, each with its reason (a pattern over the whole name, the reason)
NO_PICTURE: tuple[tuple[str, str], ...] = (
    ("task_work", "the abstract interface of a task's procedure: a program writes one, it never calls the interface"),
    ("figure_time|figure_file_time", "a clock, a file's time: nothing drawn"),
    ("ig_get_style_color|ip_get_style_color|ip_get_style_var", "a query of the style: nothing drawn (what it reads is "
     "checked by behaviour, the style's effect by the pictures of the setters)"),
    (r"tex%(?:width|height)|md%is_initialized|v%is_initialized|v%render_info|v%pick|app%prefs_file"
     r"|log%(?:count|following|in_view|line|copy)", "a query: nothing drawn"),
    ("log%set_cap", "how many lines a log keeps: data, checked by behaviour (log%count); the drawing is log%draw's"),
    ("test_(?:quit|record_items|unnamed_items|item_exists|item_value|item_type_text)",
     "figure_testing: it drives or inspects the GUI, it has no picture of its own"),
    ("app%(?:open_file_dialog|save_file_dialog)", "the operating system's dialog, not drawn by FIGURE (refused headless: "
     "checked by behaviour)"),
    ("app%(?:set_size_limits|wake|set_checks)", "nothing drawn: the window manager's size limits, the frame loop's "
     "wake-up, what a usage error does"),
    ("ig_invisible_button", "invisible by definition: its click and hover are checked by behaviour"),
    ("ip_line_device", "the arrays live on a device: figure_test_device compares its picture with ip_line's of the same "
     "series copied to the host (ip_line's pictures are golden-checked), in FUNDAL's CPU mode and on the GPU"),
)
# names that need no behaviour check, each with its reason
NO_BEHAVIOUR: tuple[tuple[str, str], ...] = (
    ("task_work", "the abstract interface of a task's procedure: a program writes one, it never calls the interface"),
    ("app%init", "it opens a window: the tests run headless (app%init_headless); the window is pictured by the "
     "recordings' programs and opened by scripts/window_check.py in the Platforms workflow"),
    ("ig_show_demo_window|ig_show_style_editor", "Dear ImGui's own demo and style editor, shown for exploration: their "
     "picture is checked, their behaviour is Dear ImGui's"),
)


def exemption(name: str, rules: tuple[tuple[str, str], ...]) -> str:
    """The reason a name is exempt by the first rule that matches it ('' none)."""
    for pattern, reason in rules:
        if re.fullmatch(pattern, name):
            return reason
    return ""


# ------------------------------------------------------------------------------------------------------- the programs
@dataclass
class Program:
    """A program that a check runs: a test, or a recording's program, with what the coverage needs of it."""

    label: str  # how the matrix names it
    code: str  # its code: comments, ``use`` statements and continuations removed (with the local modules it uses)
    variables: dict[str, set[str]] = field(default_factory=dict)  # public type: the variables declared of it
    golden: bool = False  # it compares a capture with a golden of src/tests/data
    tags: list[str] = field(default_factory=list)  # the interaction classes it claims


def fortran_code(text: str) -> str:
    """The code of a Fortran source: continuations joined, comments and ``use`` statements removed."""
    text = re.sub(r"&\s*(?:![^\n]*)?\n\s*&?", " ", text)
    lines = [check_docs.strip_comment(line) for line in text.splitlines() if not re.match(r"\s*use\b", line, re.I)]
    return "\n".join(lines)


def declared(code: str) -> dict[str, set[str]]:
    """For each public type with type-bound procedures, the variables (and components) the code declares of it."""
    out: dict[str, set[str]] = {}
    for line in code.splitlines():
        m = re.match(r"^\s*(?:type|class)\s*\(\s*(\w+)\s*\)[^:]*::", line, re.I)
        if m and m.group(1).lower() in check_docs.TYPES:
            out.setdefault(m.group(1).lower(), set()).update(check_docs.entity_names(line))
    return out


def local_sources(main: Path) -> list[Path]:
    """A program's source and those of the modules it uses that sit beside it (docs/examples/src: tut12_heat)."""
    files, todo = [main], [main]
    modules = {}
    for f in main.parent.glob("*.[Ff]90"):
        for m in re.finditer(r"^\s*module\s+(\w+)\s*$", f.read_text(), re.M | re.I):
            modules[m.group(1).lower()] = f
    while todo:
        for m in re.finditer(r"^\s*use\s+(\w+)", todo.pop().read_text(), re.M | re.I):
            f = modules.get(m.group(1).lower())
            if f and f not in files:
                files.append(f)
                todo.append(f)
    return files


def program(label: str, sources: list[Path]) -> Program:
    """A program from its sources."""
    raw = "\n".join(f.read_text() for f in sources)
    code = fortran_code(raw)
    golden = bool(re.search(r"\btest_compare_image\b", code)) and GOLDENS in raw
    return Program(label, code, declared(code), golden, [t for m in TAG_TEST.finditer(raw) for t in m.group(1).split()])


def tests() -> list[Program]:
    """The test programs of src/tests."""
    return [program(f.stem, [f]) for f in sorted(TESTS.glob("figure_test_*.F90"))]


@dataclass
class Recording:
    """A recording of docs/media and what the coverage needs of it."""

    name: str
    program: Program | None  # its program (None: not found)
    tokens: str  # the input script's events up to the poster's frame, one word each (Interaction)
    checked: bool  # --check compares its poster on Linux
    tags: list[str]


def event_token(words: list[str]) -> str:
    """One event of an input script as a token (Interaction)."""
    verb, args = words[0], words[1:]
    if verb in ("down", "up"):
        return f"{verb}:{args[0] if args else 'left'}"
    if verb == "key":
        return ":".join(["key", *args[:2]])
    if verb == "text":
        return "text:utf8" if any(ord(c) > 127 for c in " ".join(args)) else "text"
    return verb


def recordings() -> list[Recording]:
    """The recordings of docs/media."""
    out = []
    for rec in sorted(RECS.glob("*.rec")):
        header, script = docs_media.parse(rec)
        frames = int(header["frames"])
        last = int(header.get("from", 0)) + int(header.get("poster", frames - 1))
        events = []
        for line in script.splitlines():
            words = line.split()
            if len(words) >= 2 and not line.lstrip().startswith("#") and words[0].isdigit() and int(words[0]) <= last:
                events.append((int(words[0]), event_token(words[1:])))
        tokens = " ".join(t for _, t in sorted(events, key=lambda e: e[0])) + " "
        exe = Path(header["program"])
        src_dir = ROOT / "docs" / "examples" / "src" if "docs-examples" in exe.parts else ROOT / "src" / "examples"
        main = next((p for p in (src_dir / f"{exe.name}.F90", src_dir / f"{exe.name}.f90") if p.is_file()), None)
        prog = program(exe.name, local_sources(main)) if main else None
        checked = ("remote" not in header and (POSTERS / f"{rec.stem}.png").is_file()
                   and "skip" not in header.get("check.linux", "").split())
        tags = [t for m in TAG_REC.finditer(script) for t in m.group(1).split()]
        out.append(Recording(rec.stem, prog, tokens, checked, tags))
    return out


# ---------------------------------------------------------------------------------------------------------- the matrix
def calls(prog: Program, name: str) -> bool:
    """Whether a program calls a public name (a type-bound one on a variable of its type)."""
    if "%" in name:
        var, proc = name.split("%")
        names = prog.variables.get(VAR_OF[var], set())
        if not names:
            return False
        alt = "|".join(re.escape(n) for n in sorted(names))
        return bool(re.search(rf"(?<!\w)(?:{alt})\s*(?:\([^()]*\))?\s*%\s*{re.escape(proc)}\b", prog.code, re.I))
    return bool(check_docs.name_pattern(name).search(prog.code))


def test_evidence(cls: Interaction, prog: Program) -> bool:
    """Whether a test program's code has a class's evidence."""
    return any(all(re.search(p, prog.code, re.I) for p in alt) for alt in cls.test)


def rec_evidence(cls: Interaction, rec: Recording) -> bool:
    """Whether a recording's input (up to the poster) and program have a class's evidence."""
    if rec.program is None:
        return False
    return any(re.search(inp, rec.tokens) and all(re.search(p, rec.program.code, re.I) for p in code)
               for inp, code in cls.rec)


@dataclass
class Coverage:
    """The matrix: for each public name and each class, the checks by picture and by behaviour; and the errors."""

    names: dict[str, tuple[list[str], list[str]]] = field(default_factory=dict)
    classes: dict[str, tuple[list[str], list[str]]] = field(default_factory=dict)
    errors: list[str] = field(default_factory=list)
    candidates: dict[str, list[str]] = field(default_factory=dict)


def measure() -> Coverage:
    """Measure the coverage."""
    cov = Coverage()
    progs, recs = tests(), recordings()
    pictured = [(p.label, p) for p in progs if p.golden]
    pictured += [(f"{r.name}.rec", r.program) for r in recs if r.checked and r.program is not None]
    for name in check_docs.api_names():
        pic = [label for label, p in pictured if calls(p, name)]
        beh = [p.label for p in progs if calls(p, name)]
        cov.names[name] = (pic, beh)
    for cls in CLASSES:
        cov.classes[cls.key] = ([], [])
    for prog in progs:
        for claim in prog.tags:
            tag, _, kind = claim.partition(":")
            if tag not in CLASS_KEYS or kind not in ("", "picture"):
                cov.errors.append(f"{prog.label}: '! oracle: {claim}' is not an interaction class (or :picture)")
                continue
            cls = next(c for c in CLASSES if c.key == tag)
            if not test_evidence(cls, prog):
                cov.errors.append(f"{prog.label}: claims {tag} but its code has not the evidence ({cls.what})")
                continue
            cov.classes[tag][1].append(prog.label)
            if kind and not prog.golden:
                cov.errors.append(f"{prog.label}: claims {claim} but compares no capture with a golden of {GOLDENS}")
            elif kind:
                cov.classes[tag][0].append(prog.label)
    for rec in recs:
        for tag in rec.tags:
            if tag not in CLASS_KEYS:
                cov.errors.append(f"{rec.name}.rec: '# oracle: {tag}' is not an interaction class")
                continue
            cls = next(c for c in CLASSES if c.key == tag)
            if not rec_evidence(cls, rec):
                cov.errors.append(f"{rec.name}.rec: claims {tag} but its input up to the poster or its program has "
                                  f"not the evidence ({cls.what})")
            elif not rec.checked:
                cov.errors.append(f"{rec.name}.rec: claims {tag} but --check does not compare it on Linux")
            else:
                cov.classes[tag][0].append(f"{rec.name}.rec")
    for cls in CLASSES:
        found = [p.label for p in progs if cls.key not in {t.partition(":")[0] for t in p.tags}
                 and test_evidence(cls, p)]
        found += [f"{r.name}.rec" for r in recs if cls.key not in r.tags and r.checked and rec_evidence(cls, r)]
        cov.candidates[cls.key] = found
    public = set(cov.names)
    for rules, kind, col in ((NO_PICTURE, "picture", 0), (NO_BEHAVIOUR, "behaviour", 1)):
        for pattern, _ in rules:
            hits = [n for n in public if re.fullmatch(pattern, n)]
            if not hits:
                cov.errors.append(f"the {kind} exemption '{pattern}' matches no public name")
            elif all(cov.names[n][col] for n in hits):
                cov.errors.append(f"the {kind} exemption '{pattern}' is stale: every name it matches has a check")
    return cov


def gaps(cov: Coverage) -> list[str]:
    """The names and classes without a check of a kind, nor an exemption."""
    out = []
    for name, (pic, beh) in cov.names.items():
        if not pic and not exemption(name, NO_PICTURE):
            out.append(f"{name}: no picture check")
        if not beh and not exemption(name, NO_BEHAVIOUR):
            out.append(f"{name}: no behaviour check")
    for cls in CLASSES:
        pic, beh = cov.classes[cls.key]
        if not pic:
            out.append(f"class {cls.key}: no picture check")
        if not beh and cls.test and cls.key != "plot-zoom-levels":
            out.append(f"class {cls.key}: no behaviour check")
    return out


def cell(found: list[str], reason: str) -> str:
    """A cell of the matrix: the first checks found (and how many), or the exemption, or a gap."""
    if found:
        more = f" (+{len(found) - 3})" if len(found) > 3 else ""
        return ", ".join(f"`{f}`" for f in found[:3]) + more
    return f"exempt: {reason}" if reason else "**gap**"


def report(cov: Coverage) -> str:
    """The matrix as markdown."""
    missing = gaps(cov)
    n_names = sum(1 for g in missing if not g.startswith("class "))
    n_classes = len(missing) - n_names
    lines = [
        "<!-- generated by scripts/oracle_coverage.py from src/tests and docs/media: do not edit -->",
        "",
        f"Gaps: {n_names} of the public names' {2 * len(cov.names)} checks, {n_classes} of the interaction classes' "
        f"{2 * len(CLASSES)}.",
        "",
        "| Interaction class | Picture | Behaviour |",
        "|---|---|---|",
    ]
    for cls in CLASSES:
        pic, beh = cov.classes[cls.key]
        beh_cell = cell(beh, "") if cls.key != "plot-zoom-levels" else "the plot's limits, set by the test"
        lines.append(f"| `{cls.key}`: {cls.what} | {cell(pic, '')} | {beh_cell} |")
    lines += ["", "| Public name | Picture | Behaviour |", "|---|---|---|"]
    for name, (pic, beh) in cov.names.items():
        lines.append(f"| `{name}` | {cell(pic, exemption(name, NO_PICTURE))} | "
                     f"{cell(beh, exemption(name, NO_BEHAVIOUR))} |")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    """Measure, write or check the matrix, print the gaps."""
    unknown = [a for a in argv if a not in ("--check", "--candidates")]
    if unknown:
        print(f"oracle_coverage: unknown option {unknown[0]} (usage: oracle_coverage.py [--check] [--candidates])",
              file=sys.stderr)
        return 2
    cov = measure()
    text = report(cov)
    missing = gaps(cov)
    problems = list(cov.errors)
    if "--check" in argv:
        if not OUT.is_file() or OUT.read_text() != text:
            problems.append(f"{OUT.relative_to(ROOT)} is not current: run python3 scripts/oracle_coverage.py")
    else:
        OUT.write_text(text)
    if "--candidates" in argv:
        for key, found in cov.candidates.items():
            if found:
                print(f"candidates {key}: {' '.join(found)}")
    for p in problems:
        print(f"oracle_coverage: {p}", file=sys.stderr)
    for g in missing:
        print(f"oracle_coverage: gap: {g}", file=sys.stderr)
    n_names = sum(1 for g in missing if not g.startswith("class "))
    print(f"oracle_coverage: {len(cov.names)} public names, {len(CLASSES)} interaction classes; gaps: {n_names} name "
          f"checks, {len(missing) - n_names} class checks; {len(problems)} errors")
    if "--check" in argv:
        return 1 if missing or problems else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
