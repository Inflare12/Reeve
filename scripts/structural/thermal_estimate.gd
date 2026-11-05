class_name ReeveThermalEstimate
extends RefCounted
## Lumped-capacitance convective temperature response for educational studies.
## All heat-transfer coefficients and geometry inputs are user supplied.

static func calculate_lumped_convective_response(
	material_id: String,
	mass_kg: float,
	exposed_area_m2: float,
	characteristic_length_m: float,
	convective_coefficient_w_m2k: float,
	ambient_temperature_k: float,
	initial_temperature_k: float,
	elapsed_time_s: float
) -> Dictionary:
	var inputs := [mass_kg, exposed_area_m2, characteristic_length_m, convective_coefficient_w_m2k, ambient_temperature_k, initial_temperature_k, elapsed_time_s]
	for value in inputs:
		if not is_finite(float(value)):
			return {"ok": false, "error": "Thermal inputs must all be finite."}
	if mass_kg <= 0.0 or exposed_area_m2 <= 0.0 or characteristic_length_m <= 0.0 or convective_coefficient_w_m2k <= 0.0:
		return {"ok": false, "error": "Mass, area, characteristic length and convection coefficient must be positive."}
	if ambient_temperature_k <= 0.0 or initial_temperature_k <= 0.0 or elapsed_time_s < 0.0:
		return {"ok": false, "error": "Absolute temperatures must be positive and elapsed time non-negative."}
	var material: Dictionary = ReeveMaterialCatalog.get_material(material_id)
	if material.is_empty():
		return {"ok": false, "error": "Unknown material ID."}
	var conductivity: float = float(material.get("thermal_conductivity_w_mk", 0.0))
	var specific_heat: float = float(material.get("specific_heat_j_kgk", 0.0))
	if conductivity <= 0.0 or specific_heat <= 0.0:
		return {"ok": false, "error": "Material thermal conductivity and specific heat must be positive."}
	var biot_number: float = convective_coefficient_w_m2k * characteristic_length_m / conductivity
	if biot_number >= 0.1:
		return {
			"ok": false,
			"error": "Lumped-capacitance assumption is not supported: Biot number must be below 0.1.",
			"biot_number": biot_number
		}
	var time_constant_s: float = mass_kg * specific_heat / (convective_coefficient_w_m2k * exposed_area_m2)
	var temperature_k: float = ambient_temperature_k + (initial_temperature_k - ambient_temperature_k) * exp(-elapsed_time_s / time_constant_s)
	var heat_rate_w: float = convective_coefficient_w_m2k * exposed_area_m2 * (ambient_temperature_k - temperature_k)
	return {
		"ok": true,
		"material_id": material_id,
		"biot_number": biot_number,
		"time_constant_s": time_constant_s,
		"temperature_k": temperature_k,
		"heat_transfer_rate_w": heat_rate_w,
		"assumption": "Uniform component temperature; constant properties and convection coefficient; no radiation or internal heat generation."
	}
