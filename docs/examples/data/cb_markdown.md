# Solver help

The solver reads an **input file** of `key = value` lines, grouped in sections. This page lists the keys; the
[boundary conditions](#boundary-conditions) are at the end. The full manual is on the
[project's site](https://szaghi.github.io/figure/).

## Fluid properties

| key | unit | default |
|---|---|---|
| `reynolds number` | – | 1e6 |
| `mach number` | – | 0.3 |
| `prandtl number` | – | 0.71 |

- `reynolds number` must be *positive*.
- Below a `mach number` of 0.3 the flow is taken as incompressible: the pressure is solved from ∇·u = 0.

## Output

```
[output-parameters]
 save frequency = 100
 format = 'xdmf'
```

> [!TIP]
> A `save frequency` of 0 writes the last step only.

## Boundary conditions

1. An **inlet** fixes the velocity.
2. An **outlet** fixes the pressure.
3. A **wall** has no slip.

Back to the [top](#solver-help).
