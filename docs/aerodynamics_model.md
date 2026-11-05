# Aerodynamics module — supplied coefficient data

## Implemented equations

For relative-air velocity vector v_rel and speed V:

- Mach: M = V / a
- Dynamic pressure: q = 0.5 rho V²
- Reynolds number: Re = rho V L / mu
- Drag vector: F_D = -q C_D(M) A v_hat
- Educational linear lift coefficient: C_L = a_L alpha
- Lift vector: F_L = q C_L A l_hat

The drag coefficient is linearly interpolated from a user-supplied table of (Mach, Cd) pairs. Mach coordinates must be strictly increasing. Extrapolation outside the supplied table is rejected rather than guessed. Lift slope is also supplied by the user; no generic vehicle coefficient is silently assumed.

The atmosphere module estimates dynamic viscosity with Sutherland's law for dry air:
mu = mu_ref (T/T_ref)^(3/2) (T_ref + S)/(T + S)
using mu_ref = 1.716e-5 Pa s, T_ref = 273.15 K and S = 110.4 K.

## Limitations

This is a coefficient-driven educational model, not CFD. It does not derive aerodynamic coefficients from geometry, model shock waves, calculate boundary-layer transition, predict separation, model fin/body interference, or determine stability derivatives. The linear lift model is valid only as an explicitly supplied local approximation. Coefficient data must be independently sourced and its applicable Mach/angle-of-attack range documented before interpreting results.
