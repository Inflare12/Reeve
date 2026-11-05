extends SceneTree
## Headless smoke test for the interactive workshop scene.

func _initialize() -> void:
	var packed := load("res://scenes/workshop/workshop.tscn") as PackedScene
	if packed == null:
		push_error("Workshop scene failed to load")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	var failures := 0
	if instance.get_node_or_null("WorkshopCamera") == null:
		push_error("Workshop camera is missing")
		failures += 1
	var spinboxes := instance.find_children("*", "SpinBox", true, false)
	if spinboxes.size() != 14:
		push_error("Workshop did not create six geometry and eight component-mass controls")
		failures += 1
	var material_options := instance.find_children("*", "OptionButton", true, false)
	if material_options.size() != 1:
		push_error("Workshop material selector is missing")
		failures += 1
	if instance.find_child("SaveAndOpenFlightLabButton", true, false) == null:
		push_error("Workshop save-and-handoff button is missing")
		failures += 1
	var component_lists := instance.find_children("*", "ItemList", true, false)
	if component_lists.size() != 1:
		push_error("Workshop component hierarchy list is missing")
		failures += 1
	else:
		var component_list := component_lists[0] as ItemList
		if str(component_list.get_item_metadata(0)) != "main_fuselage":
			push_error("Workshop component hierarchy metadata is missing")
			failures += 1
		instance.call("_on_component_selected", 0)
		var selection_label: Label = instance.get("selected_component_label")
		if selection_label == null or not selection_label.text.contains("Main fuselage shell"):
			push_error("Workshop component inspection did not show selected component details")
			failures += 1
	var visuals := ["FuelTankVisual", "OxidizerTankVisual", "EngineVisual", "NozzleVisual", "PayloadVisual", "AvionicsVisual", "RecoveryVisual", "ExternalSensorVisual", "StructuralSupportVisual"]
	for visual_name in visuals:
		if instance.get_node_or_null("RocketVisual/" + visual_name) == null:
			push_error("Workshop subassembly visual is missing: %s" % visual_name)
			failures += 1
	var labels := instance.find_children("*", "Label", true, false)
	var found_mass := false
	for label in labels:
		if label.text.contains("Estimated fuselage mass") and label.text.contains("Estimated fin set mass"):
			found_mass = true
	if not found_mass:
		push_error("Workshop did not calculate initial fuselage and fin masses")
		failures += 1
	if instance.configuration.components.size() != 5:
		push_error("Workshop did not create one fuselage and four fin component records")
		failures += 1
	var baseline_mass: float = float(instance.configuration.get_mass_breakdown().total_mass_kg)
	var mass_inputs: Dictionary = instance.get("component_mass_inputs")
	mass_inputs["payload"].value = 1.25
	var updated_mass: float = float(instance.configuration.get_mass_breakdown().total_mass_kg)
	if instance.configuration.components.size() != 6 or absf(updated_mass - baseline_mass - float(mass_inputs["payload"].value)) > 0.000001:
		push_error("Payload mass roll-up failed input=%.3f count=%d base=%.3f updated=%.3f" % [float(mass_inputs["payload"].value), instance.configuration.components.size(), baseline_mass, updated_mass])
		failures += 1
	instance.call("_save_configuration")
	mass_inputs["payload"].value = 0.0
	instance.call("_load_configuration")
	if absf(float(mass_inputs["payload"].value) - 1.3) > 0.000001:
		push_error("Workshop save/load did not preserve the user-entered payload mass")
		failures += 1
	if FileAccess.file_exists("user://reeve_vehicle.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://reeve_vehicle.json"))
	instance.queue_free()
	if failures == 0:
		print("REEVE workshop checks: PASS")
	quit(failures)
