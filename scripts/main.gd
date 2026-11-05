extends Node3D

@onready var status_label: Label = $CanvasLayer/Panel/Info/Status
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	status_label.text = "READY — no propulsion profile loaded. No flight has been simulated."
	var workshop_button := Button.new()
	workshop_button.text = "Open Rocket Workshop"
	workshop_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/workshop/workshop.tscn")
	)
	$CanvasLayer/Panel/Info.add_child(workshop_button)
