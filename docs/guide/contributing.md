---
title: Contributing
---

# Contributing

FIGURE is at v0.2.0; the API can still change before v1.0 ([roadmap](roadmap)).

## Reporting issues

- Open a ticket on the repository's GitHub Issues page.
- Describe the problem with the steps to reproduce it, the compiler and its version, the platform, and for display
  problems the SDL video driver and the OpenGL renderer (`glxinfo -B` on Linux).

## Before a pull request

```bash
fobis build --mode tests-gnu-debug && exe/figure_test_headless   # runtime checks and FPE traps
fobis build --mode tests-nvf && exe/figure_test_headless         # rm -rf exe first when switching compilers
scripts/fpm.sh test
fobis rule --ex sync                                             # fobos and fpm.toml in sync
```

## Rules of the code base

- **Two builds, one truth.** fobos is the primary build; `fpm.toml` mirrors it. A new program under `src/examples` or
  `src/tests`, or a change of the native link libraries, goes into both: `scripts/check_sync.py` (`fobis rule --ex
  sync`) fails otherwise.
- **Generated raw layer.** `src/lib/figure_cimgui*.F90`, `src/lib/figure_cimplot*.F90`,
  `native/figure_glue_generated.cpp`, `src/tests/figure_test_layout.F90` and `docs/guide/raw-bindings.md` are
  generated: never edit them. After changing `scripts/gen_bindings.py` or the pinned
  cimgui/cimplot, run `fobis rule --ex bindings` and commit the result; `fobis rule --ex bindings-check` (also run by
  CI) fails on drift.
- **C ABI only.** A cimgui/cimplot function is bound directly only if all its arguments are scalars, pointers or
  `ImVec2_c` (the generator decides); anything taking a larger structure by value goes through the glue. Glue functions are `extern "C"`,
  return a status, take strings as (pointer, length), and never let a C++ exception escape.
- **Status codes** are defined twice, in `native/figure_native.h` and `src/lib/figure_c_native.F90`: change both.
- **Pinned versions.** cimgui, cimplot and SDL3 are a matched set: do not bump one alone.
- **Tests grow with bindings.** Every new widget or plot item gets a headless check driven by synthetic input, as in
  `src/tests/figure_test_headless.F90`.

## Fortran style

- One module per file under `src/lib`, `.F90`.
- `!<` documentation comments (formal and FORD `docmark`), on the entity and on every dummy argument and local.
- Kinds from `iso_fortran_env` and `iso_c_binding` only (`int32`, `real64`, `c_int`, ...); literals with their kind
  (`1.0_real64`).
- `implicit none` everywhere; `intent` on every dummy argument.
- Joined end statements: `endif`, `enddo`, `endfunction`, `endmodule`.
- Three-space indentation.
- Never name a local `size` (nvfortran 26.9 internal compiler error, see [Known issues](known-issues)).

## Documentation

The pages live in `docs/` (VitePress). Every Fortran snippet shown in the tutorial and the cookbook is included from a
program in `docs/examples/src`, with marker comments: `!region NAME` ... `!endregion NAME` for a part shown on its
own, `!run ID COMMAND` for a run whose output is shown (headless programs only).

Every run is a test. A `!run` must exit with status 0: a `--test` or `--check` self-test that fails, or a crash, fails
`build.sh`. An example that ends with an error on purpose (an `error stop` shown in the pages) is marked
`!run-exit STATUS ID COMMAND` and must exit with exactly that status; its output ends with `[exit status STATUS]`.
`build.sh` goes through every run, then names each one that failed and its output file (written all the same, to be
read) and exits with status 1.

```bash
bash docs/examples/build.sh     # compile every example against src/lib, run the headless ones,
                                # regenerate docs/examples/snippets and docs/examples/output
cd docs && npm install && npm run docs:build
```
