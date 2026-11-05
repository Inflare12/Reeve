extends SceneTree
## Instantiates the main scene and checks required 3D nodes/resources.

func _initialize() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	if packed == null:
		push_error("Main scene failed to load")
		quit(1)
		return

	var instance := packed.instantiate()
	if instance == null:
		push_error("Main scene failed to instantiate")
		quit(1)
		return

	root.add_child(instance)
	await process_frame
	var fuselage := instance.get_node_or_null("RocketVisual/Fuselage") as MeshInstance3D
	var nose := instance.get_node_or_null("RocketVisual/NoseCone") as MeshInstance3D
	var camera := instance.get_node_or_null("Camera3D") as Camera3D
	var status := instance.get_node_or_null("CanvasLayer/Panel/Info/Status") as Label

	var failures := 0
	if fuselage == null or not (fuselage.mesh is CylinderMesh):
		push_error("Fuselage mesh is missing or invalid")
		failures += 1
	if nose == null or not (nose.mesh is CylinderMesh):
		push_error("Nose cone mesh is missing or invalid")
		failures += 1
	if camera == null or not camera.current:
		push_error("Main camera is missing or not current")
		failures += 1
	if status == null:
		push_error("Scene status label is missing")
		failures += 1

	for control_name in ["PauseResumeButton", "SingleStepButton", "SlowerButton", "FasterButton", "ExportCsvButton", "ExportJsonButton"]:
		if instance.get_node_or_null("CanvasLayer/Panel/Info/" + control_name) == null:
			push_error("Flight Lab control is missing: %s" % control_name)
			failures += 1

	var telemetry_panel := instance.find_child("TelemetryPanel", true, false) as PanelContainer
	var altitude_plot := instance.find_child("AltitudePlot", true, false) as ReeveTelemetryPlot
	if telemetry_panel == null or altitude_plot == null:
		push_error("Live telemetry dashboard or altitude plot is missing")
		failures += 1

	var wind_x := instance.find_child("WindXInput", true, false) as SpinBox
	var wind_z := instance.find_child("WindZInput", true, false) as SpinBox
	var temperature_offset := instance.find_child("TemperatureOffsetInput", true, false) as SpinBox
	var pressure_scale := instance.find_child("PressureScaleInput", true, false) as SpinBox
	if wind_x == null or wind_z == null or temperature_offset == null or pressure_scale == null:
		push_error("Flight Lab wind and atmosphere controls are missing")
		failures += 1
	else:
		wind_x.value = 10.0
		wind_z.value = -2.0
		temperature_offset.value = 5.0
		pressure_scale.value = 1.1

	var gravity_button := instance.get_node_or_null("CanvasLayer/Panel/Info/GravityDropButton") as Button
	if gravity_button == null:
		push_error("Gravity-only demonstration button is missing")
		failures += 1
	else:
		gravity_button.pressed.emit()
		instance.call("_process", 1.0 / 60.0)
		var simulation: ReeveSimulationController = instance.get("simulation")
		if simulation == null or simulation.state == null or simulation.state.time_s <= 0.0:
			push_error("Gravity-only demonstration did not advance physics")
			failures += 1
		elif absf(simulation.wind_velocity_m_s.x - 10.0) > 0.000001 or absf(simulation.wind_velocity_m_s.z + 2.0) > 0.000001:
			push_error("Flight Lab wind controls were not passed into the simulation")
			failures += 1
		elif absf(float(simulation.model.atmosphere_conditions.temperature_offset_k) - 5.0) > 0.000001 or absf(float(simulation.model.atmosphere_conditions.pressure_scale) - 1.1) > 0.000001:
			push_error("Flight Lab atmosphere controls were not passed into the simulation")
			failures += 1
		elif altitude_plot == null or altitude_plot.samples.is_empty():
			push_error("Live altitude plot did not receive simulation telemetry")
			failures += 1
		else:
			var pause_button := instance.get_node("CanvasLayer/Panel/Info/PauseResumeButton") as Button
			var step_button := instance.get_node("CanvasLayer/Panel/Info/SingleStepButton") as Button
			pause_button.pressed.emit()
			var before_step: float = simulation.state.time_s
			step_button.pressed.emit()
			if absf(simulation.state.time_s - before_step - simulation.fixed_dt_s) > 0.000001:
				push_error("Flight Lab single-step control did not advance exactly one physics step")
				failures += 1
			var slower_button := instance.get_node("CanvasLayer/Panel/Info/SlowerButton") as Button
			var faster_button := instance.get_node("CanvasLayer/Panel/Info/FasterButton") as Button
			slower_button.pressed.emit()
			if absf(float(instance.get("time_scale")) - 0.5) > 0.000001:
				push_error("Flight Lab slower time-scale control failed")
				failures += 1
			faster_button.pressed.emit()
			if absf(float(instance.get("time_scale")) - 1.0) > 0.000001:
				push_error("Flight Lab faster time-scale control failed")
				failures += 1
			var csv_button := instance.get_node("CanvasLayer/Panel/Info/ExportCsvButton") as Button
			var json_button := instance.get_node("CanvasLayer/Panel/Info/ExportJsonButton") as Button
			csv_button.pressed.emit()
			json_button.pressed.emit()
			if not FileAccess.file_exists("user://reeve_telemetry.csv") or not FileAccess.file_exists("user://reeve_telemetry.json"):
				push_error("Flight Lab telemetry export buttons did not create both files")
				failures += 1
			if FileAccess.file_exists("user://reeve_telemetry.csv"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://reeve_telemetry.csv"))
			if FileAccess.file_exists("user://reeve_telemetry.json"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://reeve_telemetry.json"))

	instance.queue_free()
	if failures == 0:
		print("REEVE scene checks: PASS")
	quit(failures)
