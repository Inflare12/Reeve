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

	var atmosphere_conditions: Dictionary = model.get("atmosphere_conditions", {})
	var atmosphere: Dictionary = ReeveAtmosphere.sample(state.position_m.y, atmosphere_conditions)
	if not bool(atmosphere.get("ok", false)):
		return false
	var dry_mass_kg: float = maxf(float(model.get("dry_mass_kg", 0.001)), 0.001)
	var thrust_n: float = maxf(float(model.get("thrust_n", 0.0)), 0.0)
	var mass_flow_kg_s: float = maxf(float(model.get("mass_flow_kg_s", 0.0)), 0.0)
	var supplied_profile: Variant = model.get("propulsion_profile", null)
	if supplied_profile is ReevePropulsionProfile:
		var profile_sample: Dictionary = supplied_profile.sample(state.time_s)
		if not bool(profile_sample.get("ok", false)):
			return false
		thrust_n = maxf(float(profile_sample.thrust_n), 0.0)
		mass_flow_kg_s = maxf(float(profile_sample.mass_flow_kg_s), 0.0)
	if state.propellant_remaining_kg <= 0.0 or state.mass_kg <= dry_mass_kg:
		thrust_n = 0.0
		mass_flow_kg_s = 0.0
	var thrust_direction: Vector3 = model.get("thrust_direction", Vector3.UP)
	if model.has("thrust_direction_body"):
		var body_direction: Vector3 = model.get("thrust_direction_body", Vector3.UP)
		thrust_direction = state.orientation * body_direction.normalized()
	var cd: float = maxf(float(model.get("drag_coefficient", 0.5)), 0.0)
	var area: float = maxf(float(model.get("reference_area_m2", 0.01)), 0.0)
	var recovery_configuration: Variant = model.get("recovery", {})
	if recovery_configuration is Dictionary and not recovery_configuration.is_empty():
		if ReeveRecoveryModel.is_deployed(state.position_m.y, state.velocity_m_s.y, recovery_configuration):
			# Combine drag areas through the equivalent Cd*A product.
			var recovery_cd_area: float = float(recovery_configuration.drag_coefficient) * float(recovery_configuration.canopy_area_m2)
			var vehicle_cd_area: float = cd * area
			cd = 1.0
			area = vehicle_cd_area + recovery_cd_area

	state.applied_thrust_n = thrust_n
	var old_acceleration: Vector3
	var aerodynamic_moment_body := Vector3.ZERO
	if model.has("aerodynamic_model"):
		var aerodynamic_configuration: Variant = model.get("aerodynamic_model")
		if not aerodynamic_configuration is Dictionary:
			return false
		var relative_air_velocity: Vector3 = state.velocity_m_s - wind_velocity_m_s
		var body_axis_world: Vector3 = state.orientation * Vector3.UP
		var flow_speed: float = relative_air_velocity.length()
		var angle_of_attack_rad: float = 0.0
		var lift_direction_world := Vector3.ZERO
		if flow_speed > 0.000001:
			var flow_direction: Vector3 = relative_air_velocity / flow_speed
			angle_of_attack_rad = acos(clampf(body_axis_world.normalized().dot(flow_direction), -1.0, 1.0))
			lift_direction_world = body_axis_world - flow_direction * body_axis_world.dot(flow_direction)
		var drag_curve: Array[Dictionary] = []
		for point in aerodynamic_configuration.get("drag_curve", []):
			if point is Dictionary:
				drag_curve.append(point)
		var aerodynamic_result := ReeveAerodynamics.calculate_forces(
			relative_air_velocity,
			float(atmosphere.density_kg_m3),
			float(atmosphere.dynamic_viscosity_pa_s),
			float(atmosphere.speed_of_sound_m_s),
			float(aerodynamic_configuration.get("reference_area_m2", area)),
			float(aerodynamic_configuration.get("characteristic_length_m", 1.0)),
			drag_curve,
			angle_of_attack_rad,
			float(aerodynamic_configuration.get("lift_slope_per_rad", 0.0)),
			lift_direction_world
		)
		if not bool(aerodynamic_result.get("ok", false)):
			return false
		var aerodynamic_force_world: Vector3 = aerodynamic_result.total_aerodynamic_force_n
		if recovery_configuration is Dictionary and not recovery_configuration.is_empty():
			if ReeveRecoveryModel.is_deployed(state.position_m.y, state.velocity_m_s.y, recovery_configuration) and flow_speed > 0.000001:
				var recovery_cd_area: float = float(recovery_configuration.drag_coefficient) * float(recovery_configuration.canopy_area_m2)
				aerodynamic_force_world += -0.5 * float(atmosphere.density_kg_m3) * recovery_cd_area * flow_speed * relative_air_velocity
		var cp_offset_body: Vector3 = aerodynamic_configuration.get("center_of_pressure_offset_body_m", Vector3.ZERO)
		if not cp_offset_body.is_finite():
			return false
		var aerodynamic_force_body: Vector3 = state.orientation.inverse() * aerodynamic_force_world
		aerodynamic_moment_body = cp_offset_body.cross(aerodynamic_force_body)
		var gravity_acceleration := Vector3.DOWN * ReeveAtmosphere.gravity_at_altitude(state.position_m.y)
		var thrust_force := thrust_direction.normalized() * thrust_n if thrust_direction.length_squared() > 0.000001 else Vector3.ZERO
		old_acceleration = (thrust_force + aerodynamic_force_world) / maxf(state.mass_kg, 0.000001) + gravity_acceleration
	else:
		old_acceleration = calculate_acceleration(
			state, thrust_n, thrust_direction, cd, area, wind_velocity_m_s, atmosphere
		)

	var available_mass_above_dry: float = maxf(state.mass_kg - dry_mass_kg, 0.0)
	var consumed: float = minf(mass_flow_kg_s * dt_s, minf(state.propellant_remaining_kg, available_mass_above_dry))
	state.propellant_remaining_kg -= consumed
	state.mass_kg = maxf(dry_mass_kg, state.mass_kg - consumed)
	state.velocity_m_s += old_acceleration * dt_s
	state.position_m += state.velocity_m_s * dt_s
	state.acceleration_m_s2 = old_acceleration

	if not _integrate_rotation(state, dt_s, model, aerodynamic_moment_body):
		return false
	return state.is_valid()

