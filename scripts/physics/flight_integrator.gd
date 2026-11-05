class_name ReeveFlightIntegrator
extends RefCounted
## Educational 3-DOF point-mass integrator using semi-implicit Euler.
## Propulsion inputs must come from a user-supplied, documented data profile.

static func calculate_acceleration(
	state: ReeveFlightState,
	thrust_n: float,
	thrust_direction: Vector3,
	drag_coefficient: float,
	reference_area_m2: float,
	wind_velocity_m_s: Vector3,
	atmosphere: Dictionary
) -> Vector3:
	var safe_mass: float = maxf(state.mass_kg, 0.000001)
	var direction: Vector3 = thrust_direction.normalized() if thrust_direction.length_squared() > 0.0 else Vector3.ZERO
	var thrust_force: Vector3 = direction * maxf(thrust_n, 0.0)

	var relative_air_velocity: Vector3 = state.velocity_m_s - wind_velocity_m_s
	var relative_speed: float = relative_air_velocity.length()
	var density: float = maxf(float(atmosphere.get("density_kg_m3", 0.0)), 0.0)
	var cd: float = maxf(drag_coefficient, 0.0)
	var area: float = maxf(reference_area_m2, 0.0)
	var drag_force: Vector3 = Vector3.ZERO
	if relative_speed > 0.000001:
		drag_force = -0.5 * density * cd * area * relative_speed * relative_air_velocity

	var gravity: Vector3 = Vector3.DOWN * ReeveAtmosphere.gravity_at_altitude(state.position_m.y)
	return (thrust_force + drag_force) / safe_mass + gravity

static func step(
	state: ReeveFlightState,
	dt_s: float,
	model: Dictionary,
	wind_velocity_m_s: Vector3 = Vector3.ZERO
) -> bool:
	if dt_s <= 0.0 or dt_s > 0.1 or not is_finite(dt_s) or not state.is_valid():
		return false

	var atmosphere: Dictionary = ReeveAtmosphere.sample(state.position_m.y)
	var thrust_n: float = maxf(float(model.get("thrust_n", 0.0)), 0.0)
	if state.propellant_remaining_kg <= 0.0 or state.mass_kg <= dry_mass_kg:
		thrust_n = 0.0
	var thrust_direction: Vector3 = model.get("thrust_direction", Vector3.UP)
	var mass_flow_kg_s: float = maxf(float(model.get("mass_flow_kg_s", 0.0)), 0.0)
	var dry_mass_kg: float = maxf(float(model.get("dry_mass_kg", 0.001)), 0.001)
	var cd: float = maxf(float(model.get("drag_coefficient", 0.5)), 0.0)
	var area: float = maxf(float(model.get("reference_area_m2", 0.01)), 0.0)

	var old_acceleration := calculate_acceleration(
		state, thrust_n, thrust_direction, cd, area, wind_velocity_m_s, atmosphere
	)
	var available_mass_above_dry: float = maxf(state.mass_kg - dry_mass_kg, 0.0)
	var consumed: float = minf(mass_flow_kg_s * dt_s, minf(state.propellant_remaining_kg, available_mass_above_dry))
	state.propellant_remaining_kg -= consumed
	state.mass_kg = maxf(dry_mass_kg, state.mass_kg - consumed)

	state.velocity_m_s += old_acceleration * dt_s
	state.position_m += state.velocity_m_s * dt_s
	state.time_s += dt_s
	state.acceleration_m_s2 = old_acceleration

	return state.is_valid()
