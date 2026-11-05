class_name ReeveStructuralEstimate
extends RefCounted
## Linear-elastic, uniform-member axial tension estimate.
## Not a pressure-vessel, shell-buckling, fatigue, joint or flight-qualification model.

static func calculate_axial_tension(
	material_id: String,
	cross_section_area_m2: float,
	gauge_length_m: float,
	tensile_force_n: float
) -> Dictionary:
	if not is_finite(cross_section_area_m2) or cross_section_area_m2 <= 0.0:
		return {"ok": false, "error": "Cross-sectional area must be finite and positive."}
	if not is_finite(gauge_length_m) or gauge_length_m <= 0.0:
		return {"ok": false, "error": "Gauge length must be finite and positive."}
	if not is_finite(tensile_force_n) or tensile_force_n < 0.0:
		return {"ok": false, "error": "Tensile force must be finite and non-negative."}
	var material: Dictionary = ReeveMaterialCatalog.get_material(material_id)
	if material.is_empty():
		return {"ok": false, "error": "Unknown material ID."}
	var youngs_modulus_pa: float = float(material.get("youngs_modulus_pa", 0.0))
	if not is_finite(youngs_modulus_pa) or youngs_modulus_pa <= 0.0:
		return {"ok": false, "error": "Material has no usable Young's modulus."}
	var yield_strength_pa: float = float(material.get("yield_strength_pa", 0.0))
	var ultimate_strength_pa: float = float(material.get("ultimate_tensile_strength_pa", 0.0))
	var reference_strength_pa: float
	var strength_basis: String
	if yield_strength_pa > 0.0:
		reference_strength_pa = yield_strength_pa
		strength_basis = "nominal_yield_strength"
	else:
		reference_strength_pa = ultimate_strength_pa
		strength_basis = "nominal_ultimate_tensile_strength"
	if not is_finite(reference_strength_pa) or reference_strength_pa <= 0.0:
		return {"ok": false, "error": "Material has no usable tensile reference strength."}
	var stress_pa: float = tensile_force_n / cross_section_area_m2
	var strain: float = stress_pa / youngs_modulus_pa
	var deformation_m: float = strain * gauge_length_m
	var safety_factor: Variant = null
	if stress_pa > 0.0:
		safety_factor = reference_strength_pa / stress_pa
	return {
		"ok": true,
		"material_id": material_id,
		"material_name": str(material.name),
		"strength_basis": strength_basis,
		"cross_section_area_m2": cross_section_area_m2,
		"gauge_length_m": gauge_length_m,
		"tensile_force_n": tensile_force_n,
		"axial_stress_pa": stress_pa,
		"elastic_strain": strain,
		"elastic_deformation_m": deformation_m,
		"reference_strength_pa": reference_strength_pa,
		"reference_strength_factor": safety_factor,
		"assumptions": [
			"Uniform prismatic cross-section",
			"Small-strain linear elasticity",
			"Uniaxial tensile loading",
			"Room-temperature nominal catalogue properties",
			"No stress concentrations, joints, defects, fatigue or thermal effects"
		],
		"warning": "Reference strength factor is not a design safety factor or flight qualification."
	}
