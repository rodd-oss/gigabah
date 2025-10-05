@tool
extends MarginContainer

@onready var vbox_container: VBoxContainer = $HBoxContainer/VBoxContainer
@onready var generate_button: Button = $HBoxContainer/VBoxContainer/GenerateButton
@onready var edit_settings_button: Button = $HBoxContainer/VBoxContainer/EditSettingsButton

var sprite_frames: SpriteFrames
var bottom_panel_button: Button

@onready var ani_config: SpriteSheetGeneratorConfig = load("res://addons/sprite_frames_generator/sprite_sheet_generator_config/sprite_sheet_generator_config.tres")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	show_options_in_inspector()
	
	edit_settings_button.pressed.connect(show_options_in_inspector, CONNECT_DEFERRED)

func show_options_in_inspector() -> void:
	EditorInterface.edit_resource(ani_config)

func initialize(button: Button) -> void:
	bottom_panel_button = button
	bottom_panel_button.pressed.connect(show_options_in_inspector, CONNECT_DEFERRED)
	

func _on_generate_button_pressed() -> void:
	var sprite_sheets_entries: Array[SpriteSheetEntry] = ani_config.sprite_sheets

	# for print_entry in sprite_sheets_entries:
	# 	print(print_entry.file_name, " -> ", print_entry.texture)
	# return

	if ani_config.base_sprite_frames == null:
		push_error("Please assign a Base SpriteFrames resource in the configuration.")
		return

	if sprite_sheets_entries.size() == 0 or ani_config.animations_names.size() == 0:
		push_error("Please select at least one sprite sheet and one animation.")
		return
	
	var new_sprite_frames_list: Array[SpriteFrames] = []

	for sprite_sheet_entery in sprite_sheets_entries:
		var new_frames = _create_sprite_frames(sprite_sheet_entery, ani_config)

		new_sprite_frames_list.append(new_frames)
	
	print("Generated %d SpriteFrames resources." % new_sprite_frames_list.size())

	DirAccess.make_dir_recursive_absolute(ani_config.output_directory)
	for i in range(new_sprite_frames_list.size()):
		var path = ani_config.output_directory.path_join(ani_config.sprite_sheets[i].file_name)
		ResourceSaver.save(new_sprite_frames_list[i], path)

	
func _create_sprite_frames(entry: SpriteSheetEntry, config: SpriteSheetGeneratorConfig) -> SpriteFrames:
	var new_sprite_frames = SpriteFrames.new()
	new_sprite_frames.resource_name = entry.file_name
	var texture = entry.texture
	
	if not texture:
		push_error("SpriteSheetEntry '%s' has no texture assigned." % entry.file_name)
		return new_sprite_frames # Return empty SpriteFrames if no texture

	if not config.base_sprite_frames:
		push_error("Base SpriteFrames not assigned in configuration.")
		return new_sprite_frames # Return empty SpriteFrames if no base frames

	for animation in config.animations_names:
		if animation == "default":
			continue

		new_sprite_frames.add_animation(animation)
		new_sprite_frames.set_animation_speed(animation, config.base_sprite_frames.get_animation_speed(animation))
		new_sprite_frames.set_animation_loop(animation, config.base_sprite_frames.get_animation_loop(animation))

		for i in config.base_sprite_frames.get_frame_count(animation):
			var updated_texture: AtlasTexture = config.base_sprite_frames.get_frame_texture(animation, i).duplicate()
			if updated_texture is AtlasTexture:
				updated_texture.atlas = texture
			new_sprite_frames.add_frame(animation, updated_texture)

	return new_sprite_frames