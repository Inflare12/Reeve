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

func _ready() -> void:
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

	var gravity_button := Button.new()
	gravity_button.name = "GravityDropButton"
	gravity_button.text = "Run Gravity-Only Drop Test"
	gravity_button.pressed.connect(_start_gravity_drop)
	$CanvasLayer/Panel/Info.add_child(gravity_button)

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
		time_scale_label.text = "Simulation time scale: %.3gx" % time_scale

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
	var initial_state := ReeveFlightState.new()
	initial_state.position_m = Vector3(0.0, 20.0, 0.0)
	initial_state.mass_kg = 25.0
	initial_state.propellant_remaining_kg = 0.0
	var model := {
		"thrust_n": 0.0,
		"mass_flow_kg_s": 0.0,
		"dry_mass_kg": 25.0,
		"drag_coefficient": 0.5,
		"reference_area_m2": PI * 0.28 * 0.28,
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
	status_label.text = "RUNNING — gravity-only drop test"
	_update_flight_display()

func _reset_demonstration() -> void:
	simulation.reset()
	$RocketVisual.position = Vector3.ZERO
	camera.position = Vector3(10.0, 7.0, 13.0)
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
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
	camera.position = state.position_m + Vector3(10.0, 6.0, 13.0)
	camera.look_at(state.position_m + Vector3.UP * 2.0, Vector3.UP)
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
