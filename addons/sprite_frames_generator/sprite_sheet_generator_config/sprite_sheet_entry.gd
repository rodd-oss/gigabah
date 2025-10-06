@tool
class_name SpriteSheetEntry
extends Resource

@export var texture: Texture2D:
    get:
        return texture
    set(value):
        texture = value
        if texture:
            file_name = _convert_file_name(texture.resource_path.get_file().get_basename(), naming_convention)
        notify_property_list_changed()
        emit_changed()


@export var file_name: String

@export var naming_convention: SpriteSheetGeneratorConfig.NamingConvention = SpriteSheetGeneratorConfig.NamingConvention.default:
    get:
        return naming_convention
    set(value):
        naming_convention = value
        file_name = _convert_file_name(file_name, naming_convention)
        notify_property_list_changed()
        emit_changed()


func _init(texture: Texture2D = null, file_name: String = "", naming_convention: SpriteSheetGeneratorConfig.NamingConvention = SpriteSheetGeneratorConfig.NamingConvention.default):
    self.texture = texture
    self.file_name = file_name
    self.naming_convention = naming_convention

    file_name = _convert_file_name(file_name, naming_convention)

func _get_name_from_path(path: String) -> String:
    return path.get_file().get_basename()


func _convert_file_name(file_name: String, naming_convention: SpriteSheetGeneratorConfig.NamingConvention) -> String:
    var base_name = file_name.get_basename()
    var extension = file_name.get_extension()
    extension = "tres"
    var new_base_name = convert_naming_convention(base_name, naming_convention)
    return "%s.%s" % [new_base_name, extension]

func change_naming_convention(new_convention: SpriteSheetGeneratorConfig.NamingConvention) -> void:
    naming_convention = new_convention
    file_name = _convert_file_name(file_name, naming_convention)
    notify_property_list_changed()
    emit_changed()

# Universal naming convention converter
# Usage: convert_naming_convention(text, target_convention: String)
# target_convention: "snake_case", "kebab-case", "PascalCase", "camelCase", "UPPER_SNAKE_CASE"
func convert_naming_convention(text: String, target_convention: SpriteSheetGeneratorConfig.NamingConvention) -> String:
    var words = _split_to_words(text)
    match target_convention:
        SpriteSheetGeneratorConfig.NamingConvention.snake_case:
            return String("_").join(words.map(func(w): return w.to_lower()))
        SpriteSheetGeneratorConfig.NamingConvention.kebab_case:
            return String("-").join(words.map(func(w): return w.to_lower()))
        SpriteSheetGeneratorConfig.NamingConvention.PascalCase:
            return String("").join(words.map(func(w): return w.capitalize()))
        SpriteSheetGeneratorConfig.NamingConvention.camelCase:
            if words.size() == 0:
                return ""
            var result = words[0].to_lower()
            for i in range(1, words.size()):
                result += words[i].capitalize()
            return result
        _:
            return text

# Helper: splits any convention to words (handles snake, kebab, Pascal, camel, UPPER_SNAKE)
func _split_to_words(text: String) -> Array[String]:
    var result: Array[String] = []
    var word = ""
    for i in text.length():
        var c = text[i]
        if c == '_' or c == '-' or c == ' ':
            if word != "":
                result.append(word)
                word = ""
        elif c.to_upper() == c and word != "":
            result.append(word)
            word = c.to_lower()
        else:
            word += c.to_lower()
    if word != "":
        result.append(word)
    return result