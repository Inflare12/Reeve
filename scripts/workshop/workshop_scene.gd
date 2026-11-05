extends Node3D
## Lightweight interactive geometry/mass workshop. Estimates are educational only.

var body_length: SpinBox
var body_diameter: SpinBox
var wall_thickness: SpinBox
var material_select: OptionButton
var mass_label: Label
var rocket_visual: Node3D
var configuration := ReeveRocketConfiguration.new()

func _ready() -> void:
	_build_environment()
	_build_interface()
	_update_model()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.075, 0.105)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.62, 0.75)
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	light.shadow_enabled = true
	add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(8.0, 5.0, 10.0)
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	ground.mesh = plane
	ground.position.y = -0.05
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.12, 0.16, 0.19)
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	add_child(ground)

	rocket_visual = Node3D.new()
	add_child(rocket_visual)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(350.0, 0.0)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "REEVE  /  ROCKET WORKSHOP"
	heading.add_theme_font_size_override("font_size", 21)
	column.add_child(heading)

	var note := Label.new()
	note.text = "Conceptual geometry and mass estimates • SI units"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

	body_length = _add_spinbox(column, "Body length (m)", 0.5, 12.0, 4.5, 0.1, 2)
	body_diameter = _add_spinbox(column, "Outer diameter (m)", 0.05, 1.0, 0.56, 0.01, 2)
	wall_thickness = _add_spinbox(column, "Wall thickness (m)", 0.0005, 0.02, 0.002, 0.0005, 4)

	var material_label := Label.new()
	material_label.text = "Material"
	column.add_child(material_label)
	material_select = OptionButton.new()
	for material_id in ReeveMaterialCatalog.get_material_ids():
		var material := ReeveMaterialCatalog.get_material(material_id)
		material_select.add_item(str(material.name))
		material_select.set_item_metadata(material_select.item_count - 1, material_id)
	column.add_child(material_select)
	material_select.item_selected.connect(_on_parameters_changed)

	mass_label = Label.new()
	mass_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(mass_label)

	var disclaimer := Label.new()
	disclaimer.text = "Mass assumes a uniform cylindrical shell. No joints, reinforcements, cut-outs, loads or thermal qualification are modelled."
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(disclaimer)

	var return_button := Button.new()
	return_button.text = "Back to Flight Lab"
	return_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	)
	column.add_child(return_button)

	for control in [body_length, body_diameter, wall_thickness]:
		control.value_changed.connect(_on_parameters_changed)

func _add_spinbox(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, initial: float, step: float, decimals: int) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = initial
	spin.step = step
	spin.rounded = false
	spin.custom_minimum_size.x = 150.0
	spin.get_line_edit().add_theme_font_size_override("font_size", 15)
	parent.add_child(spin)
	return spin

func _on_parameters_changed(_value: float = 0.0) -> void:
	_update_model()

func _update_model() -> void:
	if body_length == null or rocket_visual == null:
		return
	var radius: float = body_diameter.value * 0.5
	var wall: float = minf(wall_thickness.value, radius * 0.9)
	var material_id: String = str(material_select.get_item_metadata(material_select.selected))
	var component := ReeveRocketComponent.new()
	component.component_id = "main_fuselage"
	component.display_name = "Main fuselage shell"
	component.category = "Primary structure"
	component.material_id = material_id
	component.geometry_type = "cylinder_shell"
	component.dimensions_m = {
		"outer_radius": radius,
		"wall_thickness": wall,
		"length": body_length.value
	}
	var mass: float = component.calculate_mass_kg()
	configuration.components.clear()
	configuration.add_component(component)
	var material := ReeveMaterialCatalog.get_material(material_id)
	mass_label.text = "Estimated shell mass: %.3f kg\nMaterial density: %.0f kg/m³\nTotal modelled components: 1" % [
		mass, float(material.density_kg_m3)
	]

	for child in rocket_visual.get_children():
		child.queue_free()
	var shell_mesh := CylinderMesh.new()
	shell_mesh.top_radius = radius
	shell_mesh.bottom_radius = radius
	shell_mesh.height = body_length.value
	shell_mesh.radial_segments = 32
	var shell := MeshInstance3D.new()
	shell.mesh = shell_mesh
	shell.position.y = body_length.value * 0.5
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = Color(0.55, 0.63, 0.7)
	shell_material.metallic = 0.55
	shell_material.roughness = 0.35
	shell.material_override = shell_material
	rocket_visual.add_child(shell)

	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = radius
	nose_mesh.height = radius * 2.4
	nose_mesh.radial_segments = 32
	var nose := MeshInstance3D.new()
	nose.mesh = nose_mesh
	nose.position.y = body_length.value + radius * 1.2
	nose.material_override = shell_material
	rocket_visual.add_child(nose)
