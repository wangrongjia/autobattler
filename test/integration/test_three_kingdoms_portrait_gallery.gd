extends SceneTree

func _initialize() -> void:
	var game = load("res://ThreeKingdom/ThreeKingdom.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tick_timer.stop()

	# New PNG portraits take priority.
	assert(game._portrait_source_texture("liubei").resource_path.ends_with("/pic/liubei.png"))
	assert(game._portrait_source_texture("caocao").resource_path.ends_with("/pic/caocao.png"))
	assert(game._portrait_source_texture("dailaidongzhu").resource_path.ends_with("/pic/dailaidongzhu.png"))
	assert(game._portrait_source_texture("taishici").resource_path.ends_with("/pic/taishici.png"))
	assert(game._portrait_source_texture("dingfeng").resource_path.ends_with("/pic/dingfeng.png"))
	assert(not game.heroes.has("jiangqin"))

	# Hero artwork is hidden by default in both cards and enlarged entries.
	game.show_hero_codex_images = false
	game._show_encyclopedia()
	assert(game.encyclopedia_preview_hero_ids.size() == 15)
	assert(game.encyclopedia_grid.get_child(0).find_child("HeroPortrait", true, false) == null)
	game._show_encyclopedia_preview("liubei")
	assert(game.encyclopedia_preview_overlay.visible)
	assert(not game.encyclopedia_preview_portrait.visible)
	assert(game.encyclopedia_preview_portrait.texture == null)
	assert(not game.encyclopedia_preview_detail.text.is_empty())
	game._hide_encyclopedia_preview()

	# Enabling the persisted setting restores card and enlarged artwork.
	game._toggle_hero_codex_images_setting()
	await process_frame
	assert(game.show_hero_codex_images)
	assert(game.hero_codex_images_setting_button.text.contains("开启") or game.hero_codex_images_setting_button.text.contains("ON"))
	assert(game.encyclopedia_grid.get_child(0).find_child("HeroPortrait", true, false) != null)
	game._show_encyclopedia_preview("liubei")
	assert(game.encyclopedia_preview_portrait.visible)
	assert(game.encyclopedia_preview_portrait.texture.resource_path.ends_with("/pic/liubei.png"))
	var first_index: int = game.encyclopedia_preview_index
	game._step_encyclopedia_preview(-1)
	assert(game.encyclopedia_preview_index == game.encyclopedia_preview_hero_ids.size() - 1)
	game._step_encyclopedia_preview(1)
	assert(game.encyclopedia_preview_index == first_index)
	game._hide_encyclopedia_preview()
	assert(not game.encyclopedia_preview_overlay.visible)
	game._toggle_hero_codex_images_setting()
	assert(not game.show_hero_codex_images)

	# Weapon codex is a separate tab with all 15 supplied Shu weapons,
	# ownership labels, enlarged artwork and wraparound browsing.
	game._set_encyclopedia_mode("weapons")
	await process_frame
	assert(game.encyclopedia_mode == "weapons")
	assert(not game.encyclopedia_hero_filters.visible)
	assert(game.encyclopedia_grid.get_child_count() == 15)
	assert(game.encyclopedia_preview_hero_ids.size() == 15)
	for weapon in game.SHU_WEAPON_CODEX:
		assert(ResourceLoader.exists(str(weapon.path)))
	game._show_encyclopedia_preview("liubei")
	assert(game.encyclopedia_preview_overlay.visible)
	assert(game.encyclopedia_preview_portrait.texture.resource_path.ends_with("/weapon/shuanggujian.png"))
	assert(game.encyclopedia_preview_name.text.contains("双股剑") or game.encyclopedia_preview_name.text.contains("Twin Swords"))
	assert(game.encyclopedia_preview_detail.text.contains("刘备") or game.encyclopedia_preview_detail.text.contains("Liu Bei"))
	game._step_encyclopedia_preview(-1)
	assert(game.encyclopedia_preview_index == game.SHU_WEAPON_CODEX.size() - 1)
	assert(game.encyclopedia_preview_name.text.contains("蛮骨狼牙棒") or game.encyclopedia_preview_name.text.contains("Wolf-Fang Mace"))
	game._hide_encyclopedia_preview()

	# Bond graph is a third codex tab. It exposes every hero, faction bond,
	# special bond and connection in a pannable/zoomable GraphEdit.
	game._set_encyclopedia_mode("bonds")
	await process_frame
	await process_frame
	assert(game.encyclopedia_mode == "bonds")
	assert(game.encyclopedia_bond_graph.visible)
	assert(not game.encyclopedia_content_scroll.visible)
	assert(game.encyclopedia_star_filter_buttons.all(func(button): return not button.visible))
	assert(game.encyclopedia_bond_reset_button.visible)
	var shu_graph_nodes: Array = game.encyclopedia_bond_graph.get_children().filter(func(child): return child is GraphNode)
	assert(shu_graph_nodes.size() == 30)
	assert(game.encyclopedia_bond_graph.get_connection_list().size() == 32)
	assert(game.encyclopedia_bond_graph.has_node("hero_dailaidongzhu"))
	assert(game.encyclopedia_bond_graph.has_node("bond_sibling_bond"))
	game.encyclopedia_bond_graph.get_node("hero_liubei").position_offset = Vector2(9999, 9999)
	game.encyclopedia_bond_reset_button.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(game.encyclopedia_bond_graph.get_node("hero_liubei").position_offset != Vector2(9999, 9999))
	assert(game.encyclopedia_bond_graph.get_connection_list().size() == 32)
	# Selecting a node keeps its direct neighborhood clear and fades the rest.
	var liubei_node: GraphNode = game.encyclopedia_bond_graph.get_node("hero_liubei")
	game._on_encyclopedia_bond_node_selected(liubei_node)
	assert(game.encyclopedia_bond_graph.get_node("bond_peach_garden").modulate.a == 1.0)
	assert(game.encyclopedia_bond_graph.get_node("hero_dailaidongzhu").modulate.a < 0.5)
	assert(game.encyclopedia_bond_label.text.contains("刘备") or game.encyclopedia_bond_label.text.contains("Liu Bei"))
	game._on_encyclopedia_bond_node_deselected(liubei_node)
	assert(game.encyclopedia_bond_graph.get_node("hero_dailaidongzhu").modulate.a == 1.0)
	var faction_graph_sizes := {
		"wei":[18, 14],
		"wu":[28, 28],
		"qun":[18, 14],
	}
	for faction in faction_graph_sizes:
		game._set_encyclopedia_faction(faction)
		await process_frame
		await process_frame
		var graph_nodes: Array = game.encyclopedia_bond_graph.get_children().filter(func(child): return child is GraphNode)
		assert(graph_nodes.size() == faction_graph_sizes[faction][0])
		assert(game.encyclopedia_bond_graph.get_connection_list().size() == faction_graph_sizes[faction][1])
		if faction == "wu":
			assert(game.encyclopedia_bond_graph.has_node("hero_taishici"))
			assert(game.encyclopedia_bond_graph.has_node("hero_dingfeng"))
			assert(game.encyclopedia_bond_graph.has_node("bond_shenting_duel"))
			assert(game.encyclopedia_bond_graph.has_node("bond_tiger_ministers"))
			assert(not game.encyclopedia_bond_graph.has_node("hero_jiangqin"))

	game._set_encyclopedia_mode("heroes")
	game._set_encyclopedia_faction("shu")
	await process_frame
	assert(game.encyclopedia_hero_filters.visible)
	assert(game.encyclopedia_content_scroll.visible)
	assert(game.encyclopedia_grid.get_child_count() == 15)
	game._show_encyclopedia_preview("dailaidongzhu")
	assert(game.encyclopedia_preview_name.text.contains("带来洞主") or game.encyclopedia_preview_name.text.contains("Dailai Dongzhu"))
	assert(game.encyclopedia_preview_detail.text.contains("蛮骨狼袭") or game.encyclopedia_preview_detail.text.contains("Savage-Bone"))

	quit()
