extends Control

const SETTINGS_PATH: String = "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

# 0 means unlimited / uncapped.
const FRAME_RATE_LIMITS: Array[int] = [
	0,
	30,
	60,
	120,
	144,
	165,
	240
]

const DEFAULT_WINDOWED_RESOLUTION_INDEX := 0
const DEFAULT_FULLSCREEN_RESOLUTION_INDEX := 2
const DEFAULT_DISPLAY_MODE_INDEX := 1
const DEFAULT_MASTER_VOLUME := 0.5

# 0 = OFF
# 1 = ON
# 2 = ADAPTIVE
const DEFAULT_VSYNC_INDEX := 1

# 0 = Unlimited
# 1 = 30 FPS
# 2 = 60 FPS
# 3 = 120 FPS
# 4 = 144 FPS
# 5 = 165 FPS
# 6 = 240 FPS
const DEFAULT_FRAME_RATE_LIMIT_INDEX := 2

@onready var display_mode_option: OptionButton = $OptionsOverlay/OptionsLayout/SettingsPages/VideoPage/DisplayModeOption
@onready var resolution_option: OptionButton = $OptionsOverlay/OptionsLayout/SettingsPages/VideoPage/ResolutionOption
@onready var vsync_option: OptionButton = $OptionsOverlay/OptionsLayout/SettingsPages/VideoPage/VSyncOption
@onready var frame_rate_limit_option: OptionButton = $OptionsOverlay/OptionsLayout/SettingsPages/VideoPage/FrameRateLimitOption

@onready var master_volume_slider: HSlider = $OptionsOverlay/OptionsLayout/MasterVolumeSlider
@onready var exit_dialog: ConfirmationDialog = $ExitDialog

@onready var video_page: VBoxContainer = $OptionsOverlay/OptionsLayout/SettingsPages/VideoPage
@onready var graphics_page: VBoxContainer = $OptionsOverlay/OptionsLayout/SettingsPages/GraphicsPage

# These must be direct children of MainMenu.
@onready var video_confirm_dialog: ConfirmationDialog = $VideoConfirmDialog
@onready var video_confirm_timer: Timer = $VideoConfirmTimer
@onready var graphics_settings_button: Button = $OptionsOverlay/OptionsLayout/CategoryButtons/GraphicsSettingsButton

var exit_dialog_open := false
var video_change_pending := false

# 0 = 1280 x 720
# 1 = 1600 x 900
var current_windowed_resolution_index := DEFAULT_WINDOWED_RESOLUTION_INDEX

# 2 = 1920 x 1080
# 3 = 2560 x 1440
var current_fullscreen_resolution_index := DEFAULT_FULLSCREEN_RESOLUTION_INDEX

# 0 = WINDOWED
# 1 = FULLSCREEN
var current_display_mode_index := DEFAULT_DISPLAY_MODE_INDEX

# 0 = OFF
# 1 = ON
# 2 = ADAPTIVE
var current_vsync_index := DEFAULT_VSYNC_INDEX

# Index into FRAME_RATE_LIMITS.
var current_frame_rate_limit_index := DEFAULT_FRAME_RATE_LIMIT_INDEX

# Confirmed display settings, used when the player chooses REVERT
# or the 10-second confirmation timer reaches zero.
var previous_windowed_resolution_index := DEFAULT_WINDOWED_RESOLUTION_INDEX
var previous_fullscreen_resolution_index := DEFAULT_FULLSCREEN_RESOLUTION_INDEX
var previous_display_mode_index := DEFAULT_DISPLAY_MODE_INDEX


func _ready() -> void:
	_setup_display_mode_options()
	_setup_resolution_options()
	_setup_vsync_options()
	_setup_frame_rate_limit_options()

	_load_settings()
	_apply_loaded_video_settings()

	exit_dialog.get_ok_button().hide()
	exit_dialog.get_cancel_button().hide()
	exit_dialog.dialog_close_on_escape = false

	video_confirm_dialog.title = "Keep Display Settings?"
	video_confirm_dialog.dialog_text = (
		"Keep these display settings?\n"
		+ "They will revert automatically in 10 seconds."
	)
	video_confirm_dialog.dialog_close_on_escape = false
	video_confirm_dialog.exclusive = true
	video_confirm_dialog.get_ok_button().text = "KEEP SETTINGS"
	video_confirm_dialog.get_cancel_button().text = "REVERT"

	video_confirm_timer.wait_time = 10.0
	video_confirm_timer.one_shot = true

	video_page.hide()
	graphics_page.hide()
	graphics_settings_button.pressed.connect(
	_on_graphics_settings_button_pressed
)


