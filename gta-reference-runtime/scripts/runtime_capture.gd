class_name RuntimeCapture
extends RefCounted

static func has_graphical_signal(image: Image, minimum_max_brightness := 0.03, minimum_variance := 0.0001, minimum_alpha := 0.03) -> bool:
	if image == null or image.is_empty():
		return false
	var sample_step := 8
	var count := 0
	var brightness_sum := 0.0
	var brightness_square_sum := 0.0
	var max_brightness := 0.0
	var alpha_sum := 0.0
	for y in range(0, image.get_height(), sample_step):
		for x in range(0, image.get_width(), sample_step):
			var pixel := image.get_pixel(x, y)
			var brightness := (pixel.r + pixel.g + pixel.b) / 3.0
			brightness_sum += brightness
			brightness_square_sum += brightness * brightness
			max_brightness = maxf(max_brightness, brightness)
			alpha_sum += pixel.a
			count += 1
	if count == 0:
		return false
	var average := brightness_sum / count
	var variance := maxf(0.0, brightness_square_sum / count - average * average)
	return max_brightness > minimum_max_brightness and alpha_sum / count > minimum_alpha and variance > minimum_variance

static func capture(viewport: Viewport, capture_id: String) -> String:
	if viewport == null or viewport.get_texture() == null:
		return ""
	var directory := "user://reference-captures"
	var absolute_directory := ProjectSettings.globalize_path(directory)
	DirAccess.make_dir_recursive_absolute(absolute_directory)
	var safe_id := capture_id.replace("/", "_").replace("\\", "_")
	var path := directory + "/" + safe_id + ".png"
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return ""
	return path if image.save_png(path) == OK else ""
