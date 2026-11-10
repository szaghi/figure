---
title: 19. Fields, lists and sizes
---

# 19. Fields, lists and sizes

Three habits of a finished application: a field that commits its value when the user leaves it, not at every key; a
message about a problem that takes the user to the field it names; and sizes that follow the font, so that a larger
font gives a larger studio, not a cramped one.

<Media name="tut19_layout" video alt="The studio on the plate case, Input in front. The title field is clicked and B typed, then escape: the title is Heated plate again and the window's title has no star. B typed again, then enter: the window's title reads * Heated plate B. In the Grid form, lx is selected and 0 typed, enter: two problems appear above the tree in red, each marked [!!], the plate needs a positive size and the body reaches the plate's edge. Body is picked in the tree; a click on the first problem shows the Grid form again with the lx field taking the keys; 1.5 is typed and enter: the problems are gone. View > Larger text: the whole studio grows with the font, the side bar, the panels' widths, the status bar" caption="docs/examples/src/tut19_layout.F90, run as tut19_layout --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut19_layout.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut19_layout.F90),
chapter 18's studio with the changes below.

## A field that commits when it is left

Chapter 9's title field set `edited` and the window's title at every key, and escape, which gives the field back its
text, still left the star in the title. `ig_last_item()` tells what happened to the item drawn last, in one
`item_status_object` ([What happened to an item](/guide/widgets#what-happened-to-an-item)): `activated` on the frame
the field takes the keys, `deactivated_after_edit` on the frame it is left after a change (enter, tab, a click
elsewhere).

<<< @/examples/snippets/tut19_layout-title.F90{fortran}

- The variable still follows every key (the field edits `inp%title` in place); what waits for the field to be left is
  what the studio does with it: the star, the window's title, and one undo step for the whole edit.
- Escape gives the field back the text it had when it took the keys, and leaves it: `inp%title` equals
  `title_before`, so nothing is committed.
- `ig_last_item()` describes the item drawn **last**: call it right after the field, before another widget.

The test checks both ways out of the field:

<<< @/examples/snippets/tut19_layout-leave.F90{fortran}

## A problem that takes you to its field

Chapter 15 listed the input's problems above the tree. Now each is a link (`ig_text_link`, drawn in the palette's
error colour, with its `[!!]` mark): a click shows the problem's section, scrolls the tree to it and gives its field
the keyboard.

<<< @/examples/snippets/tut19_layout-problems.F90{fortran}

The form gives the keys to the field right before drawing it:

<<< @/examples/snippets/tut19_layout-take_keys.F90{fortran}

and the tree scrolls its node into view as it draws it:

<<< @/examples/snippets/tut19_layout-reveal.F90{fortran}

In the video the plate's size is the problem and its `lx` field takes the keys; the test makes the body's radius
too large and checks the radius field. `ig_focus_here()` gives the **next** item the keyboard focus, as a click would: a field is edited at once, its text
selected. `ig_scroll_here()` scrolls the window or region drawn in so that the line of the item drawn **last** is at
its centre. Both take effect on the next frame ([Scrolling and focus](/guide/widgets#scrolling-and-focus)). The test
clicks the problem and checks the radius field has the keys: `ig_last_item()%focused`.

## Sizes in em

Every size of part two was in pixels, chosen for the default font of 15 pixels: the side bar 76, the tree 170, the
log 380. With a larger font the labels outgrew them. A size in **em** is a number of font sizes: `ig_em(5)` is 75
pixels at 15, 95 at 19 ([Layout](/guide/widgets#layout)). The studio's sizes are all in em now:

<<< @/examples/snippets/tut19_layout-em.F90{fortran}

The status bar is one row of widgets high, `ig_frame_height()`, and a margin. View > Larger text sets the font to 19
pixels, and the next frame lays out everything again:

<<< @/examples/snippets/tut19_layout-text_size.F90{fortran}

The About box's Close button sits at its right edge, wherever the text makes the box end:

<<< @/examples/snippets/tut19_layout-align.F90{fortran}

`ig_align_begin(id, 'right')` starts a group placed from its width in the previous frame: on the first frame a group
is drawn where it starts and placed the frame after (FIGURE asks for that frame by itself). The Case panel's
parameters have a title, `ig_separator_text('Parameters')`.

## The test

<<< @/examples/output/tut19.txt{text}

(The `ig_end_tab` line is the report of [chapter 18](./18-checks#the-test-fails-on-any-mistake)'s deliberate mistake.)

::: tip What you learned
`ig_last_item()` and its `activated` and `deactivated_after_edit`: commit on leave, one undo step per edit;
`ig_text_link` for a message that acts; `ig_focus_here` and `ig_scroll_here` to take the user to an item; sizes in em
with `ig_em` and `ig_frame_height`, a font changed at run time, `ig_align_begin` for a right-aligned button.
Reference: [What happened to an item](/guide/widgets#what-happened-to-an-item), [Scrolling and
focus](/guide/widgets#scrolling-and-focus), [Layout](/guide/widgets#layout).
:::

**Next:** [20. Tables that act](./20-tables): context menus on the boundaries, a sortable list of runs, numbers with
drag boxes and radio buttons.
