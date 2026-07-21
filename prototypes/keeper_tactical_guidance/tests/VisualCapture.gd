extends SceneTree

const ENTRY_SCENE: String = "res://prototypes/keeper_tactical_guidance/KeeperTacticalGuidance.tscn"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var width: int = 1440
	var height: int = 900
	var output_path: String = "/tmp/keeper_tactical_guidance_desktop.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--width="):
			width = maxi(640, int(argument.trim_prefix("--width=")))
		elif argument.begins_with("--height="):
			height = maxi(480, int(argument.trim_prefix("--height=")))
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	root.size = Vector2i(width, height)
	var packed: PackedScene = load(ENTRY_SCENE)
	if packed == null:
		push_error("Visual capture could not load the prototype entry scene.")
		quit(1)
		return
	root.add_child(packed.instantiate())
	await process_frame
	await process_frame
	await process_frame
	var texture: ViewportTexture = root.get_texture()
	if texture == null:
		push_error("Visual capture requires a rendering display; the dummy headless renderer has no viewport texture.")
		quit(1)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("Visual capture could not write %s." % output_path)
		quit(1)
		return
	print("Captured %dx%d prototype viewport to %s" % [width, height, output_path])
	quit(0)
