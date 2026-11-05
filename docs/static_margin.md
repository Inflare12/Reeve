# Static-margin estimate

REEVE provides a static-margin arithmetic helper for user-supplied axial center-of-gravity (CG) and center-of-pressure (CP) locations measured from the nose toward the tail.

`static_margin_calibers = (CP - CG) / reference_diameter`

With this convention, positive margin means CP is aft of CG. The helper does not derive CG from component masses or CP from aerodynamic geometry and coefficient data. It does not calculate aerodynamic derivatives, damping, dynamic stability or control response. The result is only as credible as the externally supplied CG and CP values and their reference axes.
