extends SceneTree
## Lightweight headless checks for the first physics milestone.

func _initialize() -> void:
	var failures: int = 0
	failures += _check_atmosphere()
	failures += _check_atmosphere_domain()
	failures += _check_atmosphere_modifiers()
	failures += _check_gravity()
	failures += _check_drag_opposes_motion()
	failures += _check_mass_accounting()
	failures += _check_fixed_step_controller()
	failures += _check_controller_input_validation()
	failures += _check_component_mass()
	failures += _check_invalid_component_dimensions()
	failures += _check_configuration_rollup()
	failures += _check_flight_handoff_data()
	failures += _check_configuration_serialization()
	failures += _check_aerodynamic_force_model()
	failures += _check_attitude_coupled_aerodynamics()
	failures += _check_ground_contact_event()
	failures += _check_supplied_propulsion_profile()
	failures += _check_profile_drives_flight()
	failures += _check_telemetry_json_export()
	failures += _check_recovery_model()
	failures += _check_wind_relative_telemetry()
	failures += _check_mission_events()
	failures += _check_quaternion_rigid_body_dynamics()
	failures += _check_time_varying_wind()
	failures += _check_structural_axial_estimate()
	failures += _check_thermal_lumped_response()
	failures += _check_analytic_free_fall()
	failures += _check_static_margin_estimate()
	if failures == 0:
		print("REEVE physics checks: PASS")
	else:
		push_error("REEVE physics checks: %d failure(s)" % failures)
	quit(failures)

func _check_atmosphere() -> int:
	var sea := ReeveAtmosphere.sample(0.0)
	var high := ReeveAtmosphere.sample(10000.0)
	if absf(float(sea.pressure_pa) - 101325.0) > 1.0:
		push_error("Sea-level pressure reference check failed")
		return 1
	if float(high.density_kg_m3) >= float(sea.density_kg_m3):
		push_error("Atmospheric density should decrease with altitude")
		return 1
	return 0

func _check_gravity() -> int:
	var g0 := ReeveAtmosphere.gravity_at_altitude(0.0)
	var g10 := ReeveAtmosphere.gravity_at_altitude(10000.0)
	if absf(g0 - 9.80665) > 0.0001 or g10 >= g0:
		push_error("Altitude gravity check failed")
		return 1
	return 0

func _check_drag_opposes_motion() -> int:
	var state := ReeveFlightState.new()
	state.position_m = Vector3(0.0, 1000.0, 0.0)
	state.velocity_m_s = Vector3(0.0, 0.0, 100.0)
	var atmosphere := ReeveAtmosphere.sample(1000.0)
	var acceleration := ReeveFlightIntegrator.calculate_acceleration(
		state, 0.0, Vector3.UP, 0.5, 0.1, Vector3.ZERO, atmosphere
	)
	if acceleration.z >= 0.0:
		push_error("Drag did not oppose positive-Z motion")
		return 1
	return 0

func _check_mass_accounting() -> int:
	var state := ReeveFlightState.new()
	state.mass_kg = 10.0
	state.propellant_remaining_kg = 2.0
	var model := {
		"thrust_n": 10.0,
		"mass_flow_kg_s": 0.5,
		"dry_mass_kg": 8.0,
		"drag_coefficient": 0.0,
		"reference_area_m2": 0.0
	}
	var ok := ReeveFlightIntegrator.step(state, 0.1, model)
	if not ok or absf(state.mass_kg - 9.95) > 0.0001 or absf(state.propellant_remaining_kg - 1.95) > 0.0001:
		push_error("Mass accounting check failed")
		return 1
	return 0

func _check_fixed_step_controller() -> int:
	var state := ReeveFlightState.new()
	state.position_m = Vector3(0.0, 100.0, 0.0)
	state.mass_kg = 1.0
	var controller := ReeveSimulationController.new()
	if not controller.configure(state, {"thrust_n": 0.0, "drag_coefficient": 0.0, "reference_area_m2": 0.0}):
		push_error("Simulation controller configuration failed")
		return 1
	var steps := controller.advance_frame(1.0 / 60.0)
	if steps != 2 or absf(controller.state.time_s - 1.0 / 60.0) > 0.000001:
		push_error("Fixed-step accumulator did not execute the expected two steps")
		return 1
	return 0

func _check_component_mass() -> int:
	var component := ReeveRocketComponent.new()
	component.component_id = "test_tube"
	component.display_name = "Test cylindrical shell"
	component.geometry_type = "cylinder_shell"
	component.material_id = "aluminium_6061_t6"
	component.dimensions_m = {
		"outer_radius": 0.1,
		"wall_thickness": 0.002,
		"length": 1.0
	}
	var expected_volume: float = PI * (0.1 * 0.1 - 0.098 * 0.098)
	var expected_mass: float = expected_volume * 2700.0
	var actual_mass: float = component.calculate_mass_kg()
	if absf(actual_mass - expected_mass) > 0.000001:
		push_error("Cylinder shell mass calculation failed")
		return 1
	return 0

