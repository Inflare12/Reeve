# REEVE model assumptions — initial physics core

## Coordinate system and units

- World axes: +Y is up; +X and +Z are horizontal.
- Position: metres (m).
- Time: seconds (s).
- Velocity: metres per second (m/s).
- Acceleration: metres per second squared (m/s²).
- Mass: kilograms (kg).
- Force: newtons (N).
- Pressure: pascals (Pa).
- Temperature: kelvin (K).

## Atmosphere

The initial model uses dry air and a two-layer approximation:
- 0–11,000 m: linear temperature lapse rate of 0.0065 K/m.
- 11,000–20,000 m: isothermal layer at 216.65 K.
- Pressure follows the hydrostatic barometric equations for each layer.
- Density follows the ideal gas equation, rho = p/(R T).
- Speed of sound follows a = sqrt(gamma R T).

The model clamps geopotential altitude to -500–20,000 m. Humidity, weather, wind shear, and atmospheric composition changes are not represented. It is not a complete US Standard Atmosphere 1976 implementation.

## Gravity

Gravity varies with altitude using the inverse-square approximation:
g(h) = g0 [Re / (Re + h)]².
The model uses mean Earth radius and standard sea-level gravity. Latitude and local geoid effects are omitted.

## Translational flight

The state is a 3-DOF point mass. The force model is:
- Thrust: supplied scalar thrust multiplied by a supplied direction vector.
- Drag: Fd = -0.5 rho Cd A |v_rel| v_rel.
- Gravity: downward, altitude-adjusted.

Relative air velocity is vehicle velocity minus the configured wind velocity. The integrator uses semi-implicit Euler at fixed steps no larger than 0.1 s. This is simple and inspectable, but not a high-order solver. Results are timestep-dependent and must be converged before being used for comparisons.

Mass flow is accepted only as externally supplied model data. Consumption is capped by remaining propellant and total mass is not allowed below the configured dry mass. The current implementation does not model tank residuals, pressurization, pumps, combustion, or engine internal physics.

## Validity boundaries

This model is educational. It does not include attitude, angular dynamics, aerodynamic moments, centre of pressure, flexible-body dynamics, slosh, wind turbulence, parachutes, heating, CFD, FEA, or flight qualification. A single drag coefficient is not suitable across all Mach numbers and angles of attack. Do not use this model to make real-world flight safety decisions.
