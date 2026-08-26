extends Control

## Lightweight, code-drawn ornament layer used by the premium Three Kingdoms UI.
## It deliberately contains no input handling, so it can sit behind every screen.

enum Variant { BACKDROP, HOME, MAP, TALENT, CODEX, COMBAT }

var variant: Variant = Variant.BACKDROP
var accent := Color("#b98a4f")
var paper := false # 绢纸(亮色)主题：纸面底色 + 暖棕纹样，替代玄墨底色
var tree_points: Dictionary = {}
var _grain_texture: ImageTexture

func _grain() -> ImageTexture:
	# 细微胶片颗粒：把纯黑背景变成有质感的墨面。只生成一次并平铺绘制。
	if _grain_texture != null: return _grain_texture
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var value := randf() * 0.5 + 0.25
			image.set_pixel(x, y, Color(value, value, value, 0.055))
	_grain_texture = ImageTexture.create_from_image(image)
	return _grain_texture

func configure(next_variant: Variant, next_accent := Color("#b98a4f"), next_paper := false) -> void:
	variant = next_variant
	accent = next_accent
	paper = next_paper
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func set_tree_points(points: Dictionary) -> void:
	tree_points = points
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_draw_backdrop()
	match variant:
		Variant.HOME:
			_draw_home_halo()
		Variant.MAP:
			_draw_map()
		Variant.TALENT:
			_draw_tree()
		Variant.CODEX:
			_draw_codex_aura()
		Variant.COMBAT:
			_draw_combat_grid()
	_draw_frame()

func _draw_backdrop() -> void:
	if paper:
		# 绢纸主题：半透明米黄纸面 + 竖向绢纹 + 淡金纹样 + 暖棕轻暗角，透出根纸色渐变。
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.965, 0.945, 0.878, 0.42))
		var silk := 22
		for index in silk:
			var t := float(index) / float(silk - 1)
			var band := Color("#ead9b5").lerp(Color("#f6efdd"), t)
			band.a = 0.46
			draw_rect(Rect2(0.0, size.y * t, size.x, size.y / silk + 2.0), band)
		for index in 9:
			var y := size.y * (0.18 + index * 0.075)
			var alpha := 0.045 + float(index % 3) * 0.014
			draw_arc(Vector2(size.x * 0.12, y), 90.0 + index * 21.0, PI * 0.10, PI * 0.92, 24, Color(0.55, 0.41, 0.19, alpha), 2.0)
			draw_arc(Vector2(size.x * 0.90, size.y - y * 0.55), 75.0 + index * 18.0, PI * 1.05, PI * 1.82, 24, Color(0.55, 0.41, 0.19, alpha), 2.0)
		draw_texture_rect(_grain(), Rect2(Vector2.ZERO, size), true, Color(0.72, 0.62, 0.44, 0.55))
		var vignette_light := 30
		var depth_light := minf(size.x, size.y) * 0.16
		var band_light := depth_light / float(vignette_light) + 1.0
		for index in vignette_light:
			var alpha_light := 0.13 * pow(1.0 - float(index) / float(vignette_light), 1.8)
			var shade_light := Color(0.42, 0.30, 0.12, alpha_light)
			draw_rect(Rect2(0.0, index * band_light, size.x, band_light + 1.0), shade_light)
			draw_rect(Rect2(0.0, size.y - (index + 1) * band_light, size.x, band_light + 1.0), shade_light)
			draw_rect(Rect2(index * band_light, 0.0, band_light + 1.0, size.y), shade_light)
			draw_rect(Rect2(size.x - (index + 1) * band_light, 0.0, band_light + 1.0, size.y), shade_light)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.04, 0.55))
	var bands := 22
	for index in bands:
		var t := float(index) / float(bands - 1)
		var warm := Color("#1e1710").lerp(Color("#090b0d"), t)
		warm.a = 0.52
		draw_rect(Rect2(0.0, size.y * t, size.x, size.y / bands + 2.0), warm)
	for index in 9:
		var y := size.y * (0.18 + index * 0.075)
		var alpha := 0.035 + float(index % 3) * 0.012
		draw_arc(Vector2(size.x * 0.12, y), 90.0 + index * 21.0, PI * 0.10, PI * 0.92, 24, Color(0.79, 0.59, 0.31, alpha), 2.0)
		draw_arc(Vector2(size.x * 0.90, size.y - y * 0.55), 75.0 + index * 18.0, PI * 1.05, PI * 1.82, 24, Color(0.79, 0.59, 0.31, alpha), 2.0)
	# 中央烛光：让画面中心比四角透气，形成视觉焦点。
	draw_circle(Vector2(size.x * 0.5, size.y * 0.42), minf(size.x, size.y) * 0.55, Color(0.98, 0.83, 0.55, 0.016))
	draw_circle(Vector2(size.x * 0.5, size.y * 0.42), minf(size.x, size.y) * 0.34, Color(0.98, 0.83, 0.55, 0.022))
	# 墨面颗粒 + 四角暗角。
	draw_texture_rect(_grain(), Rect2(Vector2.ZERO, size), true, Color(1, 1, 1, 0.6))
	var vignette := 30
	var depth := minf(size.x, size.y) * 0.16
	var band := depth / float(vignette) + 1.0
	for index in vignette:
		var alpha := 0.34 * pow(1.0 - float(index) / float(vignette), 1.8)
		var shade := Color(0, 0, 0, alpha)
		draw_rect(Rect2(0.0, index * band, size.x, band + 1.0), shade)
		draw_rect(Rect2(0.0, size.y - (index + 1) * band, size.x, band + 1.0), shade)
		draw_rect(Rect2(index * band, 0.0, band + 1.0, size.y), shade)
		draw_rect(Rect2(size.x - (index + 1) * band, 0.0, band + 1.0, size.y), shade)

