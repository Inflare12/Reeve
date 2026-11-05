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
	if spinboxes.size() != 6:
		push_error("Workshop did not create its three geometry controls")
		failures += 1
	var material_options := instance.find_children("*", "OptionButton", true, false)
	if material_options.size() != 1:
		push_error("Workshop material selector is missing")
		failures += 1
	var labels := instance.find_children("*", "Label", true, false)
	var found_mass := false
	for label in labels:
		if label.text.contains("Estimated fuselage mass") and label.text.contains("Estimated fin set mass"):
			found_mass = true
	if not found_mass:
		push_error("Workshop did not calculate an initial shell mass")
		failures += 1
	instance.queue_free()
	if failures == 0:
		print("REEVE workshop checks: PASS")
	quit(failures)
