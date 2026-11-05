extends Node3D

@onready var status_label: Label = $CanvasLayer/Panel/Info/Status
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	status_label.text = "READY — no propulsion profile loaded. No flight has been simulated."
