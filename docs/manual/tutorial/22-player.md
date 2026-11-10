---
title: 22. The field and its snapshots
---

# 22. The field and its snapshots

The last chapter of part three changes how the studio draws its result. The field is coloured through the colormap
once, into a texture, and coloured again only when something changed; its legend becomes the colour scale's control,
dragged and zoomed by the user; and a player steps through the snapshots the solver wrote during the run, the
converged field last.

<Media name="tut22_player" video alt="F5 runs the plate case; the solver writes the field every 4 iterations. The Result panel shows the converged field and, above it, a player: a step-back button, a play button, a step-forward button and a slider reading converged. Play: the slider reads iteration 4, 8, 16 and on, and the field, its contour lines with it, takes each snapshot's values, again and again from the start; pause, then step back twice. The legend beside the field is dragged down: its range moves, and the field is coloured again with it; two wheel steps over the legend zoom the range; Reset range gives back 0 to 100" caption="docs/examples/src/tut22_player.F90, run as tut22_player --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut22_player.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut22_player.F90),
chapter 21's studio with the changes below. The solver is chapter 21's, started with `--snapshots 4`: every 4
iterations it writes the field to `snap_NNNNNN.dat` and a line to `snapshots.txt`.

## The field through a colormap, in one call

Part two drew the field with `ip_heatmap`, which ImPlot colours cell by cell on every frame. `ip_field_image` colours
the field into a texture kept between frames, and colours it again only when the field, its range, its colormap or
its scale change ([Fields](/guide/plots#fields)):

<<< @/examples/snippets/tut22_player-field.F90{fortran}

- `x0`, `x1`, `y0`, `y1` are the edges of the cells, in plot units, as for the heatmap; the field is read in place
  (`f(i, j)`, i along x, j = 1 at the bottom).
- **A field changed in place is not seen.** FIGURE compares the array's address, its shape, the range, the colormap and
  the scale, not the values: when the program writes new values into the same array it says so with
  `changed=.true.`, for one frame. The studio sets `recolour` when it puts a snapshot into `shown_field`, and clears it
  after the call.
- A field of millions of cells costs its colouring once, not on every frame: a lazy studio that redraws for a moving
  pointer does not colour anything.

## A legend that sets the range

<<< @/examples/snippets/tut22_player-legend.F90{fortran}

`ip_colormap_legend_edit` draws the legend of chapter 12 and lets the user change its range: a drag along the bar
moves `[t_lo, t_hi]` with the pointer, the wheel over it zooms the range about the value under the pointer; the two
variables change in place, and `ip_field_image`, given them, colours the field again on that frame
([Fields](/guide/plots#fields)). The program keeps its own way back: *Reset range* sets them to the field's minimum and
maximum.

## A player over the snapshots

After a run, `read_snapshots` reads the list the solver wrote and sets up a `player_object`: `count` the snapshots and
the converged field, `index` the one shown, the last at first. The player is one widget:

<<< @/examples/snippets/tut22_player-player.F90{fortran}

`ig_player` draws a step-back button, a play/pause button, a step-forward button and a slider showing the label of the
snapshot shown; a right click on it opens a menu for the speed, in snapshots per second, and the mode, `'loop'` (the
default), `'once'` or `'bounce'`. It is true on the frame `index` changed, by a button, the slider or the playing
itself ([Players](/guide/widgets#players)); the studio then reads that snapshot:

<<< @/examples/snippets/tut22_player-show.F90{fortran}

The player plays on the frame clock and asks for the frames it needs while playing, so a lazy loop ([Lazy redraw](/guide/frame-loop#lazy-redraw))
keeps time without input; paused, the studio sleeps again.

## The test

`test_field_uploads()` counts the colourings `ip_field_image` made: none on a frame where nothing changed, one per
snapshot while playing. The test plays the player as its play button does, by setting `playing`:

<<< @/examples/snippets/tut22_player-player_test.F90{fortran}

<<< @/examples/output/tut22.txt{text}

(The `ig_end_tab` line is the report of [chapter 18](./18-checks#the-test-fails-on-any-mistake)'s deliberate mistake.)

::: tip What you learned
`ip_field_image`, a field coloured once and again only on a change, with `changed` for values changed in place;
`ip_colormap_legend_edit`, a legend whose range the user drags and zooms; `player_object` and `ig_player`, a player
over saved snapshots. Reference: [Fields](/guide/plots#fields), [Players](/guide/widgets#players).
:::

This is the end of part three. The [Cookbook](../cookbook) answers one task per recipe, the
[Reference](/guide/features) lists every procedure, and the [name map](/guide/imgui-names) gives the FIGURE call of a
Dear ImGui or ImPlot function.
