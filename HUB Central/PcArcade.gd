extends Node2D

# Arcade désactivée — le PC ne fait plus rien

func _ready() -> void:
	hide()
	process_mode = PROCESS_MODE_DISABLED
