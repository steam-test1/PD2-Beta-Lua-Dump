PlayerArrested = PlayerArrested or class(PlayerStandard)
function PlayerArrested:init(unit)
	PlayerArrested.super.init(self, unit)
	self._ids_escape = Idstring("escape")
	self._ids_cuffed = Idstring("cuffed")
end
function PlayerArrested:enter(state_data, enter_data)
	PlayerArrested.super.enter(self, state_data, enter_data)
	self._revive_SO_data = {
		unit = self._unit
	}
	self._old_selection = self._unit:inventory():equipped_selection()
	self:_start_action_handcuffed(managers.player:player_timer():time())
	self:_start_action_unequip_weapon(managers.player:player_timer():time(), {selection_wanted = 1})
	self._timer_finished = false
	if Network:is_server() then
		self._unit:base():set_slot(self._unit, 4)
		PlayerBleedOut._register_revive_SO(self._revive_SO_data, "untie")
	end
	managers.groupai:state():on_criminal_neutralized(self._unit)
	managers.groupai:state():report_criminal_downed(self._unit)
	managers.hud:pd_hide_text()
	self._unit:camera():camera_unit():base():set_target_tilt(0)
	self._unit:camera():camera_unit():base():set_limits(135, nil)
	self._unit:character_damage():on_arrested()
	self._unit:character_damage():set_invulnerable(true)
	self._entry_speech_clbk = "PlayerArrested_entryspeech"
	managers.enemy:add_delayed_clbk(self._entry_speech_clbk, callback(self, self, "clbk_entry_speech"), managers.player:player_timer():time() + 5 + 2 * math.random())
end
function PlayerArrested:_enter(enter_data)
	self._ext_movement:set_attention_settings({
		"pl_enemy_cur_peaceful",
		"pl_team_cur_peaceful",
		"pl_civ_cbt"
	})
	if Network:is_server() and self._ext_movement:nav_tracker() then
		managers.groupai:state():on_player_weapons_hot()
	end
end
function PlayerArrested:exit(state_data, new_state_name)
	PlayerArrested.super.exit(self, state_data, new_state_name)
	self._unit:character_damage():set_invulnerable(false)
	self:_end_action_handcuffed(managers.player:player_timer():time())
	PlayerBleedOut._unregister_revive_SO(self)
	self._SO_id = nil
	self._rescuer = nil
	self._unit:character_damage():on_freed()
	self._unit:camera():camera_unit():base():remove_limits()
	managers.hud:pd_hide_text()
	if self._entry_speech_clbk then
		managers.enemy:remove_delayed_clbk(self._entry_speech_clbk)
		self._entry_speech_clbk = nil
	end
	if not self._unequip_weapon_expire_t and not self._timer_finished then
		local exit_data = {
			equip_weapon = self._old_selection
		}
		return exit_data
	end
end
function PlayerArrested:interaction_blocked()
	return true
end
function PlayerArrested:update(t, dt)
	PlayerArrested.super.update(self, t, dt)
end
function PlayerArrested:_update_check_actions(t, dt)
	local input = self:_get_input()
	if input.btn_stats_screen_press then
		self._unit:base():set_stats_screen_visible(true)
	elseif input.btn_stats_screen_release then
		self._unit:base():set_stats_screen_visible(false)
	end
	self:_update_foley(t, input)
	if self._unit:character_damage()._arrested_timer <= 0 and not self._timer_finished then
		self._timer_finished = true
		managers.hud:pd_stop_timer()
		managers.hud:pd_show_text()
		self._unit:camera():play_redirect(self._ids_escape)
		PlayerStandard.say_line(self, "s21x_sin")
	end
	if self._equip_weapon_expire_t and t >= self._equip_weapon_expire_t then
		self._equip_weapon_expire_t = nil
	end
	if self._unequip_weapon_expire_t and t >= self._unequip_weapon_expire_t + 0.5 then
		self._unequip_weapon_expire_t = nil
		self._unit:camera():play_redirect(self._ids_cuffed)
	end
	self:_update_foley(t, input)
	local new_action = self:_check_action_interact(t, input)
end
function PlayerArrested:_check_action_interact(t, input)
	local new_action
	local interaction_wanted = input.btn_interact_press
	if interaction_wanted then
		local action_forbidden = self:chk_action_forbidden("interact") or self._stats_screen
		if not action_forbidden then
			if self._timer_finished then
				self._unit:character_damage():revive(true)
				return
			else
				new_action = self:_start_action_distance_interact(t)
			end
		end
	end
	return new_action
end
function PlayerArrested:_start_action_distance_interact(t)
	if not self._intimidate_t or t - self._intimidate_t > tweak_data.player.movement_state.interaction_delay then
		self._intimidate_t = t
		self:call_teammate("f13", t, true, true)
	end
end
function PlayerArrested:call_teammate(line, t, no_gesture, skip_alert)
	local voice_type, plural, prime_target = self:_get_unit_intimidation_action(true, false, true, true, false)
	local interact_type, queue_name
	if voice_type == "come" then
		interact_type = "cmd_come"
		local character_code = managers.criminals:character_static_data_by_unit(prime_target.unit).ssuffix
		queue_name = line .. character_code .. "_sin"
	elseif voice_type == "stop_cop" then
		local shout_sound = tweak_data.character[prime_target.unit:base()._tweak_table].priority_shout
		shout_sound = managers.groupai:state():whisper_mode() and tweak_data.character[prime_target.unit:base()._tweak_table].silent_priority_shout or shout_sound
		if shout_sound then
			interact_type = "cmd_point"
			queue_name = shout_sound .. "y_any"
			if managers.player:has_category_upgrade("player", "special_enemy_highlight") then
				local marked_extra_damage = managers.player:has_category_upgrade("player", "marked_enemy_extra_damage") or false
				managers.game_play_central:add_enemy_contour(prime_target.unit, marked_extra_damage)
				managers.network:session():send_to_peers_synched("mark_enemy", prime_target.unit, marked_extra_damage)
				managers.challenges:set_flag("eagle_eyes")
			end
		end
	end
	if interact_type then
		if not no_gesture then
		else
		end
		self:_do_action_intimidate(t, interact_type or nil, queue_name, skip_alert)
		return true
	end
end
function PlayerArrested:_update_movement(t, dt)
end
function PlayerArrested:_start_action_handcuffed(t)
	self:_interupt_action_running(t)
	self._state_data.ducking = true
	self:_stance_entered(true)
	self:_update_crosshair_offset()
	self._unit:kill_mover()
	self._unit:character_damage()._arrested = true
	self._unit:activate_mover(Idstring("duck"))
end
function PlayerArrested:_end_action_handcuffed(t)
	if not self:_can_stand() then
		return
	end
	self._state_data.ducking = false
	self:_stance_entered()
	self:_update_crosshair_offset()
	self._unit:kill_mover()
	self._unit:character_damage()._arrested = nil
	self._unit:activate_mover(Idstring("stand"))
end
function PlayerArrested:clbk_entry_speech()
	self._entry_speech_clbk = nil
	PlayerStandard.say_line(self, "s20x_sin")
end
function PlayerArrested:pre_destroy(unit)
	PlayerBleedOut._unregister_revive_SO(self)
	if self._entry_speech_clbk then
		managers.enemy:remove_delayed_clbk(self._entry_speech_clbk)
		self._entry_speech_clbk = nil
	end
end
function PlayerArrested:destroy()
	PlayerBleedOut._unregister_revive_SO(self)
end
