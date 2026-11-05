extends Node3D

@onready var status_label: Label = $CanvasLayer/Panel/Info/Status
@onready var scope_label: Label = $CanvasLayer/Panel/Info/Scope
@onready var camera: Camera3D = $Camera3D

var simulation := ReeveSimulationController.new()
var time_scale: float = 1.0
var run_button: Button
var time_scale_label: Label
var telemetry_plots: Array[ReeveTelemetryPlot] = []
var wind_x_input: SpinBox
var wind_z_input: SpinBox
var temperature_offset_input: SpinBox
var pressure_scale_input: SpinBox
var workshop_configuration: ReeveRocketConfiguration
var camera_mode_selector: OptionButton
var camera_mode: int = 0

func _ready() -> void:
	_build_flight_environment()
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	status_label.text = "READY — no propulsion profile loaded. No flight has been simulated."

	wind_x_input = _add_environment_spinbox("Wind X velocity (m/s)", -100.0, 100.0, 0.0, 0.5)
	wind_x_input.name = "WindXInput"
	wind_z_input = _add_environment_spinbox("Wind Z velocity (m/s)", -100.0, 100.0, 0.0, 0.5)
	wind_z_input.name = "WindZInput"
	temperature_offset_input = _add_environment_spinbox("Temperature offset (K)", -50.0, 50.0, 0.0, 1.0)
	temperature_offset_input.name = "TemperatureOffsetInput"
	pressure_scale_input = _add_environment_spinbox("Pressure scale", 0.5, 1.5, 1.0, 0.01)
	pressure_scale_input.name = "PressureScaleInput"
	camera_mode_selector = OptionButton.new()
	camera_mode_selector.name = "CameraModeSelector"
	for camera_mode_name in ["External Chase", "Side Observation", "Ground Observation", "Rocket Follow", "Free Camera", "Engineering Inspection"]:
		camera_mode_selector.add_item(camera_mode_name)
	camera_mode_selector.select(0)
	camera_mode_selector.item_selected.connect(_on_camera_mode_selected)
	$CanvasLayer/Panel/Info.add_child(camera_mode_selector)

	var gravity_button := Button.new()
	gravity_button.name = "GravityDropButton"
	gravity_button.text = "Run Gravity-Only Drop Test"
	gravity_button.pressed.connect(_start_gravity_drop)
	$CanvasLayer/Panel/Info.add_child(gravity_button)

	var load_workshop_button := Button.new()
	load_workshop_button.name = "LoadWorkshopVehicleButton"
	load_workshop_button.text = "Load Workshop Vehicle"
	load_workshop_button.pressed.connect(_load_workshop_vehicle)
	$CanvasLayer/Panel/Info.add_child(load_workshop_button)

	var reset_button := Button.new()
	reset_button.name = "ResetDemoButton"
	reset_button.text = "Reset Demonstration"
	reset_button.pressed.connect(_reset_demonstration)
	$CanvasLayer/Panel/Info.add_child(reset_button)

	var pause_button := Button.new()
	pause_button.name = "PauseResumeButton"
	pause_button.text = "Pause / Resume"
	pause_button.pressed.connect(_toggle_pause)
	$CanvasLayer/Panel/Info.add_child(pause_button)

	var step_button := Button.new()
	step_button.name = "SingleStepButton"
	step_button.text = "Advance One Physics Step"
	step_button.pressed.connect(_single_step)
	$CanvasLayer/Panel/Info.add_child(step_button)

	time_scale_label = Label.new()
	time_scale_label.name = "TimeScaleLabel"
	$CanvasLayer/Panel/Info.add_child(time_scale_label)
	_update_time_scale_label()
	_build_telemetry_dashboard()

	var slower_button := Button.new()
	slower_button.name = "SlowerButton"
	slower_button.text = "0.5x Simulation Time"
	slower_button.pressed.connect(func() -> void:
		time_scale = maxf(0.125, time_scale * 0.5)
		_update_time_scale_label()
	)
	$CanvasLayer/Panel/Info.add_child(slower_button)

	var faster_button := Button.new()
	faster_button.name = "FasterButton"
	faster_button.text = "2x Simulation Time"
	faster_button.pressed.connect(func() -> void:
		time_scale = minf(8.0, time_scale * 2.0)
		_update_time_scale_label()
	)
	$CanvasLayer/Panel/Info.add_child(faster_button)

	var export_csv_button := Button.new()
	export_csv_button.name = "ExportCsvButton"
	export_csv_button.text = "Export Telemetry CSV"
	export_csv_button.pressed.connect(_export_csv)
	$CanvasLayer/Panel/Info.add_child(export_csv_button)

	var export_json_button := Button.new()
	export_json_button.name = "ExportJsonButton"
	export_json_button.text = "Export Telemetry JSON"
	export_json_button.pressed.connect(_export_json)
	$CanvasLayer/Panel/Info.add_child(export_json_button)

	var workshop_button := Button.new()
	workshop_button.name = "WorkshopButton"
	workshop_button.text = "Open Rocket Workshop"
	workshop_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/workshop/workshop.tscn")
	)
	$CanvasLayer/Panel/Info.add_child(workshop_button)

