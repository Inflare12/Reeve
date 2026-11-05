class_name ReeveTelemetryRecorder
extends RefCounted
## Stores measured simulation state; does not synthesize or interpolate samples.

var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []

func record_event(event_name: String, state: ReeveFlightState, details: Dictionary = {}) -> void:
	if event_name.strip_edges().is_empty() or state == null or not state.is_valid():
		return
	events.append({
		"event": event_name,
		"time_s": state.time_s,
		"altitude_m": state.position_m.y,
		"vertical_velocity_m_s": state.velocity_m_s.y,
		"mass_kg": state.mass_kg,
		"details": details.duplicate(true)
	})

func record(
	state: ReeveFlightState,
	atmosphere: Dictionary,
	thrust_n: float,
	wind_velocity_m_s: Vector3 = Vector3.ZERO
) -> void:
	var relative_air_velocity_m_s: Vector3 = state.velocity_m_s - wind_velocity_m_s
	var air_speed_m_s: float = relative_air_velocity_m_s.length()
	var horizontal_speed_m_s: float = Vector2(state.velocity_m_s.x, state.velocity_m_s.z).length()
	var sound_speed: float = maxf(float(atmosphere.get("speed_of_sound_m_s", 0.0)), 0.001)
	samples.append({
		"time_s": state.time_s,
		"altitude_m": state.position_m.y,
		"position_x_m": state.position_m.x,
		"position_z_m": state.position_m.z,
		"velocity_m_s": state.velocity_m_s.length(),
		"horizontal_velocity_m_s": horizontal_speed_m_s,
		"vertical_velocity_m_s": state.velocity_m_s.y,
		"relative_air_speed_m_s": air_speed_m_s,
		"wind_speed_m_s": wind_velocity_m_s.length(),
		"acceleration_m_s2": state.acceleration_m_s2.length(),
		"acceleration_x_m_s2": state.acceleration_m_s2.x,
		"acceleration_y_m_s2": state.acceleration_m_s2.y,
		"acceleration_z_m_s2": state.acceleration_m_s2.z,
		"mass_kg": state.mass_kg,
		"propellant_remaining_kg": state.propellant_remaining_kg,
		"thrust_n": thrust_n,
		"mach": air_speed_m_s / sound_speed,
		"dynamic_pressure_pa": 0.5 * float(atmosphere.get("density_kg_m3", 0.0)) * air_speed_m_s * air_speed_m_s,
		"pressure_pa": float(atmosphere.get("pressure_pa", 0.0)),
		"density_kg_m3": float(atmosphere.get("density_kg_m3", 0.0)),
		"temperature_k": float(atmosphere.get("temperature_k", 0.0))
	})

func clear() -> void:
	samples.clear()
	events.clear()

func export_csv(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var headers := [
		"time_s", "altitude_m", "position_x_m", "position_z_m",
		"velocity_m_s", "horizontal_velocity_m_s", "vertical_velocity_m_s",
		"relative_air_speed_m_s", "wind_speed_m_s", "acceleration_m_s2",
		"acceleration_x_m_s2", "acceleration_y_m_s2", "acceleration_z_m_s2",
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

func export_json(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var payload := {
		"schema_version": 1,
		"units": {
			"time": "s",
			"position": "m",
			"velocity": "m/s",
			"horizontal_velocity": "m/s",
			"relative_air_speed": "m/s",
			"wind_speed": "m/s",
			"acceleration": "m/s^2",
			"mass": "kg",
			"thrust": "N",
			"pressure": "Pa",
			"density": "kg/m^3",
			"temperature": "K"
		},
		"samples": samples,
		"events": events
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return OK
