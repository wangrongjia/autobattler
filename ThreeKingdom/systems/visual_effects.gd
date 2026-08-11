extends "res://ThreeKingdom/systems/balance_lab.gd"

var weapon_cutout_material: ShaderMaterial
var fire_effect_cutout_material: ShaderMaterial

func _play_visual_events(events: Array) -> void:
	var processed_groups := {}
	for event in events:
		var visual_group := str(event.get("visual_group", ""))
		if not visual_group.is_empty():
			if processed_groups.has(visual_group): continue
			var grouped_events: Array = events.filter(func(candidate): return str(candidate.get("visual_group", "")) == visual_group)
			var group_style := ""
			for candidate in grouped_events:
				if not str(candidate.get("group_style", "")).is_empty():
					group_style = str(candidate.group_style)
					break
			if group_style == "simultaneous":
				processed_groups[visual_group] = true
				await _play_grouped_auxiliary(grouped_events)
				continue
			if group_style in ["row_burn", "tile_burn", "burn_tick", "poison_tick", "poison_apply", "weak_apply", "fear_tick", "fireball_chain"] or grouped_events.any(func(candidate): return str(candidate.get("kind", "")) in ["damage", "empty"]):
				processed_groups[visual_group] = true
				await _play_grouped_damage(grouped_events)
				continue
		await _play_single_visual_event(event)

func _play_grouped_auxiliary(grouped_events: Array) -> void:
	var speed_scale := 1.0 / game_speed
	var last_tween: Tween
	for event in grouped_events:
		var target: Control = unit_cell_refs.get(str(event.get("target_id", "")))
		if not is_instance_valid(target): continue
		var kind := str(event.get("kind", ""))
		if kind in ["heal", "regen", "regen_apply"]:
			var healed_unit = _find_by_id(combat_units, str(event.get("target_id", "")))
			var health_bar: ProgressBar = health_bar_refs.get(str(event.get("target_id", "")))
			if healed_unit != null and is_instance_valid(health_bar): health_bar.value = float(healed_unit.hp)
			_floating_text(target, "+" + str(event.get("amount", 0)), Color("#77ff9c"))
			last_tween = create_tween()
			last_tween.tween_property(target, "modulate", Color("#77ff9c"), 0.10 * speed_scale)
			last_tween.tween_property(target, "modulate", Color.WHITE, 0.18 * speed_scale)
		elif kind == "skill":
			last_tween = create_tween()
			last_tween.tween_property(target, "scale", Vector2(1.10, 1.10), 0.10 * speed_scale)
			last_tween.parallel().tween_property(target, "modulate", Color("#d58dff"), 0.10 * speed_scale)
			last_tween.tween_property(target, "scale", Vector2.ONE, 0.16 * speed_scale)
			last_tween.parallel().tween_property(target, "modulate", Color.WHITE, 0.16 * speed_scale)
	if last_tween != null: await last_tween.finished

func _play_single_visual_event(event: Dictionary) -> void:
	var actor: Control = unit_cell_refs.get(event.get("source_id", ""))
	var target: Control = unit_cell_refs.get(event.get("target_id", ""))
	if not is_instance_valid(target) and event.has("team"):
		target = tile_cell_refs.get(str(event.team) + ":" + str(event.row) + ":" + str(event.col))
	if not is_instance_valid(target): return
	var speed_scale := 1.0 / game_speed
	var style: String = event.get("style", "magic" if event.get("skill", false) else "melee")
	var source_unit = _find_by_id(combat_units, str(event.get("source_id", "")))
	var profile := _hero_fx(str(source_unit.hero_id) if source_unit != null else "")
	var kind := str(event.get("kind", ""))
	if kind in ["damage", "heal", "empty"] and is_instance_valid(actor) and actor != target:
		if style == "melee": await _play_melee_strike(actor, target, speed_scale, profile, bool(event.get("skill", false)))
		elif style in ["ranged", "magic", "heal"]: await _play_projectile(actor, target, style, speed_scale, profile, bool(event.get("skill", false)))
	if not is_instance_valid(target): return
	match kind:
		"damage":
			_floating_damage_text(target, int(event.get("amount", 0)))
			var hit_tween := _start_hit_recoil(target, speed_scale)
			await hit_tween.finished
		"death":
			var death_tween := _start_death_ghost(target, str(event.get("target_id", "")), speed_scale)
			if death_tween != null: await death_tween.finished
		"heal", "regen", "regen_apply":
			var healed_unit = _find_by_id(combat_units, str(event.get("target_id", "")))
			var health_bar: ProgressBar = health_bar_refs.get(str(event.get("target_id", "")))
			if healed_unit != null and is_instance_valid(health_bar):
				health_bar.value = float(healed_unit.hp)
			var heal_tween := create_tween()
			heal_tween.tween_property(target, "modulate", Color("#77ff9c"), 0.10 * speed_scale)
			heal_tween.tween_property(target, "modulate", Color("#b9ffca"), 0.10 * speed_scale)
			heal_tween.tween_property(target, "modulate", Color.WHITE, 0.18 * speed_scale)
			if kind == "regen_apply": _floating_text(target, t("回春", "REGEN"), Color("#77ff9c"))
			else: _floating_text(target, "+" + str(event.amount), Color("#77ff9c"))
			await heal_tween.finished
		"charge":
			await _play_action_shake(target, profile, speed_scale)
		"skill":
			var skill_tween := create_tween()
			skill_tween.tween_property(target, "scale", Vector2(1.10, 1.10), 0.10 * speed_scale)
			skill_tween.parallel().tween_property(target, "modulate", Color("#d58dff"), 0.10 * speed_scale)
			skill_tween.tween_property(target, "scale", Vector2.ONE, 0.16 * speed_scale)
			skill_tween.parallel().tween_property(target, "modulate", Color.WHITE, 0.16 * speed_scale)
			await skill_tween.finished
		"empty":
			var empty_tween := create_tween()
			empty_tween.tween_property(target, "scale", Vector2(0.92, 0.92), 0.07 * speed_scale)
			empty_tween.parallel().tween_property(target, "modulate", Color("#ffd36f"), 0.07 * speed_scale)
			empty_tween.tween_property(target, "scale", Vector2(1.06, 1.06), 0.10 * speed_scale)
			empty_tween.tween_property(target, "scale", Vector2.ONE, 0.12 * speed_scale)
			empty_tween.parallel().tween_property(target, "modulate", Color.WHITE, 0.12 * speed_scale)
			_floating_text(target, t("✦ 空击", "✦ EMPTY") + (" -" + str(event.amount) if event.amount > 0 else ""), Color("#ffd36f"))
			await empty_tween.finished

