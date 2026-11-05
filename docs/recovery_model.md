# Educational recovery model

REEVE's recovery model applies a user-supplied parachute drag area after the vehicle descends to or below a configured deployment altitude. It is a simplified point-mass drag model, not a parachute design, packing, deployment reliability, opening-shock or recovery-system qualification tool.

Configuration fields:

- `deployment_altitude_m`: user-selected altitude threshold, metres.
- `canopy_area_m2`: user-supplied reference area, square metres.
- `drag_coefficient`: user-supplied coefficient, dimensionless.

The model uses the quadratic drag relation:

`F_D = 0.5 * rho * Cd * A * |v_rel|^2`

The drag vector opposes relative airflow. For the existing translational integrator, the parachute's `Cd*A` is added to the vehicle's supplied `Cd*A` product after deployment. This treats the combined drag areas as a first-order approximation and ignores canopy inflation transients, line dynamics, porosity, wake interaction, pendulum motion and structural opening loads.

The reported terminal descent speed is the steady vertical, still-air estimate:

`v_t = sqrt(2*m*g/(rho*Cd*A))`

It is not a prediction of actual landing speed in gusts or during deployment. The recovery model is available in the physics core but the current Flight Lab UI does not yet expose recovery configuration controls.