func _setup_display_mode_options() -> void:
	display_mode_option.clear()
	display_mode_option.add_item("WINDOWED")
	display_mode_option.add_item("FULLSCREEN")


func _setup_resolution_options() -> void:
	resolution_option.clear()

	for resolution: Vector2i in RESOLUTIONS:
		resolution_option.add_item(
			"%d x %d" % [
				resolution.x,
				resolution.y
			]
		)


func _setup_vsync_options() -> void:
	vsync_option.clear()
	vsync_option.add_item("OFF")
	vsync_option.add_item("ON")
	vsync_option.add_item("ADAPTIVE")


func _setup_frame_rate_limit_options() -> void:
	frame_rate_limit_option.clear()
	frame_rate_limit_option.add_item("UNLIMITED")
	frame_rate_limit_option.add_item("30 FPS")
	frame_rate_limit_option.add_item("60 FPS")
	frame_rate_limit_option.add_item("120 FPS")
	frame_rate_limit_option.add_item("144 FPS")
	frame_rate_limit_option.add_item("165 FPS")
	frame_rate_limit_option.add_item("240 FPS")


func _load_settings() -> void:
	var config := ConfigFile.new()
	var load_error: Error = config.load(SETTINGS_PATH)

	if load_error != OK:
		current_windowed_resolution_index = (
			DEFAULT_WINDOWED_RESOLUTION_INDEX
		)

		current_fullscreen_resolution_index = (
			DEFAULT_FULLSCREEN_RESOLUTION_INDEX
		)

		current_display_mode_index = (
			DEFAULT_DISPLAY_MODE_INDEX
		)

		current_vsync_index = DEFAULT_VSYNC_INDEX

		current_frame_rate_limit_index = (
			DEFAULT_FRAME_RATE_LIMIT_INDEX
		)

		master_volume_slider.set_value_no_signal(
			DEFAULT_MASTER_VOLUME
		)

		_set_master_volume(DEFAULT_MASTER_VOLUME)
		return

	var saved_volume: float = float(
		config.get_value(
			"audio",
			"master_volume",
			DEFAULT_MASTER_VOLUME
		)
	)

	current_windowed_resolution_index = clampi(
		int(config.get_value(
			"video",
			"windowed_resolution_index",
			DEFAULT_WINDOWED_RESOLUTION_INDEX
		)),
		0,
		1
	)

	current_fullscreen_resolution_index = clampi(
		int(config.get_value(
			"video",
			"fullscreen_resolution_index",
			DEFAULT_FULLSCREEN_RESOLUTION_INDEX
		)),
		2,
		3
	)

	current_display_mode_index = clampi(
		int(config.get_value(
			"video",
			"display_mode_index",
			DEFAULT_DISPLAY_MODE_INDEX
		)),
		0,
		1
	)

	current_vsync_index = clampi(
		int(config.get_value(
			"video",
			"vsync_index",
			DEFAULT_VSYNC_INDEX
		)),
		0,
		2
	)

	current_frame_rate_limit_index = clampi(
		int(config.get_value(
			"video",
			"frame_rate_limit_index",
			DEFAULT_FRAME_RATE_LIMIT_INDEX
		)),
		0,
		FRAME_RATE_LIMITS.size() - 1
	)

	master_volume_slider.set_value_no_signal(saved_volume)
	_set_master_volume(saved_volume)


func _save_settings() -> void:
	var config := ConfigFile.new()

	config.load(SETTINGS_PATH)

	config.set_value(
		"audio",
		"master_volume",
		master_volume_slider.value
	)

	config.set_value(
		"video",
		"windowed_resolution_index",
		current_windowed_resolution_index
	)

	config.set_value(
		"video",
		"fullscreen_resolution_index",
		current_fullscreen_resolution_index
	)

	config.set_value(
		"video",
		"display_mode_index",
		current_display_mode_index
	)

	config.set_value(
		"video",
		"vsync_index",
		current_vsync_index
	)

	config.set_value(
		"video",
		"frame_rate_limit_index",
		current_frame_rate_limit_index
	)

	var save_error: Error = config.save(SETTINGS_PATH)

	if save_error != OK:
		push_warning(
			"Could not save settings.cfg. Error: %s" % save_error
		)


