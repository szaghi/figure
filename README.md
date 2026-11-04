# FIGURE

**F**ortran **I**mmediate-mode **G**UI for **U**ser interfaces, **R**endering and **E**xploration.

Fortran bindings to [Dear ImGui](https://github.com/ocornut/imgui) and [ImPlot](https://github.com/epezent/implot)
(through the C APIs of [cimgui](https://github.com/cimgui/cimgui)/[cimplot](https://github.com/cimgui/cimplot)), on
[SDL3](https://github.com/libsdl-org/SDL) + OpenGL 3. Immediate mode: no widget objects, handles or callbacks; the UI
is declared every frame and its state is the program's own variables.

```fortran
call app%init('My tool', 1100, 700)
do while (app%next_frame())
   if (ig_begin('Solver')) then
      if (ig_button('Run')) call start_run(state)
      if (ig_slider('CFL', state%cfl, 0.1_real64, 2.0_real64)) continue
      if (ip_begin_plot('Residual')) then
         call ip_line('L2', iterations, residual)
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
```

**Status:** spike (milestone 1 of [plans/plan.md](plans/plan.md)). API unstable.

## Building

Two layers: the **native layer** (C/C++: Dear ImGui, ImPlot, cimgui, cimplot, SDL3, glue), built by CMake into
`lib/`; the **Fortran library**, built by FoBiS (primary) or fpm, which only link the native layer.

```sh
scripts/build_native.sh                      # once; FoBiS also runs it before every build (no-op when built)

fobis build --mode tests-gnu && exe/figure_test_headless     # gfortran
fobis build --mode examples-gnu && exe/figure_hello
fobis build --mode tests-nvf                                 # nvfortran
fobis rule --ex sync                                         # fobos and fpm.toml describe the same build

scripts/fpm.sh test                          # fpm (adds -L lib/)
scripts/fpm.sh run --example figure_hello
```

Linux needs the X11/Wayland/DBus development packages for SDL3 windows (see plans/plan.md, "Platform setup").
The headless test needs no display and no GPU.

**WSL2 (WSLg):** set `GALLIUM_DRIVER=d3d12` (e.g. in `~/.bashrc`). Without it, recent Mesa (seen with 25.2) does not
pick the GPU and renders in software (llvmpipe): FIGURE works, but every frame costs CPU. Check with
`glxinfo -B`: the renderer must be `D3D12 (<your GPU>)` with `Accelerated: yes`. FIGURE does not set it itself:
it is a property of the machine, and wrong outside WSL.
