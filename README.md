# REEVE — Rocket Engineering & Environment Visualization Engine

REEVE is an educational, SI-unit, 3D rocket-flight simulation laboratory built with Godot 4.x and GDScript.

**Scope and safety:** REEVE is an educational simulator, not a vehicle certification tool or a guide to building, testing, or firing rocket motors. Propulsion is represented through generic supplied thrust/mass-flow data. It does not provide propellant recipes, injector design, chamber design, feed-system sizing, or firing procedures.

## Current implementation status

This repository was empty when the initial project scaffold was created. The first implementation milestone establishes the Godot project, a modular physics core, a minimal 3D scene, telemetry recording, and an initial validation suite.

Implemented foundations:
- SI-unit constants and conversion helpers.
- A documented approximate lower-atmosphere model (troposphere and lower stratosphere).
- A deterministic point-mass translational flight model with gravity, supplied thrust, and quadratic drag.
- Fixed-step simulation with an accumulator.
- Telemetry samples and CSV export.
- Basic analytical checks and model documentation.

Not yet implemented: full 6-DOF rigid-body dynamics, aerodynamic stability derivatives, validated thermal/structural analysis, vehicle workshop, recovery, advanced weather, or a professional telemetry UI. These must not be inferred from the current scaffold.

## Requirements

- Godot 4.3 or newer (verify with the installed editor).
- Windows 10/11.
- Recommended: 8 GB RAM; use the Compatibility renderer on integrated graphics.

## Run

1. Download or clone this repository.
2. Open the repository folder in Godot 4.x using Import and select project.godot.
3. Run the project with F6/F5 or the editor's Run Project button.

The initial scene is a lightweight 3D flight-test visualization. The physics core is deliberately separated from rendering.

## Tests

The tests directory contains GDScript validation scripts. Run them with the Godot executable in headless mode:

    godot --headless --path . --script tests/test_physics.gd

If the executable is named godot4, substitute that command. A successful parser run is not a substitute for validating the numerical model against independent reference cases.

## Architecture

    project.godot
    scenes/main/main.tscn
    scripts/main.gd
    scripts/physics/constants.gd
    scripts/physics/atmosphere.gd
    scripts/physics/flight_state.gd
    scripts/physics/flight_integrator.gd
    scripts/telemetry/telemetry_recorder.gd
    tests/test_physics.gd
    docs/model_assumptions.md

## Model limitations

The current flight core is a 3-DOF point-mass translational model. It does not model attitude, angular momentum, gimbaling, flexible structures, slosh, compressible CFD, or finite-element stress. Drag uses a configurable coefficient and reference area; this is an educational approximation, not a universal aerodynamic database. The atmosphere is a simplified standard profile and excludes weather variability.

All values shown by the simulator must be traceable to user inputs, supplied data, or documented calculations. Unknown performance data should remain unknown rather than being fabricated.

## Development sequence

1. Stabilize project and physics foundations.
2. Build component-based 3D workshop and mass accounting.
3. Add material property records and clearly bounded structural estimates.
4. Extend environment and atmospheric inputs.
5. Validate and extend flight dynamics.
6. Add generic supplied-data propulsion profiles.
7. Add aerodynamic and recovery models.
8. Add telemetry UI, export, and simulation history.
9. Run regression tests and document validation evidence.

## License

No license has been selected yet. Do not assume the project is open-source licensed until a license file is added.
