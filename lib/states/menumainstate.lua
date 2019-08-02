require("lib/states/GameState")
MenuMainState = MenuMainState or class(GameState)
function MenuMainState:init(game_state_machine)
	GameState.init(self, "menu_main", game_state_machine)
end
function MenuMainState:at_enter(old_state)
	managers.platform:set_rich_presence("Idle")
	if old_state:name() ~= "freeflight" or not managers.menu:is_active() then
		managers.menu_scene:setup_camera()
		managers.menu_scene:set_scene_template("standard")
		self._sound_listener = SoundDevice:create_listener("main_menu")
		self._sound_listener:activate(true)
		managers.menu:open_menu("menu_main")
		managers.music:post_event("menu_music")
		if Global.load_start_menu_lobby then
			if managers.network:session() and (Network:is_server() or managers.network:session():server_peer()) then
				managers.overlay_effect:play_effect({
					color = Color.black,
					fade_in = 0,
					sustain = 0.5,
					fade_out = 0.5,
					blend_mode = "normal"
				})
				managers.menu:external_enter_online_menus()
				managers.menu:on_enter_lobby()
			else
				self:on_server_left()
			end
		elseif Global.load_start_menu then
			managers.overlay_effect:play_effect({
				color = Color.black,
				fade_in = 0,
				sustain = 0.25,
				fade_out = 0.25,
				blend_mode = "normal"
			})
		end
	end
	local has_invite = false
	if SystemInfo:platform() == Idstring("PS3") then
		Global.boot_invite = Global.boot_invite or {}
		if Application:is_booted_from_invitation() and not Global.boot_invite.used then
			has_invite = true
			Global.boot_invite.used = false
			Global.boot_invite.pending = true
			if 0 < #PSN:get_world_list() and PSN:is_online() then
				print("had world list, can join now")
				managers.network.matchmake:join_boot_invite()
			else
				managers.menu:open_ps3_sign_in_menu(function(success)
					print("success", success)
				end)
			end
		end
	elseif SystemInfo:platform() == Idstring("WIN32") then
		if Global.boot_invite then
			has_invite = true
			local lobby = Global.boot_invite
			Global.boot_invite = nil
			managers.network.matchmake:join_server_with_check(lobby)
		end
	elseif SystemInfo:platform() == Idstring("X360") and Global.boot_invite and next(Global.boot_invite) then
		has_invite = true
		managers.network.matchmake:join_boot_invite()
	end
	if Global.open_trial_buy then
		Global.open_trial_buy = nil
		managers.menu:open_node("trial_info")
	elseif not has_invite and not managers.network:session() and not Global.mission_manager.has_played_tutorial then
		local yes_func = function()
			MenuCallbackHandler:play_safehouse()
		end
		managers.menu:show_question_start_tutorial({yes_func = yes_func})
	end
end
function MenuMainState:at_exit(new_state)
	if new_state:name() ~= "freeflight" then
		managers.menu:close_menu("menu_main")
	end
	if self._sound_listener then
		self._sound_listener:delete()
		self._sound_listener = nil
	end
end
function MenuMainState:on_server_left()
	if managers.network:session() and managers.network:session():has_recieved_ok_to_load_level() then
		return
	end
	self:_create_server_left_dialog()
end
function MenuMainState:_create_server_left_dialog()
	local dialog_data = {}
	dialog_data.title = managers.localization:text("dialog_warning_title")
	dialog_data.text = Global.on_server_left_message and managers.localization:text(Global.on_server_left_message) or managers.localization:text("dialog_the_host_has_left_the_game")
	Global.on_server_left_message = nil
	dialog_data.id = "server_left_dialog"
	local ok_button = {}
	ok_button.text = managers.localization:text("dialog_ok")
	ok_button.callback_func = callback(self, self, "on_server_left_ok_pressed")
	dialog_data.button_list = {ok_button}
	managers.system_menu:show(dialog_data)
end
function MenuMainState:on_server_left_ok_pressed()
	print("[MenuMainState:on_server_left_ok_pressed]")
	managers.menu:on_leave_lobby()
end
function MenuMainState:_create_disconnected_dialog()
	managers.system_menu:close("server_left_dialog")
	managers.menu:show_mp_disconnected_internet_dialog({
		ok_func = callback(self, self, "on_server_left_ok_pressed")
	})
end
