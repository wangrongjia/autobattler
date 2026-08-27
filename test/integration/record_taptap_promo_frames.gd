extends SceneTree

const OUTPUT_DIR := "res://TapTapAssets/captures/combat-frames"
const FPS := 24
const DURATION_SECONDS := 14

var game


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame

	game.ui_theme = "light"
	game._rebuild_ui()
	await process_frame
	game.menu_overlay.hide()
	game._render()

	for _pick in range(3):
		game._choose_hero(game.choices[0])
	game._auto_place_player()
	game._start_battle()
	game.battle_speed = 1.0

	# Capture the game viewport itself so the video contains no desktop or window UI.
	# With --fixed-fps 24 each iteration advances one real gameplay frame.
	for frame_index in range(FPS * DURATION_SECONDS):
		await process_frame
		var image := root.get_texture().get_image()
		var filename := "frame-%04d.jpg" % frame_index
		var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename)
		var error := image.save_jpg(output_path, 0.9)
		if error != OK:
			push_error("Failed to save " + filename + ": " + str(error))
			quit(1)
			return

	print("Captured ", FPS * DURATION_SECONDS, " gameplay frames at ", FPS, " fps")
	quit()
