class_name ReevePropulsionProfile
extends RefCounted
## Playback of externally supplied educational thrust/mass-flow curves.
## Does not design, size, construct or operate a propulsion system.

var profile_name: String = ""
var data_quality: String = ""
var source_description: String = ""
var points: Array[Dictionary] = []

func validate() -> String:
	if profile_name.strip_edges().is_empty():
		return "Profile name is required."
	if not ["measured", "supplied", "estimated", "synthetic_test"].has(data_quality):
		return "Data quality must be measured, supplied, estimated or synthetic_test."
	if source_description.strip_edges().is_empty():
		return "Source description is required."
	if points.size() < 2:
		return "At least two time-series points are required."
	var previous_time: float = -INF
	for point in points:
		if not point.has("time_s") or not point.has("thrust_n") or not point.has("mass_flow_kg_s"):
			return "Every point requires time_s, thrust_n and mass_flow_kg_s."
		var time_s: float = float(point.time_s)
		var thrust_n: float = float(point.thrust_n)
		var mass_flow: float = float(point.mass_flow_kg_s)
		if not is_finite(time_s) or not is_finite(thrust_n) or not is_finite(mass_flow):
			return "Curve values must be finite."
		if time_s < 0.0 or time_s <= previous_time or thrust_n < 0.0 or mass_flow < 0.0:
			return "Time must increase strictly; thrust and mass flow must be non-negative."
		previous_time = time_s
	return ""

func sample(time_s: float) -> Dictionary:
	var error_message := validate()
	if not error_message.is_empty():
		return {"ok": false, "error": error_message}
	if not is_finite(time_s) or time_s < 0.0:
		return {"ok": false, "error": "Sample time must be finite and non-negative."}
	if time_s < float(points[0].time_s):
		return {"ok": true, "thrust_n": 0.0, "mass_flow_kg_s": 0.0}
	if time_s >= float(points[points.size() - 1].time_s):
		return {"ok": true, "thrust_n": 0.0, "mass_flow_kg_s": 0.0}
	for index in range(points.size() - 1):
		var lower: Dictionary = points[index]
		var upper: Dictionary = points[index + 1]
		if time_s <= float(upper.time_s):
			var fraction: float = (time_s - float(lower.time_s)) / (float(upper.time_s) - float(lower.time_s))
			return {
				"ok": true,
				"thrust_n": lerpf(float(lower.thrust_n), float(upper.thrust_n), fraction),
				"mass_flow_kg_s": lerpf(float(lower.mass_flow_kg_s), float(upper.mass_flow_kg_s), fraction)
			}
	return {"ok": true, "thrust_n": 0.0, "mass_flow_kg_s": 0.0}

func total_impulse_ns() -> float:
	if not validate().is_empty():
		return -1.0
	var impulse: float = 0.0
	for index in range(points.size() - 1):
		var first: Dictionary = points[index]
		var second: Dictionary = points[index + 1]
		var interval: float = float(second.time_s) - float(first.time_s)
		impulse += 0.5 * (float(first.thrust_n) + float(second.thrust_n)) * interval
	return impulse

func integrated_propellant_mass_kg() -> float:
	if not validate().is_empty():
		return -1.0
	var mass: float = 0.0
	for index in range(points.size() - 1):
		var first: Dictionary = points[index]
		var second: Dictionary = points[index + 1]
		var interval: float = float(second.time_s) - float(first.time_s)
		mass += 0.5 * (float(first.mass_flow_kg_s) + float(second.mass_flow_kg_s)) * interval
	return mass

func load_json(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		return ERR_INVALID_DATA
	var loaded_points: Array[Dictionary] = []
	for point in parsed.get("points", []):
		if not point is Dictionary:
			return ERR_INVALID_DATA
		loaded_points.append(point)
	var old_name := profile_name
	var old_quality := data_quality
	var old_source := source_description
	var old_points := points
	profile_name = str(parsed.get("profile_name", ""))
	data_quality = str(parsed.get("data_quality", ""))
	source_description = str(parsed.get("source_description", ""))
	points = loaded_points
	if not validate().is_empty():
		profile_name = old_name
		data_quality = old_quality
		source_description = old_source
		points = old_points
		return ERR_INVALID_DATA
	return OK
