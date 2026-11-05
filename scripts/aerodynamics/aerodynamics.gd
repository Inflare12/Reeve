class_name ReeveAerodynamics
extends RefCounted
## Educational external-flow force model.
## Requires a user-supplied drag coefficient curve and lift slope; no vehicle
## coefficients are fabricated by this module.

static func interpolate_drag_coefficient(mach: float, curve: Array[Dictionary]) -> Dictionary:
	if not is_finite(mach) or mach < 0.0 or curve.size() < 2:
		return {"ok": false, "error": "Mach must be non-negative and the supplied Cd curve needs at least two points."}
	var previous_mach: float = -1.0
	for point in curve:
		if not point.has("mach") or not point.has("cd"):
			return {"ok": false, "error": "Each Cd point must contain mach and cd."}
		var point_mach: float = float(point.mach)
		var point_cd: float = float(point.cd)
		if not is_finite(point_mach) or not is_finite(point_cd) or point_mach < 0.0 or point_cd < 0.0 or point_mach <= previous_mach:
			return {"ok": false, "error": "Cd curve Mach values must increase strictly and all values must be finite and non-negative."}
		previous_mach = point_mach

	if mach < float(curve[0].mach) or mach > float(curve[curve.size() - 1].mach):
		return {"ok": false, "error": "Mach is outside the supplied Cd curve; extrapolation is disabled."}

	for index in range(curve.size() - 1):
		var lower: Dictionary = curve[index]
		var upper: Dictionary = curve[index + 1]
		if mach <= float(upper.mach):
			var fraction: float = (mach - float(lower.mach)) / (float(upper.mach) - float(lower.mach))
			return {
				"ok": true,
				"cd": lerpf(float(lower.cd), float(upper.cd), fraction)
			}
	return {"ok": true, "cd": float(curve[curve.size() - 1].cd)}

static func calculate_flow_properties(
	relative_air_velocity_m_s: Vector3,
	density_kg_m3: float,
	dynamic_viscosity_pa_s: float,
	speed_of_sound_m_s: float,
	characteristic_length_m: float
) -> Dictionary:
	if not relative_air_velocity_m_s.is_finite() or not is_finite(density_kg_m3) or not is_finite(dynamic_viscosity_pa_s) or not is_finite(speed_of_sound_m_s) or not is_finite(characteristic_length_m) or density_kg_m3 < 0.0 or dynamic_viscosity_pa_s <= 0.0 or speed_of_sound_m_s <= 0.0 or characteristic_length_m <= 0.0:
		return {"ok": false, "error": "Density must be non-negative; viscosity, sound speed and length must be positive."}
	var speed: float = relative_air_velocity_m_s.length()
	return {
		"ok": true,
		"speed_m_s": speed,
		"mach": speed / speed_of_sound_m_s,
		"dynamic_pressure_pa": 0.5 * density_kg_m3 * speed * speed,
		"reynolds_number": density_kg_m3 * speed * characteristic_length_m / dynamic_viscosity_pa_s
	}

static func calculate_forces(
	relative_air_velocity_m_s: Vector3,
	density_kg_m3: float,
	dynamic_viscosity_pa_s: float,
	speed_of_sound_m_s: float,
	reference_area_m2: float,
	characteristic_length_m: float,
	drag_curve: Array[Dictionary],
	angle_of_attack_rad: float = 0.0,
	lift_slope_per_rad: float = 0.0,
	lift_direction: Vector3 = Vector3.ZERO
) -> Dictionary:
	if reference_area_m2 < 0.0 or not is_finite(reference_area_m2) or not is_finite(angle_of_attack_rad) or not is_finite(lift_slope_per_rad):
		return {"ok": false, "error": "Reference area and aerodynamic inputs must be finite and non-negative where applicable."}
	var flow := calculate_flow_properties(
		relative_air_velocity_m_s, density_kg_m3, dynamic_viscosity_pa_s,
		speed_of_sound_m_s, characteristic_length_m
	)
	if not bool(flow.ok):
		return flow
	var coefficient := interpolate_drag_coefficient(float(flow.mach), drag_curve)
	if not bool(coefficient.ok):
		return coefficient

	var speed: float = float(flow.speed_m_s)
	var dynamic_pressure: float = float(flow.dynamic_pressure_pa)
	var drag_force := Vector3.ZERO
	var lift_force := Vector3.ZERO
	if speed > 0.000001:
		var flow_direction: Vector3 = relative_air_velocity_m_s / speed
		drag_force = -flow_direction * dynamic_pressure * float(coefficient.cd) * reference_area_m2
		if absf(lift_slope_per_rad) > 0.0 and absf(angle_of_attack_rad) > 0.0:
			var perpendicular_lift: Vector3 = lift_direction - flow_direction * lift_direction.dot(flow_direction)
			if perpendicular_lift.length_squared() < 0.000001:
				return {"ok": false, "error": "A non-zero lift direction perpendicular to airflow is required when lift is enabled."}
			var lift_coefficient: float = lift_slope_per_rad * angle_of_attack_rad
			lift_force = perpendicular_lift.normalized() * dynamic_pressure * lift_coefficient * reference_area_m2

	return {
		"ok": true,
		"mach": flow.mach,
		"dynamic_pressure_pa": dynamic_pressure,
		"reynolds_number": flow.reynolds_number,
		"drag_coefficient": coefficient.cd,
		"drag_force_n": drag_force,
		"lift_force_n": lift_force,
		"total_aerodynamic_force_n": drag_force + lift_force
	}
