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
	state = initial_state.duplicate_state()
	model = supplied_model.duplicate(true)
	wind_velocity_m_s = wind_m_s
	fixed_dt_s = step_s
	accumulator_s = 0.0
	telemetry.clear()
	running = true
	ground_contact = false
	last_error = ""
	ground_contact = false
	return true

func advance_frame(frame_delta_s: float, time_scale: float = 1.0) -> int:
	if not running or state == null:
		return 0
	if frame_delta_s < 0.0 or not is_finite(frame_delta_s) or time_scale < 0.0:
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
