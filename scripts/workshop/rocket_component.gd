class_name ReeveRocketComponent
extends RefCounted
## Geometry-based mass estimator for simple educational component shapes.
## Not a structural sizing or flight-readiness calculation.

var component_id: String = ""
var display_name: String = "Component"
var category: String = "Structure"
var material_id: String = "aluminium_6061_t6"
var geometry_type: String = "user_mass"
var dimensions_m: Dictionary = {}
var user_mass_kg: float = 0.0

func validate() -> String:
	if component_id.strip_edges().is_empty():
		return "Component ID cannot be empty."
	if display_name.strip_edges().is_empty():
		return "Component name cannot be empty."
	if ReeveMaterialCatalog.get_material(material_id).is_empty():
		return "Unknown material ID: %s" % material_id
	match geometry_type:
		"cylinder_shell":
			var radius: float = float(dimensions_m.get("outer_radius", 0.0))
			var thickness: float = float(dimensions_m.get("wall_thickness", 0.0))
			var length: float = float(dimensions_m.get("length", 0.0))
			if radius <= 0.0 or thickness <= 0.0 or length <= 0.0 or thickness >= radius:
				return "Cylinder shell requires positive radius, thickness and length; thickness must be less than radius."
		"rectangular_plate":
			if float(dimensions_m.get("length", 0.0)) <= 0.0 or float(dimensions_m.get("width", 0.0)) <= 0.0 or float(dimensions_m.get("thickness", 0.0)) <= 0.0:
				return "Plate length, width and thickness must be positive."
		"user_mass":
			if user_mass_kg < 0.0 or not is_finite(user_mass_kg):
				return "User-supplied mass must be finite and non-negative."
		_:
			return "Unsupported geometry type: %s" % geometry_type
	return ""

func calculate_mass_kg() -> float:
	if not validate().is_empty():
		return -1.0
	var material := ReeveMaterialCatalog.get_material(material_id)
	var density: float = float(material.density_kg_m3)
	var volume_m3: float = 0.0
	match geometry_type:
		"cylinder_shell":
			var outer_radius: float = float(dimensions_m.outer_radius)
			var inner_radius: float = outer_radius - float(dimensions_m.wall_thickness)
			var length: float = float(dimensions_m.length)
			volume_m3 = PI * (outer_radius * outer_radius - inner_radius * inner_radius) * length
		"rectangular_plate":
			volume_m3 = float(dimensions_m.length) * float(dimensions_m.width) * float(dimensions_m.thickness)
		"user_mass":
			return user_mass_kg
	return volume_m3 * density

func to_record() -> Dictionary:
	return {
		"id": component_id,
		"name": display_name,
		"category": category,
		"material_id": material_id,
		"geometry_type": geometry_type,
		"dimensions_m": dimensions_m.duplicate(true),
		"mass_kg": calculate_mass_kg()
	}