func _check_configuration_rollup() -> int:
	var configuration := ReeveRocketConfiguration.new()
	var component := ReeveRocketComponent.new()
	component.component_id = "payload"
	component.display_name = "User-estimated payload"
	component.geometry_type = "user_mass"
	component.material_id = "aluminium_6061_t6"
	component.user_mass_kg = 1.25
	if not configuration.add_component(component):
		push_error("Valid component was rejected")
		return 1
	if configuration.add_component(component):
		push_error("Duplicate component ID was accepted")
		return 1
	var breakdown := configuration.get_mass_breakdown()
	if int(breakdown.component_count) != 1 or absf(float(breakdown.total_mass_kg) - 1.25) > 0.000001:
		push_error("Configuration mass roll-up failed")
		return 1
	return 0

func _check_configuration_serialization() -> int:
	var original := ReeveRocketConfiguration.new()
	original.vehicle_name = "Serialization Test"
	var component := ReeveRocketComponent.new()
	component.component_id = "test_mass"
	component.display_name = "Test mass"
	component.geometry_type = "user_mass"
	component.material_id = "aluminium_6061_t6"
	component.user_mass_kg = 2.75
	if not original.add_component(component):
		push_error("Could not create serialization test component")
		return 1
	var path := "user://reeve_config_test.json"
	var save_error := original.save_to_file(path)
	if save_error != OK:
		push_error("Configuration save failed: %s" % error_string(save_error))
		return 1
	var restored := ReeveRocketConfiguration.new()
	var load_error := restored.load_from_file(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if load_error != OK:
		push_error("Configuration load failed: %s" % error_string(load_error))
		return 1
	var result := restored.get_mass_breakdown()
	if restored.vehicle_name != "Serialization Test" or int(result.component_count) != 1 or absf(float(result.total_mass_kg) - 2.75) > 0.000001:
		push_error("Configuration serialization round trip changed data")
		return 1
	return 0

func _check_aerodynamic_force_model() -> int:
	var curve: Array[Dictionary] = [
		{"mach": 0.0, "cd": 0.5},
		{"mach": 2.0, "cd": 1.0}
	]
	var result := ReeveAerodynamics.calculate_forces(
		Vector3(0.0, 0.0, 100.0),
		1.2,
		1.8e-5,
		300.0,
		0.1,
		1.0,
		curve,
		0.1,
		2.0,
		Vector3.UP
	)
	if not bool(result.get("ok", false)):
		push_error("Aerodynamic model rejected a valid supplied-data case")
		return 1
	if absf(float(result.dynamic_pressure_pa) - 6000.0) > 0.001:
		push_error("Dynamic pressure calculation failed")
		return 1
	if absf(float(result.drag_coefficient) - (0.5 + 0.5 / 6.0)) > 0.0001:
		push_error("Mach interpolation of supplied drag curve failed")
		return 1
	if Vector3(result.drag_force_n).z >= 0.0 or Vector3(result.lift_force_n).y <= 0.0:
		push_error("Aerodynamic force directions are incorrect")
		return 1
	var outside := ReeveAerodynamics.interpolate_drag_coefficient(3.0, curve)
	if bool(outside.get("ok", true)):
		push_error("Aerodynamic model should reject extrapolation outside supplied data")
		return 1
	return 0

func _check_attitude_coupled_aerodynamics() -> int:
	var state := ReeveFlightState.new()
	state.position_m.y = 100.0
	state.velocity_m_s = Vector3(0.0, 0.0, 100.0)
	state.mass_kg = 1000.0
	var model := {
		"dry_mass_kg": 1000.0,
		"aerodynamic_model": {
			"drag_curve": [
				{"mach": 0.0, "cd": 0.5},
				{"mach": 1.0, "cd": 0.5}
			],
			"reference_area_m2": 1.0,
			"characteristic_length_m": 2.0,
			"lift_slope_per_rad": 2.0,
			"center_of_pressure_offset_body_m": Vector3.RIGHT
		},
		"inertia_diagonal_kg_m2": Vector3(1000.0, 1000.0, 1000.0)
	}
	var controller := ReeveSimulationController.new()
	if not controller.configure(state, model):
		push_error("Controller rejected valid attitude-coupled aerodynamic configuration: %s" % controller.last_error)
		return 1
	if not controller.step_once():
		push_error("Attitude-coupled aerodynamic step failed")
		return 1
	if controller.state.acceleration_m_s2.y <= 0.0:
		push_error("Body-axis angle of attack did not produce the expected positive lift component")
		return 1
	if controller.state.acceleration_m_s2.z >= 0.0:
		push_error("Supplied aerodynamic drag curve did not oppose airflow")
		return 1
	if controller.state.angular_acceleration_rad_s2.z <= 0.0:
		push_error("Supplied centre-of-pressure offset did not create the expected aerodynamic moment")
		return 1
	var invalid_controller := ReeveSimulationController.new()
	if invalid_controller.configure(state, {"dry_mass_kg": 1000.0, "aerodynamic_model": {"drag_curve": [], "reference_area_m2": 1.0, "characteristic_length_m": 1.0}}):
		push_error("Controller accepted an aerodynamic model without a supplied coefficient curve")
		return 1
	var invalid_offset_model: Dictionary = model.duplicate(true)
	invalid_offset_model.aerodynamic_model.center_of_pressure_offset_body_m = Vector3(NAN, 0.0, 0.0)
	if ReeveSimulationController.new().configure(state, invalid_offset_model):
		push_error("Controller accepted a non-finite aerodynamic centre-of-pressure offset")
		return 1
	var aligned_state := ReeveFlightState.new()
	aligned_state.position_m.y = 100.0
	aligned_state.velocity_m_s = Vector3(0.0, 0.0, 100.0)
	aligned_state.mass_kg = 1000.0
	aligned_state.orientation = Quaternion(Vector3.RIGHT, PI * 0.5)
	var aligned_controller := ReeveSimulationController.new()
	if not aligned_controller.configure(aligned_state, model) or not aligned_controller.step_once():
		push_error("Aligned-body aerodynamic case failed")
		return 1
	if absf(aligned_controller.state.acceleration_m_s2.y + ReeveConstants.STANDARD_GRAVITY) > 0.02:
		push_error("Aligned body and airflow should have near-zero angle of attack and no lift")
		return 1
	var out_of_curve_state := ReeveFlightState.new()
	out_of_curve_state.position_m.y = 100.0
	out_of_curve_state.velocity_m_s = Vector3(0.0, 0.0, 500.0)
	out_of_curve_state.mass_kg = 1000.0
	var out_of_curve_controller := ReeveSimulationController.new()
	if not out_of_curve_controller.configure(out_of_curve_state, model):
		push_error("Controller rejected a valid coefficient curve before its Mach-domain check")
		return 1
	if out_of_curve_controller.step_once() or out_of_curve_controller.state.time_s != 0.0:
		push_error("Aerodynamic model extrapolated outside supplied Mach data or mutated state on rejection")
		return 1
	return 0

func _check_ground_contact_event() -> int:
	var state := ReeveFlightState.new()
	state.position_m = Vector3(0.0, 0.001, 0.0)
	state.mass_kg = 5.0
	var controller := ReeveSimulationController.new()
	var model := {
		"thrust_n": 0.0,
		"dry_mass_kg": 5.0,
		"drag_coefficient": 0.0,
		"reference_area_m2": 0.0,
		"ground_altitude_m": 0.0
	}
	if not controller.configure(state, model):
		push_error("Ground-contact test could not configure controller")
		return 1
	controller.advance_frame(1.0 / 60.0)
	if not controller.ground_contact or controller.running or absf(controller.state.position_m.y) > 0.000001 or controller.state.velocity_m_s.length() > 0.000001:
		push_error("Ground-contact event did not stop and settle: contact=%s running=%s y=%.9f vy=%.9f t=%.9f error=%s" % [controller.ground_contact, controller.running, controller.state.position_m.y, controller.state.velocity_m_s.y, controller.state.time_s, controller.last_error])
		return 1
	var ground_event: Dictionary = {}
	for event in controller.telemetry.events:
		if str(event.event) == "ground_contact":
			ground_event = event
	if ground_event.is_empty() or float(ground_event.details.get("impact_speed_m_s", 0.0)) <= 0.0:
		push_error("Ground-contact event did not preserve pre-contact impact speed")
		return 1
	return 0

func _check_supplied_propulsion_profile() -> int:
	var profile := ReevePropulsionProfile.new()
	profile.profile_name = "Synthetic unit-test curve"
	profile.data_quality = "synthetic_test"
	profile.source_description = "Test-only values; not engine performance data."
	profile.points = [
		{"time_s": 0.0, "thrust_n": 0.0, "mass_flow_kg_s": 0.0},
		{"time_s": 1.0, "thrust_n": 100.0, "mass_flow_kg_s": 0.2},
		{"time_s": 2.0, "thrust_n": 0.0, "mass_flow_kg_s": 0.0}
	]
	if not profile.validate().is_empty():
		push_error("Valid supplied propulsion curve was rejected")
		return 1
	var middle := profile.sample(0.5)
	if not bool(middle.ok) or absf(float(middle.thrust_n) - 50.0) > 0.000001 or absf(float(middle.mass_flow_kg_s) - 0.1) > 0.000001:
		push_error("Supplied propulsion curve interpolation failed")
		return 1
	if absf(profile.total_impulse_ns() - 100.0) > 0.000001 or absf(profile.integrated_propellant_mass_kg() - 0.2) > 0.000001:
		push_error("Supplied propulsion curve integration failed")
		return 1
	var invalid := ReevePropulsionProfile.new()
	invalid.profile_name = "Invalid"
	invalid.data_quality = "supplied"
	invalid.source_description = "Bad time ordering"
	invalid.points = [
		{"time_s": 1.0, "thrust_n": 0.0, "mass_flow_kg_s": 0.0},
		{"time_s": 0.5, "thrust_n": 1.0, "mass_flow_kg_s": 0.1}
	]
	if invalid.validate().is_empty():
		push_error("Non-monotonic propulsion curve was accepted")
		return 1
	return 0

func _check_profile_drives_flight() -> int:
	var profile := ReevePropulsionProfile.new()
	profile.profile_name = "Synthetic integration test"
	profile.data_quality = "synthetic_test"
	profile.source_description = "Unit test only; not a real motor curve."
	profile.points = [
		{"time_s": 0.0, "thrust_n": 100.0, "mass_flow_kg_s": 0.1},
		{"time_s": 1.0, "thrust_n": 100.0, "mass_flow_kg_s": 0.1}
	]
	var state := ReeveFlightState.new()
	state.mass_kg = 10.0
	state.propellant_remaining_kg = 2.0
	var model := {
		"dry_mass_kg": 8.0,
		"drag_coefficient": 0.0,
		"reference_area_m2": 0.0,
		"propulsion_profile": profile
	}
	var controller := ReeveSimulationController.new()
	controller.max_substeps_per_frame = 20
	if not controller.configure(state, model):
		push_error("Simulation controller rejected a valid supplied propulsion profile")
		return 1
	controller.advance_frame(0.1)
	if absf(controller.state.applied_thrust_n - 100.0) > 0.000001:
		push_error("Supplied propulsion profile thrust was not applied")
		return 1
	var expected_consumption: float = 0.1 * controller.state.time_s
	if absf(controller.state.mass_kg - (10.0 - expected_consumption)) > 0.000001 or absf(controller.state.propellant_remaining_kg - (2.0 - expected_consumption)) > 0.000001:
		push_error("Supplied propulsion profile mass flow was not applied")
		return 1
	for _step in range(140):
		if not controller.step_once():
			break
	var found_powered_start := false
	var found_cutoff := false
	for event in controller.telemetry.events:
		if str(event.event) == "powered_flight_start":
			found_powered_start = true
		elif str(event.event) == "engine_cutoff":
			found_cutoff = true
	if not found_powered_start or not found_cutoff:
		push_error("Supplied thrust profile did not produce powered-flight start and engine-cutoff events")
		return 1
	return 0

func _check_telemetry_json_export() -> int:
	var state := ReeveFlightState.new()
	state.position_m = Vector3(1.0, 2.0, 3.0)
	state.velocity_m_s = Vector3(0.0, 4.0, 0.0)
	state.mass_kg = 7.5
	var recorder := ReeveTelemetryRecorder.new()
	recorder.record(state, ReeveAtmosphere.sample(2.0), 12.0)
	recorder.record_event("test_event", state, {"verified": true})
	var path := "user://reeve_telemetry_test.json"
	var save_error := recorder.export_json(path)
	if save_error != OK:
		push_error("Telemetry JSON export failed")
		return 1
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Telemetry JSON output could not be reopened")
		return 1
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		push_error("Telemetry JSON schema is invalid")
		return 1
	if parsed.get("samples", []).size() != 1 or parsed.get("units", {}).get("time", "") != "s" or parsed.get("events", []).size() != 1:
		push_error("Telemetry JSON sample, event or units metadata missing")
		return 1
	return 0

func _check_atmosphere_domain() -> int:
	for altitude in [-501.0, 20001.0, INF, NAN]:
		var sample := ReeveAtmosphere.sample(altitude)
		if bool(sample.get("ok", true)):
			push_error("Atmosphere silently accepted out-of-domain altitude: %s" % altitude)
			return 1
	var upper := ReeveAtmosphere.sample(20000.0)
	if not bool(upper.get("ok", false)):
		push_error("Atmosphere rejected its documented upper boundary")
		return 1
	var state := ReeveFlightState.new()
	state.position_m.y = 25000.0
	state.mass_kg = 1.0
	var original_position := state.position_m
	var model := {"dry_mass_kg": 1.0, "drag_coefficient": 0.0, "reference_area_m2": 0.0}
	if ReeveFlightIntegrator.step(state, 1.0 / 120.0, model) or state.position_m != original_position or state.time_s != 0.0:
		push_error("Flight integrator did not reject out-of-domain atmosphere without mutation")
		return 1
	return 0

func _check_invalid_component_dimensions() -> int:
	var component := ReeveRocketComponent.new()
	component.component_id = "invalid_shell"
	component.display_name = "Invalid shell"
	component.geometry_type = "cylinder_shell"
	component.material_id = "aluminium_6061_t6"
	component.dimensions_m = {"outer_radius": NAN, "wall_thickness": 0.001, "length": 1.0}
	if component.validate().is_empty() or component.calculate_mass_kg() >= 0.0:
		push_error("Non-finite geometry produced a component mass")
		return 1
	return 0

func _check_controller_input_validation() -> int:
	var state := ReeveFlightState.new()
	state.mass_kg = 10.0
	state.propellant_remaining_kg = 3.0
	var controller := ReeveSimulationController.new()
	if controller.configure(state, {"dry_mass_kg": 8.0}):
		push_error("Controller accepted propellant mass greater than wet-minus-dry mass")
		return 1
	state.propellant_remaining_kg = 2.0
	if controller.configure(state, {"dry_mass_kg": 8.0}, Vector3(NAN, 0.0, 0.0)):
		push_error("Controller accepted non-finite wind")
		return 1
	if not controller.configure(state, {"dry_mass_kg": 8.0}):
		push_error("Controller rejected valid dry/propellant mass")
		return 1
	controller.advance_frame(0.01, NAN)
	if controller.running or not controller.last_error.contains("time scale"):
		push_error("Controller did not stop on non-finite time scale")
		return 1
	return 0

func _check_recovery_model() -> int:
	var config := {
		"deployment_altitude_m": 100.0,
		"canopy_area_m2": 8.0,
		"drag_coefficient": 1.5
	}
	if not ReeveRecoveryModel.validate(config).is_empty():
		push_error("Valid educational recovery parameters were rejected")
		return 1
	if ReeveRecoveryModel.is_deployed(100.0, -1.0, config) == false or ReeveRecoveryModel.is_deployed(100.0, 1.0, config) or ReeveRecoveryModel.is_deployed(101.0, -1.0, config) or ReeveRecoveryModel.is_deployed(100.0, 0.0, config):
		push_error("Recovery deployment altitude condition is incorrect")
		return 1
	var result := ReeveRecoveryModel.calculate_acceleration(10.0, 1.2, Vector3.DOWN * 10.0, 8.0, 1.5)
	if not bool(result.get("ok", false)) or Vector3(result.drag_force_n).y <= 0.0:
		push_error("Parachute drag did not oppose downward relative airflow")
		return 1
	var expected_terminal := sqrt(2.0 * 10.0 * ReeveConstants.STANDARD_GRAVITY / (1.2 * 1.5 * 8.0))
	if absf(float(result.terminal_descent_speed_m_s) - expected_terminal) > 0.000001:
		push_error("Parachute terminal-speed estimate is inconsistent with the drag model")
		return 1
	var invalid_controller := ReeveSimulationController.new()
	var state := ReeveFlightState.new()
	state.position_m.y = 200.0
	state.mass_kg = 10.0
	if invalid_controller.configure(state, {"dry_mass_kg": 10.0, "recovery": {"deployment_altitude_m": -1.0, "canopy_area_m2": 8.0, "drag_coefficient": 1.5}}):
		push_error("Controller accepted invalid recovery configuration")
		return 1
	return 0

func _check_wind_relative_telemetry() -> int:
	var state := ReeveFlightState.new()
	state.position_m.y = 100.0
	state.velocity_m_s = Vector3(10.0, 0.0, 0.0)
	state.mass_kg = 2.0
	var wind := Vector3(10.0, 0.0, 0.0)
	var recorder := ReeveTelemetryRecorder.new()
	var atmosphere := ReeveAtmosphere.sample(100.0)
	recorder.record(state, atmosphere, 0.0, wind)
	var sample: Dictionary = recorder.samples[0]
	if absf(float(sample.relative_air_speed_m_s)) > 0.000001 or absf(float(sample.dynamic_pressure_pa)) > 0.000001 or absf(float(sample.mach)) > 0.000001:
		push_error("Wind-relative telemetry did not use air-relative velocity")
		return 1
	if absf(float(sample.horizontal_velocity_m_s) - 10.0) > 0.000001 or absf(float(sample.wind_speed_m_s) - 10.0) > 0.000001:
		push_error("Horizontal velocity or wind telemetry is incorrect")
		return 1
	return 0

func _check_mission_events() -> int:
	var state := ReeveFlightState.new()
	state.position_m.y = 100.0
	state.velocity_m_s.y = 10.0
	state.mass_kg = 1.0
	var controller := ReeveSimulationController.new()
	var model := {
		"dry_mass_kg": 1.0,
		"drag_coefficient": 0.0,
		"reference_area_m2": 0.0,
		"ground_altitude_m": 0.0
	}
	if not controller.configure(state, model):
		push_error("Mission event test could not configure simulation")
		return 1
	for _frame in range(100):
		controller.advance_frame(controller.fixed_dt_s * 8.0)
		if controller.ground_contact:
			break
	var found_apogee := false
	var found_descent := false
	var found_ground := false
	for event in controller.telemetry.events:
		match str(event.event):
			"apogee":
				found_apogee = true
			"descent_start":
				found_descent = true
			"ground_contact":
				found_ground = true
	if not found_apogee or not found_descent or not found_ground:
		push_error("Mission event detector missed apogee, descent or ground contact")
		return 1
	if controller.running:
		push_error("Mission event detector did not stop after ground contact")
		return 1
	var recovery_state := ReeveFlightState.new()
	recovery_state.position_m.y = 100.01
	recovery_state.velocity_m_s.y = -5.0
	recovery_state.mass_kg = 1.0
	var recovery_controller := ReeveSimulationController.new()
	var recovery_model := {
		"dry_mass_kg": 1.0,
		"drag_coefficient": 0.0,
		"reference_area_m2": 0.0,
		"recovery": {
			"deployment_altitude_m": 100.0,
			"canopy_area_m2": 1.0,
			"drag_coefficient": 1.5
		}
	}
	if not recovery_controller.configure(recovery_state, recovery_model) or not recovery_controller.step_once():
		push_error("Recovery event test could not advance the configured descent")
		return 1
	var found_recovery_deployment := false
	for event in recovery_controller.telemetry.events:
		if str(event.event) == "recovery_deployment":
			found_recovery_deployment = true
	if not found_recovery_deployment:
		push_error("Recovery deployment event was not recorded when descent crossed its altitude condition")
		return 1
	return 0


func _check_quaternion_rigid_body_dynamics() -> int:
	var state := ReeveFlightState.new()
	state.position_m.y = 100.0
	state.mass_kg = 1.0
	var model := {
		"dry_mass_kg": 1.0,
		"drag_coefficient": 0.0,
		"reference_area_m2": 0.0,
		"inertia_diagonal_kg_m2": Vector3(2.0, 3.0, 4.0),
		"body_moment_nm": Vector3(0.0, 0.0, 8.0)
	}
	if not ReeveFlightIntegrator.step(state, 0.01, model):
		push_error("Rigid-body angular integration rejected valid inputs")
		return 1
	if absf(state.angular_acceleration_rad_s2.z - 2.0) > 0.000001 or absf(state.angular_velocity_rad_s.z - 0.02) > 0.000001:
		push_error("Rigid-body angular acceleration or velocity is incorrect")
		return 1
	if absf(state.orientation.length() - 1.0) > 0.000001:
		push_error("Quaternion attitude lost unit length")
		return 1
	var rotated_state := ReeveFlightState.new()
	rotated_state.position_m.y = 100.0
	rotated_state.mass_kg = 2.0
	rotated_state.propellant_remaining_kg = 1.0
	rotated_state.orientation = Quaternion(Vector3.BACK, PI * 0.5)
	var thrust_model := {
		"dry_mass_kg": 1.0,
		"thrust_n": 10.0,
		"thrust_direction_body": Vector3.UP,
		"drag_coefficient": 0.0,
		"reference_area_m2": 0.0
	}
	if not ReeveFlightIntegrator.step(rotated_state, 0.01, thrust_model) or rotated_state.acceleration_m_s2.x >= 0.0:
		push_error("Body-frame thrust direction did not follow quaternion attitude")
		return 1
	var invalid_controller := ReeveSimulationController.new()
	var invalid_state := ReeveFlightState.new()
	invalid_state.mass_kg = 1.0
	if invalid_controller.configure(invalid_state, {"dry_mass_kg": 1.0, "body_moment_nm": Vector3(1.0, 0.0, 0.0)}):
		push_error("Controller accepted applied moment without a valid inertia tensor")
		return 1
	return 0

func _check_time_varying_wind() -> int:
	var config := {
		"base_velocity_m_s": Vector3(5.0, 0.0, 0.0),
		"gust_amplitude_m_s": Vector3(2.0, 0.0, 0.0),
		"gust_frequency_hz": Vector3(0.25, 0.0, 0.0),
		"phase_rad": Vector3.ZERO
	}
	if not ReeveWindModel.validate(config).is_empty():
		push_error("Valid time-varying wind configuration was rejected")
		return 1
	var at_start := ReeveWindModel.sample(0.0, config)
	var at_quarter := ReeveWindModel.sample(1.0, config)
	var at_three_quarters := ReeveWindModel.sample(3.0, config)
	if not bool(at_start.ok) or not bool(at_quarter.ok) or not bool(at_three_quarters.ok):
		push_error("Time-varying wind sampling failed")
		return 1
	if absf(Vector3(at_start.velocity_m_s).x - 5.0) > 0.000001 or absf(Vector3(at_quarter.velocity_m_s).x - 7.0) > 0.000001 or absf(Vector3(at_three_quarters.velocity_m_s).x - 3.0) > 0.000001:
		push_error("Wind gust sinusoid does not match its specified phase and frequency")
		return 1
	var invalid := config.duplicate(true)
	invalid.gust_frequency_hz = Vector3(-0.1, 0.0, 0.0)
	if ReeveWindModel.validate(invalid).is_empty():
		push_error("Wind model accepted negative gust frequency")
		return 1
	var state := ReeveFlightState.new()
	state.position_m.y = 100.0
	state.mass_kg = 2.0
	state.velocity_m_s = Vector3(10.0, 0.0, 0.0)
	var controller := ReeveSimulationController.new()
	var model := {
		"dry_mass_kg": 2.0,
		"drag_coefficient": 0.0,
		"reference_area_m2": 0.0,
		"wind_model": {"base_velocity_m_s": Vector3(10.0, 0.0, 0.0)}
	}
	if not controller.configure(state, model):
		push_error("Controller rejected valid wind model")
		return 1
	if not controller.step_once():
		push_error("Controller wind step failed: %s" % controller.last_error)
		return 1
	if controller.telemetry.samples.is_empty() or absf(float(controller.telemetry.samples[0].relative_air_speed_m_s) - absf(controller.state.velocity_m_s.y)) > 0.000001:
		push_error("Controller did not cancel matching horizontal wind and retain vertical air-relative velocity")
		return 1
	return 0

func _check_structural_axial_estimate() -> int:
	var result := ReeveStructuralEstimate.calculate_axial_tension(
		"aluminium_6061_t6", 0.001, 1.0, 1000.0
	)
	if not bool(result.get("ok", false)):
		push_error("Valid axial tension estimate was rejected")
		return 1
	if absf(float(result.axial_stress_pa) - 1.0e6) > 0.001:
		push_error("Axial stress calculation is incorrect")
		return 1
	var expected_strain: float = 1.0e6 / 68.9e9
	if absf(float(result.elastic_strain) - expected_strain) > 1.0e-12 or absf(float(result.elastic_deformation_m) - expected_strain) > 1.0e-12:
		push_error("Linear-elastic strain or deformation calculation is incorrect")
		return 1
	if str(result.strength_basis) != "nominal_yield_strength" or absf(float(result.reference_strength_factor) - 276.0) > 0.000001:
		push_error("Metal yield reference factor is incorrect")
		return 1
	var composite := ReeveStructuralEstimate.calculate_axial_tension("carbon_fibre_generic", 0.001, 1.0, 1000.0)
	if not bool(composite.get("ok", false)) or str(composite.strength_basis) != "nominal_ultimate_tensile_strength":
		push_error("Composite tensile reference strength basis was not labelled correctly")
		return 1
	var invalid := ReeveStructuralEstimate.calculate_axial_tension("aluminium_6061_t6", 0.0, 1.0, 100.0)
	if bool(invalid.get("ok", true)):
		push_error("Structural estimate accepted zero cross-sectional area")
		return 1
	return 0

func _check_thermal_lumped_response() -> int:
	var result := ReeveThermalEstimate.calculate_lumped_convective_response(
		"aluminium_6061_t6", 1.0, 0.1, 0.01, 10.0, 300.0, 400.0, 100.0
	)
	if not bool(result.get("ok", false)):
		push_error("Valid lumped thermal response was rejected")
		return 1
	var expected_tau: float = 1.0 * 896.0 / (10.0 * 0.1)
	var expected_temperature: float = 300.0 + 100.0 * exp(-100.0 / expected_tau)
	if absf(float(result.time_constant_s) - expected_tau) > 0.000001 or absf(float(result.temperature_k) - expected_temperature) > 0.000001:
		push_error("Lumped thermal response calculation is incorrect")
		return 1
	var invalid_biot := ReeveThermalEstimate.calculate_lumped_convective_response(
		"fibreglass_generic", 1.0, 0.1, 0.1, 100.0, 300.0, 400.0, 10.0
	)
	if bool(invalid_biot.get("ok", true)) or float(invalid_biot.get("biot_number", 0.0)) < 0.1:
		push_error("Thermal model failed to reject unsupported lumped-capacitance assumption")
		return 1
	return 0

func _check_analytic_free_fall() -> int:
	var state := ReeveFlightState.new()
	state.position_m.y = 1000.0
	state.mass_kg = 1.0
	var model := {
		"dry_mass_kg": 1.0,
		"drag_coefficient": 0.0,
		"reference_area_m2": 0.0
	}
	var dt := 1.0 / 120.0
	for _step in range(120):
		if not ReeveFlightIntegrator.step(state, dt, model):
			push_error("Analytical free-fall integration rejected a valid step")
			return 1
	var expected_velocity: float = -ReeveConstants.STANDARD_GRAVITY
	var expected_position: float = 1000.0 - 0.5 * ReeveConstants.STANDARD_GRAVITY
	if absf(state.velocity_m_s.y - expected_velocity) > 0.01:
		push_error("Free-fall velocity diverged from analytical constant-gravity solution")
		return 1
	# Semi-implicit Euler has a known O(dt) position offset; bound it explicitly.
	if absf(state.position_m.y - expected_position) > 0.05:
		push_error("Free-fall position error exceeded the documented semi-implicit Euler tolerance")
		return 1
	return 0

func _check_atmosphere_modifiers() -> int:
	var standard := ReeveAtmosphere.sample(1000.0)
	var modified := ReeveAtmosphere.sample(1000.0, {"temperature_offset_k": 10.0, "pressure_scale": 1.1})
	if not bool(modified.get("ok", false)):
		push_error("Valid atmospheric temperature and pressure modifiers were rejected")
		return 1
	if absf(float(modified.temperature_k) - float(standard.temperature_k) - 10.0) > 0.000001 or absf(float(modified.pressure_pa) / float(standard.pressure_pa) - 1.1) > 0.000001:
		push_error("Atmospheric temperature or pressure modifier was not applied")
		return 1
	var expected_density: float = float(modified.pressure_pa) / (ReeveConstants.AIR_GAS_CONSTANT * float(modified.temperature_k))
	if absf(float(modified.density_kg_m3) - expected_density) > 0.000001:
		push_error("Atmospheric density was not recomputed from modified pressure and temperature")
		return 1
	var invalid := ReeveAtmosphere.sample(1000.0, {"pressure_scale": 0.0})
	if bool(invalid.get("ok", true)):
		push_error("Atmosphere accepted a non-positive pressure scale")
		return 1
	return 0

func _check_flight_handoff_data() -> int:
	var configuration := ReeveRocketConfiguration.new()
	var shell := ReeveRocketComponent.new()
	shell.component_id = "main_fuselage"
	shell.display_name = "Main fuselage"
	shell.geometry_type = "cylinder_shell"
	shell.material_id = "aluminium_6061_t6"
	shell.dimensions_m = {"outer_radius": 0.1, "wall_thickness": 0.002, "length": 2.0}
	if not configuration.add_component(shell):
		push_error("Could not create handoff fuselage component")
		return 1
	var payload := ReeveRocketComponent.new()
	payload.component_id = "payload"
	payload.display_name = "Payload"
	payload.geometry_type = "user_mass"
	payload.material_id = "aluminium_6061_t6"
	payload.user_mass_kg = 3.0
	if not configuration.add_component(payload):
		push_error("Could not create handoff payload mass")
		return 1
	var handoff := configuration.get_flight_handoff()
	if not bool(handoff.get("ok", false)):
		push_error("Valid workshop configuration did not produce flight handoff data")
		return 1
	var expected_area: float = PI * 0.1 * 0.1
	if absf(float(handoff.total_mass_kg) - (shell.calculate_mass_kg() + 3.0)) > 0.000001 or absf(float(handoff.frontal_reference_area_m2) - expected_area) > 0.000001:
		push_error("Workshop flight handoff mass or reference area is incorrect")
		return 1
	if bool(handoff.drag_coefficient_supplied) or bool(handoff.propulsion_profile_supplied):
		push_error("Workshop handoff falsely claimed unknown propulsion or drag data")
		return 1
	return 0

func _check_static_margin_estimate() -> int:
	var stable := ReeveStabilityEstimate.calculate_static_margin(1.0, 2.5, 0.5)
	if not bool(stable.get("ok", false)) or absf(float(stable.static_margin_calibers) - 3.0) > 0.000001:
		push_error("Static-margin calculation is incorrect for aft CP")
		return 1
	var negative := ReeveStabilityEstimate.calculate_static_margin(2.5, 1.0, 0.5)
	if not bool(negative.get("ok", false)) or float(negative.static_margin_calibers) >= 0.0:
		push_error("Static-margin sign convention is incorrect for forward CP")
		return 1
	var invalid := ReeveStabilityEstimate.calculate_static_margin(1.0, 2.0, 0.0)
	if bool(invalid.get("ok", true)):
		push_error("Static-margin calculation accepted zero reference diameter")
		return 1
	return 0
