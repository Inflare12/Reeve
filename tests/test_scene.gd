extends SceneTree
## Instantiates the main scene and checks required 3D nodes/resources.

func _initialize() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	if packed == null:
		push_error("Main scene failed to load")
		quit(1)
		return

	var instance := packed.instantiate()
	if instance == null:
		push_error("Main scene failed to instantiate")
		quit(1)
		return

	root.add_child(instance)
	var fuselage := instance.get_node_or_null("RocketVisual/Fuselage") as MeshInstance3D
	var nose := instance.get_node_or_null("RocketVisual/NoseCone") as MeshInstance3D
	var camera := instance.get_node_or_null("Camera3D") as Camera3D
	var status := instance.get_node_or_null("CanvasLayer/Panel/Info/Status") as Label

	var failures := 0
	if fuselage == null or not (fuselage.mesh is CylinderMesh):
		push_error("Fuselage mesh is missing or invalid")
		failures += 1
	if nose == null or not (nose.mesh is CylinderMesh):
		push_error("Nose cone mesh is missing or invalid")
		failures += 1
	if camera == null or not camera.current:
		push_error("Main camera is missing or not current")
		failures += 1
	if status == null or not status.text.contains("no propulsion profile"):
		push_error("Scene status does not clearly describe idle state")
		failures += 1

	instance.queue_free()
	if failures == 0:
		print("REEVE scene checks: PASS")
	quit(failures)
