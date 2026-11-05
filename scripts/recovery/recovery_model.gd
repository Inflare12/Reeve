class_name ReeveRecoveryModel
extends RefCounted
## Educational parachute descent model. Canopy parameters are user-supplied;
## this module does not size or certify a recovery system.

static func validate(configuration: Dictionary) -> String:
	var deployment_altitude_m: float = float(configuration.get("deployment_altitude_m", NAN))
	var canopy_area_m2: float = float(configuration.get("canopy_area_m2", NAN))
	var drag_coefficient: float = float(configuration.get("drag_coefficient", NAN))
	if not is_finite(deployment_altitude_m) or deployment_altitude_m < 0.0:
		return "Deployment altitude must be finite and non-negative."
	if not is_finite(canopy_area_m2) or canopy_area_m2 <= 0.0:
		return "Canopy reference area must be finite and positive."
	if not is_finite(drag_coefficient) or drag_coefficient <= 0.0:
		return "Canopy drag coefficient must be finite and positive."
	return ""

static func is_deployed(altitude_m: float, vertical_velocity_m_s: float, configuration: Dictionary) -> bool:
	if not validate(configuration).is_empty() or not is_finite(altitude_m) or not is_finite(vertical_velocity_m_s):
		return false
	# Deploy only after the vehicle has crossed the threshold while descending.
	return altitude_m <= float(configuration.deployment_altitude_m) and vertical_velocity_m_s < 0.0

static func calculate_acceleration(
	mass_kg: float,
	density_kg_m3: float,
	relative_air_velocity_m_s: Vector3,
	canopy_area_m2: float,
	drag_coefficient: float
) -> Dictionary:
	if not is_finite(mass_kg) or mass_kg <= 0.0 or not is_finite(density_kg_m3) or density_kg_m3 < 0.0 or not relative_air_velocity_m_s.is_finite() or not is_finite(canopy_area_m2) or canopy_area_m2 <= 0.0 or not is_finite(drag_coefficient) or drag_coefficient <= 0.0:
		return {"ok": false, "error": "Recovery model inputs must be finite and physically valid."}
	var speed_m_s: float = relative_air_velocity_m_s.length()
	var drag_force_n: Vector3 = Vector3.ZERO
	if speed_m_s > 0.000001:
		drag_force_n = -0.5 * density_kg_m3 * drag_coefficient * canopy_area_m2 * speed_m_s * relative_air_velocity_m_s
	var gravity_force_n: Vector3 = Vector3.DOWN * mass_kg * ReeveConstants.STANDARD_GRAVITY
	var acceleration_m_s2: Vector3 = (gravity_force_n + drag_force_n) / mass_kg
	var terminal_speed_m_s: float = sqrt(2.0 * mass_kg * ReeveConstants.STANDARD_GRAVITY / maxf(density_kg_m3 * drag_coefficient * canopy_area_m2, 0.000001))
	return {
		"ok": true,
		"drag_force_n": drag_force_n,
		"acceleration_m_s2": acceleration_m_s2,
		"terminal_descent_speed_m_s": terminal_speed_m_s,
		"relative_air_speed_m_s": speed_m_s
	}
