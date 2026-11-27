"""Check FIGURE's Fortran sources for the forms that nvfortran 26.9 compiles wrong (docs/adr/0001-fortran-stack.md).

Five source patterns, each a defect with a reproducer on szaghi/figure#4 (the first four with a canary in
figure_test_canaries):

  - ``move-alloc``: ``call move_alloc(from, to)``, ``to`` a local array of a procedure or main program that has
    internal procedures, or a host's local from inside one of them: the array's size is wrong afterwards (a module
    variable, a dummy or a component is right);
  - ``hoist``: in an internal procedure, a loop whose body tests ``size``, ``allocated``, ``ubound`` or ``lbound`` of
    a host's allocatable or pointer array (or of a component of a host's variable) and calls a procedure: ``-O2 -mp``
    reads the size once, before the loop;
  - ``append``: ``x = [x, ...]`` (or ``[..., x]``), ``x`` declared ``type(...)`` or ``class(...)`` in the file: with
    allocatable or deferred-length components, the earlier elements get wrong components (a derived type without them
    is right, but the check does not resolve types: build into a temporary instead);
  - ``select``: in a file that holds a character typed array constructor (``[character(len=...) :: ...]``),
    ``select case`` on a call of a function of the file whose result has deferred length, or a call of a function of
    the file whose result has its dummy's length (``character(len=len(s))``) with a variable as the actual: no case
    matches, the result is empty.

  - ``stride-expr``: an arithmetic operator applied to a strided section (``x(1::4) * 0.25``, ``y(1:n:2, k) + 1``): the
    expression, assigned to an allocatable or passed as an actual argument, gets the parent array's extent (its
    ``size()`` is right); name the section first, or loop.

Two more patterns are not wrong code but a heap allocation per execution (szaghi/figure#16 S5, C4; measured with a
malloc counter, gfortran and ifx make none), checked in the library and the paths only (``src/lib``, ``src/paths``):

  - ``temp-actual``: an array-valued expression as an actual argument: an operator, a type conversion or an elemental
    function (``real(v, real64)``, ``abs(v)``, ``-v``, ``p + q``, ``merge(p, q, p > q)``) applied to a whole array or a
    section (an array constructor, a variable, a section, a parenthesised variable, a function result and an
    expression assigned to a variable or reduced by ``sum`` make none); name the value first (a fixed local), or pass
    scalars;
  - ``temp-overlap``: an assignment between two sections of the same array (or substrings of the same variable)
    whose ranges in one dimension differ and are not both constant and disjoint (``c(p + 2:n + 1) = c(p + 1:n)``,
    ``s(2:6) = s(1:5)``); write the loop (backward for a shift up).
The check is syntactic and conservative: a line may carry ``! nvf-ok: <reason>`` to accept it. Exit status 0 when no
pattern is found, 1 otherwise (each finding printed as ``file:line: pattern: text``). ``--self-test`` runs the check on
built-in cases, each of which must be found or not as stated. Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_DIRS = (
    "src/lib",
    "src/paths",
    "src/tests",
    "src/examples",
    "docs/examples/src",
)
ACCEPT = re.compile(r"!\s*nvf-ok\b", re.I)
PROC = re.compile(
    r"^\s*(?:(?:pure|elemental|impure|recursive|module|simple)\s+)*"
    r"(?:(?:integer|real|logical|complex|character|type|class)\s*(?:\([^)]*\))?\s+)?"
    r"(subroutine|function)\s+(\w+)\s*(\([^)]*\))?\s*(?:result\s*\(\s*(\w+)\s*\))?",
    re.I,
)
END_PROC = re.compile(r"^\s*end\s*(subroutine|function|program)\b", re.I)
PROGRAM = re.compile(r"^\s*program\s+(\w+)", re.I)
INTERFACE = re.compile(r"^\s*(abstract\s+)?interface\b", re.I)
END_INTERFACE = re.compile(r"^\s*end\s*interface\b", re.I)
TYPE_DEF = re.compile(r"^\s*type\s*(?:,[^:]*)?(?:::)?\s*[A-Za-z_]\w*\s*$", re.I)
END_TYPE = re.compile(r"^\s*end\s*type\b", re.I)
CONTAINS = re.compile(r"^\s*contains\b", re.I)
DO = re.compile(r"^\s*(\w+\s*:\s*)?do\b", re.I)
END_DO = re.compile(r"^\s*end\s*do\b", re.I)
CALL = re.compile(r"\bcall\b|%\s*\w+\s*\(", re.I)
SIZE_OF = re.compile(
    r"\b(?:size|allocated|ubound|lbound)\s*\(\s*([A-Za-z_][\w%]*)", re.I
)
COUNTED_DO = re.compile(r"^\s*(\w+\s*:\s*)?do\s+\w+\s*=", re.I)
MOVE_ALLOC = re.compile(r"\bcall\s+move_alloc\s*\((.*)\)", re.I)
TYPED_CHAR_CTOR = re.compile(r"\[\s*character\s*\([^)]*\)\s*::", re.I)
SELECT_CALL = re.compile(
    r"^\s*(?:\w+\s*:\s*)?select\s+case\s*\(\s*([A-Za-z_]\w*)\s*\(", re.I
)
STRIDED = r"[A-Za-z_][\w%]*\s*\((?:[^()]*,)?[^(),]*:[^(),]*:[^(),]*(?:,[^()]*)?\)"
STRIDE_EXPR = re.compile(rf"(?:{STRIDED})\s*(?:[-+/]|\*(?!\*))|(?<![*/])(?:[-+*/])\s*(?:{STRIDED})")
# intrinsics whose result does not carry the expression's extent (sizes, reductions, elementals inside a reduction)
ELEMENTAL_SAFE = {
    "size", "sum", "product", "maxval", "minval", "any", "all", "count", "maxloc", "minloc", "norm2", "dot_product",
    "shape", "ubound", "lbound", "abs", "sqrt", "exp", "log", "log10", "sin", "cos", "tan", "real", "int", "nint",
    "dble", "min", "max", "merge", "ieee_is_nan", "ieee_is_finite",
}
APPEND = re.compile(r"^\s*([A-Za-z_][\w%]*)\s*=\s*\[(.*)\]\s*$", re.I)
# temp-actual, temp-overlap: where they are checked, and what the expressions' names are
HOT_DIRS = ("src/lib/", "src/paths/")
NAME_REF = re.compile(r"([A-Za-z_][\w%]*)\s*\(")
# intrinsics whose result is not an array temporary of the expression (inquiries, reductions, scalar character work)
SCALAR_RESULT = {
    "size", "sum", "product", "maxval", "minval", "any", "all", "count", "maxloc", "minloc", "findloc", "norm2",
    "dot_product", "ubound", "lbound", "shape", "rank", "allocated", "associated", "present", "kind", "len",
    "len_trim", "storage_size", "is_contiguous", "c_loc", "c_associated", "loc", "trim", "adjustl", "adjustr",
    "index", "scan", "verify",
}
# intrinsic elemental (and array) functions: applied to an array, a temporary
INTRINSIC_ARRAY = {
    "abs", "real", "int", "nint", "dble", "sqrt", "exp", "log", "log10", "sin", "cos", "tan", "atan2", "min", "max",
    "merge", "floor", "ceiling", "mod", "modulo", "sign", "iand", "ior", "ieor", "ishft", "btest", "achar", "char",
    "ichar", "iachar", "cmplx", "aimag", "conjg", "transfer", "reshape", "pack", "spread", "matmul", "transpose",
    "cshift", "eoshift", "ieee_is_nan", "ieee_is_finite", "logical",
}
# names followed by a parenthesis that are statements, not references
KEYWORDS = {
    "if", "while", "case", "write", "read", "print", "open", "close", "inquire", "format", "where", "forall",
    "select", "associate", "call", "allocate", "deallocate", "nullify", "character", "type", "class", "integer",
    "complex", "rewind", "flush", "backspace", "endfile", "return", "stop", "error", "intent", "dimension", "go",
}


@dataclass
class Unit:
    """A procedure: its name, lines, declared names, dummies and internal procedures."""

    name: str
    start: int
    dummies: set[str]
    result: str
    end: int = 0
    declared: set[str] = field(default_factory=set)
    movable: set[str] = field(default_factory=set)
    derived: set[str] = field(default_factory=set)
    internals: list[Unit] = field(default_factory=list)
    host: Unit | None = None


def logical_lines(text: str) -> list[tuple[int, str, bool]]:
    """Return the statements of a free-form source: (first line number, code without comments, accepted)."""
    out: list[tuple[int, str, bool]] = []
    pending, first, accepted = "", 0, False
    for number, raw in enumerate(text.splitlines(), start=1):
        code = strip_comment(raw)
        accepted = accepted or bool(ACCEPT.search(raw))
        if not pending:
            first = number
        piece = code.strip()
        if pending and piece.startswith("&"):
            piece = piece[1:]
        if piece.endswith("&"):
            pending += piece[:-1] + " "
            continue
        statement = (pending + piece).strip()
        pending = ""
        if statement:
            for part in split_semicolons(statement):
                out.append((first, part, accepted))
        accepted = False
    return out


def strip_comment(line: str) -> str:
    """Return the line without its comment, quotes respected."""
    quote = ""
    for k, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = ""
        elif ch in "'\"":
            quote = ch
        elif ch == "!":
            return line[:k]
    return line


def split_semicolons(statement: str) -> list[str]:
    """Return the statements of a line split at semicolons outside quotes."""
    parts, quote, start = [], "", 0
    for k, ch in enumerate(statement):
        if quote:
            if ch == quote:
                quote = ""
        elif ch in "'\"":
            quote = ch
        elif ch == ";":
            parts.append(statement[start:k].strip())
            start = k + 1
    parts.append(statement[start:].strip())
    return [p for p in parts if p]


def declared_names(statement: str) -> set[str]:
    """Return the names a type declaration statement declares (empty for another statement)."""
    if "::" not in statement or not re.match(
        r"^\s*(integer|real|logical|complex|character|type|class|procedure|double)\b",
        statement,
        re.I,
    ):
        return set()
    entities = statement.split("::", 1)[1]
    depth, names, current = 0, [], ""
    for ch in entities:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif ch == "," and depth == 0:
            names.append(current)
            current = ""
            continue
        current += ch
    names.append(current)
    return {
        m.group(1).lower() for n in names if (m := re.match(r"\s*([A-Za-z_]\w*)", n))
    }


def split_arguments(text: str) -> list[str]:
    """Return the top-level comma-separated items of an argument list or constructor."""
    depth, items, current, quote = 0, [], "", ""
    for ch in text:
        if quote:
            if ch == quote:
                quote = ""
        elif ch in "'\"":
            quote = ch
        elif ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif ch == "," and depth == 0:
            items.append(current.strip())
            current = ""
            continue
        current += ch
    items.append(current.strip())
    return items


def balanced_end(text: str, start: int) -> int:
    """Return the index of the parenthesis closing the one at start (len(text) when none)."""
    depth = 0
    for k in range(start, len(text)):
        if text[k] == "(":
            depth += 1
        elif text[k] == ")":
            depth -= 1
            if depth == 0:
                return k
    return len(text)


def array_names(statement: str) -> set[str]:
    """Return the arrays a type declaration statement declares (empty for another statement)."""
    if "::" not in statement or not re.match(
        r"^\s*(integer|real|logical|complex|character|type|class|double)\b", statement, re.I
    ):
        return set()
    attributes, entities = statement.split("::", 1)
    dimension = bool(re.search(r"\bdimension\s*\(", attributes, re.I))
    out = set()
    for entity in split_arguments(entities):
        if (m := re.match(r"\s*([A-Za-z_]\w*)\s*(\()?", entity)) and (dimension or m.group(2)):
            out.add(m.group(1).lower())
    return out


def is_designator(text: str) -> bool:
    """Whether text is a name followed only by parenthesised groups and components (a variable, an element, a
    section; or, written the same, a function reference)."""
    t = text.strip()
    m = re.match(r"[A-Za-z_]\w*", t)
    if not m:
        return False
    k = m.end()
    while k < len(t):
        rest = t[k:].lstrip()
        k = len(t) - len(rest)
        if rest.startswith("("):
            k = balanced_end(t, k) + 1
        elif part := re.match(r"%\s*[A-Za-z_]\w*", rest):
            k += part.end()
        else:
            return False
    return True


def mask_calls(expr: str, keep: set[str]) -> str:
    """Return expr with the arguments of the references not named in keep replaced by 0 (their results are not
    temporaries of the expression; a call's own actual arguments are checked as that call's)."""
    out, k = expr, 0
    while m := NAME_REF.search(out, k):
        start = m.end() - 1
        if m.group(1).lower().split("%")[-1] in keep:
            k = start + 1
            continue
        end = balanced_end(out, start)
        out = out[:start] + "(0)" + out[end + 1 :]
        k = start + 3
    return out


def refers_to_array(expr: str, arrays: set[str]) -> bool:
    """Whether expr names a whole array or a section of one (an element does not count)."""
    for m in re.finditer(r"\b([A-Za-z_]\w*)\b(\s*\()?", expr):
        if m.group(1).lower() not in arrays or expr[: m.start()].rstrip().endswith("%"):
            continue
        if not m.group(2):
            return True
        inner = expr[m.end() : balanced_end(expr, m.end() - 1)]
        if any(":" in a for a in split_arguments(inner)):
            return True
    return False


def is_array_expression(actual: str, arrays: set[str], elemental: set[str]) -> bool:
    """Whether an actual argument is an array-valued expression (temp-actual)."""
    a = re.sub(r"^\s*[A-Za-z_]\w*\s*=(?!=)\s*", "", actual).strip()  # a keyword argument's value
    if not a or a.startswith("["):
        return False
    head = re.match(r"([A-Za-z_]\w*)\s*\(", a)
    applied = bool(head) and head.group(1).lower() in INTRINSIC_ARRAY | elemental
    if (is_designator(a) and not applied) or re.fullmatch(r"\(\s*[A-Za-z_][\w%]*\s*\)", a):
        return False
    return refers_to_array(mask_calls(a, (INTRINSIC_ARRAY | elemental | arrays) - SCALAR_RESULT), arrays)


def constant_disjoint(a: str, b: str) -> bool:
    """Whether two subscript triplets are constant ranges that do not overlap."""
    ra, rb = (re.fullmatch(r"(\d+)(?:_\w+)?:(\d+)(?:_\w+)?", t) for t in (a, b))
    if not (ra and rb):
        return False
    return int(ra.group(2)) < int(rb.group(1)) or int(rb.group(2)) < int(ra.group(1))


def single(triplet: str) -> bool:
    """Whether a subscript triplet is a single element written as a range (``k:k``): a copy of one, no temporary."""
    lo, _, hi = triplet.partition(":")
    return lo == hi and ":" not in hi


def check_temporaries(lines: list[tuple[int, str, bool]], text: str) -> list[tuple[int, str, str]]:
    """Return the temp-actual and temp-overlap findings of a source's statements."""
    elemental = {
        m.group(1).lower()
        for m in re.finditer(
            r"^\s*(?:\w+\s+)*elemental\s+(?:\w+\s+)*(?:function|subroutine)\s+(\w+)", text, re.I | re.M
        )
    }
    module_arrays: set[str] = set()
    scopes: list[set[str]] = []
    findings: list[tuple[int, str, str]] = []
    in_type, in_interface = False, 0
    for number, statement, _ in lines:
        if TYPE_DEF.match(statement) or END_TYPE.match(statement):
            in_type = bool(TYPE_DEF.match(statement))
            continue
        if INTERFACE.match(statement) or END_INTERFACE.match(statement):
            in_interface += 1 if INTERFACE.match(statement) else -1
            continue
        if in_type or in_interface:
            continue
        if PROC.match(statement) and not re.match(r"^\s*end\b", statement, re.I):
            scopes.append(set())
            continue
        if END_PROC.match(statement) and scopes:
            scopes.pop()
            continue
        if names := array_names(statement):
            (scopes[-1] if scopes else module_arrays).update(names)
            continue
        if not scopes:
            continue
        arrays = module_arrays.union(*scopes)
        code = re.sub(r"'[^']*'|\"[^\"]*\"", "''", statement)
        for m in NAME_REF.finditer(code):  # every call and function reference, nested ones too
            name = m.group(1).lower()
            last = name.split("%")[-1]
            if name in arrays or last in arrays or last in SCALAR_RESULT | INTRINSIC_ARRAY | KEYWORDS:
                continue
            args = code[m.end() : balanced_end(code, m.end() - 1)]
            if any(is_array_expression(a, arrays, elemental) for a in split_arguments(args)):
                findings.append((number, "temp-actual", statement))
                break
        else:
            lhs = re.match(r"^\s*([A-Za-z_][\w%]*)\s*\(", code)
            if not lhs:
                continue
            end = balanced_end(code, lhs.end() - 1)
            base = lhs.group(1).lower()
            if not re.match(r"^\s*=(?!=)", code[end + 1 :]):
                continue
            left = [a.replace(" ", "") for a in split_arguments(code[lhs.end() : end])]
            for m in NAME_REF.finditer(code[end + 1 :]):
                if m.group(1).lower() != base:
                    continue
                rhs = code[end + 1 :]
                right = [a.replace(" ", "") for a in split_arguments(rhs[m.end() : balanced_end(rhs, m.end() - 1)])]
                if len(right) == len(left) and any(
                    ":" in x and ":" in y and x != y and not constant_disjoint(x, y) and not (single(x) and single(y))
                    for x, y in zip(left, right)
                ):
                    findings.append((number, "temp-overlap", statement))
                    break
    return findings