func _apply_loaded_video_settings() -> void:
	if current_display_mode_index == 0:
		_set_windowed_resolution(
			current_windowed_resolution_index,
			false
		)
	else:
		_set_fullscreen_resolution(
			current_fullscreen_resolution_index,
			false
		)

	_apply_vsync(current_vsync_index)
	_apply_frame_rate_limit(current_frame_rate_limit_index)


func _apply_vsync(index: int) -> void:
	current_vsync_index = clampi(index, 0, 2)
	vsync_option.select(current_vsync_index)

	match current_vsync_index:
		0:
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_DISABLED
			)

		1:
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED
			)

		2:
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ADAPTIVE
			)


func _apply_frame_rate_limit(index: int) -> void:
	current_frame_rate_limit_index = clampi(
		index,
		0,
		FRAME_RATE_LIMITS.size() - 1
	)

	frame_rate_limit_option.select(
		current_frame_rate_limit_index
	)

	Engine.max_fps = FRAME_RATE_LIMITS[
		current_frame_rate_limit_index
	]


func _on_options_button_pressed() -> void:
	_update_display_mode_selection()
	video_page.hide()
	graphics_page.hide()
	$OptionsOverlay.show()


func _on_video_settings_button_pressed() -> void:
	video_page.show()


func _on_option_back_button_pressed() -> void:
	video_page.hide()
	graphics_page.hide()
	$OptionsOverlay.hide()


func _on_display_mode_option_item_selected(index: int) -> void:
	if video_change_pending:
		return

	if index != 0 and index != 1:
		return

	_begin_video_change_confirmation()

	if index == 0:
		_set_windowed_resolution(
			current_windowed_resolution_index,
			false
		)
	else:
		_set_fullscreen_resolution(
			current_fullscreen_resolution_index,
			false
		)


func _on_resolution_option_item_selected(index: int) -> void:
	if video_change_pending:
		return

	if index < 0 or index >= RESOLUTIONS.size():
		return

	_begin_video_change_confirmation()

	# 1280 x 720 and 1600 x 900 are windowed options.
	if index == 0 or index == 1:
		_set_windowed_resolution(index, false)

	# 1920 x 1080 and 2560 x 1440 are fullscreen options.
	else:
		_set_fullscreen_resolution(index, false)


func _on_vsync_option_item_selected(index: int) -> void:
	if index < 0 or index > 2:
		return

	_apply_vsync(index)
	_save_settings()


func _on_frame_rate_limit_option_item_selected(
	index: int
) -> void:
	if index < 0 or index >= FRAME_RATE_LIMITS.size():
		return

	_apply_frame_rate_limit(index)
	_save_settings()


func _begin_video_change_confirmation() -> void:
	previous_windowed_resolution_index = (
		current_windowed_resolution_index
	)

	previous_fullscreen_resolution_index = (
		current_fullscreen_resolution_index
	)

	previous_display_mode_index = current_display_mode_index

	video_change_pending = true

	video_confirm_dialog.dialog_text = (
		"Keep these display settings?\n"
		+ "They will revert automatically in 10 seconds."
	)

	video_confirm_dialog.popup_centered()
	video_confirm_timer.start()


func _on_video_confirm_dialog_confirmed() -> void:
	if not video_change_pending:
		return

	video_change_pending = false
	video_confirm_timer.stop()

	_save_settings()


func _on_video_confirm_dialog_canceled() -> void:
	_revert_video_settings()


func _on_video_confirm_timer_timeout() -> void:
	_revert_video_settings()


func _revert_video_settings() -> void:
	if not video_change_pending:
		return

	video_change_pending = false
	video_confirm_timer.stop()
	video_confirm_dialog.hide()

	current_windowed_resolution_index = (
		previous_windowed_resolution_index
	)

	current_fullscreen_resolution_index = (
		previous_fullscreen_resolution_index
	)

	current_display_mode_index = previous_display_mode_index

	if previous_display_mode_index == 0:
		_set_windowed_resolution(
			previous_windowed_resolution_index,
			false
		)
	else:
		_set_fullscreen_resolution(
			previous_fullscreen_resolution_index,
			false
		)


