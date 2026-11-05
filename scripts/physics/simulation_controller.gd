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
	telemetry.record_event("simulation_start", state)
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
		if not step_once():
			running = false
			break
		accumulator_s -= fixed_dt_s
		steps += 1
		if ground_contact:
			break
	return steps

func step_once() -> bool:
	if state == null or not state.is_valid() or ground_contact:
		return false
	var step_wind_velocity_m_s: Vector3 = wind_velocity_m_s
	if model.has("wind_model"):
		var wind_sample: Dictionary = ReeveWindModel.sample(state.time_s, model.wind_model)
		if not bool(wind_sample.get("ok", false)):
			last_error = "Wind model sample failed: %s" % str(wind_sample.get("error", "unknown error"))
			return false
		step_wind_velocity_m_s = wind_sample.velocity_m_s
	var previous_vertical_velocity_m_s: float = state.velocity_m_s.y
	var previous_thrust_n: float = state.applied_thrust_n
	var recovery_configuration: Dictionary = model.get("recovery", {})
	var recovery_was_deployed: bool = not recovery_configuration.is_empty() and ReeveRecoveryModel.is_deployed(state.position_m.y, state.velocity_m_s.y, recovery_configuration)
	if not ReeveFlightIntegrator.step(state, fixed_dt_s, model, step_wind_velocity_m_s):
		last_error = "Physics step rejected invalid state or timestep."
		return false
	if previous_thrust_n <= 0.0 and state.applied_thrust_n > 0.0:
		telemetry.record_event("powered_flight_start", state, {"thrust_n": state.applied_thrust_n})
	elif previous_thrust_n > 0.0 and state.applied_thrust_n <= 0.0:
		telemetry.record_event("engine_cutoff", state)
	if previous_vertical_velocity_m_s > 0.0 and state.velocity_m_s.y <= 0.0:
		telemetry.record_event("apogee", state)
		telemetry.record_event("descent_start", state)
	var recovery_is_deployed: bool = not recovery_configuration.is_empty() and ReeveRecoveryModel.is_deployed(state.position_m.y, state.velocity_m_s.y, recovery_configuration)
	if not recovery_was_deployed and recovery_is_deployed:
		telemetry.record_event("recovery_deployment", state, recovery_configuration)
	var ground_altitude_m: float = float(model.get("ground_altitude_m", -INF))
	if state.position_m.y <= ground_altitude_m:
		var impact_velocity_m_s: Vector3 = state.velocity_m_s
		state.position_m.y = ground_altitude_m
		state.velocity_m_s = Vector3.ZERO
		state.acceleration_m_s2 = Vector3.ZERO
		ground_contact = true
		running = false
		telemetry.record_event("ground_contact", state, {
			"impact_velocity_m_s": [impact_velocity_m_s.x, impact_velocity_m_s.y, impact_velocity_m_s.z],
			"impact_speed_m_s": impact_velocity_m_s.length()
		})
	var atmosphere_conditions: Dictionary = model.get("atmosphere_conditions", {})
	var atmosphere := ReeveAtmosphere.sample(state.position_m.y, atmosphere_conditions)
	if not bool(atmosphere.get("ok", false)):
		last_error = "Telemetry atmosphere sample is outside the supported model domain."
		return false
	telemetry.record(state, atmosphere, state.applied_thrust_n, step_wind_velocity_m_s)
	return true

func pause() -> void:
	running = false