def check_source(
    path: str, text: str, derived_elsewhere: frozenset[str] = frozenset(), hot: bool | None = None
) -> list[tuple[int, str, str]]:
    """Return the findings of one source file: (line, pattern, statement); derived_elsewhere: the components other
    files' type definitions declare ``type(...)`` or ``class(...)``; hot: check the temporaries (default: a file under
    ``HOT_DIRS``)."""
    lines = logical_lines(text)
    findings: list[tuple[int, str, str]] = []
    if hot is None:
        hot = any(d in Path(path).as_posix() for d in HOT_DIRS)
    if hot:
        findings += check_temporaries(lines, text)
    units: list[Unit] = []
    stack: list[Unit] = []
    module_names: set[str] = set()
    derived: set[str] = set(derived_elsewhere)
    module_derived: set[str] = set()
    deferred_results: set[str] = set()
    length_of_dummy: set[str] = set()
    has_typed_ctor = any(TYPED_CHAR_CTOR.search(s) for _, s, _ in lines)
    in_interface = 0
    in_type = False

    for number, statement, _ in lines:
        if TYPE_DEF.match(statement):
            in_type = True
            continue
        if END_TYPE.match(statement):
            in_type = False
            continue
        if in_type:  # a component: of a derived type, or not
            if re.match(r"^\s*(type|class)\s*\(", statement, re.I):
                derived |= declared_names(statement)
            continue
        if INTERFACE.match(statement):
            in_interface += 1
            continue
        if END_INTERFACE.match(statement):
            in_interface -= 1
            continue
        if in_interface:
            continue
        if (program := PROGRAM.match(statement)) and not stack:
            unit = Unit(program.group(1).lower(), number, set(), "")
            stack.append(unit)
            units.append(unit)
            continue
        match = PROC.match(statement)
        if match and not re.match(r"^\s*end\b", statement, re.I):
            dummies = {
                d.strip().lower()
                for d in (match.group(3) or "()")[1:-1].split(",")
                if d.strip()
            }
            name = match.group(2).lower()
            result = (
                (match.group(4) or name).lower()
                if match.group(1).lower() == "function"
                else ""
            )
            unit = Unit(
                name, number, dummies, result, host=stack[-1] if stack else None
            )
            if stack:
                stack[-1].internals.append(unit)
            stack.append(unit)
            units.append(unit)
            continue
        if END_PROC.match(statement) and stack:
            stack.pop().end = number
            continue
        names = declared_names(statement)
        is_derived = bool(re.match(r"^\s*(type|class)\s*\(", statement, re.I))
        if stack:
            unit = stack[-1]
            unit.declared |= names
            if is_derived:
                unit.derived |= names
            if re.search(
                r"\b(allocatable|pointer)\b", statement.split("::", 1)[0], re.I
            ):
                unit.movable |= names
            if (
                unit.result
                and unit.result in names
                and re.match(r"^\s*character\b", statement, re.I)
            ):
                spec = statement.split("::", 1)[0].replace(" ", "").lower()
                if "len=:" in spec or "(:)" in spec:
                    deferred_results.add(unit.name)
                if "len=len(" in spec:
                    length_of_dummy.add(unit.name)
        else:
            module_names |= names
            if is_derived:
                module_derived |= names

    def owner(number: int) -> Unit | None:
        """Return the innermost procedure holding a line."""
        best = None
        for unit in units:
            if unit.start <= number <= unit.end and (
                best is None or unit.start > best.start
            ):
                best = unit
        return best

    def local_of(unit: Unit, name: str) -> bool:
        """Whether name is a local of unit (declared there, not a dummy nor the result)."""
        return (
            name in unit.declared and name not in unit.dummies and name != unit.result
        )

    def host_associated(unit: Unit, name: str) -> bool:
        """Whether name, used in an internal procedure, is its host's (local or dummy)."""
        return (
            unit.host is not None
            and name not in unit.declared
            and name not in unit.dummies
            and (name in unit.host.declared or name in unit.host.dummies)
        )

    def reallocatable_in_host(unit: Unit, name: str) -> bool:
        """Whether name (a whole array or a component) is a host's array that a call can reallocate: an allocatable or
        pointer local or dummy of the host, or a component of the host's local or dummy."""
        base = name.split("%")[0]
        if unit.host is None or not host_associated(unit, base):
            return False
        return "%" in name or base in unit.host.movable

    def stride_expr_exposed(code: str, at: int, unit: Unit | None) -> bool:
        """Whether the expression at `at` is an actual argument of a call or of a non-intrinsic function, or the
        right side of an assignment to an allocatable or pointer variable."""
        depth = 0
        for k in range(at - 1, -1, -1):  # the innermost parenthesis enclosing the expression, and its name
            if code[k] == ")":
                depth += 1
            elif code[k] == "(":
                if depth == 0:
                    name = re.search(r"([A-Za-z_]\w*)\s*$", code[:k])
                    if re.match(r"^\s*call\b", code, re.I) and code.find("(") == k:
                        return True
                    if name and name.group(1).lower() not in ELEMENTAL_SAFE:
                        return True
                    if not name:  # a parenthesised operand: look further out
                        continue
                    return False
                depth -= 1
        lhs = re.match(r"^\s*([A-Za-z_][\w%]*)\s*=(?!=)", code)
        if not lhs:
            return False
        base = lhs.group(1).lower().split("%")
        if len(base) > 1:  # a component: its attributes are not resolved here
            return True
        scope = unit
        while scope is not None:
            if base[0] in scope.declared:
                return base[0] in scope.movable
            scope = scope.host
        return False

    loop_depth, loop_lines, loop_start = 0, [], 0
    accepted_lines: set[int] = set()
    for number, statement, accepted in lines:
        unit = owner(number)
        if accepted:
            accepted_lines.add(number)
        # move-alloc
        if (m := MOVE_ALLOC.search(statement)) and unit is not None:
            args = split_arguments(m.group(1))
            to = re.sub(
                r"^\s*to\s*=\s*", "", args[1] if len(args) > 1 else "", flags=re.I
            ).lower()
            if re.fullmatch(r"[a-z_]\w*", to) and (
                (unit.internals and local_of(unit, to))
                or (
                    unit.host is not None
                    and host_associated(unit, to)
                    and local_of(unit.host, to)
                )
            ):
                findings.append((number, "move-alloc", statement))
        # append
        if (m := APPEND.match(statement)) and "::" not in m.group(2):
            target = m.group(1).lower()
            items = [i.lower() for i in split_arguments(m.group(2))]
            if (
                "%" in target
            ):  # a component: declared type(...) in a type of this file or another
                of_derived_type = target.split("%")[-1] in derived
            else:  # a variable: declared type(...) where it is visible (its procedure, the hosts, the module)
                scope, of_derived_type = unit, False
                while scope is not None and not of_derived_type:
                    if target in scope.declared:
                        of_derived_type = target in scope.derived
                        break
                    scope = scope.host
                else:
                    of_derived_type = of_derived_type or target in module_derived
            if target in items and of_derived_type:
                findings.append((number, "append", statement))
        # stride-expr: as an actual argument, or assigned to an allocatable (a fixed-shape target is right)
        code = re.sub(r"'[^']*'|\"[^\"]*\"", "''", statement)
        for m in STRIDE_EXPR.finditer(code):
            if stride_expr_exposed(code, m.start(), unit):
                findings.append((number, "stride-expr", statement))
                break
        # select
        if has_typed_ctor:
            if (m := SELECT_CALL.match(statement)) and m.group(
                1
            ).lower() in deferred_results:
                findings.append((number, "select", statement))
            for name in length_of_dummy:
                for call in re.finditer(rf"\b{name}\s*\(([^()]*)\)", statement, re.I):
                    if unit is not None and unit.name == name:
                        continue
                    if any(
                        re.fullmatch(r"[A-Za-z_][\w%]*", a)
                        for a in split_arguments(call.group(1))
                    ):
                        findings.append((number, "select", statement))
        # hoist: loops of internal procedures
        if unit is not None and unit.host is not None:
            if DO.match(statement):
                if loop_depth == 0:
                    loop_lines, loop_start = [], number
                loop_depth += 1
            if loop_depth:
                loop_lines.append(statement)
            if END_DO.match(statement) and loop_depth:
                loop_depth -= 1
                if loop_depth == 0:
                    # a counted loop's bounds are evaluated once by the standard: only its body's tests count
                    body = "\n".join(
                        loop_lines[1:]
                        if COUNTED_DO.match(loop_lines[0])
                        else loop_lines
                    )
                    tested = {n.lower() for n in SIZE_OF.findall(body)}
                    if CALL.search(body) and any(
                        reallocatable_in_host(unit, n) for n in tested
                    ):
                        findings.append((loop_start, "hoist", loop_lines[0]))
        else:
            loop_depth = 0
    return sorted({f for f in findings if f[0] not in accepted_lines})


