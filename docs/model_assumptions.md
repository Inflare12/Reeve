# REEVE model assumptions and validity boundaries

## Coordinate system and units

- World axes: +Y is up; +X and +Z are horizontal.
- Position: metres (m); time: seconds (s).
- Velocity: m/s; acceleration: m/s².
- Mass: kg; force: N; moment: N m.
- Pressure: Pa; temperature: kelvin (K).
- Attitude: unit quaternion; angular velocity: rad/s.
- Inertia: diagonal principal-axis values in kg m².

## Atmosphere

The current dry-air reference atmosphere is a two-layer approximation:

- -500–11,000 m: linear temperature lapse rate of 0.0065 K/m.
- 11,000–20,000 m: isothermal layer at 216.65 K.
- Pressure follows the hydrostatic barometric equations for each layer.
- Density follows the ideal-gas equation, rho = p/(R T).
- Speed of sound follows a = sqrt(gamma R T).
- Dynamic viscosity uses Sutherland's law.

Queries outside -500–20,000 m are rejected; values are not silently clamped. This is not a complete US Standard Atmosphere 1976 implementation. Humidity, composition variation, real weather and atmospheric boundary-layer effects are not modelled.

## Gravity

Gravity varies with altitude using the inverse-square approximation:

g(h) = g0 [Re / (Re + h)]².

The model uses mean Earth radius and standard sea-level gravity. Latitude and local geoid effects are omitted.

## Translational flight

The translation state is a 3-DOF point mass. The force model includes:

- Thrust: externally supplied thrust magnitude and direction.
- Drag: Fd = -0.5 rho Cd A |v_rel| v_rel.
- Gravity: downward, altitude-adjusted.
- Optional recovery drag: user-supplied parachute Cd*A after the configured altitude is crossed while descending.

Relative air velocity is vehicle velocity minus sampled wind velocity. Wind can be constant or a deterministic, user-configured sinusoidal three-axis gust model. The gust model is a sensitivity-study input, not stochastic turbulence or weather.

The default integrator uses semi-implicit Euler at a fixed 1/120 s step. The controller bounds catch-up work and allows a configured step no larger than 0.1 s. Results are timestep-dependent; compare against analytical cases and perform timestep convergence checks before relying on them.

Mass flow is accepted only as externally supplied model data. Consumption is capped by remaining propellant and available mass above configured dry mass. Tanks, residual propellant distribution, pressurization, pumps, combustion and engine internal physics are not simulated.

## Rotational foundation

The flight state also supports quaternion attitude and body angular rates. A user-supplied diagonal inertia tensor and body moment are used in the rigid-body angular equation:

I * omega_dot = M - omega cross (I * omega).

Body-frame thrust direction is rotated into world coordinates by the current quaternion. This rotational foundation is not yet fully coupled to aerodynamic forces, centre-of-pressure motion, aerodynamic stability derivatives, control surfaces, gimbaling, slosh or flexible-body dynamics. It is not a complete validated 6-DOF vehicle model.

## Aerodynamics

The standalone aerodynamic module calculates flow properties, drag and a supplied-slope lift estimate. Drag coefficients must be provided as a Mach curve; extrapolation outside that curve is rejected. The translational flight integrator currently uses its configured Cd and reference area rather than automatically coupling the standalone aerodynamic curve and lift model into attitude dynamics. No universal rocket coefficient database is assumed.

## Recovery, structural and thermal estimates

The recovery model is a point-mass quadratic-drag approximation. It excludes canopy inflation, line dynamics, opening shock, porosity, wake interaction and deployment reliability.

The structural module is limited to uniform-member linear-elastic axial tension. It does not calculate shell buckling, pressure-vessel stress, joints, fatigue, anisotropic laminate response or finite-element stress.

The thermal module is a lumped-capacitance convective response. It checks Biot number and rejects cases outside the stated lumped assumption. It does not model aerodynamic heating, radiation, heat shields, internal heat generation or temperature-dependent material properties.

## General validity

All coefficients and profiles not defined by physical constants must be supplied with a source or clearly labelled as estimates or synthetic tests. These educational models are not design allowables, flight qualification or real-world safety analysis.
