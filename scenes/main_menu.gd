extends Control

const SETTINGS_PATH: String = "user://settings.cfg"

@onready var display_mode_option: OptionButton = $OptionsOverlay/OptionsLayout/DisplayModeOption
@onready var master_volume_slider: HSlider = $OptionsOverlay/OptionsLayout/MasterVolumeSlider
@onready var exit_dialog: ConfirmationDialog = $ExitDialog

var exit_dialog_open := false


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	display_mode_option.clear()
	display_mode_option.add_item("WINDOWED")
	display_mode_option.add_item("FULLSCREEN")
	display_mode_option.select(1)

	exit_dialog.get_ok_button().hide()
	exit_dialog.get_cancel_button().hide()
	exit_dialog.dialog_close_on_escape = false

	_load_master_volume()


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
		var window_position := Vector2i(
			int((screen_size.x - window_size.x) / 2.0),
			int((screen_size.y - window_size.y) / 2.0)
		)

		DisplayServer.window_set_position(window_position)

	elif index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_exit_game_button_pressed() -> void:
	exit_dialog_open = true
	exit_dialog.popup_centered()
	exit_dialog.grab_focus()


func _update_display_mode_selection() -> void:
	var current_mode: int = DisplayServer.window_get_mode()

	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		display_mode_option.select(1)
	else:
		display_mode_option.select(0)


func _save_master_volume(volume: float) -> void:
	var config := ConfigFile.new()
	var load_error: Error = config.load(SETTINGS_PATH)

	if load_error != OK:
		print("Creating new settings file.")

	config.set_value("audio", "master_volume", volume)

	var save_error: Error = config.save(SETTINGS_PATH)

	if save_error == OK:
		print("SAVED master volume: ", volume)
	else:
		print("FAILED to save master volume. Error: ", save_error)


func _load_master_volume() -> void:
	var config := ConfigFile.new()
	var load_error: Error = config.load(SETTINGS_PATH)

	var saved_volume: float = 0.5

	if load_error == OK:
		saved_volume = float(config.get_value("audio", "master_volume", 0.5))
		print("LOADED master volume: ", saved_volume)
	else:
		print("No saved volume yet. Using default: 0.5")

	master_volume_slider.set_value_no_signal(saved_volume)

	var master_bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(master_bus, saved_volume)


func _on_master_volume_slider_value_changed(value: float) -> void:
	print("SLIDER SIGNAL FIRED: ", value)

	var master_bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(master_bus, value)

	_save_master_volume(value)


func _process(_delta: float) -> void:
	if not exit_dialog_open:
		return

	if Input.is_key_pressed(KEY_Y):
		get_tree().quit()

	elif Input.is_key_pressed(KEY_N):
		exit_dialog_open = false
		exit_dialog.hide()

		get_viewport().set_input_as_handled()
