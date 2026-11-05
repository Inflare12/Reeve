class_name ReeveWindModel
extends RefCounted
## Deterministic time-varying wind field for educational simulations.
## Gust inputs are user-supplied; this is not a meteorological turbulence model.

static func validate(configuration: Dictionary) -> String:
	var base_velocity: Vector3 = configuration.get("base_velocity_m_s", Vector3.ZERO)
	var gust_amplitude: Vector3 = configuration.get("gust_amplitude_m_s", Vector3.ZERO)
	var gust_frequency: Vector3 = configuration.get("gust_frequency_hz", Vector3.ZERO)
	var phase: Vector3 = configuration.get("phase_rad", Vector3.ZERO)
	if not base_velocity.is_finite() or not gust_amplitude.is_finite() or not gust_frequency.is_finite() or not phase.is_finite():
		return "Wind vectors must contain finite values."
	if gust_frequency.x < 0.0 or gust_frequency.y < 0.0 or gust_frequency.z < 0.0:
		return "Gust frequencies must be non-negative."
	return ""

static func sample(time_s: float, configuration: Dictionary) -> Dictionary:
	if not is_finite(time_s) or time_s < 0.0:
		return {"ok": false, "error": "Wind sample time must be finite and non-negative."}
	var error_message: String = validate(configuration)
	if not error_message.is_empty():
		return {"ok": false, "error": error_message}
	var base_velocity: Vector3 = configuration.get("base_velocity_m_s", Vector3.ZERO)
	var amplitude: Vector3 = configuration.get("gust_amplitude_m_s", Vector3.ZERO)
	var frequency: Vector3 = configuration.get("gust_frequency_hz", Vector3.ZERO)
	var phase: Vector3 = configuration.get("phase_rad", Vector3.ZERO)
	var gust := Vector3(
		amplitude.x * sin(TAU * frequency.x * time_s + phase.x),
		amplitude.y * sin(TAU * frequency.y * time_s + phase.y),
		amplitude.z * sin(TAU * frequency.z * time_s + phase.z)
	)
	return {"ok": true, "velocity_m_s": base_velocity + gust, "gust_velocity_m_s": gust}
