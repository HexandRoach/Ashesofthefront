extends Control

@onready var display_mode_option: OptionButton = $OptionsOverlay/OptionsLayout/DisplayModeOption
@onready var master_volume_slider: HSlider = $OptionsOverlay/OptionsLayout/MasterVolumeSlider


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	display_mode_option.clear()
	display_mode_option.add_item("WINDOWED")
	display_mode_option.add_item("FULLSCREEN")

	await get_tree().process_frame
	display_mode_option.select(1)

	master_volume_slider.value = 0.5

	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(master_bus, 0.5)


func _on_options_button_pressed() -> void:
	_update_display_mode_selection()
	$OptionsOverlay.show()


func _on_option_back_button_pressed() -> void:
	$OptionsOverlay.hide()


func _on_display_mode_option_item_selected(index: int) -> void:
	if index == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

		await get_tree().process_frame

		var window_size := Vector2i(1280, 720)
		DisplayServer.window_set_size(window_size)

		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - window_size) / 2)

	elif index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _update_display_mode_selection() -> void:
	var current_mode := DisplayServer.window_get_mode()

	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		display_mode_option.select(1)
	else:
		display_mode_option.select(0)


func _on_exit_game_button_pressed() -> void:
	$ExitDialog.popup_centered()


func _on_exit_dialog_confirmed() -> void:
	get_tree().quit()


func _on_master_volume_slider_value_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(master_bus, value)
