text = '# The studio'//LF//LF// &
   'A **case** is a folder holding its input, `heat.inp`. Open one with *File > Open case* (ctrl+o), or drop '// &
   'its folder on the window; run the solver with *Run > Run* (F5).'//LF//LF// &
   '# The input'//LF//LF// &
   '`heat.inp` is the namelist `&heat`: `name = value` items, `!` comments. Edit it in the form or as text: '// &
   'the text marks each mistake on its line, and *Apply* waits until none is left.'//LF//LF// &
   '## Grid'//LF//LF//'| name | meaning | unit |'//LF//'|---|---|---|'//LF// &
   '| `nx`, `ny` | grid nodes along x and y, at least 3 | |'//LF// &
   '| `lx`, `ly` | the plate''s width and height | m |'//LF//LF//'[The grid in the input](form:1)'//LF//LF// &
   '## Boundaries'//LF//LF//'| name | meaning | unit |'//LF//'|---|---|---|'//LF// &
   '| `bc_kind` | west, east, south, north: `''fixed''` or `''insulated''` | |'//LF// &
   '| `bc_value` | the fixed sides'' temperatures | C |'//LF//LF// &
   'Not every side insulated: the temperature would not be determined.'//LF//LF// &
   '[The boundaries in the input](form:2)'//LF//LF// &
   '## Body'//LF//LF//'| name | meaning | unit |'//LF//'|---|---|---|'//LF// &
   '| `body_x`, `body_y` | the body''s centre | m |'//LF//'| `body_r` | its radius, inside the plate | m |'//LF// &
   '| `body_t` | its temperature | C |'//LF//LF//'[The body in the input](form:3)'//LF//LF// &
   '## Solver'//LF//LF//'| name | meaning | unit |'//LF//'|---|---|---|'//LF// &
   '| `omega` | over-relaxation factor, in (0, 2): 1 is Gauss-Seidel | |'//LF// &
   '| `tolerance` | the residual to reach | C |'//LF//'| `max_iter` | iterations at most | |'//LF//LF// &
   '[The solver in the input](form:4)'//LF//LF// &
   '# Keys'//LF//LF//'| key | does |'//LF//'|---|---|'//LF//'| ctrl+o | open a case |'//LF// &
   '| ctrl+s | save the input |'//LF//'| ctrl+z | undo an edit of the form |'//LF//'| F5, shift+F5 | run, stop |'// &
   LF//'| F1 | this help |'//LF
