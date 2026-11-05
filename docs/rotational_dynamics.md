# Rotational rigid-body foundation

The translational state now carries a unit quaternion attitude, body angular velocity and body angular acceleration. The educational rotational update accepts a user-supplied diagonal inertia tensor in kg m^2 and an applied body-frame moment in N m.

The rigid-body equation used is:

`I * omega_dot = M - omega cross (I * omega)`

The implementation evaluates the gyroscopic term in body coordinates, advances angular velocity with the fixed simulation timestep, then updates attitude with a normalized quaternion increment. When `thrust_direction_body` is supplied, the direction is transformed into world coordinates using the current attitude.

## Explicit limitations

- The inertia tensor is diagonal and assumes the supplied axes are principal axes.
- The moment is externally supplied; aerodynamic stability derivatives, fin moments, thrust misalignment moments and control-system response are not yet derived automatically.
- The translational aerodynamic model remains a point-mass drag/lift approximation and is not yet fully coupled to body attitude and vehicle geometry.
- This is a first rotational dynamics milestone, not a complete validated 6-DOF vehicle model.
- Users must supply defensible inertia and moment data; REEVE does not infer them from a visual mesh.

Quaternion normalization is applied after each attitude update. The regression suite checks angular acceleration, body-frame thrust rotation and unit quaternion magnitude.