func resume() -> void:
	if state != null and state.is_valid() and not ground_contact and last_error.is_empty():
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
	var atmosphere_configuration: Variant = supplied_model.get("atmosphere_conditions", {})
	if not atmosphere_configuration is Dictionary:
		return "Atmosphere conditions must be a Dictionary."
	var temperature_offset: float = float(atmosphere_configuration.get("temperature_offset_k", 0.0))
	var pressure_scale: float = float(atmosphere_configuration.get("pressure_scale", 1.0))
	if not is_finite(temperature_offset) or not is_finite(pressure_scale) or pressure_scale <= 0.0:
		return "Atmosphere temperature offset must be finite and pressure scale finite and positive."
	var wind_configuration: Variant = supplied_model.get("wind_model", {})
	if not wind_configuration is Dictionary:
		return "Wind model configuration must be a Dictionary."
	if not wind_configuration.is_empty():
		var wind_error: String = ReeveWindModel.validate(wind_configuration)
		if not wind_error.is_empty():
			return "Invalid wind model: %s" % wind_error
	if supplied_model.has("aerodynamic_model"):
		var aerodynamic_configuration: Variant = supplied_model.get("aerodynamic_model")
		if not aerodynamic_configuration is Dictionary:
			return "Aerodynamic model must be a Dictionary."
		var raw_curve: Variant = aerodynamic_configuration.get("drag_curve", [])
		if not raw_curve is Array:
			return "Aerodynamic drag curve must be an Array."
		var drag_curve: Array[Dictionary] = []
		for point in raw_curve:
			if not point is Dictionary:
				return "Every aerodynamic drag-curve point must be a Dictionary."
			drag_curve.append(point)
		if drag_curve.size() < 2:
			return "Aerodynamic drag curve requires at least two supplied points."
		var curve_check := ReeveAerodynamics.interpolate_drag_coefficient(float(drag_curve[0].get("mach", -1.0)), drag_curve)
		if not bool(curve_check.get("ok", false)):
			return "Invalid aerodynamic drag curve: %s" % str(curve_check.get("error", "unknown error"))
		for key in ["reference_area_m2", "characteristic_length_m", "lift_slope_per_rad"]:
			var value: float = float(aerodynamic_configuration.get(key, 0.0))
			if not is_finite(value):
				return "Aerodynamic %s must be finite." % key
		if float(aerodynamic_configuration.get("reference_area_m2", 0.0)) <= 0.0 or float(aerodynamic_configuration.get("characteristic_length_m", 0.0)) <= 0.0:
			return "Aerodynamic reference area and characteristic length must be positive."
		var cp_offset: Vector3 = aerodynamic_configuration.get("center_of_pressure_offset_body_m", Vector3.ZERO)
		if not cp_offset.is_finite():
			return "Aerodynamic center-of-pressure offset must contain finite values."
	var recovery_configuration: Variant = supplied_model.get("recovery", {})
	if not recovery_configuration is Dictionary:
		return "Recovery configuration must be a Dictionary."
	if not recovery_configuration.is_empty():
		var recovery_error: String = ReeveRecoveryModel.validate(recovery_configuration)
		if not recovery_error.is_empty():
			return "Invalid recovery configuration: %s" % recovery_error
	var direction: Vector3 = supplied_model.get("thrust_direction", Vector3.UP)
	if not direction.is_finite():
		return "Thrust direction must contain finite values."
	var body_direction: Vector3 = supplied_model.get("thrust_direction_body", Vector3.UP)
	if not body_direction.is_finite():
		return "Body-frame thrust direction must contain finite values."
	var inertia: Vector3 = supplied_model.get("inertia_diagonal_kg_m2", Vector3.ZERO)
	var moment: Vector3 = supplied_model.get("body_moment_nm", Vector3.ZERO)
	if not inertia.is_finite() or not moment.is_finite():
		return "Inertia and applied body moment must contain finite values."
	if moment.length_squared() > 0.0 or inertia.length_squared() > 0.0 or initial_state.angular_velocity_rad_s.length_squared() > 0.0:
		if inertia.x <= 0.0 or inertia.y <= 0.0 or inertia.z <= 0.0:
			return "Positive diagonal inertia values are required for rotational dynamics."
	if supplied_model.has("ground_altitude_m"):
		var ground_altitude: float = float(supplied_model.ground_altitude_m)
		if not is_finite(ground_altitude):
			return "Ground altitude must be finite."
	return ""
