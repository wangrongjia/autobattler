extends Control

## 战斗回放折线图(结算画面用)：代码绘制的主公生命/累计伤害曲线。
## 与 premium_ui_art.gd 同款的轻量独立绘制控件，不含输入处理。

var series: Array = []        # [{name, color, points: Array[Vector2], width, alpha}]
var x_max := 1.0              # x 轴上限(整关累计战斗秒数)
var y_max := 1.0              # y 轴上限(各序列最大值)
var round_marks: Array = []   # 回合分隔线的 x 坐标(每回合结束时间点)
var round_mark_labels: Array = [] # 分隔线顶部的回合名(如 "第3回")
var y_tick_labels: Array = [] # 5 档横向网格线的 y 轴标签(由调用方格式化)
var reveal := 1.0             # 曲线从左到右的生长动画进度(0~1)

const PLOT_MARGIN := Rect2(40.0, 16.0, 12.0, 20.0) # 曲线区域四周留白(左/上/右/下)

func configure(next_series: Array, next_x_max: float, next_y_max: float, next_round_marks := [], next_round_mark_labels := [], next_y_tick_labels := []) -> void:
	series = next_series
	x_max = maxf(1.0, next_x_max)
	y_max = maxf(1.0, next_y_max)
	round_marks = next_round_marks
	round_mark_labels = next_round_mark_labels
	y_tick_labels = next_y_tick_labels
	reveal = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw): resized.connect(queue_redraw)
	queue_redraw()

func set_reveal(value: float) -> void:
	reveal = clampf(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#07090c"))
	var plot := Rect2(Vector2(PLOT_MARGIN.position.x, PLOT_MARGIN.position.y), Vector2(size.x - PLOT_MARGIN.position.x - PLOT_MARGIN.size.x, size.y - PLOT_MARGIN.position.y - PLOT_MARGIN.size.y))
	if plot.size.x <= 4.0 or plot.size.y <= 4.0: return
	_draw_grid(plot)
	_draw_round_marks(plot)
	for entry in series:
		_draw_series(entry, plot)

func _plot_point(plot: Rect2, point: Vector2) -> Vector2:
	var fx := clampf(point.x / x_max, 0.0, 1.0)
	var fy := clampf(point.y / y_max, 0.0, 1.0)
	return Vector2(plot.position.x + plot.size.x * fx, plot.position.y + plot.size.y * (1.0 - fy))

func _draw_grid(plot: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var font_color := Color("#8a8272")
	for index in 5:
		var fy := float(index) / 4.0
		var y := plot.position.y + plot.size.y * (1.0 - fy)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color("#2c2b24"), 1.0)
		var label := ""
		if index < y_tick_labels.size(): label = str(y_tick_labels[index])
		elif fy > 0.0: label = str(int(round(y_max * fy)))
		if label != "":
			draw_string(font, Vector2(4.0, y + 5.0), label, HORIZONTAL_ALIGNMENT_RIGHT, PLOT_MARGIN.position.x - 8.0, font_size - 3, font_color)
	draw_line(Vector2(plot.position.x, plot.end.y + 2.0), Vector2(plot.end.x, plot.end.y + 2.0), Color("#4d4635"), 1.0)
	draw_line(Vector2(plot.position.x - 2.0, plot.position.y), Vector2(plot.position.x - 2.0, plot.end.y), Color("#4d4635"), 1.0)
	var x_label := "%ds" % int(round(x_max))
	draw_string(font, Vector2(plot.end.x - 30.0, size.y - 4.0), x_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3, font_color)

func _draw_round_marks(plot: Rect2) -> void:
	if round_marks.is_empty(): return
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	for index in round_marks.size():
		var mark_x: float = float(round_marks[index]) / x_max
		if mark_x <= 0.005 or mark_x >= 0.995: continue
		var x := plot.position.x + plot.size.x * mark_x
		_draw_dashed_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(0.75, 0.60, 0.35, 0.38), 1.0, 5.0, 4.0)
		var label := str(round_mark_labels[index]) if index < round_mark_labels.size() else ""
		if label != "":
			draw_string(font, Vector2(x + 3.0, plot.position.y + font_size - 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Color(0.75, 0.60, 0.35, 0.75))

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var length := from.distance_to(to)
	if length <= 0.5: return
	var direction := (to - from) / length
	var travelled := 0.0
	while travelled < length:
		var seg_end := minf(travelled + dash, length)
		draw_line(from + direction * travelled, from + direction * seg_end, color, width)
		travelled = seg_end + gap

func _draw_series(entry: Dictionary, plot: Rect2) -> void:
	var points: Array = entry.get("points", [])
	if points.size() < 2: return
	var color: Color = entry.get("color", Color.WHITE)
	var width: float = float(entry.get("width", 2.0))
	var alpha: float = float(entry.get("alpha", 1.0))
	var limit_x := x_max * reveal
	var screen_points: Array[Vector2] = []
	for index in points.size():
		var point: Vector2 = points[index]
		if float(point.x) <= limit_x:
			screen_points.append(_plot_point(plot, point))
			continue
		# 生长动画：遇到第一个超出边界的点时，与前一点插值出边界上的线头。
		if index > 0:
			var prev: Vector2 = points[index - 1]
			var span := float(point.x) - float(prev.x)
			var ratio := 0.0 if span <= 0.0 else (limit_x - float(prev.x)) / span
			screen_points.append(_plot_point(plot, Vector2(limit_x, lerpf(float(prev.y), float(point.y), clampf(ratio, 0.0, 1.0)))))
		break
	if screen_points.size() < 2: return
	var packed := PackedVector2Array(screen_points)
	if bool(entry.get("glow", false)):
		draw_polyline(packed, Color(color.r, color.g, color.b, alpha * 0.22), width + 3.0)
	draw_polyline(packed, Color(color.r, color.g, color.b, alpha), width)