static func _integrate_rotation(state: ReeveFlightState, dt_s: float, model: Dictionary, aerodynamic_moment_body: Vector3 = Vector3.ZERO) -> bool:
	var inertia: Vector3 = model.get("inertia_diagonal_kg_m2", Vector3.ZERO)
	var applied_moment_body: Vector3 = model.get("body_moment_nm", Vector3.ZERO) + aerodynamic_moment_body
	if applied_moment_body.length_squared() > 0.0 or inertia.length_squared() > 0.0 or state.angular_velocity_rad_s.length_squared() > 0.0:
		if not inertia.is_finite() or inertia.x <= 0.0 or inertia.y <= 0.0 or inertia.z <= 0.0 or not applied_moment_body.is_finite():
			return false
		var angular_momentum_body := Vector3(inertia.x * state.angular_velocity_rad_s.x, inertia.y * state.angular_velocity_rad_s.y, inertia.z * state.angular_velocity_rad_s.z)
		var gyroscopic_moment_body := state.angular_velocity_rad_s.cross(angular_momentum_body)
		state.angular_acceleration_rad_s2 = Vector3(
			(applied_moment_body.x - gyroscopic_moment_body.x) / inertia.x,
			(applied_moment_body.y - gyroscopic_moment_body.y) / inertia.y,
			(applied_moment_body.z - gyroscopic_moment_body.z) / inertia.z
		)
		state.angular_velocity_rad_s += state.angular_acceleration_rad_s2 * dt_s
		var angular_speed: float = state.angular_velocity_rad_s.length()
		if angular_speed > 0.0000001:
			var body_rotation := Quaternion(state.angular_velocity_rad_s / angular_speed, angular_speed * dt_s)
			state.orientation = (state.orientation * body_rotation).normalized()
	state.time_s += dt_s
	return state.is_valid()
