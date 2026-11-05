extends Node3D
## Lightweight interactive geometry/mass workshop. Estimates are educational only.

var body_length: SpinBox
var body_diameter: SpinBox
var wall_thickness: SpinBox
var fin_count: SpinBox
var fin_span: SpinBox
var fin_chord: SpinBox
var material_select: OptionButton
var mass_label: Label
var rocket_visual: Node3D
var component_list: ItemList
var component_mass_inputs: Dictionary = {}
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
	camera.name = "WorkshopCamera"
	camera.position = Vector3(8.0, 5.0, 10.0)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)

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
	rocket_visual.name = "RocketVisual"
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
	fin_count = _add_spinbox(column, "Fin count", 3.0, 6.0, 4.0, 1.0, 0)
	fin_span = _add_spinbox(column, "Fin span (m)", 0.05, 0.5, 0.18, 0.01, 2)
	fin_chord = _add_spinbox(column, "Fin chord (m)", 0.1, 1.0, 0.35, 0.01, 2)

	var component_heading := Label.new()
	component_heading.text = "Additional component masses (user-entered kg)"
	column.add_child(component_heading)
	var mass_fields := {
		"fuel_tank": "Fuel tank assembly mass",
		"oxidizer_tank": "Oxidizer tank assembly mass",
		"engine": "Engine assembly mass",
		"payload": "Payload mass",
		"avionics": "Avionics mass",
		"recovery": "Recovery system mass",
		"sensors": "External sensors mass",
		"supports": "Internal supports mass"
	}
	for component_key in mass_fields:
		var mass_input := _add_spinbox(column, str(mass_fields[component_key]), 0.0, 10000.0, 0.0, 0.1, 2)
		component_mass_inputs[component_key] = mass_input

	var material_label := Label.new()
	material_label.text = "Material"
	column.add_child(material_label)
	material_select = OptionButton.new()
	for material_id in ReeveMaterialCatalog.get_material_ids():
		var material := ReeveMaterialCatalog.get_material(material_id)
		material_select.add_item(str(material.name))
		material_select.set_item_metadata(material_select.item_count - 1, material_id)
	if material_select.item_count > 0:
		material_select.select(0)
	column.add_child(material_select)
	material_select.item_selected.connect(_on_parameters_changed)

	mass_label = Label.new()
	mass_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(mass_label)

	var hierarchy_label := Label.new()
	hierarchy_label.text = "Vehicle component hierarchy / mass inclusion"
	column.add_child(hierarchy_label)
	component_list = ItemList.new()
	component_list.custom_minimum_size = Vector2(300.0, 130.0)
	column.add_child(component_list)

	var disclaimer := Label.new()
	disclaimer.text = "Mass assumes a uniform cylindrical shell. No joints, reinforcements, cut-outs, loads or thermal qualification are modelled."
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(disclaimer)

	var save_button := Button.new()
	save_button.text = "Save Vehicle"
	save_button.pressed.connect(_save_configuration)
	column.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Load Vehicle"
	load_button.pressed.connect(_load_configuration)
	column.add_child(load_button)

	var return_button := Button.new()
	return_button.text = "Back to Flight Lab"
	return_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	)
	column.add_child(return_button)

	for control in [body_length, body_diameter, wall_thickness, fin_count, fin_span, fin_chord]:
		control.value_changed.connect(_on_parameters_changed)
	for mass_input in component_mass_inputs.values():
		mass_input.value_changed.connect(_on_parameters_changed)

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
	var fin_thickness_m: float = 0.005
	var fin_masses: float = 0.0
	for fin_index in range(int(fin_count.value)):
		var fin_component := ReeveRocketComponent.new()
		fin_component.component_id = "fin_%d" % fin_index
		fin_component.display_name = "Fin %d" % (fin_index + 1)
		fin_component.category = "Stabilizing surfaces"
		fin_component.material_id = material_id
		fin_component.geometry_type = "rectangular_plate"
		fin_component.dimensions_m = {
			"length": fin_chord.value,
			"width": fin_span.value,
			"thickness": fin_thickness_m
		}
		configuration.add_component(fin_component)
		fin_masses += fin_component.calculate_mass_kg()
	var mass_categories := {
		"fuel_tank": "Propellant tank representation",
		"oxidizer_tank": "Oxidizer tank representation",
		"engine": "Engine assembly",
		"payload": "Payload",
		"avionics": "Avionics compartment",
		"recovery": "Recovery system",
		"sensors": "External sensors",
		"supports": "Structural supports"
	}
	for component_key in component_mass_inputs:
		var entered_mass: float = float(component_mass_inputs[component_key].value)
		if entered_mass <= 0.0:
			continue
		var mass_component := ReeveRocketComponent.new()
		mass_component.component_id = "mass_%s" % component_key
		mass_component.display_name = str(mass_categories[component_key])
		mass_component.category = str(mass_categories[component_key])
		mass_component.material_id = material_id
		mass_component.geometry_type = "user_mass"
		mass_component.user_mass_kg = entered_mass
		configuration.add_component(mass_component)
	var material := ReeveMaterialCatalog.get_material(material_id)
	var total_mass: float = float(configuration.get_mass_breakdown().total_mass_kg)
	var additional_mass: float = total_mass - mass - fin_masses
	mass_label.text = "Estimated fuselage mass: %.3f kg\nEstimated fin set mass: %.3f kg\nUser-entered additional mass: %.3f kg\nTotal modelled mass: %.3f kg\nMaterial density: %.0f kg/m³\nMass-counted components: %d" % [
		mass, fin_masses, additional_mass, total_mass, float(material.density_kg_m3), configuration.components.size()
	]
	component_list.clear()
	component_list.add_item("Main fuselage shell — %.3f kg" % mass)
	for fin_index in range(int(fin_count.value)):
		component_list.add_item("Fin %d — included in mass" % (fin_index + 1))
	for component_key in component_mass_inputs:
		var entered_mass: float = float(component_mass_inputs[component_key].value)
		var category_name: String = str(mass_categories[component_key])
		component_list.add_item("%s — %.3f kg%s" % [category_name, entered_mass, "" if entered_mass > 0.0 else " (not included)"])

	for child in rocket_visual.get_children():
		rocket_visual.remove_child(child)
		child.free()
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

	for fin_index in range(int(fin_count.value)):
		var angle: float = TAU * float(fin_index) / float(fin_count.value)
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(fin_span.value, fin_chord.value, fin_thickness_m)
		var fin := MeshInstance3D.new()
		fin.mesh = fin_mesh
		fin.position = Vector3(
			cos(angle) * (radius + fin_span.value * 0.5),
			fin_chord.value * 0.5,
			sin(angle) * (radius + fin_span.value * 0.5)
		)
		fin.rotation.y = -angle
		fin.material_override = shell_material
		rocket_visual.add_child(fin)

	# Distinct conceptual subassemblies are visualized separately. Their mass
	# enters the bill of materials only when the user supplies a mass above.
	var tank_material := _make_visual_material(Color(0.18, 0.48, 0.72))
	var tank_mesh := CylinderMesh.new()
	tank_mesh.top_radius = radius * 0.72
	tank_mesh.bottom_radius = radius * 0.72
	tank_mesh.height = body_length.value * 0.18
	_add_visual_component("FuelTankVisual", tank_mesh, Vector3(0.0, body_length.value * 0.34, 0.0), tank_material)
	var oxidizer_mesh := CylinderMesh.new()
	oxidizer_mesh.top_radius = radius * 0.72
	oxidizer_mesh.bottom_radius = radius * 0.72
	oxidizer_mesh.height = body_length.value * 0.18
	_add_visual_component("OxidizerTankVisual", oxidizer_mesh, Vector3(0.0, body_length.value * 0.58, 0.0), _make_visual_material(Color(0.22, 0.62, 0.48)))
	var payload_mesh := BoxMesh.new()
	payload_mesh.size = Vector3(radius * 1.15, body_length.value * 0.10, radius * 1.15)
	_add_visual_component("PayloadVisual", payload_mesh, Vector3(0.0, body_length.value * 0.86, 0.0), _make_visual_material(Color(0.82, 0.68, 0.32)))
	var avionics_mesh := BoxMesh.new()
	avionics_mesh.size = Vector3(radius * 0.75, body_length.value * 0.07, radius * 0.75)
	_add_visual_component("AvionicsVisual", avionics_mesh, Vector3(0.0, body_length.value * 0.72, 0.0), _make_visual_material(Color(0.38, 0.72, 0.76)))
	var recovery_mesh := CylinderMesh.new()
	recovery_mesh.top_radius = radius * 0.65
	recovery_mesh.bottom_radius = radius * 0.65
	recovery_mesh.height = body_length.value * 0.08
	_add_visual_component("RecoveryVisual", recovery_mesh, Vector3(0.0, body_length.value * 0.65, 0.0), _make_visual_material(Color(0.72, 0.42, 0.52)))
	var engine_mesh := CylinderMesh.new()
	engine_mesh.top_radius = radius * 0.58
	engine_mesh.bottom_radius = radius * 0.48
	engine_mesh.height = radius * 0.55
	_add_visual_component("EngineVisual", engine_mesh, Vector3(0.0, -radius * 0.28, 0.0), _make_visual_material(Color(0.48, 0.52, 0.58)))
	var nozzle_mesh := CylinderMesh.new()
	nozzle_mesh.top_radius = radius * 0.32
	nozzle_mesh.bottom_radius = radius * 0.62
	nozzle_mesh.height = radius * 0.65
	_add_visual_component("NozzleVisual", nozzle_mesh, Vector3(0.0, -radius * 0.88, 0.0), _make_visual_material(Color(0.34, 0.37, 0.42)))
	var sensor_mesh := SphereMesh.new()
	sensor_mesh.radius = maxf(radius * 0.08, 0.005)
	sensor_mesh.height = maxf(radius * 0.16, 0.01)
	_add_visual_component("ExternalSensorVisual", sensor_mesh, Vector3(radius * 1.05, body_length.value * 0.42, 0.0), _make_visual_material(Color(0.9, 0.45, 0.2)))
	var support_mesh := BoxMesh.new()
	support_mesh.size = Vector3(radius * 1.3, body_length.value * 0.025, radius * 0.08)
	_add_visual_component("StructuralSupportVisual", support_mesh, Vector3(0.0, body_length.value * 0.50, 0.0), _make_visual_material(Color(0.62, 0.65, 0.68)))

