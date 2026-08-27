extends SceneTree

const OUTPUT_DIR := "res://TapTapAssets/captures"

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

	# Build a real three-hero formation through the same game flow used by players.
	for _pick in range(3):
		game._choose_hero(game.choices[0])
	game._auto_place_player()
	game._start_battle()
	game.battle_speed = 1.0
	await _wait_seconds(1.5)
	await _save_frame("battle-opening.png")
	await _wait_seconds(5.0)
	await _save_frame("battle-mid.png")
	await _wait_seconds(5.0)
	await _save_frame("battle-late.png")
	await _wait_seconds(2.5)
	quit()


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _save_frame(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename)
	var error := image.save_png(output_path)
	print(filename, " size=", image.get_size(), " result=", error)
	assert(error == OK)
