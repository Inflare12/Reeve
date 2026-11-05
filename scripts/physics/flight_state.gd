class_name ReeveFlightState
extends RefCounted
## Mutable translational state. World convention: +Y is up; all values are SI.

var time_s: float = 0.0
var position_m: Vector3 = Vector3.ZERO
var velocity_m_s: Vector3 = Vector3.ZERO
var acceleration_m_s2: Vector3 = Vector3.ZERO
var mass_kg: float = 1.0
var propellant_remaining_kg: float = 0.0

func is_valid() -> bool:
	return is_finite(time_s) and position_m.is_finite() and velocity_m_s.is_finite() 		and acceleration_m_s2.is_finite() and is_finite(mass_kg) 		and is_finite(propellant_remaining_kg) and mass_kg > 0.0 		and propellant_remaining_kg >= 0.0

func duplicate_state() -> ReeveFlightState:
	var copy := ReeveFlightState.new()
	copy.time_s = time_s
	copy.position_m = position_m
	copy.velocity_m_s = velocity_m_s
	copy.acceleration_m_s2 = acceleration_m_s2
	copy.mass_kg = mass_kg
	copy.propellant_remaining_kg = propellant_remaining_kg
	return copy
