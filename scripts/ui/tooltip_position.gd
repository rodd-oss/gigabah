class_name TooltipPosition
extends Node

@export var source_control: Control
@export var tooltip_side: Side = SIDE_TOP
@export var spacing: int = 0


func _ready() -> void:
	if not source_control:
		return

	var parent := get_parent()
	if not parent or parent is not PopupPanel:
		push_warning("parent isn't popuppanel")
		return

	var popup := parent as PopupPanel
	popup.size_changed.connect(_on_popup_size_changed)
	call_deferred(&"_set_popup_position", popup)


func _set_popup_position(popup: PopupPanel) -> void:
	var src_rect := source_control.get_global_rect()
	var pop_size := popup.size

	if tooltip_side == SIDE_TOP or tooltip_side == SIDE_BOTTOM:
		popup.position.x = int(src_rect.position.x)
		popup.position.x += int(src_rect.size.x / 2.0)
		popup.position.x -= int(pop_size.x / 2.0)

		if tooltip_side == SIDE_TOP:
			popup.position.y = int(src_rect.position.y)
			popup.position.y -= int(pop_size.y)
			popup.position.y -= spacing
		else:
			popup.position.y = int(src_rect.position.y)
			popup.position.y += int(src_rect.size.y)
			popup.position.y += spacing

	if tooltip_side == SIDE_LEFT or tooltip_side == SIDE_RIGHT:
		popup.position.y = int(src_rect.position.y)
		popup.position.y += int(src_rect.size.y / 2.0)
		popup.position.y -= int(pop_size.y / 2.0)

		if tooltip_side == SIDE_LEFT:
			popup.position.x = int(src_rect.position.x)
			popup.position.x -= int(pop_size.x)
			popup.position.x -= spacing
		else:
			popup.position.x = int(src_rect.position.x)
			popup.position.x += int(src_rect.size.x)
			popup.position.x += spacing


func _on_popup_size_changed() -> void:
	var popup := get_parent() as PopupPanel
	_set_popup_position(popup)
