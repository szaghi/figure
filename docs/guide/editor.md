---
title: Code editor
---

# Code editor

`code_editor_object` is a text editor for code and input files: syntax highlighting, line numbers, marks that put a
validator's findings on their lines, completion of the words the program knows, find and replace, undo and redo, the
clipboard. `code_diff` draws the difference of two texts. Both are
[ImGuiColorTextEdit](https://github.com/goossens/ImGuiColorTextEdit) (the goossens fork, MIT, vendored at a recorded
commit: [Third-party software](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md)) with FIGURE's own glue:
they draw through Dear ImGui only, so a window, headless mode and the [remote UI](remote) show the same editor.

Everything is polled, as every FIGURE widget: `ed%draw` returns `.true.` on the frame the user changed the text,
`ed%completing` while the completion popup is open; no procedure of the program is called back.

<Media name="cb_editor" video alt="An input file in the editor. Line 2, reynolds number = -15, and line 3, mach numbr = 0.3, are tinted vermilion with a crossed circle beside their numbers. The pointer rests on line 2 and its tooltip reads: error: reynolds number must be positive. A click after the minus sign, a backspace: the value becomes 15 and the mark goes. On the empty line 5, typing mach n opens a popup offering mach number; tab inserts it." caption="docs/examples/src/cb_editor.F90: an input file, its errors marked, a fix, a key completed" />

## Procedures