func _process(delta: float) -> void:
	if not simulation.running:
		return
	simulation.advance_frame(delta, time_scale)
	_update_flight_display()
	if simulation.ground_contact:
		status_label.text = "GROUND CONTACT — demonstration complete"
	elif not simulation.last_error.is_empty():
		status_label.text = "SIMULATION ERROR — %s" % simulation.last_error

func _build_flight_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "FlightWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.36, 0.52, 0.69)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.86)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var ground := MeshInstance3D.new()
	ground.name = "GroundPlane"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(300.0, 300.0)
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, -0.15, 0.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.19, 0.25, 0.21)
	ground_material.roughness = 0.95
	ground.material_override = ground_material
	add_child(ground)

	var launch_pad := MeshInstance3D.new()
	launch_pad.name = "LaunchPad"
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.0
	pad_mesh.bottom_radius = 2.0
	pad_mesh.height = 0.14
	pad_mesh.radial_segments = 32
	launch_pad.mesh = pad_mesh
	launch_pad.position = Vector3(0.0, -0.07, 0.0)
	var pad_material := StandardMaterial3D.new()
	pad_material.albedo_color = Color(0.24, 0.27, 0.31)
	pad_material.metallic = 0.35
	pad_material.roughness = 0.7
	launch_pad.material_override = pad_material
	add_child(launch_pad)

func _add_environment_spinbox(label_text: String, minimum: float, maximum: float, initial: float, step: float) -> SpinBox:
	var container := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	container.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = initial
	spin.step = step
	spin.rounded = false
	container.add_child(spin)
	$CanvasLayer/Panel/Info.add_child(container)
	return spin

func _load_workshop_vehicle() -> void:
	var loaded := ReeveRocketConfiguration.new()
	var load_error: Error = loaded.load_from_file("user://reeve_vehicle.json")
	if load_error != OK:
		status_label.text = "Workshop vehicle load failed: %s" % error_string(load_error)
		return
	var handoff: Dictionary = loaded.get_flight_handoff()
	if not bool(handoff.get("ok", false)):
		status_label.text = "Workshop handoff rejected: %s" % str(handoff.get("error", "unknown error"))
		return
	workshop_configuration = loaded
	status_label.text = "LOADED — %s | %.3f kg | frontal area %.4f m². Cd and propulsion remain unspecified." % [
		str(handoff.vehicle_name),
		float(handoff.total_mass_kg),
		float(handoff.frontal_reference_area_m2)
	]

func _on_camera_mode_selected(index: int) -> void:
	camera_mode = clampi(index, 0, 5)
	if simulation.state != null:
		_update_flight_display()

