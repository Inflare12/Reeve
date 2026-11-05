class_name ReeveMaterialCatalog
extends RefCounted
## Representative room-temperature material properties for educational mass/elastic estimates.
## Values are approximate nominal references, not certified allowables or design data.

const MATERIALS: Dictionary = {
	"aluminium_6061_t6": {
		"name": "Aluminium 6061-T6",
		"category": "Aluminium alloy",
		"density_kg_m3": 2700.0,
		"youngs_modulus_pa": 68.9e9,
		"poisson_ratio": 0.33,
		"yield_strength_pa": 276.0e6,
		"ultimate_tensile_strength_pa": 310.0e6,
		"thermal_conductivity_w_mk": 167.0,
		"specific_heat_j_kgk": 896.0,
		"service_temperature_note": "Property-dependent; do not use as a temperature rating"
	},
	"stainless_304": {
		"name": "Stainless steel 304",
		"category": "Stainless steel",
		"density_kg_m3": 8000.0,
		"youngs_modulus_pa": 193.0e9,
		"poisson_ratio": 0.29,
		"yield_strength_pa": 215.0e6,
		"ultimate_tensile_strength_pa": 505.0e6,
		"thermal_conductivity_w_mk": 16.2,
		"specific_heat_j_kgk": 500.0,
		"service_temperature_note": "Property-dependent; do not use as a temperature rating"
	},
	"titanium_grade_5": {
		"name": "Titanium Ti-6Al-4V (Grade 5)",
		"category": "Titanium alloy",
		"density_kg_m3": 4430.0,
		"youngs_modulus_pa": 114.0e9,
		"poisson_ratio": 0.34,
		"yield_strength_pa": 880.0e6,
		"ultimate_tensile_strength_pa": 950.0e6,
		"thermal_conductivity_w_mk": 6.7,
		"specific_heat_j_kgk": 560.0,
		"service_temperature_note": "Property-dependent; do not use as a temperature rating"
	},
	"fibreglass_generic": {
		"name": "Fibreglass composite (generic)",
		"category": "Composite",
		"density_kg_m3": 1850.0,
		"youngs_modulus_pa": 25.0e9,
		"poisson_ratio": 0.25,
		"yield_strength_pa": 0.0,
		"ultimate_tensile_strength_pa": 350.0e6,
		"thermal_conductivity_w_mk": 0.35,
		"specific_heat_j_kgk": 800.0,
		"service_temperature_note": "Strongly dependent on fibre, resin, layup and cure"
	},
	"carbon_fibre_generic": {
		"name": "Carbon-fibre composite (generic)",
		"category": "Composite",
		"density_kg_m3": 1600.0,
		"youngs_modulus_pa": 70.0e9,
		"poisson_ratio": 0.28,
		"yield_strength_pa": 0.0,
		"ultimate_tensile_strength_pa": 600.0e6,
		"thermal_conductivity_w_mk": 5.0,
		"specific_heat_j_kgk": 800.0,
		"service_temperature_note": "Strongly dependent on fibre direction, resin, layup and cure"
	}
}

static func get_material(material_id: String) -> Dictionary:
	if not MATERIALS.has(material_id):
		return {}
	return MATERIALS[material_id].duplicate(true)

static func get_material_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for material_id in MATERIALS.keys():
		ids.append(str(material_id))
	ids.sort()
	return ids
