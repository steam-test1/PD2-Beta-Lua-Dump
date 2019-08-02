require("lib/states/GameState")
MenuTitlescreenState = MenuTitlescreenState or class(GameState)
function MenuTitlescreenState:init(game_state_machine, setup)
	GameState.init(self, "menu_titlescreen", game_state_machine)
	if setup then
		self:setup()
	end
end
local is_ps3 = SystemInfo:platform() == Idstring("PS3")
local is_x360 = SystemInfo:platform() == Idstring("X360")
function MenuTitlescreenState:setup()
	local res = RenderSettings.resolution
	local gui = Overlay:gui()
	self._workspace = managers.gui_data:create_saferect_workspace()
	self._workspace:hide()
	managers.gui_data:layout_workspace(self._workspace)
	self._full_workspace = gui:create_screen_workspace()
	self._full_workspace:hide()
	self._back_drop_gui = MenuBackdropGUI:new()
	self._back_drop_gui:hide()
	local bitmap = self._workspace:panel():bitmap({
		texture = "guis/textures/menu_title_screen",
		layer = 1
	})
	bitmap:set_center(self._workspace:panel():w() / 2, self._workspace:panel():h() / 2)
	self._full_workspace:panel():rect({
		visible = false,
		color = Color.black,
		layer = 0
	})
	local text_id = (is_ps3 or is_x360) and "menu_press_start" or "menu_visit_forum3"
	local text = self._workspace:panel():text({
		text = managers.localization:text(text_id),
		font = tweak_data.menu.pd2_large_font,
		font_size = tweak_data.menu.topic_font_size,
		color = Color.white,
		align = "center",
		vertical = "bottom",
		w = self._workspace:panel():w(),
		h = self._workspace:panel():h(),
		layer = 2
	})
	text:set_bottom(self._workspace:panel():h() / 1.25)
	self._controller_list = {}
	for index = 1, managers.controller:get_wrapper_count() do
		self._controller_list[index] = managers.controller:create_controller("title_" .. index, index, false)
	end
	self:reset_attract_video()
end
function MenuTitlescreenState:at_enter()
	if not self._controller_list then
		self:setup()
		Application:stack_dump_error("Shouldn't enter title more than once. Except when toggling freeflight.")
	end
	managers.music:post_event("menu_music")
	managers.menu:input_enabled(false)
	for index, controller in ipairs(self._controller_list) do
		controller:enable()
	end
	managers.overlay_effect:play_effect({
		color = Color.black,
		fade_in = 0,
		sustain = 0.1,
		fade_out = 0.4,
		blend_mode = "normal"
	})
	managers.menu_scene:setup_camera()
	managers.menu_scene:set_scene_template("lobby")
	self._workspace:show()
	self._full_workspace:show()
	managers.user:set_index(nil)
	managers.controller:set_default_wrapper_index(nil)
	self._clbk_game_has_music_control_callback = callback(self, self, "clbk_game_has_music_control")
	managers.platform:add_event_callback("media_player_control", self._clbk_game_has_music_control_callback)
	self:reset_attract_video()
end
function MenuTitlescreenState:clbk_game_has_music_control(status)
	if alive(self._attract_video_gui) then
		self._attract_video_gui:set_volume_gain(status and 1 or 0)
	end
end
function MenuTitlescreenState:update(t, dt)
	if self._waiting_for_loaded_savegames then
		if not managers.savefile:is_in_loading_sequence() and not self._user_has_changed then
			self:_load_savegames_done()
		end
		return
	end
	self:check_confirm_pressed()
	if managers.system_menu:is_active() then
		self:reset_attract_video()
	else
		self._controller_index = self:get_start_pressed_controller_index()
		if self._controller_index then
			managers.controller:set_default_wrapper_index(self._controller_index)
			managers.user:set_index(self._controller_index)
			managers.user:check_user(callback(self, self, "check_user_callback"), true)
			if managers.dlc:has_corrupt_data() and not Global.corrupt_dlc_msg_shown then
				Global.corrupt_dlc_msg_shown = true
				print("[MenuTitlescreenState:update] showing corrupt_DLC")
				managers.menu:show_corrupt_dlc()
			end
		elseif not self:check_attract_video() and self:is_attract_video_delay_done() then
			self:play_attract_video()
		end
	end
