extends Node3D

@onready var status_label: Label = $CanvasLayer/Panel/Info/Status
@onready var scope_label: Label = $CanvasLayer/Panel/Info/Scope
@onready var camera: Camera3D = $Camera3D

var simulation := ReeveSimulationController.new()

func _ready() -> void:
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	status_label.text = "READY — no propulsion profile loaded. No flight has been simulated."

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
	simulation.advance_frame(delta)
	_update_flight_display()
	if simulation.ground_contact:
		status_label.text = "GROUND CONTACT — demonstration complete"
	elif not simulation.last_error.is_empty():
		status_label.text = "SIMULATION ERROR — %s" % simulation.last_error

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
		"ground_altitude_m": 0.0
	}
	if not simulation.configure(initial_state, model):
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

func _update_flight_display() -> void:
	if simulation.state == null:
		return
	var state := simulation.state
	var atmosphere := ReeveAtmosphere.sample(state.position_m.y)
	var speed: float = state.velocity_m_s.length()
	var dynamic_pressure: float = 0.5 * float(atmosphere.density_kg_m3) * speed * speed
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
