@tool
class_name SpriteSheetGeneratorConfig
extends Resource

enum NamingConvention {
	default,
	PascalCase,
	snake_case,
	kebab_case,
	camelCase
}

## The Base SpriteFrames to copy animations from
@export var base_sprite_frames: SpriteFrames:
	get:
		return base_sprite_frames
	set(value):
		base_sprite_frames = value
		if base_sprite_frames:
			_on_sprite_frames_changed()

@export var scan_from_directory: bool = false:
	get:
		return scan_from_directory
	set(value):
		scan_from_directory = value
		_on_scan_from_directory_changed()

@export var directory: String = "res://":
	get:
		return directory
	set(value):
		directory = value
		_on_directory_changed()
@export var file_extensions: Array[String] = ["png", "jpg", "jpeg"]

@export var naming_convention: NamingConvention = NamingConvention.default:
	get:
		return naming_convention
	set(value):
		naming_convention = value
		for entry in sprite_sheets:
			entry.change_naming_convention(naming_convention)
		notify_property_list_changed()
		emit_changed()

## List of sprite sheets to generate SpriteFrames from
@export var sprite_sheets: Array[SpriteSheetEntry] = []:
	get:
		return sprite_sheets
	set(value):
		sprite_sheets = value

		for i in range(sprite_sheets.size()):
			if not sprite_sheets[i]:
				sprite_sheets[i] = SpriteSheetEntry.new()

		notify_property_list_changed()
		emit_changed()

## List of animation names to copy from the base SpriteFrames
@export var animations_names: Array[String] = []:
	get:
		return animations_names
	set(value):
		animations_names = value
		emit_changed()


@export var output_directory: String = "res://sprite_frames_sheet_generator_output"


func _on_sprite_frames_changed():
	print("SpriteFrames changed")
	var new_animions_names: Array[String] = []

	for animation in base_sprite_frames.get_animation_names():
		new_animions_names.append(animation)

	animations_names = new_animions_names
	emit_changed()
	notify_property_list_changed()

func _on_scan_from_directory_changed():
	emit_changed()
	notify_property_list_changed()
	_on_directory_changed()

func _on_directory_changed():
	print("Directory changed")
	var enteries: Array[SpriteSheetEntry] = []
	if scan_from_directory:
		_scan_dir_recursive(directory, enteries)
		sprite_sheets = enteries

	emit_changed()
	notify_property_list_changed()

func _validate_property(property: Dictionary) -> void:
	if property.name == "directory" or property.name == "file_extensions":
		if not scan_from_directory:
			property.usage |= PROPERTY_USAGE_READ_ONLY
			notify_property_list_changed()
	

func _scan_dir_recursive(path: String, entries: Array[SpriteSheetEntry]) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_error("Could not open directory: %s" % path)
		return
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break

		if file_name == "." or file_name == "..":
			continue

		var file_path = path.path_join(file_name)
		if dir.current_is_dir():
			_scan_dir_recursive(file_path, entries)
			continue

		var ext = file_name.get_extension().to_lower()
		if ext in file_extensions:
			var texture = load(file_path)
			if texture and texture is Texture2D:
				var entry = SpriteSheetEntry.new(texture, file_name, naming_convention)
				# entry.texture = texture
				# entry.file_name = file_name.get_basename() + ".tres"
				entries.append(entry)

	dir.list_dir_end()