SELF_TESTS: list[tuple[str, str, set[str]] | tuple[str, str, set[str], bool]] = [
    (
        "an elemental expression of a strided section",
        """subroutine s(xs, ys)
real, intent(in) :: xs(:), ys(:, :)
call plot(xs(1::4) * 0.25, 1.0 + ys(1:41:4, 2))
endsubroutine
""",
        {"stride-expr"},
    ),
    (
        "a strided expression assigned to an allocatable",
        """subroutine s(xs)
real, intent(in) :: xs(:)
real, allocatable :: t(:)
t = xs(1::4) * 0.25
endsubroutine
""",
        {"stride-expr"},
    ),
    (
        "a strided expression assigned to a fixed-shape array or section, or reduced (right)",
        """subroutine s(xs)
real, intent(in) :: xs(:)
real :: t(11), r(4)
t = xs(1::4) * 0.25
r(1:3:2) = r(1:3:2) - 1.0
print *, size(xs(1::4) * 0.25), sum(xs(1::2) * 2.0)
endsubroutine
""",
        set(),
    ),
    (
        "a strided section passed as it is, and a contiguous section in an expression (right)",
        """subroutine s(xs)
real, intent(in) :: xs(:)
call plot(xs(1::4), xs(1:10) * 2.0)
endsubroutine
""",
        set(),
    ),
    (
        "move_alloc into a host local",
        """subroutine outer()
real, allocatable :: a(:), b(:)
allocate(b(3))
call move_alloc(b, a)
contains
subroutine inner()
endsubroutine
endsubroutine
""",
        {"move-alloc"},
    ),
    (
        "move_alloc into a dummy (right)",
        """subroutine outer(a)
real, allocatable, intent(inout) :: a(:)
real, allocatable :: b(:)
allocate(b(3))
call move_alloc(b, a)
contains
subroutine inner()
endsubroutine
endsubroutine
""",
        set(),
    ),
    (
        "size of a host array in an internal loop",
        """subroutine outer()
real, allocatable :: field(:)
call t()
contains
subroutine t()
integer :: k
do k = 1, 10
   if (size(field) > 0) exit
   call grow()
enddo
endsubroutine
subroutine grow()
endsubroutine
endsubroutine
""",
        {"hoist"},
    ),
    (
        "size of a local in an internal loop (right)",
        """subroutine outer()
call t()
contains
subroutine t()
real, allocatable :: field(:)
integer :: k
do k = 1, 10
   if (size(field) > 0) exit
   call grow()
enddo
endsubroutine
endsubroutine
""",
        set(),
    ),
    (
        "append to an array of a derived type",
        """subroutine add(h, r)
type(holder_t), intent(inout) :: h
type(run_t), intent(in) :: r
h%runs = [h%runs, r]
endsubroutine
""",
        set(),
    ),
    (
        "append to a component of a derived type declared in the file",
        """module m
type :: holder_t
   type(run_t), allocatable :: runs(:)
endtype
contains
subroutine add(h, r)
type(holder_t), intent(inout) :: h
type(run_t), intent(in) :: r
h%runs = [h%runs, r]
endsubroutine
endmodule
""",
        {"append"},
    ),
    (
        "append to a character array (right)",
        """subroutine add(seen, title)
character(len=128), allocatable, intent(inout) :: seen(:)
character(len=*), intent(in) :: title
seen = [character(len=128) :: seen, title]
endsubroutine
""",
        set(),
    ),
    (
        "select case on a deferred-length result, typed constructor in the file",
        """module m
character(len=*), parameter :: NAMES(2) = [character(len=9) :: 'title', 'nx']
contains
function name_of() result(name)
character(len=:), allocatable :: name
name = 'Setup'
endfunction
subroutine s()
select case (name_of())
case ('Setup')
endselect
endsubroutine
endmodule
""",
        {"select"},
    ),
    (
        "select case on a deferred-length result, no typed constructor (right)",
        """module m
contains
function name_of() result(name)
character(len=:), allocatable :: name
name = 'Setup'
endfunction
subroutine s()
select case (name_of())
case ('Setup')
endselect
endsubroutine
endmodule
""",
        set(),
    ),
    (
        "len(s) result with a variable actual, typed constructor in the file",
        """module m
contains
pure function lower(s) result(l)
character(len=*), intent(in) :: s
character(len=len(s)) :: l
l = s
endfunction
subroutine s(name)
character(len=*), intent(in) :: name
character(len=:), allocatable :: n
character(len=9), allocatable :: k(:)
k = [character(len=9) :: 'a', 'b']
n = lower(name)
n = lower(trim(adjustl(name)))
endsubroutine
endmodule
""",
        {"select"},
    ),
    (
        "temporaries: an array expression, a conversion, an elemental function as actual arguments",
        """module m
contains
pure elemental function twice(a) result(b)
real, intent(in) :: a
real :: b
b = 2.0 * a
endfunction
subroutine s(v, w)
real, intent(in) :: v(:), w(2)
real :: p(2), q(2)
call take(p + q)
call take_d(real(v(1:2), kind(1.0d0)))
call take(abs(w))
call take(twice(p))
endsubroutine
endmodule
""",
        {"temp-actual"},
        True,
    ),
    (
        "temporaries: a constructor, a variable, a section, an element expression, a function result, a reduction (right)",
        """subroutine s(v, x, y)
real, intent(in) :: v(:), x, y
real :: p(2), q(2), t
call take([x, y])
call take([p(1) + q(1), p(2)])
call take(p)
call take(v(1:2))
call take(v(1::2))
call take((p))
call take(p(1) + 1.0)
call take(pair(x, y))
call take(real(x, kind(1.0d0)))
t = sum(p * q)
p = q * 2.0
call take(size(v) * 1.0)
endsubroutine
""",
        set(),
        True,
    ),
    (
        "temporaries: shifted sections of one array, and substrings of one variable",
        """subroutine add(c, nc, p, s, k)
integer, intent(inout) :: c(:), nc
integer, intent(in) :: p, k
character(len=*), intent(inout) :: s
real :: r(6)
c(p + 2:nc + 1) = c(p + 1:nc)
r(2:6) = r(1:5)
s(k:k + 20) = s(k + 5:k + 25)
endsubroutine
""",
        {"temp-overlap"},
        True,
    ),
    (
        "temporaries: the same section, other columns, constant disjoint ranges, one character (right)",
        """subroutine s(m, k)
real, intent(inout) :: m(:, :)
integer, intent(in) :: k
real :: r(4)
m(:, 2) = m(:, 2) * 2.0
m(:, k + 1) = m(:, k)
r(3:4) = r(1:2) + 1.0
r(1:2) = r(1:2) + 1.0
endsubroutine
subroutine t(u, k, z)
character(len=*), intent(inout) :: u
integer, intent(in) :: k, z
u(k + z:k + z) = u(k:k)
endsubroutine
""",
        set(),
        True,
    ),
    (
        "temporaries outside the library and the paths (right)",
        """subroutine s(p, q)
real, intent(in) :: p(2), q(2)
call take(p + q)
endsubroutine
""",
        set(),
    ),
    (
        "an accepted line",
        """subroutine outer()
real, allocatable :: a(:), b(:)
call move_alloc(b, a) ! nvf-ok: probed
contains
subroutine inner()
endsubroutine
endsubroutine
""",
        set(),
    ),
]


