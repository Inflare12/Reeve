class_name ReeveSimulationController
extends RefCounted
## Fixed-step simulation coordinator. Rendering frame time never changes physics dt.

var state: ReeveFlightState
var model: Dictionary = {}
var wind_velocity_m_s: Vector3 = Vector3.ZERO
var telemetry := ReeveTelemetryRecorder.new()
var fixed_dt_s: float = 1.0 / 120.0
var max_substeps_per_frame: int = 8
var accumulator_s: float = 0.0
var running: bool = false
var last_error: String = ""
var ground_contact: bool = false

func configure(
	initial_state: ReeveFlightState,
	supplied_model: Dictionary,
	wind_m_s: Vector3 = Vector3.ZERO,
	step_s: float = 1.0 / 120.0
) -> bool:
	if initial_state == null or not initial_state.is_valid():
		last_error = "Initial flight state is invalid."
		return false
	if step_s <= 0.0 or step_s > 0.1 or not is_finite(step_s):
		last_error = "Fixed timestep must be in the interval (0, 0.1] seconds."
		return false
	if not wind_m_s.is_finite():
		last_error = "Wind velocity must contain finite SI values."
		return false
	var model_error: String = _validate_model(initial_state, supplied_model)
	if not model_error.is_empty():
		last_error = model_error
		return false
	var supplied_profile: Variant = supplied_model.get("propulsion_profile", null)
	if supplied_profile != null:
		if not supplied_profile is ReevePropulsionProfile:
			last_error = "propulsion_profile must be a validated ReevePropulsionProfile object."
			return false
		var profile_error: String = supplied_profile.validate()
		if not profile_error.is_empty():
			last_error = "Invalid propulsion profile: %s" % profile_error
			return false
	state = initial_state.duplicate_state()
	model = supplied_model.duplicate(true)
	wind_velocity_m_s = wind_m_s
	fixed_dt_s = step_s
	accumulator_s = 0.0
	telemetry.clear()
	running = true
	ground_contact = false
	last_error = ""
	return true

func advance_frame(frame_delta_s: float, time_scale: float = 1.0) -> int:
	if not running or state == null:
		return 0
	if frame_delta_s < 0.0 or not is_finite(frame_delta_s) or time_scale < 0.0 or not is_finite(time_scale):
		last_error = "Frame delta and time scale must be finite and non-negative."
		running = false
		return 0

	accumulator_s += minf(frame_delta_s * time_scale, fixed_dt_s * float(max_substeps_per_frame))
	var steps: int = 0
	while accumulator_s >= fixed_dt_s and steps < max_substeps_per_frame:
		if not ReeveFlightIntegrator.step(state, fixed_dt_s, model, wind_velocity_m_s):
			last_error = "Physics step rejected invalid state or timestep."
			running = false
			break
		var ground_altitude_m: float = float(model.get("ground_altitude_m", -INF))
		if state.position_m.y <= ground_altitude_m:
			state.position_m.y = ground_altitude_m
			state.velocity_m_s = Vector3.ZERO
			state.acceleration_m_s2 = Vector3.ZERO
			ground_contact = true
			running = false
		var atmosphere := ReeveAtmosphere.sample(state.position_m.y)
		telemetry.record(state, atmosphere, state.applied_thrust_n)
		accumulator_s -= fixed_dt_s
		steps += 1
		if ground_contact:
			break
	return steps

func pause() -> void:
	running = false

func resume() -> void:
	if state != null and state.is_valid():
		running = true

func reset() -> void:
	running = false
	state = null
	accumulator_s = 0.0
	telemetry.clear()
	last_error = ""
	ground_contact = false

func _validate_model(initial_state: ReeveFlightState, supplied_model: Dictionary) -> String:
	var dry_mass_kg: float = float(supplied_model.get("dry_mass_kg", 0.001))
	if not is_finite(dry_mass_kg) or dry_mass_kg <= 0.0 or dry_mass_kg > initial_state.mass_kg:
		return "Dry mass must be finite, positive and no greater than initial vehicle mass."
	if initial_state.propellant_remaining_kg > initial_state.mass_kg - dry_mass_kg + 0.000001:
		return "Initial propellant mass cannot exceed vehicle mass minus dry mass."
	for key in ["thrust_n", "mass_flow_kg_s", "drag_coefficient", "reference_area_m2"]:
		if supplied_model.has(key):
			var value: float = float(supplied_model[key])
			if not is_finite(value) or value < 0.0:
				return "%s must be finite and non-negative." % key
	var direction: Vector3 = supplied_model.get("thrust_direction", Vector3.UP)
	if not direction.is_finite():
		return "Thrust direction must contain finite values."
	if supplied_model.has("ground_altitude_m"):
		var ground_altitude: float = float(supplied_model.ground_altitude_m)
		if not is_finite(ground_altitude):
			return "Ground altitude must be finite."
	return ""
