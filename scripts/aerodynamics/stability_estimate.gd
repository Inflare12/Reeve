class_name ReeveStabilityEstimate
extends RefCounted
## Static-margin arithmetic using user-supplied CG and CP locations.
## Does not predict either location or establish vehicle stability.

static func calculate_static_margin(
	center_of_gravity_from_nose_m: float,
	center_of_pressure_from_nose_m: float,
	body_reference_diameter_m: float
) -> Dictionary:
	if not is_finite(center_of_gravity_from_nose_m) or not is_finite(center_of_pressure_from_nose_m):
		return {"ok": false, "error": "CG and CP positions must be finite."}
	if not is_finite(body_reference_diameter_m) or body_reference_diameter_m <= 0.0:
		return {"ok": false, "error": "Reference diameter must be finite and positive."}
	var static_margin_m: float = center_of_pressure_from_nose_m - center_of_gravity_from_nose_m
	return {
		"ok": true,
		"center_of_gravity_from_nose_m": center_of_gravity_from_nose_m,
		"center_of_pressure_from_nose_m": center_of_pressure_from_nose_m,
		"static_margin_m": static_margin_m,
		"static_margin_calibers": static_margin_m / body_reference_diameter_m,
		"convention": "Positive margin means CP is aft of CG for coordinates measured from nose toward tail.",
		"warning": "CG and CP are user-supplied; this arithmetic does not calculate aerodynamic derivatives or prove dynamic stability."
	}
