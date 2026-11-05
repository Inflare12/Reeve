extends SceneTree
## Lightweight headless checks for the first physics milestone.

func _initialize() -> void:
	var failures: int = 0
	failures += _check_atmosphere()
	failures += _check_gravity()
	failures += _check_drag_opposes_motion()
	failures += _check_mass_accounting()
	failures += _check_fixed_step_controller()
	failures += _check_component_mass()
	failures += _check_configuration_rollup()
	failures += _check_configuration_serialization()
	failures += _check_aerodynamic_force_model()
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
	if absf(float(result.drag_coefficient) - (0.5 + 0.5 / 3.0)) > 0.0001:
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
