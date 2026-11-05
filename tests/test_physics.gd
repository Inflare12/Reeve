extends SceneTree
## Lightweight headless checks for the first physics milestone.

func _initialize() -> void:
	var failures: int = 0
	failures += _check_atmosphere()
	failures += _check_gravity()
	failures += _check_drag_opposes_motion()
	failures += _check_mass_accounting()
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
		"thrust_n": 0.0,
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
