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
	if instance.get_node_or_null("Camera3D") != null:
		push_error("Workshop should own a dynamically created camera, not a duplicated fixed node")
		failures += 1
	var spinboxes := instance.find_children("*", "SpinBox", true, false)
	if spinboxes.size() != 14:
		push_error("Workshop did not create six geometry and eight component-mass controls")
		failures += 1
	var material_options := instance.find_children("*", "OptionButton", true, false)
	if material_options.size() != 1:
		push_error("Workshop material selector is missing")
		failures += 1
	var component_list := instance.find_children("*", "ItemList", true, false)
	if component_list.size() != 1:
		push_error("Workshop component hierarchy list is missing")
		failures += 1
	var visuals := ["FuelTankVisual", "OxidizerTankVisual", "EngineVisual", "NozzleVisual", "PayloadVisual", "AvionicsVisual", "RecoveryVisual", "ExternalSensorVisual", "StructuralSupportVisual"]
	for visual_name in visuals:
		if instance.get_node_or_null("FuelTankVisual") == null and visual_name == "FuelTankVisual":
			push_error("Workshop tank visual is missing")
			failures += 1
		elif instance.get_node_or_null(visual_name) == null:
			push_error("Workshop subassembly visual is missing: %s" % visual_name)
			failures += 1
	var mass_inputs: Dictionary = instance.get("component_mass_inputs")
	mass_inputs["payload"].value = 1.25
	instance.call("_update_model")
	if absf(float(instance.configuration.get_mass_breakdown().total_mass_kg) - (float(instance.configuration.get_mass_breakdown().total_mass_kg))) > 0.000001 or instance.configuration.components.size() != 6:
		push_error("Workshop did not include user-entered payload mass in the bill of materials")
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
	instance.queue_free()
	if failures == 0:
		print("REEVE workshop checks: PASS")
	quit(failures)