func _play_grouped_damage(grouped_events: Array) -> void:
	var damage_events: Array = grouped_events.filter(func(event): return event.get("kind", "") == "damage")
	var impact_events: Array = grouped_events.filter(func(event): return str(event.get("kind", "")) in ["damage", "empty", "skill"])
	var group_style := ""
	for event in grouped_events:
		if not str(event.get("group_style", "")).is_empty():
			group_style = str(event.group_style)
			break
	var source_id := ""
	if not damage_events.is_empty(): source_id = str(damage_events[0].get("source_id", ""))
	elif not grouped_events.is_empty(): source_id = str(grouped_events[0].get("source_id", ""))
	var source_unit = _find_by_id(combat_units, source_id)
	var actor: Control = unit_cell_refs.get(source_id)
	var profile := _hero_fx(str(source_unit.hero_id) if source_unit != null else "")
	var targets: Array = []
	for event in impact_events:
		var target: Control
		if event.get("kind", "") in ["damage", "skill"]:
			target = unit_cell_refs.get(event.get("target_id", ""))
		else:
			target = tile_cell_refs.get(str(event.team) + ":" + str(event.row) + ":" + str(event.col))
		if is_instance_valid(target) and not targets.has(target): targets.append(target)
	var speed_scale := 1.0 / game_speed
	var custom_impacts := false
	if group_style in ["row_burn", "tile_burn", "burn_tick"]:
		await _play_grouped_burn(grouped_events, speed_scale)
	elif group_style in ["poison_tick", "poison_apply", "weak_apply", "fear_tick"]:
		await _play_grouped_status_flare(grouped_events, speed_scale, group_style)
	elif group_style == "fireball_chain" and is_instance_valid(actor):
		await _play_fireball_chain(actor, impact_events, speed_scale)
	elif group_style == "spear_rapid" and is_instance_valid(actor) and not targets.is_empty():
		var rapid_hits := int(grouped_events[0].get("rapid_hits", maxi(1, impact_events.size())))
		await _play_rapid_spear_thrust(actor, targets[0], profile, speed_scale, rapid_hits, impact_events)
		custom_impacts = true
	elif group_style == "spear_column" and is_instance_valid(actor):
		await _play_column_spear_thrust(actor, targets, profile, speed_scale)
	elif is_instance_valid(actor):
		var strike_targets: Array = targets
		if source_unit != null and source_unit.hero_id == "guanyu" and not damage_events.is_empty():
			strike_targets = []
			var target_team := str(damage_events[0].get("team", ""))
			var target_col := int(damage_events[0].get("col", 0))
			for row in BOARD_ROWS:
				var column_tile: Control = tile_cell_refs.get(target_team + ":" + str(row) + ":" + str(target_col))
				if is_instance_valid(column_tile): strike_targets.append(column_tile)
		await _play_signature_weapon(actor, strike_targets, profile, speed_scale)
	if not custom_impacts:
		var last_hit_tween: Tween
		for event in damage_events:
			var target: Control = unit_cell_refs.get(event.get("target_id", ""))
			if not is_instance_valid(target): continue
			_floating_damage_text(target, int(event.get("amount", 0)))
			last_hit_tween = _start_hit_recoil(target, speed_scale)
		var last_empty_tween: Tween
		for event in grouped_events:
			if event.get("kind", "") != "empty" or int(event.get("amount", 0)) <= 0: continue
			var empty_target: Control = tile_cell_refs.get(str(event.get("team", "")) + ":" + str(event.get("row", 0)) + ":" + str(event.get("col", 0)))
			if is_instance_valid(empty_target):
				_floating_damage_text(empty_target, int(event.amount))
				last_empty_tween = _start_empty_impact(empty_target, speed_scale)
		if last_hit_tween != null:
			await last_hit_tween.finished
		elif last_empty_tween != null:
			await last_empty_tween.finished
	var last_death_tween: Tween
	for event in grouped_events:
		if event.get("kind", "") != "death": continue
		var target: Control = unit_cell_refs.get(event.get("target_id", ""))
		if not is_instance_valid(target): continue
		last_death_tween = _start_death_ghost(target, str(event.get("target_id", "")), speed_scale)
	if last_death_tween != null: await last_death_tween.finished

func _play_grouped_status_flare(grouped_events: Array, speed_scale: float, group_style: String) -> void:
	var is_poison := group_style in ["poison_tick", "poison_apply"]
	var icon_path := "res://ThreeKingdom/animations/poisoning.png" if is_poison else "res://ThreeKingdom/animations/weak.png"
	var tint := Color("#63e67a") if is_poison else Color("#c9b8d8")
	var last_tween: Tween
	for event in grouped_events:
		if str(event.get("kind", "")) not in ["damage", "skill"]: continue
		var target: Control = unit_cell_refs.get(str(event.get("target_id", "")))
		if not is_instance_valid(target): continue
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 150
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(34, 34)
		icon.position = Vector2(target.size.x * 0.5 - 17.0, target.size.y * 0.5 - 17.0)
		icon.pivot_offset = icon.size * 0.5
		target.add_child(icon)
		last_tween = create_tween()
		last_tween.tween_property(icon, "scale", Vector2(1.35, 1.35), 0.10 * speed_scale).set_trans(Tween.TRANS_BACK)
		last_tween.parallel().tween_property(target, "modulate", tint, 0.10 * speed_scale)
		last_tween.tween_property(icon, "modulate:a", 0.0, 0.18 * speed_scale)
		last_tween.parallel().tween_property(target, "modulate", Color.WHITE, 0.18 * speed_scale)
		last_tween.tween_callback(icon.queue_free)
	if last_tween != null: await last_tween.finished