def self_test() -> int:
    """Run the built-in cases; return the number that fail."""
    failed = 0
    for title, source, expected, *hot in SELF_TESTS:
        found = {pattern for _, pattern, _ in check_source(title, source, hot=bool(hot and hot[0]))}
        status = "ok" if found == expected else "FAIL"
        failed += status == "FAIL"
        print(f"{status}: {title}: expected {sorted(expected)}, found {sorted(found)}")
    return failed


def main() -> int:
    """Check the given directories or files (default: the library and the two paths)."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "paths",
        nargs="*",
        default=list(DEFAULT_DIRS),
        help="directories or files to check",
    )
    parser.add_argument(
        "--self-test", action="store_true", help="run the built-in cases"
    )
    args = parser.parse_args()
    if args.self_test:
        return 1 if self_test() else 0
    files: list[Path] = []
    for name in args.paths:
        path = Path(name)
        files += sorted(path.rglob("*.[Ff]90")) if path.is_dir() else [path]
    texts = {file: file.read_text(errors="replace") for file in files}
    derived: set[str] = set()
    for text in texts.values():
        in_type = False
        for _, statement, _ in logical_lines(text):
            if TYPE_DEF.match(statement):
                in_type = True
            elif END_TYPE.match(statement):
                in_type = False
            elif in_type and re.match(r"^\s*(type|class)\s*\(", statement, re.I):
                derived |= declared_names(statement)
    count = 0
    for file, text in texts.items():
        for number, pattern, statement in check_source(
            str(file), text, frozenset(derived)
        ):
            print(f"{file}:{number}: {pattern}: {statement.strip()[:120]}")
            count += 1
    print(f"check_nvf_patterns: {len(files)} files, {count} finding(s)")
    return 1 if count else 0


if __name__ == "__main__":
    sys.exit(main())