end
function MenuTitlescreenState:get_start_pressed_controller_index()
	for index, controller in ipairs(self._controller_list) do
		if is_ps3 or is_x360 then
			if controller:get_input_pressed("start") then
				return index
			end
		else
			if controller:get_any_input_pressed() then
				return index
			end
			if controller._default_controller_id == "keyboard" and (#Input:keyboard():pressed_list() > 0 or 0 < #Input:mouse():pressed_list()) then
				return index
			end
		end
	end
	return nil
end
function MenuTitlescreenState:check_confirm_pressed()
	for index, controller in ipairs(self._controller_list) do
		if controller:get_input_pressed("confirm") then
			print("check_confirm_pressed")
			local active, dialog = managers.system_menu:is_active_by_id("invite_join_message")
			if active then
				print("close")
				dialog:button_pressed_callback()
			end
			local active, dialog = managers.system_menu:is_active_by_id("user_changed")
			if active then
				print("close user_changed")
				dialog:button_pressed_callback()
			end
			local active, dialog = managers.system_menu:is_active_by_id("inactive_user_accepted_invite")
			if active then
				print("close inactive_user_accepted_invite")
				dialog:button_pressed_callback()
			end
		end
	end
end
function MenuTitlescreenState:check_user_callback(success)
	if success then
		managers.user:check_storage(callback(self, self, "check_storage_callback"), true)
	else
		local dialog_data = {}
		dialog_data.title = managers.localization:text("dialog_warning_title")
		dialog_data.text = managers.localization:text("dialog_skip_signin_warning")
		local yes_button = {}
		yes_button.text = managers.localization:text("dialog_yes")
		yes_button.callback_func = callback(self, self, "continue_without_saving_yes_callback")
		local no_button = {}
		no_button.text = managers.localization:text("dialog_no")
		no_button.callback_func = callback(self, self, "continue_without_saving_no_callback")
		dialog_data.button_list = {yes_button, no_button}
		managers.system_menu:show(dialog_data)
	end
end
function MenuTitlescreenState:check_storage_callback(success)
	if success then
		self._waiting_for_loaded_savegames = true
	else
		local dialog_data = {}
		dialog_data.title = managers.localization:text("dialog_warning_title")
		dialog_data.text = managers.localization:text("dialog_skip_storage_warning")
		local yes_button = {}
		yes_button.text = managers.localization:text("dialog_yes")
		yes_button.callback_func = callback(self, self, "continue_without_saving_yes_callback")
		local no_button = {}
		no_button.text = managers.localization:text("dialog_no")
		no_button.callback_func = callback(self, self, "continue_without_saving_no_callback")
		dialog_data.button_list = {yes_button, no_button}
		managers.system_menu:show(dialog_data)
	end
end
function MenuTitlescreenState:_load_savegames_done()
	local sound_source = SoundDevice:create_source("MenuTitleScreen")
	sound_source:post_event("menu_start")
	self:gsm():change_state_by_name("menu_main")
end
function MenuTitlescreenState:continue_without_saving_yes_callback()
	self:gsm():change_state_by_name("menu_main")
end
function MenuTitlescreenState:continue_without_saving_no_callback()
	managers.user:set_index(nil)
	managers.controller:set_default_wrapper_index(nil)
end
function MenuTitlescreenState:check_attract_video()
	if alive(self._attract_video_gui) then
		if self._attract_video_gui:loop_count() > 0 or self:is_any_input_pressed() then
			self:reset_attract_video()
		else
			return true
		end
	elseif self:is_any_input_pressed() then
		self:reset_attract_video()
	end
	return false
end
function MenuTitlescreenState:is_any_input_pressed()
	for _, controller in ipairs(self._controller_list) do
		if controller:get_any_input_pressed() then
			return true
		end
	end
	return false
end
function MenuTitlescreenState:reset_attract_video()
	self._attract_video_time = TimerManager:main():time()
	if alive(self._attract_video_gui) then
		self._attract_video_gui:stop()
		self._full_workspace:panel():remove(self._attract_video_gui)
		self._attract_video_gui = nil
	end
end
function MenuTitlescreenState:is_attract_video_delay_done()
	return TimerManager:main():time() > self._attract_video_time + _G.tweak_data.states.title.ATTRACT_VIDEO_DELAY
end
function MenuTitlescreenState:play_attract_video()
	self:reset_attract_video()
	local res = RenderSettings.resolution
	local src_width, src_height = 1280, 720
	local dest_width, dest_height
	if src_width / src_height > res.x / res.y then
		dest_width = res.x
		dest_height = src_height * dest_width / src_width
	else
		dest_height = res.y
		dest_width = src_width * dest_height / src_height
	end
	local x = (res.x - dest_width) / 2
	local y = (res.y - dest_height) / 2
	self._attract_video_gui = self._full_workspace:panel():video({
		video = "movies/attract",
		x = x,
		y = y,
		width = dest_width,
		height = dest_height,
		layer = tweak_data.gui.ATTRACT_SCREEN_LAYER
	})
	self._attract_video_gui:play()
	self._attract_video_gui:set_volume_gain(managers.music:has_music_control() and 1 or 0)
end
function MenuTitlescreenState:at_exit()
	managers.platform:remove_event_callback("media_player_control", self._clbk_game_has_music_control_callback)
	if alive(self._workspace) then
		Overlay:gui():destroy_workspace(self._workspace)
		self._workspace = nil
	end
	if alive(self._full_workspace) then
		Overlay:gui():destroy_workspace(self._full_workspace)
		self._full_workspace = nil
	end
	self._back_drop_gui:destroy()
	if self._controller_list then
		for _, controller in ipairs(self._controller_list) do
			controller:destroy()
		end
		self._controller_list = nil
	end
	managers.menu_component:test_camera_shutter_tech()
	managers.menu:input_enabled(true)
	managers.user:set_active_user_state_change_quit(true)
	managers.system_menu:init_finalize()
end
function MenuTitlescreenState:on_user_changed(old_user_data, user_data)
	print("MenuTitlescreenState:on_user_changed")
	if old_user_data and old_user_data.signin_state ~= "not_signed_in" and self._waiting_for_loaded_savegames then
		self._user_has_changed = true
	end
end
function MenuTitlescreenState:on_storage_changed(old_user_data, user_data)
	print("MenuTitlescreenState:on_storage_changed")
	if self._waiting_for_loaded_savegames then
		self._waiting_for_loaded_savegames = nil
	end
end