func _play_column_spear_thrust(actor: Control, targets: Array, profile: Dictionary, speed_scale: float) -> void:
	if not is_instance_valid(actor) or targets.is_empty(): return
	var centers: Array[Vector2] = []
	for target in targets:
		if is_instance_valid(target): centers.append(target.global_position + target.size * 0.5)
	if centers.is_empty(): return
	centers.sort_custom(func(a, b): return a.y < b.y)
	var column_center := Vector2.ZERO
	for center in centers: column_center += center
	column_center /= float(centers.size())
	var actor_origin := actor.global_position
	var actor_center := actor.global_position + actor.size * 0.5
	var direction := (column_center - actor_center).normalized()
	var lunge := create_tween()
	lunge.tween_property(actor, "global_position", actor_origin + direction * 62.0, 0.13 * speed_scale).set_trans(Tween.TRANS_BACK)
	lunge.parallel().tween_property(actor, "scale", Vector2(1.13, 0.92), 0.11 * speed_scale)
	await lunge.finished
	if not is_instance_valid(actor):
		return
	var spear := _spear_sprite(profile)
	var spear_start := actor.global_position + actor.size * 0.5 - global_position - spear.size * 0.5
	var spear_end := column_center - global_position - spear.size * 0.5
	spear.position = spear_start
	spear.rotation = direction.angle() + PI * 0.5
	add_child(spear)
	var column_line := Line2D.new()
	column_line.z_index = 172
	column_line.width = 18.0
	column_line.default_color = Color(profile.color.lightened(0.35), 0.94)
	column_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	column_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	column_line.points = PackedVector2Array([centers[0] - global_position, centers[-1] - global_position])
	column_line.modulate.a = 0.0
	add_child(column_line)
	var thrust := create_tween()
	thrust.tween_property(spear, "position", spear_end, 0.15 * speed_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	thrust.parallel().tween_property(column_line, "modulate:a", 1.0, 0.05 * speed_scale)
	thrust.parallel().tween_property(column_line, "width", 5.0, 0.17 * speed_scale)
	thrust.tween_property(spear, "position", spear_start, 0.09 * speed_scale)
	thrust.parallel().tween_property(column_line, "modulate:a", 0.0, 0.09 * speed_scale)
	await thrust.finished
	if is_instance_valid(spear): spear.queue_free()
	if is_instance_valid(column_line): column_line.queue_free()
	if not is_instance_valid(actor):
		return
	var retreat := create_tween()
	retreat.tween_property(actor, "global_position", actor_origin, 0.18 * speed_scale)
	retreat.parallel().tween_property(actor, "scale", Vector2.ONE, 0.16 * speed_scale)
	await retreat.finished

func _play_rapid_spear_thrust(actor: Control, target: Control, profile: Dictionary, speed_scale: float, hit_count: int, impact_events: Array) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target): return
	var actor_origin := actor.global_position
	var actor_center := actor.global_position + actor.size * 0.5
	var target_center := target.global_position + target.size * 0.5
	var direction := (target_center - actor_center).normalized()
	var approach := create_tween()
	approach.tween_property(actor, "global_position", actor_origin + direction * 54.0, 0.11 * speed_scale).set_trans(Tween.TRANS_BACK)
	approach.parallel().tween_property(actor, "scale", Vector2(1.10, 0.94), 0.10 * speed_scale)
	await approach.finished
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return
	var spear := _spear_sprite(profile)
	spear.rotation = direction.angle() + PI * 0.5
	add_child(spear)
	var trail := Line2D.new()
	trail.z_index = 171
	trail.width = 9.0
	trail.default_color = Color(profile.color.lightened(0.40), 0.92)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)
	for hit_index in maxi(1, hit_count):
		if not is_instance_valid(actor) or not is_instance_valid(target) or not is_instance_valid(spear) or not is_instance_valid(trail): break
		var start_center := actor.global_position + actor.size * 0.5 + direction * 18.0
		var end_center := target.global_position + target.size * 0.5 - direction * 10.0
		var spear_start := start_center - global_position - spear.size * 0.5
		var spear_end := end_center - global_position - spear.size * 0.5
		spear.position = spear_start
		trail.points = PackedVector2Array([start_center - global_position, end_center - global_position])
		trail.modulate.a = 0.0
		var thrust := create_tween()
		thrust.tween_property(spear, "position", spear_end, 0.055 * speed_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		thrust.parallel().tween_property(trail, "modulate:a", 1.0, 0.025 * speed_scale)
		thrust.tween_property(spear, "position", spear_start, 0.045 * speed_scale)
		thrust.parallel().tween_property(trail, "modulate:a", 0.0, 0.045 * speed_scale)
		var target_origin := target.position
		var recoil := create_tween()
		recoil.tween_property(target, "position", target_origin + direction * 13.0, 0.045 * speed_scale)
		recoil.parallel().tween_property(target, "modulate", Color("#ff5748"), 0.045 * speed_scale)
		recoil.tween_property(target, "position", target_origin, 0.055 * speed_scale)
		recoil.parallel().tween_property(target, "modulate", Color.WHITE, 0.055 * speed_scale)
		if hit_index < impact_events.size():
			var event: Dictionary = impact_events[hit_index]
			_floating_damage_text(target, int(event.get("amount", 0)))
		_impact_burst(target, profile.color, profile, true, speed_scale)
		await thrust.finished
	if is_instance_valid(spear): spear.queue_free()
	if is_instance_valid(trail): trail.queue_free()
	if not is_instance_valid(actor):
		return
	var retreat := create_tween()
	retreat.tween_property(actor, "global_position", actor_origin, 0.16 * speed_scale)
	retreat.parallel().tween_property(actor, "scale", Vector2.ONE, 0.14 * speed_scale)
	await retreat.finished

func _spear_sprite(profile: Dictionary) -> TextureRect:
	var spear := TextureRect.new()
	spear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spear.z_index = 180
	spear.size = Vector2(76, 184)
	spear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var weapon_path := str(profile.get("weapon_path", ""))
	if not weapon_path.is_empty() and ResourceLoader.exists(weapon_path):
		spear.texture = load(weapon_path)
		spear.material = _weapon_cutout_material()
	else:
		var fallback := GradientTexture2D.new()
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([profile.color.lightened(0.55), profile.color])
		fallback.gradient = gradient
		spear.texture = fallback
	return spear

func _start_empty_impact(tile: Control, speed_scale: float) -> Tween:
	tile.pivot_offset = tile.size * 0.5
	var impact := create_tween()
	impact.tween_property(tile, "scale", Vector2(0.90, 0.90), 0.07 * speed_scale)
	impact.parallel().tween_property(tile, "modulate", Color("#ff6a48"), 0.07 * speed_scale)
	impact.tween_property(tile, "scale", Vector2(1.08, 1.08), 0.09 * speed_scale).set_trans(Tween.TRANS_BACK)
	impact.tween_property(tile, "scale", Vector2.ONE, 0.15 * speed_scale)
	impact.parallel().tween_property(tile, "modulate", Color.WHITE, 0.15 * speed_scale)
	return impact

func _play_grouped_burn(grouped_events: Array, speed_scale: float) -> void:
	var burn_targets: Array = []
	for event in grouped_events:
		var target: Control
		if event.get("kind", "") == "row_burn":
			target = tile_cell_refs.get(str(event.get("team", "")) + ":" + str(event.get("row", 0)) + ":" + str(event.get("col", 0)))
		elif event.get("kind", "") == "damage":
			target = unit_cell_refs.get(str(event.get("target_id", "")))
		elif event.get("kind", "") == "empty":
			target = tile_cell_refs.get(str(event.get("team", "")) + ":" + str(event.get("row", 0)) + ":" + str(event.get("col", 0)))
		if is_instance_valid(target) and not burn_targets.has(target): burn_targets.append(target)
	var longest_flame: Tween
	for target in burn_targets:
		longest_flame = _start_burn_flare(target, speed_scale)
	if longest_flame != null: await longest_flame.finished

func _start_burn_flare(target: Control, speed_scale: float) -> Tween:
	var fire_root := Control.new()
	fire_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_root.z_index = 115
	fire_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target.add_child(fire_root)
	var fire_image := TextureRect.new()
	fire_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_image.texture = load("res://ThreeKingdom/animations/onfire.png")
	fire_image.material = _fire_effect_material()
	fire_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fire_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fire_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fire_image.modulate = Color(1.0, 0.82, 0.58, 0.90)
	fire_root.add_child(fire_image)
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.color = Color("#ff5a1f55")
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fire_root.add_child(glow)
	for flame_index in 4:
		var flame := Polygon2D.new()
		var width := 15.0 + flame_index * 3.0
		var height := 42.0 + (flame_index % 2) * 18.0
		flame.polygon = PackedVector2Array([
			Vector2(0, height),
			Vector2(-width * 0.55, height * 0.58),
			Vector2(-width * 0.18, height * 0.18),
			Vector2(0, 0),
			Vector2(width * 0.32, height * 0.30),
			Vector2(width * 0.58, height * 0.66)
		])
		flame.color = Color("#ffd45a") if flame_index % 2 == 0 else Color("#ff5a20")
		flame.position = Vector2(target.size.x * (0.18 + flame_index * 0.21), target.size.y * 0.90)
		flame.scale = Vector2(0.75, 0.20)
		fire_root.add_child(flame)
		var flicker := create_tween()
		flicker.tween_property(flame, "scale", Vector2(1.10, 1.15), 0.12 * speed_scale).set_trans(Tween.TRANS_BACK)
		flicker.tween_property(flame, "rotation", -0.15 if flame_index % 2 == 0 else 0.15, 0.08 * speed_scale)
		flicker.tween_property(flame, "scale", Vector2(0.70, 0.82), 0.09 * speed_scale)
	var flare := create_tween()
	flare.tween_property(glow, "color", Color("#ff9d3277"), 0.11 * speed_scale)
	flare.parallel().tween_property(fire_root, "scale", Vector2(1.08, 1.15), 0.11 * speed_scale)
	flare.tween_property(fire_root, "modulate:a", 0.0, 0.24 * speed_scale)
	flare.tween_callback(fire_root.queue_free)
	return flare

func _play_fireball_chain(actor: Control, impact_events: Array, speed_scale: float) -> void:
	if not is_instance_valid(actor) or impact_events.is_empty():
		return
	var fireball := TextureRect.new()
	fireball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fireball.z_index = 190
	fireball.texture = load("res://ThreeKingdom/animations/fireball.png")
	fireball.material = _fire_effect_material()
	fireball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fireball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fireball.size = Vector2(58, 58)
	fireball.pivot_offset = fireball.size * 0.5
	fireball.position = actor.global_position + actor.size * 0.5 - global_position - fireball.size * 0.5
	add_child(fireball)
	var current_position := fireball.position
	for event in impact_events:
		var target: Control
		if event.get("kind", "") == "damage":
			target = unit_cell_refs.get(str(event.get("target_id", "")))
		else:
			target = tile_cell_refs.get(str(event.get("team", "")) + ":" + str(event.get("row", 0)) + ":" + str(event.get("col", 0)))
		if not is_instance_valid(target):
			continue
		var destination := target.global_position + target.size * 0.5 - global_position - fireball.size * 0.5
		var trail := Line2D.new()
		trail.z_index = 180
		trail.width = 12.0
		trail.default_color = Color("#ff7a24aa")
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail.points = PackedVector2Array([current_position + fireball.size * 0.5, destination + fireball.size * 0.5])
		add_child(trail)
		var travel := create_tween()
		travel.tween_property(fireball, "position", destination, 0.20 * speed_scale).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		travel.parallel().tween_property(fireball, "rotation", fireball.rotation + TAU * 0.65, 0.20 * speed_scale)
		travel.parallel().tween_property(fireball, "scale", Vector2(1.18, 1.18), 0.10 * speed_scale)
		travel.tween_property(fireball, "scale", Vector2.ONE, 0.06 * speed_scale)
		await travel.finished
		if is_instance_valid(target):
			_impact_burst(target, Color("#ff6a22"), _hero_fx("luxun"), true, speed_scale)
		trail.queue_free()
		current_position = destination
	fireball.queue_free()

func _play_action_shake(card: Control, profile: Dictionary, speed_scale: float) -> void:
	if not is_instance_valid(card): return
	card.pivot_offset = card.size * 0.5
	card.z_index = 150
	var origin := card.position
	_impact_burst(card, profile.color.lightened(0.16), profile, true, speed_scale)
	var shake := create_tween()
	shake.tween_property(card, "position", origin + Vector2(-18, 13), 0.07 * speed_scale)
	shake.parallel().tween_property(card, "rotation", 0.09, 0.07 * speed_scale)
	shake.tween_property(card, "position", origin + Vector2(36, -36), 0.10 * speed_scale).set_trans(Tween.TRANS_BACK)
	shake.parallel().tween_property(card, "rotation", -0.12, 0.10 * speed_scale)
	shake.parallel().tween_property(card, "scale", Vector2(1.18, 1.18), 0.10 * speed_scale)
	shake.parallel().tween_property(card, "modulate", profile.color.lightened(0.42), 0.10 * speed_scale)
	shake.tween_property(card, "position", origin, 0.11 * speed_scale)
	shake.parallel().tween_property(card, "rotation", 0.0, 0.11 * speed_scale)
	shake.parallel().tween_property(card, "scale", Vector2.ONE, 0.11 * speed_scale)
	shake.parallel().tween_property(card, "modulate", Color.WHITE, 0.11 * speed_scale)
	await shake.finished
	if is_instance_valid(card): card.z_index = 0

func _start_hit_recoil(card: Control, speed_scale: float) -> Tween:
	card.pivot_offset = card.size * 0.5
	card.z_index = 145
	var origin := card.position
	var hit := create_tween()
	hit.tween_property(card, "position", origin + Vector2(34, 1), 0.070 * speed_scale).set_trans(Tween.TRANS_BACK)
	hit.parallel().tween_property(card, "rotation", 0.115, 0.070 * speed_scale)
	hit.parallel().tween_property(card, "scale", Vector2(0.94, 1.07), 0.070 * speed_scale)
	hit.parallel().tween_property(card, "modulate", Color("#ff4a3d"), 0.070 * speed_scale)
	hit.tween_property(card, "position", origin + Vector2(-16, -2), 0.075 * speed_scale)
	hit.parallel().tween_property(card, "rotation", -0.075, 0.075 * speed_scale)
	hit.tween_property(card, "position", origin + Vector2(21, 1), 0.065 * speed_scale)
	hit.parallel().tween_property(card, "rotation", 0.065, 0.065 * speed_scale)
	hit.tween_property(card, "position", origin + Vector2(-8, 0), 0.060 * speed_scale)
	hit.tween_property(card, "position", origin, 0.12 * speed_scale)
	hit.parallel().tween_property(card, "rotation", 0.0, 0.12 * speed_scale)
	hit.parallel().tween_property(card, "scale", Vector2.ONE, 0.12 * speed_scale)
	hit.parallel().tween_property(card, "modulate", Color.WHITE, 0.12 * speed_scale)
	hit.tween_callback(Callable(self, "_finish_visual_node").bind(card.get_instance_id(), false))
	return hit

func _finish_visual_node(instance_id: int, should_hide: bool) -> void:
	var node = instance_from_id(instance_id)
	if not is_instance_valid(node):
		return
	if should_hide:
		node.hide()
	else:
		node.z_index = 0

func _start_death_ghost(card: Control, unit_id: String, speed_scale: float) -> Tween:
	if not is_instance_valid(card): return null
	var unit = _find_by_id(combat_units, unit_id)
	var ghost := TextureRect.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 130
	ghost.size = card.size
	ghost.position = card.global_position - global_position
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if unit != null: ghost.texture = _portrait_source_texture(str(unit.hero_id))
	ghost.modulate = Color("#a9d8ffcc")
	add_child(ghost)
	var soul := _outlined_label(t("魂", "SOUL"), 24, Color("#d9efff"))
	soul.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	soul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soul.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	soul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(soul)
	card.pivot_offset = card.size * 0.5
	var vanish := create_tween()
	vanish.tween_property(card, "modulate", Color(0.45, 0.52, 0.60, 0.20), 0.20 * speed_scale)
	vanish.parallel().tween_property(card, "scale", Vector2(0.86, 0.86), 0.20 * speed_scale)
	vanish.tween_callback(Callable(self, "_finish_visual_node").bind(card.get_instance_id(), true))
	var rise := create_tween()
	rise.tween_property(ghost, "position:y", ghost.position.y - 72.0, 0.72 * speed_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(ghost, "scale", Vector2(0.72, 0.72), 0.72 * speed_scale)
	rise.parallel().tween_property(ghost, "modulate:a", 0.0, 0.72 * speed_scale)
	rise.tween_callback(ghost.queue_free)
	return rise

func _play_signature_weapon(actor: Control, targets: Array, profile: Dictionary, speed_scale: float) -> void:
	if not is_instance_valid(actor): return
	if targets.is_empty(): return
	actor.pivot_offset = actor.size * 0.5
	actor.z_index = 170
	var actor_origin := actor.global_position
	var centers: Array[Vector2] = []
	for target in targets:
		if is_instance_valid(target): centers.append(target.global_position + target.size * 0.5)
	if centers.is_empty(): return
	var attack_center := Vector2.ZERO
	for center in centers: attack_center += center
	attack_center /= float(centers.size())
	var approach_side := signf(actor_origin.y + actor.size.y * 0.5 - attack_center.y)
	if approach_side == 0.0: approach_side = 1.0
	var attack_position := attack_center - actor.size * 0.5 + Vector2(0, approach_side * actor.size.y * 0.62)
	var travel := create_tween()
	travel.tween_property(actor, "global_position", attack_position, 0.20 * speed_scale).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	travel.parallel().tween_property(actor, "scale", Vector2(1.18, 1.18), 0.18 * speed_scale)
	travel.parallel().tween_property(actor, "modulate", profile.color.lightened(0.28), 0.14 * speed_scale)
	await travel.finished
	# 无暂停/高倍速下，棋盘可能在位移动画结束前重绘并释放旧卡片。
	if not is_instance_valid(actor):
		return

	var weapon_root: TextureRect
	var weapon_path := str(profile.get("weapon_path", ""))
	if not weapon_path.is_empty() and ResourceLoader.exists(weapon_path):
		weapon_root = TextureRect.new()
		weapon_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weapon_root.z_index = 180
		weapon_root.texture = load(weapon_path)
		weapon_root.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		weapon_root.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		weapon_root.size = Vector2(168, 252)
		weapon_root.position = actor.size * 0.5 - Vector2(84, 218)
		weapon_root.pivot_offset = Vector2(84, 218)
		weapon_root.material = _weapon_cutout_material()
		actor.add_child(weapon_root)
	var slash := Line2D.new()
	slash.z_index = 165
	slash.width = 34.0
	slash.default_color = Color(profile.color.lightened(0.22), 0.92)
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	centers.sort_custom(func(a, b): return a.y < b.y)
	if centers.size() == 1:
		slash.points = PackedVector2Array([centers[0] + Vector2(-64, -50) - global_position, centers[0] + Vector2(64, 50) - global_position])
	elif centers.size() > 1:
		slash.points = PackedVector2Array([centers[0] + Vector2(0, -48) - global_position, centers[-1] + Vector2(0, 48) - global_position])
	slash.modulate.a = 0.0
	add_child(slash)
	var swing := create_tween()
	if is_instance_valid(weapon_root):
		weapon_root.rotation = -1.24
		weapon_root.modulate.a = 0.0
		swing.tween_property(weapon_root, "modulate:a", 1.0, 0.06 * speed_scale)
		swing.parallel().tween_property(weapon_root, "rotation", -0.96, 0.06 * speed_scale)
		swing.tween_property(weapon_root, "rotation", 1.05, 0.28 * speed_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		swing.parallel().tween_property(slash, "modulate:a", 1.0, 0.05 * speed_scale)
		swing.parallel().tween_property(slash, "width", 10.0, 0.28 * speed_scale)
	else:
		swing.tween_property(slash, "modulate:a", 1.0, 0.05 * speed_scale)
		swing.tween_property(slash, "width", 10.0, 0.24 * speed_scale)
	swing.tween_property(slash, "modulate:a", 0.0, 0.10 * speed_scale)
	if is_instance_valid(weapon_root): swing.parallel().tween_property(weapon_root, "modulate:a", 0.0, 0.10 * speed_scale)
	await swing.finished
	if is_instance_valid(weapon_root): weapon_root.queue_free()
	if is_instance_valid(slash): slash.queue_free()
	if not is_instance_valid(actor):
		return
	var retreat := create_tween()
	retreat.tween_property(actor, "global_position", actor_origin, 0.24 * speed_scale).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	retreat.parallel().tween_property(actor, "scale", Vector2.ONE, 0.20 * speed_scale)
	retreat.parallel().tween_property(actor, "rotation", 0.0, 0.20 * speed_scale)
	retreat.parallel().tween_property(actor, "modulate", Color.WHITE, 0.20 * speed_scale)
	retreat.tween_callback(Callable(self, "_finish_visual_node").bind(actor.get_instance_id(), false))

func _weapon_cutout_material() -> ShaderMaterial:
	if is_instance_valid(weapon_cutout_material): return weapon_cutout_material
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float brightness = max(source.r, max(source.g, source.b));
	float cutout = smoothstep(0.018, 0.095, brightness);
	COLOR = vec4(source.rgb, source.a * cutout);
}
"""
	weapon_cutout_material = ShaderMaterial.new()
	weapon_cutout_material.shader = shader
	return weapon_cutout_material

func _fire_effect_material() -> ShaderMaterial:
	if is_instance_valid(fire_effect_cutout_material):
		return fire_effect_cutout_material
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 tint = COLOR;
	vec4 source = texture(TEXTURE, UV);
	float brightness = max(source.r, max(source.g, source.b));
	float warmth = max(source.r - source.b * 0.72, source.g * 0.42 - source.b * 0.18);
	float cutout = smoothstep(0.055, 0.24, warmth) * smoothstep(0.035, 0.22, brightness);
	vec3 fire_color = source.rgb * vec3(1.18, 1.04, 0.92) * tint.rgb;
	COLOR = vec4(fire_color, source.a * cutout * tint.a);
}
"""
	fire_effect_cutout_material = ShaderMaterial.new()
	fire_effect_cutout_material.shader = shader
	return fire_effect_cutout_material

func _hero_fx(hero_id: String) -> Dictionary:
	var glyphs := {"liubei":"仁", "guanyu":"龍", "zhangfei":"吼", "zhaoyun":"胆", "huangzhong":"穿", "machao":"骑", "liushan":"汉", "zhugeliang":"卦", "jiangwei":"伐", "menghuo":"蛮", "zhurong":"焰", "dailaidongzhu":"兽", "weiyan":"骨", "madai":"羽", "pangtong":"链", "caocao":"魏", "dianwei":"戟", "xuchu":"锤", "zhangliao":"威", "yuejin":"矢", "zhanghe":"变", "xuhuang":"斧", "yujin":"阵", "xiahouyuan":"速", "caoren":"城", "xiahoudun":"烈", "guojia":"冰", "simayi":"雷", "xunyu":"佐", "jiaxu":"毒", "zhouyu":"赤", "luxun":"炎", "lusu":"盟", "lvmeng":"袭", "sunjian":"虎", "sunce":"霸", "sunquan":"衡", "sunshangxiang":"弩", "daqiao":"花", "xiaoqiao":"风", "taishici":"义", "dingfeng":"雪", "xusheng":"潮", "ganning":"锦", "huanggai":"苦", "lvbu":"无", "diaochan":"魅", "dongzhuo":"暴", "gaoshun":"陷", "chengong":"谋", "yanliang":"猛", "wenchou":"返", "qunzhanghe":"幕", "gaolan":"策", "huatuo":"医", "yuji":"毒", "zuoci":"仙", "zhangjiao":"雷", "zhangliang":"弱", "zhangbao":"爆"}
	var weapons := {
		"liubei":"双股剑", "guanyu":"青龙偃月刀", "zhangfei":"丈八蛇矛", "zhaoyun":"龙胆亮银枪", "huangzhong":"落日弓",
		"machao":"虎头湛金枪", "weiyan":"鬼头刀", "madai":"斩马刀", "liushan":"细剑", "zhugeliang":"七星卧龙扇",
		"jiangwei":"麒麟破军枪", "pangtong":"黑凤涅槃扇", "menghuo":"南蛮开山斧", "zhurong":"火凤烈焰刃", "dailaidongzhu":"蛮骨狼牙棒",
		"caocao":"倚天剑", "dianwei":"双铁戟", "xuchu":"虎头锤",
		"zhouyu":"赤焰羽扇", "luxun":"连营火剑", "lvbu":"方天画戟", "diaochan":"闭月绫",
		"dongzhuo":"暴君战刃", "ganning":"锦帆刀", "lvmeng":"白衣剑"
	}
	var weapon_paths := {
		"liubei":"res://ThreeKingdom/weapon/shuanggujian.png",
		"guanyu":"res://ThreeKingdom/weapon/qinglongyanyuedao.png",
		"zhangfei":"res://ThreeKingdom/weapon/zhangbashemao.png",
		"zhaoyun":"res://ThreeKingdom/weapon/longdanliangyinqiang.png",
		"machao":"res://ThreeKingdom/weapon/hutouzhanjinqiang.png",
		"huangzhong":"res://ThreeKingdom/weapon/luorigong.png",
		"weiyan":"res://ThreeKingdom/weapon/guitoudao.png",
		"madai":"res://ThreeKingdom/weapon/zhanmadao.png",
		"liushan":"res://ThreeKingdom/weapon/xijian.png",
		"zhugeliang":"res://ThreeKingdom/weapon/qixingwolongshan.png",
		"jiangwei":"res://ThreeKingdom/weapon/qilinpojunqiang.png",
		"pangtong":"res://ThreeKingdom/weapon/heifenniepanshan.png",
		"menghuo":"res://ThreeKingdom/weapon/nanmakaishanfu.png",
		"zhurong":"res://ThreeKingdom/weapon/huofenglieyanren.png",
		"dailaidongzhu":"res://ThreeKingdom/weapon/mangulangyabang.png"
	}
	var arrows := ["huangzhong", "madai", "yuejin", "xiahouyuan", "sunshangxiang", "taishici", "chengong"]
	var hammers := ["zhangfei", "xuchu", "xuhuang", "menghuo", "dailaidongzhu", "dongzhuo", "huanggai"]
	var spears := ["zhaoyun", "machao", "jiangwei", "dianwei", "zhangliao", "zhanghe", "lvmeng", "ganning", "gaoshun", "yanliang"]
	var element := "blade"
	if arrows.has(hero_id): element = "arrow"
	elif hammers.has(hero_id): element = "hammer"
	elif spears.has(hero_id): element = "spear"
	elif hero_id in ["zhouyu", "luxun", "zhurong"]: element = "fire"
	elif hero_id in ["simayi", "zhangjiao", "zuoci", "zhangbao"]: element = "lightning"
	elif hero_id in ["guojia", "xiaoqiao"]: element = "frost"
	elif hero_id in ["liubei", "lusu", "daqiao", "huatuo"]: element = "heal"
	elif hero_id in ["yuji", "zhangliang"]: element = "arcane"
	elif hero_id in ["zhugeliang", "pangtong", "xunyu", "jiaxu", "diaochan", "gaolan"]: element = "arcane"
	var faction := str(heroes.get(hero_id, {}).get("f", "qun"))
	var base: Color = FACTION_COLORS.get(faction, Color("#d8b060")).lightened(0.20)
	var hue := fmod(abs(float(hash(hero_id))) / 997.0, 1.0)
	return {"hero_id":hero_id, "glyph":glyphs.get(hero_id, "战"), "element":element, "weapon":weapons.get(hero_id, t("专属武器", "Signature Weapon")), "weapon_path":weapon_paths.get(hero_id, ""), "color":base.lerp(Color.from_hsv(hue, 0.76, 1.0), 0.42)}

func _play_projectile(actor: Control, target: Control, style: String, speed_scale: float, profile: Dictionary, is_skill: bool) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target): return
	var projectile := PanelContainer.new()
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projectile.z_index = 90
	var element: String = profile.element
	var color: Color = Color("#66f09a") if style == "heal" else profile.color
	var extent := 38.0 if is_skill else 24.0
	projectile.size = Vector2(extent, extent)
	_style(projectile, Color(color, 0.94), int(extent * 0.5), Color.WHITE, 2)
	var glyph := _outlined_label(str(profile.glyph), 15 if is_skill else 11, Color.WHITE)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	projectile.add_child(glyph)
	projectile.position = actor.global_position + actor.size * 0.5 - global_position - projectile.size * 0.5
	add_child(projectile)
	var destination := target.global_position + target.size * 0.5 - global_position - projectile.size * 0.5
	var start := projectile.position
	var trail := Line2D.new()
	trail.z_index = 85
	trail.width = 9.0 if is_skill else 5.0
	trail.default_color = Color(color, 0.64)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)
	var tween := create_tween()
	tween.tween_method(func(progress: float):
		if not is_instance_valid(projectile): return
		var arc := -72.0 if element in ["arrow", "fire", "arcane"] else -34.0
		var control := (start + destination) * 0.5 + Vector2(0, arc)
		var point := start * pow(1.0 - progress, 2) + control * 2.0 * (1.0 - progress) * progress + destination * progress * progress
		projectile.position = point
		projectile.rotation += 0.18 if element == "lightning" else 0.08
		trail.add_point(point + projectile.size * 0.5)
		if trail.get_point_count() > 12: trail.remove_point(0)
	, 0.0, 1.0, (0.42 if is_skill else 0.30) * speed_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(target): _impact_burst(target, color, profile, is_skill, speed_scale)
	projectile.queue_free()
	trail.queue_free()

func _play_melee_strike(actor: Control, target: Control, speed_scale: float, profile: Dictionary, is_skill: bool) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target): return
	actor.pivot_offset = actor.size * 0.5
	actor.z_index = 80
	var origin := actor.position
	var direction := (target.global_position + target.size * 0.5 - actor.global_position - actor.size * 0.5).normalized()
	var color: Color = profile.color
	var element: String = profile.element
	var lunge := create_tween()
	var distance := 48.0 if element == "spear" else (38.0 if is_skill else 28.0)
	lunge.tween_property(actor, "position", origin + direction * distance, 0.10 * speed_scale).set_trans(Tween.TRANS_BACK)
	lunge.parallel().tween_property(actor, "scale", Vector2(1.08, 0.94), 0.08 * speed_scale)
	lunge.tween_property(actor, "position", origin, 0.16 * speed_scale)
	lunge.parallel().tween_property(actor, "scale", Vector2.ONE, 0.12 * speed_scale)
	var slash := ColorRect.new()
	slash.color = color.lightened(0.35)
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.z_index = 95
	slash.size = Vector2(10 if element == "hammer" else 5, target.size.y * (0.90 if is_skill else 0.72))
	slash.position = Vector2(target.size.x * 0.5, target.size.y * 0.08)
	slash.rotation = -1.0 if element == "spear" else -0.72
	target.add_child(slash)
	var weapon := create_tween()
	weapon.tween_property(slash, "rotation", 0.95, 0.18 * speed_scale)
	weapon.parallel().tween_property(slash, "modulate:a", 0.0, 0.23 * speed_scale)
	await lunge.finished
	if is_instance_valid(target): _impact_burst(target, color, profile, is_skill, speed_scale)
	if is_instance_valid(slash): slash.queue_free()
	if is_instance_valid(actor): actor.z_index = 0

