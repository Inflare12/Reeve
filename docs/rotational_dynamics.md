# Rotational rigid-body foundation

The translational state now carries a unit quaternion attitude, body angular velocity and body angular acceleration. The educational rotational update accepts a user-supplied diagonal inertia tensor in kg m^2 and an applied body-frame moment in N m.

The rigid-body equation used is:

`I * omega_dot = M - omega cross (I * omega)`

The implementation evaluates the gyroscopic term in body coordinates, advances angular velocity with the fixed simulation timestep, then updates attitude with a normalized quaternion increment. When `thrust_direction_body` is supplied, the direction is transformed into world coordinates using the current attitude.

## Explicit limitations

- The inertia tensor is diagonal and assumes the supplied axes are principal axes.
- An optional aerodynamic model can supply force and a CP-offset moment to the rotational update. Stability derivatives, damping/rate effects, fin geometry-derived coefficients, thrust misalignment moments and control-system response are not yet derived automatically.
- An optional attitude-coupled aerodynamic path derives a simplified angle of attack from the body longitudinal axis and relative airflow, then applies supplied Mach-dependent drag and supplied lift slope to the translational force balance. If the user also supplies a body-frame centre-of-pressure offset from the centre of mass, the resultant aerodynamic force is transformed into body coordinates and its lever-arm moment is applied to the rotational equation. This is a single supplied application point, not a calculated centre-of-pressure model. It remains simplified: no fin-resolved flow, damping derivatives, centre-of-pressure migration, dynamic stall or control-surface response are generated.
- This is a first rotational dynamics milestone, not a complete validated 6-DOF vehicle model.
- Users must supply defensible inertia and moment data; REEVE does not infer them from a visual mesh.

Quaternion normalization is applied after each attitude update. The regression suite checks angular acceleration, body-frame thrust rotation and unit quaternion magnitude.