func _draw_frame() -> void:
	var outer := Rect2(5.0, 5.0, size.x - 10.0, size.y - 10.0)
	var inner := Rect2(11.0, 11.0, size.x - 22.0, size.y - 22.0)
	draw_rect(outer, Color(accent, 0.62), false, 2.0)
	draw_rect(inner, Color(accent.lightened(0.2), 0.18), false, 1.0)
	var arm := minf(58.0, size.x * 0.08)
	for corner in [Vector2(13, 13), Vector2(size.x - 13, 13), Vector2(13, size.y - 13), Vector2(size.x - 13, size.y - 13)]:
		var sx := 1.0 if corner.x < size.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < size.y * 0.5 else -1.0
		draw_polyline(PackedVector2Array([corner + Vector2(sx * arm, 0), corner, corner + Vector2(0, sy * arm)]), Color(accent.lightened(0.25), 0.85), 3.0)
		draw_circle(corner + Vector2(sx * 9, sy * 9), 3.0, Color(accent.lightened(0.4), 0.9))

func _draw_home_halo() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.46)
	for radius in [265.0, 320.0, 390.0]:
		draw_arc(center, radius, 0.0, TAU, 96, Color(accent, 0.055), 3.0)
	for index in 24:
		var angle := TAU * float(index) / 24.0
		var origin := center + Vector2.from_angle(angle) * 315.0
		var end := center + Vector2.from_angle(angle) * 350.0
		draw_line(origin, end, Color(accent, 0.08), 2.0)

func _draw_map() -> void:
	var ink := Color(0.42, 0.31, 0.13, 0.30) if paper else Color(0.05, 0.08, 0.07, 0.28)
	for ridge in 7:
		var points := PackedVector2Array()
		for index in 13:
			var x := size.x * float(index) / 12.0
			var y := size.y * (0.18 + ridge * 0.105) + sin(float(index) * 1.45 + ridge) * (18.0 + ridge * 2.0)
			points.append(Vector2(x, y))
		draw_polyline(points, ink, 2.0)
	var river := PackedVector2Array()
	for index in 20:
		var x := size.x * float(index) / 19.0
		var y := size.y * 0.62 + sin(float(index) * 0.72) * 40.0
		river.append(Vector2(x, y))
	draw_polyline(river, Color(0.22, 0.45, 0.48, 0.30), 10.0)
	draw_polyline(river, Color(0.49, 0.74, 0.73, 0.18), 2.0)

func _draw_tree() -> void:
	var root := Vector2(size.x * 0.5, size.y - 20.0)
	var crown := Vector2(size.x * 0.5, 30.0)
	for width in [28.0, 18.0, 8.0]:
		draw_line(root, crown, Color(accent, 0.12 + (28.0 - width) * 0.008), width, true)
	for layer in range(1, 6):
		var points: Array = tree_points.get(layer, [])
		var below: Array = tree_points.get(layer - 1, [root])
		for point_variant in points:
			var point: Vector2 = point_variant
			var parent: Vector2 = below[mini(below.size() - 1, int(round(float(points.find(point_variant)) * maxf(1.0, float(below.size() - 1)) / maxf(1.0, float(points.size() - 1)))))]
			var mid := Vector2((parent.x + point.x) * 0.5, (parent.y + point.y) * 0.5)
			draw_polyline(PackedVector2Array([parent, Vector2(parent.x, mid.y), Vector2(point.x, mid.y), point]), Color(accent.lightened(0.12), 0.42), 7.0, true)
			draw_polyline(PackedVector2Array([parent, Vector2(parent.x, mid.y), Vector2(point.x, mid.y), point]), Color("#7a5216") if paper else Color("#f3cf75"), 2.0, true)
	for root_offset in [-170.0, -90.0, 90.0, 170.0]:
		draw_polyline(PackedVector2Array([root, Vector2(root.x + root_offset * 0.42, root.y - 12), Vector2(root.x + root_offset, root.y)]), Color(accent, 0.38), 7.0, true)

func _draw_codex_aura() -> void:
	var center := Vector2(size.x * 0.48, size.y * 0.48)
	for radius in range(110, 560, 55):
		var hue := fmod(float(radius) / 450.0, 1.0)
		var color := Color.from_hsv(0.68 + hue * 0.13, 0.42, 0.92, 0.035)
		draw_arc(center, float(radius), -0.9, 2.3, 72, color, 5.0)

func _draw_combat_grid() -> void:
	var line := Color(accent.darkened(0.25), 0.055) if paper else Color(accent, 0.018)
	for index in 16:
		var x := size.x * float(index) / 15.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), line, 1.0)
	for index in 10:
		var y := size.y * float(index) / 9.0
		draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.0)