func _impact_burst(target: Control, color: Color, profile: Dictionary, is_skill: bool, speed_scale: float) -> void:
	if not is_instance_valid(target): return
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 96
	ring.size = Vector2(28, 28)
	ring.position = target.size * 0.5 - ring.size * 0.5
	_style(ring, Color(color, 0.08), 14, color.lightened(0.28), 4)
	target.add_child(ring)
	var ray_count := 10 if is_skill else 6
	for i in ray_count:
		var ray := ColorRect.new()
		ray.color = color.lightened(0.30)
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ray.size = Vector2(4, 24 if is_skill else 15)
		ray.position = target.size * 0.5 - Vector2(2, ray.size.y)
		ray.pivot_offset = Vector2(2, ray.size.y)
		ray.rotation = TAU * float(i) / float(ray_count)
		ray.z_index = 95
		target.add_child(ray)
		var ray_tween := create_tween()
		ray_tween.tween_property(ray, "scale:y", 1.8, 0.10 * speed_scale)
		ray_tween.parallel().tween_property(ray, "modulate:a", 0.0, 0.22 * speed_scale)
		ray_tween.tween_callback(ray.queue_free)
	var glyph := _outlined_label(str(profile.glyph), 24 if is_skill else 16, color.lightened(0.35))
	glyph.position = target.size * 0.5 - Vector2(22, 22)
	glyph.size = Vector2(44, 44)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.z_index = 98
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(glyph)
	var burst := create_tween()
	burst.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.20 * speed_scale)
	burst.parallel().tween_property(ring, "modulate:a", 0.0, 0.24 * speed_scale)
	burst.parallel().tween_property(glyph, "scale", Vector2(1.45, 1.45), 0.18 * speed_scale)
	burst.parallel().tween_property(glyph, "modulate:a", 0.0, 0.26 * speed_scale)
	burst.tween_callback(ring.queue_free)
	burst.tween_callback(glyph.queue_free)

func _floating_text(target: Control, value: String, color: Color) -> void:
	if not is_instance_valid(target): return
	var label := _outlined_label(value, 21, color)
	label.z_index = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, target.size.y * 0.32)
	label.size = Vector2(target.size.x, 30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.38)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.38)
	tween.tween_callback(label.queue_free)

func _floating_damage_text(target: Control, amount: int) -> void:
	if not is_instance_valid(target): return
	var label := _outlined_label("-" + str(maxi(0, amount)), 27, Color("#ff3b30"))
	label.z_index = 140
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(target.size.x * 0.14, target.size.y * 0.20)
	label.size = Vector2(target.size.x, 38)
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_outline_color", Color("#4b0505"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(label)
	var start := label.position
	var tween := create_tween()
	tween.tween_property(label, "position", start + Vector2(18, -24), 0.20)
	tween.parallel().tween_property(label, "scale", Vector2(1.24, 1.24), 0.12)
	tween.tween_property(label, "position", start + Vector2(28, -47), 0.34)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.34)
	tween.tween_callback(label.queue_free)
