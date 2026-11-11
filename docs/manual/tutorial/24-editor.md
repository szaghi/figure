---
title: 24. The input in an editor, the help in Markdown
---

# 24. The input in an editor, the help in Markdown

The input's text, until now a plain multi-line field, becomes a **code editor**: the namelist highlighted, its names
completed, and each mistake marked on its line as the user types, so that *Apply* is not a guess. And the studio gets
its help, written in Markdown and drawn by FIGURE, whose links show a section of the input.

<Media name="tut24_editor" video alt="The plate case open, the Input panel's heat.inp tab: the namelist &heat in the code editor, its names, strings and numbers in colours, line numbers on the left. A double-click selects the name omega and a typo is typed over it, omgea: the line is tinted, an icon beside its number, the bar above the editor says [!!] the marked lines need a correction and Apply is greyed out. The pointer on the line number shows the mark's message, error: omgea is not a name of &heat. The name typed again, the mark goes and Apply is enabled. F1 opens the Help window: a drop-down of its sections and a find button at the top, then The studio, The input, Grid with a table of names, meanings and units; scrolled down, Body and Solver; a click on the link The body in the input makes the input's link read Help on Body" caption="docs/examples/src/tut24_editor.F90, run as tut24_editor --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut24_editor.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut24_editor.F90),
chapter 23's studio with the changes below.

## The editor

`source`, a `text_buffer_object` since chapter 10, is now a `code_editor_object`, created after `app%init` with the
language of its text and the words its completion offers ([Code editor](/guide/editor)):

<<< @/examples/snippets/tut24_editor-start.F90{fortran}

- **The language.** A namelist is Fortran: `code_language('fortran')` colours its names, strings, numbers and `!`
  comments. FIGURE ships `'fortran'` and `'input'` (`key = value` files) besides the editor's own languages.
- **Completion.** `set_completions(NAMES)`: typing `tol` offers `tolerance`; Tab or Enter takes it.
- **One text, two edits.** The form still writes the text with `case_text`; `set_source` puts it in the editor, which
  forgets its own undo history and marks: the program's text has no mistake.

The editor is one widget, drawn where the multi-line field was; it is true on the frame the user changed the text:

<<< @/examples/snippets/tut24_editor-editor.F90{fortran}

`height=-ig_frame_height()` leaves one line below it for the cursor's position, `source%cursor(line, column)`.

## Mistakes marked on their lines

Chapter 10's *Apply* read the text and, on a mistake, said so in a notification. The editor marks the line instead,
on each change:

<<< @/examples/snippets/tut24_editor-validate.F90{fortran}

- `source%mark(line, 'error', message)` tints the line and its number and puts an icon beside the number, so the
  colour is not the only sign; the pointer over the line shows the message. `'warning'` and `'info'` are the other severities
  ([Marks](/guide/editor#marks)).
- `clear_marks` first: the marks are the program's, and stay until it changes them.
- Three checks, in order: a name the namelist has not (`mark_names`, a small scan that skips strings and comments),
  then the run time's message when the namelist does not read, then the input's own checks of chapter 18
  (`problems`), each on the line of the name it is about.

*Apply* is enabled when the text was edited and no line is marked; the bar above the editor says which. `Ctrl+Z` in
the editor is its own undo, as it was for the field.

## The help

The help is a page of Markdown, held by a `markdown_view_object`: headings, tables, code and links, with a table of
contents (a drop-down of its headings, at the top) and a find bar ([Markdown](/guide/widgets#markdown)). The studio writes its text in the program
(`help%load(path)` reads a file instead):

<<< @/examples/snippets/tut24_editor-help_text.F90{fortran}

It is a registered window (chapter 23), floating, in no layout; *Help > Help* and `F1` show it, and the link above the
input's tree shows it at the section in front with `help%scroll_to(heading)`:

<<< @/examples/snippets/tut24_editor-help_link.F90{fortran}

<<< @/examples/snippets/tut24_editor-help.F90{fortran}

`help%draw` is true on the frame a link is clicked, with its URL: FIGURE opens nothing, the program decides. The
studio's links are its own, `form:N`, the section N of the input. *About* keeps its menu item, without the `F1` it had.

## The test

<<< @/examples/snippets/tut24_editor-editor_test.F90{fortran}

The test clicks the text's tab by its label with `test_item_click('heat.inp')`, selects `omega` with `source%find` and
types over it, as the user would; `source%mark_of(line)` reads the mark back. It corrects the name with
`source%replace`, the editor's find and replace, which is one step of its undo history.

<<< @/examples/output/tut24.txt{text}

::: tip What you learned
`code_editor_object`: `init` with `code_language`, `set_completions`, `draw`, `mark` and `clear_marks`, `find`,
`replace` and `mark_of`; `markdown_view_object`: `set_text`, `draw` with the link clicked, `scroll_to`, `find` and
`matches`. Reference: [Code editor](/guide/editor), [Markdown](/guide/widgets#markdown).
:::
