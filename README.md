# REEVE — Rocket Engineering & Environment Visualization Engine

REEVE is an educational, SI-unit, 3D rocket-flight simulation laboratory built with Godot 4.x and GDScript.

**Scope and safety:** REEVE is an educational simulator, not a vehicle certification tool or a guide to building, testing, or firing rocket motors. Propulsion is represented through generic supplied thrust/mass-flow data. It does not provide propellant recipes, injector design, chamber design, feed-system sizing, or firing procedures.

## Current implementation status

The current implementation is a modular educational simulator with a 3D workshop, a flight laboratory, SI-unit physics modules, telemetry, and automated headless validation. The feature list below describes implemented code; it does not imply that the models are flight-qualified.

Implemented foundations:
- Component records for cylindrical shells, rectangular plates, and user-entered masses.
- Interactive 3D Rocket Workshop with editable fuselage length, diameter, wall thickness, fin count/span/chord, material selection, separate conceptual subassembly visuals, selectable component inspection and user-entered masses for tanks, engine, payload, avionics, recovery, sensors and supports.
- Conceptual fin meshes and plate-mass estimates included in the vehicle mass roll-up.
- Vehicle configuration save/load to the Godot user-data directory (`user://reeve_vehicle.json`), with a one-click workshop-to-Flight-Lab handoff for total mass, fuselage dimensions and fin visual geometry; unknown Cd and propulsion remain unset.
- Initial material catalogue with explicitly approximate reference properties.
- Vehicle component collection, duplicate-ID checks, and mass breakdown by category.
- JSON vehicle configuration save/load support.
- SI-unit constants and conversion helpers.
- A documented approximate lower-atmosphere model (troposphere and lower stratosphere), including Sutherland-law dynamic viscosity and explicit out-of-domain rejection.
- Optional deterministic three-axis sinusoidal wind/gust model sampled at every fixed physics step.
- A coefficient-driven aerodynamic module calculating Mach, dynamic pressure, Reynolds number, drag and supplied-slope lift without inventing vehicle coefficients.
- Optional attitude-coupled aerodynamic force path using user-supplied Mach/Cd curves, reference geometry and lift slope; unsupported Mach extrapolation is rejected.
- A static-margin calculator using explicitly user-supplied CG and CP positions and a documented coordinate convention.
- A bounded linear-elastic axial tension estimate with explicit metal/composite strength-reference labels and engineering limitations.
- A Biot-number-checked lumped-capacitance convective thermal response estimate using supplied heat-transfer inputs.
- Validated external propulsion-curve reader with linear interpolation, impulse integration and explicit source-quality labels; the simulation controller can apply the supplied thrust and mass-flow samples to the flight model.
- A translational and rotational rigid-body foundation with gravity, supplied thrust, quadratic drag, quaternion attitude, diagonal-inertia angular dynamics and body-frame thrust direction.
- A fixed-step simulation controller with a bounded catch-up accumulator, validated model inputs and optional ground-contact event.
- An educational recovery model with altitude-triggered supplied parachute drag, terminal descent speed estimate and explicit limitations.
- Lightweight 3D launch environment with ground plane, launch pad, ambient lighting and shadows; selectable external-chase, side-observation, ground-observation, rocket-follow, free (WASD/QE) and engineering-inspection cameras.
- Live gravity-only drop demonstration with position, speed, acceleration, wind-relative dynamic pressure, mass and time telemetry.
- Flight Lab controls for horizontal wind velocity, temperature offset, pressure scaling, pause/resume, exact single-step execution, bounded simulation time scaling, and CSV/JSON telemetry export.
- Telemetry samples with CSV and unit-labelled JSON export; Mach and dynamic pressure are computed from air-relative velocity including the configured wind vector. JSON exports also include state-triggered mission events such as apogee, descent and ground contact.
- Live five-channel telemetry plots for altitude, velocity, acceleration, dynamic pressure and mass, driven by recorded simulation samples.
- Basic analytical checks and model documentation.

Not yet implemented: fin-resolved aerodynamic moments and stability derivatives, a complete validated 6-DOF aerodynamic model, pressure-vessel and buckling analysis, detailed geometry editing for every subassembly, advanced weather, multi-run history comparison and advanced telemetry analysis tools. Workshop-to-flight handoff transfers the current vehicle mass, fuselage dimensions and fin visual geometry; it deliberately does not infer unknown drag or propulsion data. Structural and thermal modules are bounded analytical estimates, not validated engineering qualification. These capabilities must not be inferred from the current implementation.

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
    scripts/structural/structural_estimate.gd
    scripts/structural/thermal_estimate.gd
    scripts/workshop/rocket_component.gd
    scripts/workshop/rocket_configuration.gd
    scripts/workshop/workshop_scene.gd
    data/materials/materials.json
    scripts/physics/atmosphere.gd
    scripts/physics/wind_model.gd
    scripts/aerodynamics/aerodynamics.gd
    scripts/aerodynamics/stability_estimate.gd
    scripts/propulsion/propulsion_profile.gd
    scripts/recovery/recovery_model.gd
    scripts/physics/flight_state.gd
    scripts/physics/flight_integrator.gd
    scripts/physics/simulation_controller.gd
    scripts/telemetry/telemetry_recorder.gd
    scripts/telemetry/telemetry_plot.gd
    tests/test_physics.gd
    docs/model_assumptions.md
    docs/aerodynamics_model.md
    docs/static_margin.md
    docs/flight_demo.md
    docs/propulsion_profile.md
    docs/recovery_model.md
    docs/rotational_dynamics.md
    docs/workshop_components.md
    docs/wind_model.md
    docs/structural_estimate.md
    docs/telemetry_plots.md
    docs/thermal_estimate.md

## Model limitations

The translational flight core remains a 3-DOF point-mass model. A separate rotational foundation integrates quaternion attitude and diagonal-inertia angular dynamics from supplied body moments. An optional simplified aerodynamic path couples body-axis angle of attack to translational drag/lift using user-supplied coefficients, but does not generate aerodynamic moments or stability derivatives. The model does not include gimbaling, flexible structures, slosh, compressible CFD, or finite-element stress. Drag uses a supplied or configured coefficient and reference area; this is an educational approximation, not a universal aerodynamic database. The atmosphere is a simplified dry-air profile and excludes meteorological weather variability.

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