func _make_visual_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	return material

func _add_visual_component(node_name: String, mesh: Mesh, position_m: Vector3, material: StandardMaterial3D) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = position_m
	visual.material_override = material
	rocket_visual.add_child(visual)

func _save_configuration() -> void:
	var save_error := configuration.save_to_file("user://reeve_vehicle.json")
	if save_error == OK:
		mass_label.text += "\nSaved: user://reeve_vehicle.json"
	else:
		mass_label.text += "\nSave failed: %s" % error_string(save_error)

func _load_configuration() -> void:
	var loaded := ReeveRocketConfiguration.new()
	var load_error := loaded.load_from_file("user://reeve_vehicle.json")
	if load_error != OK:
		mass_label.text += "\nLoad failed: %s" % error_string(load_error)
		return
	if loaded.components.is_empty():
		mass_label.text += "\nConfiguration contains no components."
		return
	var component: ReeveRocketComponent = null
	var saved_fin: ReeveRocketComponent = null
	var saved_fin_count: int = 0
	for saved_component in loaded.components:
		if str(saved_component.component_id).begins_with("mass_"):
			var mass_key: String = str(saved_component.component_id).trim_prefix("mass_")
			if component_mass_inputs.has(mass_key):
				component_mass_inputs[mass_key].value = saved_component.user_mass_kg
		if saved_component.geometry_type == "cylinder_shell" and component == null:
			component = saved_component
		elif str(saved_component.component_id).begins_with("fin_"):
			saved_fin_count += 1
			if saved_fin == null:
				saved_fin = saved_component
	if component == null:
		mass_label.text += "\nFirst component is not a supported fuselage shell."
		return
	body_length.value = float(component.dimensions_m.get("length", body_length.value))
	body_diameter.value = float(component.dimensions_m.get("outer_radius", body_diameter.value * 0.5)) * 2.0
	wall_thickness.value = float(component.dimensions_m.get("wall_thickness", wall_thickness.value))
	if saved_fin != null:
		fin_count.value = saved_fin_count
		fin_span.value = float(saved_fin.dimensions_m.get("width", fin_span.value))
		fin_chord.value = float(saved_fin.dimensions_m.get("length", fin_chord.value))
	for index in range(material_select.item_count):
		if str(material_select.get_item_metadata(index)) == component.material_id:
			material_select.select(index)
			break
	configuration = loaded
	_update_model()
