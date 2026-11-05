class_name ReeveRocketConfiguration
extends RefCounted
## Editable conceptual vehicle bill of materials and mass roll-up.

var vehicle_name: String = "REEVE Educational Vehicle"
var components: Array[ReeveRocketComponent] = []

func add_component(component: ReeveRocketComponent) -> bool:
	if component == null or not component.validate().is_empty():
		return false
	for existing in components:
		if existing.component_id == component.component_id:
			return false
	components.append(component)
	return true

func remove_component(component_id: String) -> bool:
	for index in range(components.size()):
		if components[index].component_id == component_id:
			components.remove_at(index)
			return true
	return false

func get_mass_breakdown() -> Dictionary:
	var total_mass: float = 0.0
	var category_totals: Dictionary = {}
	var records: Array[Dictionary] = []
	for component in components:
		var mass: float = component.calculate_mass_kg()
		if mass < 0.0:
			continue
		total_mass += mass
		category_totals[component.category] = float(category_totals.get(component.category, 0.0)) + mass
		records.append(component.to_record())
	return {
		"vehicle_name": vehicle_name,
		"component_count": records.size(),
		"total_mass_kg": total_mass,
		"category_totals_kg": category_totals,
		"components": records
	}

func save_to_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var data: Dictionary = {
		"schema_version": 1,
		"vehicle_name": vehicle_name,
		"components": get_mass_breakdown().components
	}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK

func load_from_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		return ERR_INVALID_DATA
	var loaded: Array[ReeveRocketComponent] = []
	for record in parsed.get("components", []):
		if not record is Dictionary:
			return ERR_INVALID_DATA
		var component := ReeveRocketComponent.new()
		component.component_id = str(record.get("id", ""))
		component.display_name = str(record.get("name", "Component"))
		component.category = str(record.get("category", "Structure"))
		component.material_id = str(record.get("material_id", ""))
		component.geometry_type = str(record.get("geometry_type", ""))
		component.dimensions_m = record.get("dimensions_m", {})
		component.user_mass_kg = float(record.get("mass_kg", 0.0))
		if not component.validate().is_empty():
			return ERR_INVALID_DATA
		loaded.append(component)
	vehicle_name = str(parsed.get("vehicle_name", "REEVE Educational Vehicle"))
	components = loaded
	return OK
