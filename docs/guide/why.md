---
title: Why immediate mode
---

# Why immediate mode

## Retained mode from Fortran

A retained-mode toolkit (wxWidgets, Qt, GTK) keeps a tree of widget objects. The program creates them, keeps
references to them, registers callbacks on them, and destroys them. From Fortran this has a specific cost:

- **Lifetimes cross the language boundary.** The widgets live in C++; Fortran holds opaque handles to them. A binding
  has to keep a handle table and track ownership and release, because Fortran has neither closures nor destructors
  that run deterministically on the C++ side's schedule.
- **Callbacks need state.** A callback receives no closure, so a binding stores a pointer to the data the callback
  works on. In Fortran that pointer is valid after the call only if the actual argument has the `target`
  attribute; when it does not, the pointer becomes undefined after the call, and no compiler or runtime check
  detects it.
- **Enumerations are duplicated.** Event types, status and modifier codes exist in C++ and again, by hand, in
  Fortran, where they can drift apart.
- **The C++ ABI.** Toolkits with a C++ public API need their C++ ABI to match the one of the compiler toolchain
  linked with the Fortran code; on Windows, a toolkit built with MSVC cannot be linked by MinGW gfortran.

None of this is a defect of a particular binding: it is the price of the retained paradigm in a language without
closures. FIGURE changes the paradigm instead of the toolkit.

## Immediate mode

In [Dear ImGui](https://github.com/ocornut/imgui) the interface is code that runs every frame. There is no widget
object: `ig_button('Run')` draws a button this frame and returns `.true.` on the frame it is clicked. Widgets are
identified by their label (see [Widgets](widgets#labels-and-identifiers)), and the library keeps only transient
interaction state (which item is hovered, which is being dragged).

For a Fortran binding this removes:

- handles, handle tables and lifetime contracts: there is nothing to create or destroy except the application;
- callbacks: control flow is an `if` on the value a widget returns;
- `target` requirements: a value is passed for the duration of the call and written back before it returns (see
  [Widgets](widgets#values-are-your-variables)).

The C++ ABI problem is removed by the boundary: Fortran calls only C functions, those of cimgui and cimplot and
those of FIGURE's own glue ([Architecture](architecture)). The `bind(C)` interfaces and every enumeration value
are generated from cimgui's and cimplot's metadata, never copied by hand, and CI checks them for drift
([Raw bindings](raw-bindings)).

## Costs

Immediate mode redraws the interface every frame. FIGURE limits this with [lazy redraw](frame-loop#lazy-redraw):
once the interface has settled, the loop sleeps until input arrives or a refresh period elapses. Building the
interface every frame also means that a program must not recompute expensive data inside a window that is not
visible: `ig_begin` returns `.false.` for a collapsed window, so its content can be skipped.

## Alternatives considered

An HTML front end over a C ABI (`webview`) was the second choice, and was set aside for speed: data crosses the
boundary as JSON. Slint, Flutter, FLTK, Nuklear and raygui were also considered and not retained.
