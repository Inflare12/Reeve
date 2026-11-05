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

	var telemetry_panel := instance.get_node_or_null("CanvasLayer/TelemetryPanel") as PanelContainer
	var altitude_plot := instance.get_node_or_null("CanvasLayer/TelemetryPanel/VBoxContainer/AltitudePlot") as ReeveTelemetryPlot
	if telemetry_panel == null or altitude_plot == null:
		push_error("Live telemetry dashboard or altitude plot is missing")
		failures += 1

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
