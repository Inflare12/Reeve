class_name ReeveTelemetryPlot
extends Control
## Lightweight telemetry time-series plot. Draws only recorded simulation samples.

var plot_title: String = "Telemetry"
var data_key: String = "altitude_m"
var unit_label: String = ""
var samples: Array[Dictionary] = []

func configure(title: String, key: String, units: String) -> void:
	plot_title = title
	data_key = key
	unit_label = units
	custom_minimum_size = Vector2(320.0, 112.0)
	queue_redraw()

func set_samples(source: Array[Dictionary]) -> void:
	samples = source
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.035, 0.05, 0.075), true)
	draw_rect(bounds, Color(0.22, 0.29, 0.38), false, 1.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(9.0, 17.0), plot_title + " (" + unit_label + ")", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.86, 0.91, 0.97))
	var plot_rect := Rect2(Vector2(34.0, 27.0), Vector2(maxf(size.x - 44.0, 10.0), maxf(size.y - 39.0, 10.0)))
	for grid_index in range(1, 4):
		var y: float = plot_rect.position.y + plot_rect.size.y * float(grid_index) / 4.0
		draw_line(Vector2(plot_rect.position.x, y), Vector2(plot_rect.end.x, y), Color(0.17, 0.22, 0.29), 1.0)
	if samples.is_empty():
		draw_string(font, Vector2(42.0, size.y * 0.65), "Waiting for simulation samples", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.55, 0.62, 0.7))
		return
	var values: PackedFloat64Array = PackedFloat64Array()
	for sample in samples:
		var value: float = float(sample.get(data_key, NAN))
		if is_finite(value):
			values.append(value)
	if values.is_empty():
		draw_string(font, Vector2(42.0, size.y * 0.65), "No finite values for this channel", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.8, 0.58, 0.42))
		return
	var minimum: float = values[0]
	var maximum: float = values[0]
	for value in values:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	var value_range: float = maxf(maximum - minimum, 0.000001)
	var points := PackedVector2Array()
	for index in range(values.size()):
		var x_fraction: float = float(index) / float(maxi(values.size() - 1, 1))
		var y_fraction: float = (values[index] - minimum) / value_range
		points.append(Vector2(
			plot_rect.position.x + x_fraction * plot_rect.size.x,
			plot_rect.end.y - y_fraction * plot_rect.size.y
		))
	if points.size() == 1:
		draw_circle(points[0], 2.5, Color(0.35, 0.82, 0.92))
	elif points.size() > 1:
		draw_polyline(points, Color(0.35, 0.82, 0.92), 1.6, true)
	draw_string(font, Vector2(4.0, plot_rect.position.y + 4.0), str(maximum), HORIZONTAL_ALIGNMENT_LEFT, 28.0, 9, Color(0.62, 0.7, 0.79))
	draw_string(font, Vector2(4.0, plot_rect.end.y), str(minimum), HORIZONTAL_ALIGNMENT_LEFT, 28.0, 9, Color(0.62, 0.7, 0.79))
