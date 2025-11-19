class_name Utils
extends Node

static func get_human_readable_byte_size(byte_size: int) -> String:
	if byte_size < 1024:
		return "%d B" % byte_size

	if byte_size < 1024 ** 2:
		return "%.2f KB" % (byte_size / 1024.0)

	if byte_size < 1024 ** 3:
		return "%.2f MB" % (byte_size / 1024.0 ** 2)

	if byte_size < 1024 ** 4:
		return "%.2f GB" % (byte_size / 1024.0 ** 3)

	if byte_size < 1024 ** 5:
		return "%.2f TB" % (byte_size / 1024.0 ** 4)

	if byte_size < 1024 ** 6:
		return "%.2f PB" % (byte_size / 1024.0 ** 5)

	if byte_size < 1024 ** 7:
		return "%.2f EB" % (byte_size / 1024.0 ** 6)

	if byte_size < 1024 ** 8:
		return "%.2f ZB" % (byte_size / 1024.0 ** 7)

	if byte_size < 1024 ** 9:
		return "%.2f YB" % (byte_size / 1024.0 ** 8)

	return "TOO MUCH"


static func get_human_readable_duration_short(secs: float) -> String:
	var v: float
	var s: String
	var neg := secs < 0.0

	if neg:
		secs = -secs

	if secs < 1.0:
		v = secs
		s = TranslationServer.translate(&"duration_short_milliseconds") % v
	elif secs < 60.0:
		v = secs
		s = TranslationServer.translate(&"duration_short_seconds") % v
	elif secs < 60.0 * 60.0:
		v = secs / 60.0
		s = TranslationServer.translate(&"duration_short_minutes") % v
	elif secs < 60.0 * 60.0 * 24.0:
		v = secs / 60.0 / 60.0
		s = TranslationServer.translate(&"duration_short_hours") % v
	elif secs < 60.0 * 60.0 * 24.0 * 7.0:
		v = secs / 60.0 / 60.0 / 24.0
		s = TranslationServer.translate(&"duration_short_days") % v
	elif secs < 60.0 * 60.0 * 24.0 * 7.0 * 30.0:
		v = secs / 60.0 / 60.0 / 24.0 / 7.0
		s = TranslationServer.translate(&"duration_short_weeks") % v
	elif secs < 60.0 * 60.0 * 24.0 * 7.0 * 30.0 * 12.0:
		v = secs / 60.0 / 60.0 / 24.0 / 7.0 / 30.0
		s = TranslationServer.translate(&"duration_short_months") % v
	else:
		v = secs / 60.0 / 60.0 / 24.0 / 7.0 / 30.0 / 12.0
		s = TranslationServer.translate(&"duration_short_years") % v

	return TranslationServer.translate(&"time_diff_ago") % s if neg else s


# array is variant to receive both untyped `Array` and typed packed
# arrays like `PackedInt32Array`
static func array_erase_replacing(array: Variant, index: int) -> void:
	if index < 0 or index >= array.size():
		return

	if array.size() == 1:
		array.clear()
		return

	var last_idx: int = array.size() - 1
	if index < last_idx:
		array[index] = array[last_idx]
	array.resize(last_idx)


static func quadratic_bezier_3d(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	return p0.lerp(p1, t).lerp(p2, t)


static func cycle_float(v: float, v_min: float, v_max: float) -> float:
	var v_range := v_max - v_min
	if v_range == 0.0:
		return v_min
	var rem := fmod(v - v_min, v_range)
	if rem < 0.0:
		rem += v_range
	return v_min + rem


## Order of iteration should be considered as random
class RecursiveChildrenIterator:
	var parent: Node
	var include_self_node: bool
	var include_internal_nodes: bool

	var _to_visit: Array[Node]
	var _current: Node


	func _init(
			node_parent: Node,
			include_self: bool = false,
			include_internal: bool = false,
	) -> void:
		assert(node_parent != null, "node_parent is null")
		parent = node_parent
		include_self_node = include_self
		include_internal_nodes = include_internal


	func _iter_init(_iter: Array) -> bool:
		if include_self_node:
			_current = parent
			return true

		if parent.get_child_count(include_internal_nodes) == 0:
			return false

		_to_visit = parent.get_children(include_internal_nodes)

		if _to_visit.is_empty():
			return false

		_current = _to_visit.pop_back()
		return true


	func _iter_get(_iter: Variant) -> Variant:
		return _current


	func _iter_next(_iter: Array) -> bool:
		if _current:
			_to_visit.append_array(_current.get_children(include_internal_nodes))

		if _to_visit.is_empty():
			return false

		_current = _to_visit.pop_back()
		return true