| Procedure | Purpose |
|---|---|
| `ed%init([language] [, stat])`, `ed%destroy()`, `ed%is_initialized()` → `logical` | create the editor, empty, highlighting `language`, a `language_object` (`code_language('fortran')`; default plain text); release it; whether it exists |
| `ed%set_language(language [, stat])` | highlight another language from now on (text, marks and undo history kept) |
| `ed%set_text(text [, stat])`, `ed%text()` → `character`, `ed%line_count()` → `int32` | replace the text (UTF-8, LF or CR LF; the marks and the undo history go); the text, every line ended by LF; its lines |
| `ed%draw(id [, width] [, height] [, stat])` → `logical` | the editor as a widget at the cursor; `.true.` on the frame the user changed the text |
| `ed%mark(line, severity, message [, stat])`, `ed%clear_marks([stat])`, `ed%mark_of(line [, message])` → `character` | mark a line `'error'`, `'warning'` or `'info'` with a message ([Marks](#marks)) |
| `ed%goto(line [, column] [, focus] [, stat])`, `ed%focus([stat])` | move the cursor and scroll to it; give the editor the keyboard |
| `ed%cursor(line, column)`, `ed%selection(first_line, first_column, last_line, last_column [, text])` → `logical`, `ed%select(first_line, first_column, last_line, last_column [, stat])` | where the cursor is; the selection; select a range |
| `ed%insert(text [, stat])`, `ed%word_at_cursor()` → `character` | insert at the cursor (in place of the selection); the word the cursor is in |
| `ed%find(text [, case_sensitive] [, whole_word] [, stat])` → `logical`, `ed%replace(text, by [, case_sensitive] [, whole_word] [, stat])` → `int32` | select the next occurrence; replace them all, in one undo ([Find and replace](#find-and-replace)) |
| `ed%set_completions(words [, stat])`, `ed%completing([words])` → `logical` | the words completion offers; whether its popup is open, and what it offers ([Completion](#completion)) |
| `ed%undo([stat])` → `logical`, `ed%redo([stat])` → `logical` | undo, redo a change (as ctrl+z and ctrl+y) |
| `ed%read_only(on [, stat])`, `ed%is_read_only()` → `logical` | make it read-only or editable again |
| `ed%set_options([line_numbers] [, tab_size] [, whitespace] [, line_highlight] [, stat])` | line numbers (default on), tab size [characters] (default 4), blanks and tabs shown (default off), the current line highlighted (default on) |
| `ed%line_rect(line, x0, y0, x1, y1)` → `logical` | a line's text area on the last draw [pixels]: for a popup beside it, or a test |
| `code_language(name [, stat])` → `language_object`, `lang%init(name [, keywords] [, ...])`, `lang%name()` → `character` | a shipped language; one of the program's own ([Languages](#languages)) |
| `code_diff(id, left, right [, side_by_side] [, language] [, width] [, height] [, stat])`, `code_diff_lines(left, right, added, removed [, stat])` | the difference of two texts, drawn; its lines ([The diff](#the-diff)) |

The fork's names, where FIGURE's differ: `draw` is `TextEditor::Render`, `mark` is `AddMarker`, `find` is
`SelectNextOccurrenceOf`, `replace` is `SelectAllOccurrencesOf` then `ReplaceTextInAllCursors`, `set_completions` is
`SetAutoCompleteConfig` with FIGURE's matcher as its callback, `code_diff` is `TextDiff::Render`. None of them is in
the [name map](imgui-names), which covers Dear ImGui and ImPlot.

**Rules.**
- `ed%init` after `app%init*`; `ed%draw` and `code_diff` inside a frame, in a window (a child region of their own,
  as `ig_begin_child`'s); the other procedures at any point of the main thread, a frame open or not.
- `ed%draw`'s result is valid on the frame it returns `.true.`: check the text then (`ed%text()`).
- An editor is drawn at most once a frame, under one id; two editors in one window need two ids.
- A change made by the program (`set_text`, `insert`, `replace`, `undo`) is not reported by `draw`: the program knows.
- `goto` and `find` move the cursor at once and scroll to it at the next draw.
- `code_editor_object` is not to be copied: a copy shares the editor. It has no finaliser, as
  [`texture_object`](images#textures): `ed%destroy()` releases it.

<<< @/examples/snippets/cb_editor-start.F90{fortran}

<<< @/examples/snippets/cb_editor-draw.F90{fortran}

**Arguments.** Lines and columns are numbered from 1; a column counts characters (a tab is one, `ρ` is one), not
bytes or screen columns. `width` and `height` are pixels: 0 the available region, negative up to that distance from
its edge (`height=-30.0_real64` leaves a line of text below), as `ig_begin_child`'s. Text is UTF-8 throughout;
`text()` ends every line with LF, so a file that ends with LF comes back as it was.

**Mouse and keyboard.** A click places the cursor, a drag selects, a double click selects a word, a triple click a
line, ctrl+click (alt+click on macOS) adds a cursor, the wheel scrolls; arrows, home, end, page up and down move;
ctrl+z, ctrl+y (or ctrl+shift+z) undo and redo; ctrl+x, ctrl+c, ctrl+v cut, copy and paste with the
[clipboard](widgets#clipboard); ctrl+a selects all; ctrl+f opens the fork's find and replace bar. On macOS cmd
stands for ctrl.

**Font and colours.** The editor draws in IBM Plex Mono at the current font size (`ig_push_font` changes the size),
with the [fallback font](styles#symbols-the-fallback-fonts)'s symbols, `ρ∞ ∇`. Its colours follow the style: the
text, the selection, the line numbers and the background are the style's; keywords, types, numbers, strings and
comments take the fork's dark or light palette, chosen by the window background's lightness.

**Statuses.** `FIG_ERR_STATE`: a procedure before `init` (the queries `text`, `line_count`, `mark_of`, `cursor`,
`selection`, `word_at_cursor`, `completing`, `is_read_only` and `line_rect` return their empty value instead), `draw`
or `code_diff` with no frame open, `insert` or `replace` in a read-only editor, any of them from a task.
`FIG_ERR_ARGUMENT`: an empty id, a line or column below 1, a line past the last (`mark`), an unknown severity, an
empty text to find or replace, a tab size outside [1, 16], an unknown language name, a keyword or type with a blank.
`stat` is optional: absent, a failure stops the program with its message ([Error handling](errors)).

**Modes.** Window, headless and remote: the same editor and the same pixels (it draws through Dear ImGui's draw
lists only). In remote mode the browser's keys reach it as any field's ([Remote UI](remote#behaviour)),
and its clipboard is the page's.

**Threads.** The main thread only: from a task every procedure is refused (`FIG_ERR_STATE`, the task stopped), the
queries return their empty value. `code_language`, `lang%init` and `code_diff_lines` draw nothing: a task may call
them.

## Languages

A `language_object` is data: the words the editor colours, its comments and strings, whether numbers are coloured,
whether case counts. `code_language(name)` gives the shipped ones, by name in any case:

| Name | What it colours |
|---|---|
| `'fortran'` | free-form Fortran 2023: its statements and operators (keywords), its types and attributes (types), `!` comments, `'...'` and `"..."` strings, numbers with exponents and kinds (`2.5d-3`, `1.0_real64`, `7_int8`), `#` preprocessor lines; any case |
| `'input'` | `key = value` files: a line `[section]`, the key before a line's `=` (blanks inside it: `reynolds number`), numbers, `!` and `#` comments, `true`, `false`, `yes`, `no`, `on`, `off`; any case |
| `'text'`, `''` | plain text |
| `'angelscript'`, `'c'`, `'c++'`, `'c#'`, `'glsl'`, `'hlsl'`, `'json'`, `'julia'`, `'lua'`, `'markdown'`, `'python'`, `'sql'`, `'wgsl'` | the fork's own languages |

`lang%init(name [, keywords] [, types] [, comment] [, comment_alt] [, block_comment] [, preprocessor] [, single_quotes]
[, double_quotes] [, numbers] [, case_sensitive] [, key_value] [, stat])` defines one:

- `keywords(:)` and `types(:)`: words coloured as keywords and as types, each trimmed, matched whole;
- `comment`, `comment_alt`: what starts a line comment (`'!'`, `'#'`, `'//'`); `block_comment = ['/*', '*/']`;
- `preprocessor`: the character that starts a preprocessor line (`'#'`);
- `single_quotes`, `double_quotes` (default true): `'...'` and `"..."` strings;
- `numbers` (default true): numbers coloured (digits, a fraction, an exponent, a kind suffix);
- `case_sensitive` (default true): keywords and types matched by case; false, in any case;
- `key_value` (default false): `[section]` lines and the keys before `=`, as `'input'`.

`FIG_ERR_ARGUMENT` for an empty name, a keyword or type that is empty or holds a blank, a preprocessor of more than
one character.

<<< @/examples/snippets/cb_languages-own.F90{fortran}

<Media name="cb_languages" alt="Six read-only editors in a grid: a Fortran module, a key = value input file with its sections and keys coloured, a solver log in a language defined by the program (converged, restart coloured as keywords, step and time as types), and the fork's Python, C++ and JSON." caption="docs/examples/src/cb_languages.F90: the shipped languages, and one of the program's own" />

## Marks

`ed%mark(line, severity, message)` puts a finding on its line: `'error'`, `'warning'` and `'info'` tint the line and
its number (vermilion, orange, blue: the Okabe-Ito colours) and put an icon beside the number (a crossed circle, a
triangle, an "i"), so the colour is not the only sign; the message, after its severity's word (`error: ...`), is the
tooltip of the line and of its number. A second mark on a line joins the messages, one per line, and keeps the
gravest severity. `ed%mark_of(line [, message])` reads a line's back (`''` for none).

A mark moves with its line as lines are inserted or deleted above it, and goes with the line. **Deleting text in a
marked line removes its mark** (the fork's rule: the finding was about the old text); typing in it keeps it. A
validator run on each change (`if (ed%draw('editor')) call validate(ed)`) marks the lines again in any case: clear
the marks, then mark what it finds. `set_text` removes them all.

<<< @/examples/snippets/cb_editor-validate.F90{fortran}

A check that takes long (a solver's dry run) belongs in a [task](processes#tasks): mark the lines when it ends.

## Completion

`ed%set_completions(words)` gives the words completion offers (none: completion off). While the user types a word,
a popup under the cursor lists the words that start with it, then those that contain it, in the order given, in any
case; up and down choose, tab or enter inserts, escape or a click elsewhere closes it, ctrl+space opens it. In a
`key_value` language a word may hold blanks and dashes: the term is the line's text up to the cursor, its indentation
kept, so `mach n` offers `mach number`. Completion is not offered in comments and strings.

`ed%completing([words])` is true while the popup is open, from the frame after the keystroke that opened it, with the
words it offers: what a test checks, or a program shows beside it (a key's documentation).

<<< @/examples/snippets/cb_editor-test.F90{fortran}

<<< @/examples/output/cb_editor.txt{text}

## Find and replace

`ed%find(text [, case_sensitive] [, whole_word])` selects the next occurrence after the cursor, from the start again
past the end, and scrolls to it at the next draw: true when found (the selection is then `text`). `ed%replace(text,
by [, case_sensitive] [, whole_word])` replaces every occurrence, as one change (one ctrl+z undoes it all), and
returns how many there were. `case_sensitive` defaults to true, `whole_word` to false. The user has the same in the
fork's bar, ctrl+f (cmd+f on macOS): find, find all, replace, replace all, by case, by whole word.

<<< @/examples/snippets/cb_editor-find.F90{fortran}

## The diff

`code_diff(id, left, right [, side_by_side] [, language] [, width] [, height] [, stat])` draws the difference of two
texts as a widget at the cursor, read-only: in one column the removed lines of `left` (tinted red, marked `-`) before
the added lines of `right` (green, `+`), or, with `side_by_side`, the two texts next to each other with their line
numbers. It is drawn by id, as a widget: FIGURE compares the texts again only when one of them, the language or the
layout changes, and forgets a diff not drawn for 600 frames. Lines are compared whole by the fork's algorithm (dtl's
shortest edit script): a changed line is a removed line and an added one.

`code_diff_lines(left, right, added, removed [, stat])` reports the same lines without drawing: `added`, the lines of
`right` (from 1) that are not in `left`; `removed`, the lines of `left` that are not in `right`. It needs no frame
and a task may call it.

<<< @/examples/snippets/cb_diff-lines.F90{fortran}

<<< @/examples/output/cb_diff.txt{text}

<<< @/examples/snippets/cb_diff-draw.F90{fortran}

<Media name="cb_diff" alt="Two versions of an input file side by side: the old reynolds number = 1000 tinted red on the left, the new 5000 green on the right, and restart file = RST/r added at the end, green." caption="docs/examples/src/cb_diff.F90: two versions of an input file" />

**Statuses and modes.** `code_diff`: `FIG_ERR_ARGUMENT` for an empty id, `FIG_ERR_STATE` with no frame open and from a
task; the same in every mode. `code_diff_lines`: always `FIG_OK`.

## Limits

- **Symbols of the fallback font keep their own width.** The editor lays text out on a grid of Plex Mono's advance;
  a symbol from Noto Sans Math (`ρ`, `∇`) is drawn at its column with its own width and may touch the next character
  ([Known issues](known-issues)).
- **One mark per line**: a second one joins the first; deleting text in a marked line removes its mark.
- **The visible part only**: the editor draws the lines in view; a very long line (10⁵ characters) is laid out
  whole on each change. Input files and source files of a few thousand lines are fine.
- **No folding, no word wrap, no minimap** in FIGURE's API: the fork has them, behind options FIGURE does not expose
  yet.
- **Language rules are per line**: in a key = value file a second `=` on a line colours the words before it as a key
  too.
- **The diff compares lines**, not words within a line.
