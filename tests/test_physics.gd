extends SceneTree
## Lightweight headless checks for the first physics milestone.

func _initialize() -> void:
	var failures: int = 0
	failures += _check_atmosphere()
	failures += _check_atmosphere_domain()
	failures += _check_gravity()
	failures += _check_drag_opposes_motion()
	failures += _check_mass_accounting()
	failures += _check_fixed_step_controller()
	failures += _check_controller_input_validation()
	failures += _check_component_mass()
	failures += _check_invalid_component_dimensions()
	failures += _check_configuration_rollup()
	failures += _check_configuration_serialization()
	failures += _check_aerodynamic_force_model()
	failures += _check_ground_contact_event()
	failures += _check_supplied_propulsion_profile()
	failures += _check_profile_drives_flight()
	failures += _check_telemetry_json_export()
	failures += _check_recovery_model()
	failures += _check_wind_relative_telemetry()
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
	return 0

func _check_telemetry_json_export() -> int:
	var state := ReeveFlightState.new()
	state.position_m = Vector3(1.0, 2.0, 3.0)
	state.velocity_m_s = Vector3(0.0, 4.0, 0.0)
	state.mass_kg = 7.5
	var recorder := ReeveTelemetryRecorder.new()
	recorder.record(state, ReeveAtmosphere.sample(2.0), 12.0)
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
	if parsed.get("samples", []).size() != 1 or parsed.get("units", {}).get("time", "") != "s":
		push_error("Telemetry JSON sample or units metadata missing")
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