func _update_camera_for_state(target_position: Vector3) -> void:
	match camera_mode:
		0:
			camera.position = target_position + Vector3(10.0, 6.0, 13.0)
		1:
			camera.position = target_position + Vector3(0.0, 5.0, 24.0)
		2:
			camera.position = Vector3(22.0, 5.0, 22.0)
		3:
			camera.position = target_position + Vector3(0.0, 2.5, 7.0)
		4:
			return
		5:
			camera.position = target_position + Vector3(2.5, 1.5, 5.0)
	camera.look_at(target_position + Vector3.UP * 2.0, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if camera_mode != 4 or not event is InputEventKey or not event.pressed or event.echo:
		return
	var movement := Vector3.ZERO
	match event.keycode:
		KEY_W:
			movement.z -= 1.0
		KEY_S:
			movement.z += 1.0
		KEY_A:
			movement.x -= 1.0
		KEY_D:
			movement.x += 1.0
		KEY_Q:
			movement.y -= 1.0
		KEY_E:
			movement.y += 1.0
		_:
			return
	var move_scale: float = 5.0 if event.shift_pressed else 1.0
	camera.translate_object_local(movement.normalized() * move_scale)

func _toggle_pause() -> void:
	if simulation.state == null:
		status_label.text = "Start a demonstration before pausing."
	elif simulation.running:
		simulation.pause()
		status_label.text = "PAUSED — simulation state preserved"
	else:
		simulation.resume()
		status_label.text = "RUNNING — simulation resumed"

func _single_step() -> void:
	if simulation.state == null:
		status_label.text = "Start a demonstration before stepping."
		return
	simulation.pause()
	if simulation.step_once():
		status_label.text = "PAUSED — advanced exactly one %.6f s physics step" % simulation.fixed_dt_s
		_update_flight_display()
	else:
		status_label.text = "STEP FAILED — %s" % simulation.last_error

func _update_time_scale_label() -> void:
	if time_scale_label != null:
		time_scale_label.text = "Simulation time scale: %.3fx" % time_scale

func _export_csv() -> void:
	if simulation.telemetry.samples.is_empty():
		status_label.text = "No telemetry samples to export."
		return
	var result: Error = simulation.telemetry.export_csv("user://reeve_telemetry.csv")
	status_label.text = "CSV exported to user://reeve_telemetry.csv" if result == OK else "CSV export failed: %s" % error_string(result)

func _export_json() -> void:
	if simulation.telemetry.samples.is_empty():
		status_label.text = "No telemetry samples to export."
		return
	var result: Error = simulation.telemetry.export_json("user://reeve_telemetry.json")
	status_label.text = "JSON exported to user://reeve_telemetry.json" if result == OK else "JSON export failed: %s" % error_string(result)

func _start_gravity_drop() -> void:
	var initial_mass_kg: float = 25.0
	var reference_area_m2: float = PI * 0.28 * 0.28
	var drag_coefficient: float = 0.5
	if workshop_configuration != null:
		var handoff: Dictionary = workshop_configuration.get_flight_handoff()
		if not bool(handoff.get("ok", false)):
			status_label.text = "Workshop handoff became invalid: %s" % str(handoff.get("error", "unknown error"))
			return
		initial_mass_kg = float(handoff.total_mass_kg)
		reference_area_m2 = float(handoff.frontal_reference_area_m2)
		# Unknown vehicle Cd must not be fabricated; use a drag-free mass-transfer test.
		drag_coefficient = 0.0
	var initial_state := ReeveFlightState.new()
	initial_state.position_m = Vector3(0.0, 20.0, 0.0)
	initial_state.mass_kg = initial_mass_kg
	initial_state.propellant_remaining_kg = 0.0
	var model := {
		"thrust_n": 0.0,
		"mass_flow_kg_s": 0.0,
		"dry_mass_kg": initial_mass_kg,
		"drag_coefficient": drag_coefficient,
		"reference_area_m2": reference_area_m2,
		"ground_altitude_m": 0.0,
		"atmosphere_conditions": {
			"temperature_offset_k": temperature_offset_input.value,
			"pressure_scale": pressure_scale_input.value
		}
	}
	var wind_velocity_m_s := Vector3(wind_x_input.value, 0.0, wind_z_input.value)
	if not simulation.configure(initial_state, model, wind_velocity_m_s):
		status_label.text = "Could not start test: %s" % simulation.last_error
		return
	status_label.text = "RUNNING — gravity-only drop test" if workshop_configuration == null else "RUNNING — workshop mass-transfer check; drag disabled because Cd is unknown"
	_update_flight_display()

func _reset_demonstration() -> void:
	simulation.reset()
	$RocketVisual.position = Vector3.ZERO
	camera_mode = 0
	if camera_mode_selector != null:
		camera_mode_selector.select(0)
	_update_camera_for_state(Vector3.ZERO)
	status_label.text = "READY — no propulsion profile loaded. No flight has been simulated."
	scope_label.text = "3-DOF point-mass physics foundation"
	_update_telemetry_plots()

func _update_flight_display() -> void:
	if simulation.state == null:
		return
	var state := simulation.state
	var atmosphere_conditions: Dictionary = simulation.model.get("atmosphere_conditions", {})
	var atmosphere := ReeveAtmosphere.sample(state.position_m.y, atmosphere_conditions)
	var speed: float = state.velocity_m_s.length()
	var dynamic_pressure: float = 0.0
	if not simulation.telemetry.samples.is_empty():
		dynamic_pressure = float(simulation.telemetry.samples[simulation.telemetry.samples.size() - 1].dynamic_pressure_pa)
	else:
		var relative_air_speed: float = (state.velocity_m_s - simulation.wind_velocity_m_s).length()
		dynamic_pressure = 0.5 * float(atmosphere.density_kg_m3) * relative_air_speed * relative_air_speed
	$RocketVisual.position = state.position_m
	_update_camera_for_state(state.position_m)
	scope_label.text = "Altitude: %.2f m\nSpeed: %.2f m/s\nAcceleration: %.2f m/s²\nDynamic pressure: %.2f Pa\nMass: %.2f kg\nFlight time: %.3f s" % [
		state.position_m.y,
		speed,
		state.acceleration_m_s2.length(),
		dynamic_pressure,
		state.mass_kg,
		state.time_s
	]
	_update_telemetry_plots()

func _build_telemetry_dashboard() -> void:
	var layer := $CanvasLayer
	var panel := PanelContainer.new()
	panel.name = "TelemetryPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -410.0
	panel.offset_top = 20.0
	panel.offset_right = -20.0
	panel.offset_bottom = 620.0
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "LIVE TELEMETRY"
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)
	var chart_specs := [
		["AltitudePlot", "Altitude", "altitude_m", "m"],
		["VelocityPlot", "Total velocity", "velocity_m_s", "m/s"],
		["AccelerationPlot", "Acceleration", "acceleration_m_s2", "m/s²"],
		["DynamicPressurePlot", "Dynamic pressure", "dynamic_pressure_pa", "Pa"],
		["MassPlot", "Vehicle mass", "mass_kg", "kg"]
	]
	for spec in chart_specs:
		var plot := ReeveTelemetryPlot.new()
		plot.name = str(spec[0])
		plot.configure(str(spec[1]), str(spec[2]), str(spec[3]))
		column.add_child(plot)
		telemetry_plots.append(plot)

func _update_telemetry_plots() -> void:
	for plot in telemetry_plots:
		plot.set_samples(simulation.telemetry.samples)