func _set_windowed_resolution(
	index: int,
	save_after_change: bool = true
) -> void:
	if index < 0 or index > 1:
		index = DEFAULT_WINDOWED_RESOLUTION_INDEX

	current_windowed_resolution_index = index
	current_display_mode_index = 0

	var window_size: Vector2i = RESOLUTIONS[index]

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED
	)

	DisplayServer.window_set_flag(
		DisplayServer.WINDOW_FLAG_BORDERLESS,
		false
	)

	await get_tree().create_timer(0.3).timeout

	DisplayServer.window_set_size(window_size)

	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var window_position := Vector2i(
		int((screen_size.x - window_size.x) / 2.0),
		int((screen_size.y - window_size.y) / 2.0)
	)

	DisplayServer.window_set_position(window_position)

	display_mode_option.select(0)
	resolution_option.select(index)

	if save_after_change:
		_save_settings()


func _set_fullscreen_resolution(
	index: int,
	save_after_change: bool = true
) -> void:
	if index < 2 or index > 3:
		index = DEFAULT_FULLSCREEN_RESOLUTION_INDEX

	current_fullscreen_resolution_index = index
	current_display_mode_index = 1

	display_mode_option.select(1)
	resolution_option.select(index)

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
	)

	if save_after_change:
		_save_settings()


func _on_reset_settings_button_pressed() -> void:
	if video_change_pending:
		video_change_pending = false
		video_confirm_timer.stop()
		video_confirm_dialog.hide()

	current_windowed_resolution_index = (
		DEFAULT_WINDOWED_RESOLUTION_INDEX
	)

	current_fullscreen_resolution_index = (
		DEFAULT_FULLSCREEN_RESOLUTION_INDEX
	)

	current_display_mode_index = DEFAULT_DISPLAY_MODE_INDEX

	master_volume_slider.set_value_no_signal(
		DEFAULT_MASTER_VOLUME
	)

	_set_master_volume(DEFAULT_MASTER_VOLUME)

	_set_fullscreen_resolution(
		DEFAULT_FULLSCREEN_RESOLUTION_INDEX,
		false
	)

	_apply_vsync(DEFAULT_VSYNC_INDEX)

	_apply_frame_rate_limit(
		DEFAULT_FRAME_RATE_LIMIT_INDEX
	)

	_save_settings()


func _on_exit_game_button_pressed() -> void:
	exit_dialog_open = true
	exit_dialog.popup_centered()
	exit_dialog.grab_focus()


func _update_display_mode_selection() -> void:
	var current_mode: int = DisplayServer.window_get_mode()

	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		current_display_mode_index = 1
		display_mode_option.select(1)
		resolution_option.select(
			current_fullscreen_resolution_index
		)
	else:
		current_display_mode_index = 0
		display_mode_option.select(0)
		resolution_option.select(
			current_windowed_resolution_index
		)

	vsync_option.select(current_vsync_index)

	frame_rate_limit_option.select(
		current_frame_rate_limit_index
	)


func _set_master_volume(value: float) -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")

	if master_bus == -1:
		push_warning("Master audio bus was not found.")
		return

	AudioServer.set_bus_volume_linear(master_bus, value)


func _on_master_volume_slider_value_changed(
	value: float
) -> void:
	_set_master_volume(value)
	_save_settings()


func _on_exit_dialog_confirmed() -> void:
	get_tree().quit()


func _on_exit_dialog_canceled() -> void:
	exit_dialog_open = false
	exit_dialog.hide()


func _process(_delta: float) -> void:
	if not exit_dialog_open:
		return

	if Input.is_key_pressed(KEY_Y):
		get_tree().quit()

	elif Input.is_key_pressed(KEY_N):
		exit_dialog_open = false
		exit_dialog.hide()

	get_viewport().set_input_as_handled()


func _on_graphics_settings_button_pressed() -> void:
	print("GRAPHICS BUTTON PRESSED")
	print("Before show - visible: ", graphics_page.visible)
	print("Before show - position: ", graphics_page.position)
	print("Before show - size: ", graphics_page.size)

	video_page.hide()
	graphics_page.show()

	print("After show - visible: ", graphics_page.visible)
	print("After show - position: ", graphics_page.position)
	print("After show - size: ", graphics_page.size)


func _on_graphics_back_button_pressed() -> void:
	graphics_page.hide()
