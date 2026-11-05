# Lumped-capacitance thermal estimate

The optional thermal estimate models a uniform-temperature component exchanging heat by convection with a constant-temperature environment.

It uses the lumped energy balance:

`T(t) = T_inf + (T_initial - T_inf) * exp(-t/tau)`

where:

`tau = m * cp / (h * A)`

The model computes the Biot number:

`Bi = h * Lc / k`

and rejects the lumped approximation when `Bi >= 0.1`. Mass, exposed area, characteristic length, convection coefficient, ambient temperature, initial temperature and elapsed time are user-supplied. Material specific heat and conductivity are read from the nominal material catalogue.

This is not an aerodynamic heating model, heat-shield analysis, radiation model, combustion-chamber thermal model or material temperature qualification. It assumes constant material properties, constant convection coefficient, uniform component temperature, no internal heat generation and no radiative exchange. The user must justify the supplied convection coefficient and characteristic length.
