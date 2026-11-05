# Axial structural estimate

REEVE includes a small-strain linear-elastic estimate for a uniform prismatic member under a user-supplied tensile load.

Equations:

- Axial stress: `sigma = F / A`
- Elastic strain: `epsilon = sigma / E`
- Elastic extension: `delta = epsilon * L`

For materials with a non-zero nominal yield-strength reference, the module reports yield strength divided by tensile stress. For generic composites whose yield strength is not defined in the catalogue, it reports a factor against the catalogue ultimate tensile-strength reference and labels that basis explicitly.

This estimate assumes uniform uniaxial tension, constant cross-section, room-temperature nominal material properties and linear elasticity. It excludes stress concentrations, shell buckling, pressure-vessel stresses, joints, fasteners, fatigue, anisotropic laminate behaviour, thermal loads, defects, manufacturing variation and dynamic coupling. The reported strength factor is not a design allowable, certification margin or flight-safety factor.

No structural result should be interpreted as proof that a rocket component is safe to build or fly.
