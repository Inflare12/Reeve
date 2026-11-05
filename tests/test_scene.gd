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
	var ground := instance.get_node_or_null("GroundPlane") as MeshInstance3D
	var launch_pad := instance.get_node_or_null("LaunchPad") as MeshInstance3D
	var world_environment := instance.get_node_or_null("FlightWorldEnvironment") as WorldEnvironment

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
	if ground == null or not (ground.mesh is PlaneMesh) or launch_pad == null or not (launch_pad.mesh is CylinderMesh) or world_environment == null:
		push_error("3D launch environment ground, pad or world lighting is missing")
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

	var camera_selector := instance.find_child("CameraModeSelector", true, false) as OptionButton
	if camera_selector == null or camera_selector.item_count != 6:
		push_error("Flight Lab camera mode selector is missing or incomplete")
		failures += 1
	else:
		camera_selector.select(4)
		camera_selector.item_selected.emit(4)
		var free_camera_position: Vector3 = camera.position
		var move_key := InputEventKey.new()
		move_key.pressed = true
		move_key.keycode = KEY_W
		instance.call("_unhandled_input", move_key)
		if camera.position.distance_to(free_camera_position) < 0.1:
			push_error("Free camera keyboard movement did not move the camera")
			failures += 1
		camera_selector.select(1)
		camera_selector.item_selected.emit(1)

	var workshop_config := ReeveRocketConfiguration.new()
	var workshop_shell := ReeveRocketComponent.new()
	workshop_shell.component_id = "main_fuselage"
	workshop_shell.display_name = "Test fuselage"
	workshop_shell.geometry_type = "cylinder_shell"
	workshop_shell.material_id = "aluminium_6061_t6"
	workshop_shell.dimensions_m = {"outer_radius": 0.1, "wall_thickness": 0.002, "length": 2.0}
	var workshop_fin_mass_kg: float = 0.0
	for fin_index in range(4):
		var workshop_fin := ReeveRocketComponent.new()
		workshop_fin.component_id = "fin_%d" % fin_index
		workshop_fin.display_name = "Test fin %d" % fin_index
		workshop_fin.category = "Stabilizing surfaces"
		workshop_fin.geometry_type = "rectangular_plate"
		workshop_fin.material_id = "aluminium_6061_t6"
		workshop_fin.dimensions_m = {"length": 0.35, "width": 0.25, "thickness": 0.002}
		if not workshop_config.add_component(workshop_fin):
			push_error("Could not prepare workshop fin fixture")
			failures += 1
		else:
			workshop_fin_mass_kg += workshop_fin.calculate_mass_kg()
	var workshop_payload := ReeveRocketComponent.new()
	workshop_payload.component_id = "mass_payload"
	workshop_payload.display_name = "Payload"
	workshop_payload.geometry_type = "user_mass"
	workshop_payload.material_id = "aluminium_6061_t6"
	workshop_payload.user_mass_kg = 2.5
	if not workshop_config.add_component(workshop_shell) or not workshop_config.add_component(workshop_payload) or workshop_config.save_to_file("user://reeve_vehicle.json") != OK:
		push_error("Could not prepare workshop-to-flight handoff fixture")
		failures += 1
	var load_workshop_button := instance.find_child("LoadWorkshopVehicleButton", true, false) as Button
	if load_workshop_button == null:
		push_error("Flight Lab workshop vehicle load control is missing")
		failures += 1
	else:
		load_workshop_button.pressed.emit()

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
		elif camera == null or camera.position.distance_to(simulation.state.position_m + Vector3(0.0, 5.0, 24.0)) > 0.000001:
			push_error("Side observation camera mode did not position the camera correctly")
			failures += 1
		elif absf(simulation.wind_velocity_m_s.x - 10.0) > 0.000001 or absf(simulation.wind_velocity_m_s.z + 2.0) > 0.000001:
			push_error("Flight Lab wind controls were not passed into the simulation")
			failures += 1
		elif absf(simulation.state.mass_kg - (workshop_shell.calculate_mass_kg() + workshop_fin_mass_kg + 2.5)) > 0.000001 or float(simulation.model.drag_coefficient) != 0.0:
			push_error("Flight Lab did not transfer workshop mass or incorrectly invented drag coefficient")
			failures += 1
		elif absf(float((instance.get_node("RocketVisual/Fuselage") as MeshInstance3D).mesh as CylinderMesh).height - 2.0) > 0.000001:
			push_error("Workshop fuselage length was not transferred to the Flight Lab visual")
			failures += 1
		elif instance.find_children("WorkshopFin_*", "MeshInstance3D", true, false).size() != 4:
			push_error("Workshop fin geometry was not transferred to the Flight Lab visual")
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
			if FileAccess.file_exists("user://reeve_vehicle.json"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://reeve_vehicle.json"))

	instance.queue_free()
	if failures == 0:
		print("REEVE scene checks: PASS")
	quit(failures)
