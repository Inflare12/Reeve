# REEVE — Rocket Engineering & Environment Visualization Engine

REEVE is an educational, SI-unit, 3D rocket-flight simulation laboratory built with Godot 4.x and GDScript.

**Scope and safety:** REEVE is an educational simulator, not a vehicle certification tool or a guide to building, testing, or firing rocket motors. Propulsion is represented through generic supplied thrust/mass-flow data. It does not provide propellant recipes, injector design, chamber design, feed-system sizing, or firing procedures.

## Current implementation status

This repository was empty when the initial project scaffold was created. The first implementation milestone establishes the Godot project, a modular physics core, a minimal 3D scene, telemetry recording, and an initial validation suite.

Implemented foundations:
- Component records for cylindrical shells, rectangular plates, and user-entered masses.
- Interactive 3D Rocket Workshop with editable fuselage length, diameter, wall thickness, fin count/span/chord, material selection, separate conceptual subassembly visuals, selectable component inspection and user-entered masses for tanks, engine, payload, avionics, recovery, sensors and supports.
- Conceptual fin meshes and plate-mass estimates included in the vehicle mass roll-up.
- Vehicle configuration save/load to the Godot user-data directory (`user://reeve_vehicle.json`).
- Initial material catalogue with explicitly approximate reference properties.
- Vehicle component collection, duplicate-ID checks, and mass breakdown by category.
- JSON vehicle configuration save/load support.
- SI-unit constants and conversion helpers.
- A documented approximate lower-atmosphere model (troposphere and lower stratosphere), including Sutherland-law dynamic viscosity.
- A coefficient-driven aerodynamic module calculating Mach, dynamic pressure, Reynolds number, drag and supplied-slope lift without inventing vehicle coefficients.
- Validated external propulsion-curve reader with linear interpolation, impulse integration and explicit source-quality labels; the simulation controller can apply the supplied thrust and mass-flow samples to the flight model.
- A translational and rotational rigid-body foundation with gravity, supplied thrust, quadratic drag, quaternion attitude, diagonal-inertia angular dynamics and body-frame thrust direction.
- A fixed-step simulation controller with a bounded catch-up accumulator, validated model inputs and optional ground-contact event.
- An educational recovery model with altitude-triggered supplied parachute drag, terminal descent speed estimate and explicit limitations.
- Live gravity-only drop demonstration with position, speed, acceleration, wind-relative dynamic pressure, mass and time telemetry.
- Flight Lab controls for pause/resume, exact single-step execution, bounded simulation time scaling, and CSV/JSON telemetry export.
- Telemetry samples with CSV and unit-labelled JSON export; Mach and dynamic pressure are computed from air-relative velocity including the configured wind vector. JSON exports also include state-triggered mission events such as apogee, descent and ground contact.
- Basic analytical checks and model documentation.

Not yet implemented: full coupled 6-DOF aerodynamics and stability derivatives, validated thermal/structural analysis, component-specific geometry editing and workshop-to-flight handoff, advanced weather, or a professional telemetry plotting UI. These must not be inferred from the current scaffold.

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
    godot --headless --path . --script tests/test_scene.gd
    godot --headless --path . --script tests/test_workshop.gd

If the executable is named godot4, substitute that command. A successful parser run is not a substitute for validating the numerical model against independent reference cases.

## Architecture

    project.godot
    scenes/main/main.tscn
    scenes/workshop/workshop.tscn
    scripts/main.gd
    scripts/physics/constants.gd
    scripts/materials/material_catalog.gd
    scripts/workshop/rocket_component.gd
    scripts/workshop/rocket_configuration.gd
    scripts/workshop/workshop_scene.gd
    data/materials/materials.json
    scripts/physics/atmosphere.gd
    scripts/aerodynamics/aerodynamics.gd
    scripts/propulsion/propulsion_profile.gd
    scripts/recovery/recovery_model.gd
    scripts/physics/flight_state.gd
    scripts/physics/flight_integrator.gd
    scripts/physics/simulation_controller.gd
    scripts/telemetry/telemetry_recorder.gd
    tests/test_physics.gd
    docs/model_assumptions.md
    docs/aerodynamics_model.md
    docs/flight_demo.md
    docs/propulsion_profile.md
    docs/recovery_model.md
    docs/rotational_dynamics.md
    docs/workshop_components.md

## Model limitations

The current flight core is a 3-DOF point-mass translational model. It does not model attitude, angular momentum, gimbaling, flexible structures, slosh, compressible CFD, or finite-element stress. Drag uses a configurable coefficient and reference area; this is an educational approximation, not a universal aerodynamic database. The atmosphere is a simplified standard profile and excludes weather variability.

All values shown by the simulator must be traceable to user inputs, supplied data, or documented calculations. Unknown performance data should remain unknown rather than being fabricated.

## Development sequence

1. Stabilize project and physics foundations.
2. Expand component-based 3D workshop and connect editable parameters to the scene.
3. Expand material property records and clearly bounded structural estimates.
4. Extend environment and atmospheric inputs.
5. Validate and extend flight dynamics.
6. Add generic supplied-data propulsion profiles.
7. Add aerodynamic and recovery models.
8. Add telemetry UI, export, and simulation history.
9. Run regression tests and document validation evidence.

## License

No license has been selected yet. Do not assume the project is open-source licensed until a license file is added.
