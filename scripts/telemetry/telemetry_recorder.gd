class_name ReeveTelemetryRecorder
extends RefCounted
## Stores measured simulation state; does not synthesize or interpolate samples.

var samples: Array[Dictionary] = []

func record(state: ReeveFlightState, atmosphere: Dictionary, thrust_n: float) -> void:
	var speed: float = state.velocity_m_s.length()
	var sound_speed: float = maxf(float(atmosphere.get("speed_of_sound_m_s", 0.0)), 0.001)
	samples.append({
		"time_s": state.time_s,
		"altitude_m": state.position_m.y,
		"position_x_m": state.position_m.x,
		"position_z_m": state.position_m.z,
		"velocity_m_s": speed,
		"vertical_velocity_m_s": state.velocity_m_s.y,
		"acceleration_m_s2": state.acceleration_m_s2.length(),
		"mass_kg": state.mass_kg,
		"propellant_remaining_kg": state.propellant_remaining_kg,
		"thrust_n": thrust_n,
		"mach": speed / sound_speed,
		"dynamic_pressure_pa": 0.5 * float(atmosphere.get("density_kg_m3", 0.0)) * speed * speed,
		"pressure_pa": float(atmosphere.get("pressure_pa", 0.0)),
		"density_kg_m3": float(atmosphere.get("density_kg_m3", 0.0)),
		"temperature_k": float(atmosphere.get("temperature_k", 0.0))
	})

func clear() -> void:
	samples.clear()

func export_csv(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var headers := [
		"time_s", "altitude_m", "position_x_m", "position_z_m",
		"velocity_m_s", "vertical_velocity_m_s", "acceleration_m_s2",
		"mass_kg", "propellant_remaining_kg", "thrust_n", "mach",
		"dynamic_pressure_pa", "pressure_pa", "density_kg_m3", "temperature_k"
	]
	file.store_line(",".join(headers))
	for sample in samples:
		var row: PackedStringArray = PackedStringArray()
		for header in headers:
			row.append(str(sample.get(header, "")))
		file.store_line(",".join(row))
	file.close()
	return OK
