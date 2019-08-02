PlayerBleedOut = PlayerBleedOut or class(PlayerStandard)
function PlayerBleedOut:init(unit)
	PlayerBleedOut.super.init(self, unit)
end
function PlayerBleedOut:enter(state_data, enter_data)
	PlayerBleedOut.super.enter(self, state_data, enter_data)
	self._revive_SO_data = {
		unit = self._unit
	}
	self:_start_action_bleedout(managers.player:player_timer():time())
	self._tilt_wait_t = managers.player:player_timer():time() + 1
	self._old_selection = nil
	if not managers.player:has_category_upgrade("player", "primary_weapon_when_downed") and self._unit:inventory():equipped_selection() ~= 1 then
		self._old_selection = self._unit:inventory():equipped_selection()
		self:_start_action_unequip_weapon(managers.player:player_timer():time(), {selection_wanted = 1})
		self._unit:inventory():unit_by_selection(1):base():on_reload()
	end
	self._unit:camera():play_shaker("player_bleedout_land")
	local effect_id_world = "world_downed_Peer" .. tostring(managers.network:session():local_peer():id())
	managers.time_speed:play_effect(effect_id_world, tweak_data.timespeed.downed)
	local effect_id_player = "player_downed_Peer" .. tostring(managers.network:session():local_peer():id())
	managers.time_speed:play_effect(effect_id_player, tweak_data.timespeed.downed_player)
	managers.groupai:state():on_criminal_disabled(self._unit)
	if Network:is_server() and self._ext_movement:nav_tracker() then
		self._register_revive_SO(self._revive_SO_data, "revive")
	end
	if self._state_data.in_steelsight then
		self:_interupt_action_steelsight(managers.player:player_timer():time())
	end
	managers.groupai:state():report_criminal_downed(self._unit)
end
function PlayerBleedOut:_enter(enter_data)
	self._unit:base():set_slot(self._unit, 2)
	if Network:is_server() and self._ext_movement:nav_tracker() then
		managers.groupai:state():on_player_weapons_hot()
	end
	self._ext_movement:set_attention_settings({
		"pl_enemy_cbt",
		"pl_team_idle_std",
		"pl_civ_cbt"
	})
end
function PlayerBleedOut:exit(state_data, new_state_name)
	PlayerBleedOut.super.exit(self, state_data, new_state_name)
	self:_end_action_bleedout(managers.player:player_timer():time())
	self._unit:camera():camera_unit():base():set_target_tilt(0)
	self._tilt_wait_t = nil
	local exit_data = {
		equip_weapon = self._old_selection
	}
	if Network:is_server() then
		if new_state_name == "fatal" then
			exit_data.revive_SO_data = self._revive_SO_data
			self._revive_SO_data = nil
		else
			self:_unregister_revive_SO()
		end
	end
	exit_data.skip_equip = true
	if new_state_name == "standard" then
		exit_data.wants_crouch = true
	end
	return exit_data
end
function PlayerBleedOut:interaction_blocked()
	return true
end
function PlayerBleedOut:update(t, dt)
	PlayerBleedOut.super.update(self, t, dt)
	if self._tilt_wait_t then
		local tilt = math.lerp(35, 0, self._tilt_wait_t - t)
		self._unit:camera():camera_unit():base():set_target_tilt(tilt)
		if t > self._tilt_wait_t then
			self._tilt_wait_t = nil
			self._unit:camera():camera_unit():base():set_target_tilt(35)
		end
	end
end
function PlayerBleedOut:_update_check_actions(t, dt)
	local input = self:_get_input()
	self._unit:camera():set_shaker_parameter("headbob", "amplitude", 0)
	self:_update_reload_timers(t, dt, input)
	self:_update_equip_weapon_timers(t, input)
	if input.btn_stats_screen_press then
		self._unit:base():set_stats_screen_visible(true)
	elseif input.btn_stats_screen_release then
		self._unit:base():set_stats_screen_visible(false)
	end
	self:_update_foley(t, input)
	local new_action
	new_action = new_action or self:_check_action_weapon_gadget(t, input)
	new_action = new_action or self:_check_action_reload(t, input)
	new_action = new_action or self:_check_change_weapon(t, input)
	if not new_action then
		new_action = self:_check_action_primary_attack(t, input)
		self._shooting = new_action
	end
	new_action = new_action or self:_check_action_equip(t, input)
	new_action = new_action or self:_check_action_interact(t, input)
	new_action = new_action or self:_check_action_steelsight(t, input)
	PlayerCarry._check_use_item(self, t, input)
end
function PlayerBleedOut:_check_action_interact(t, input)
	if input.btn_interact_press and (not self._intimidate_t or t - self._intimidate_t > tweak_data.player.movement_state.interaction_delay) then
		self._intimidate_t = t
		if not PlayerArrested.call_teammate(self, "f11", t) then
			self:call_civilian("f11", t, false, true, self._revive_SO_data)
		end
	end
end
function PlayerBleedOut:_check_change_weapon(...)
	if managers.player:has_category_upgrade("player", "primary_weapon_when_downed") then
		return PlayerBleedOut.super._check_change_weapon(self, ...)
	end
	return false
end
function PlayerBleedOut:_check_action_equip(...)
	if managers.player:has_category_upgrade("player", "primary_weapon_when_downed") then
		return PlayerBleedOut.super._check_action_equip(self, ...)
	end
	return false
end
function PlayerBleedOut:_check_action_steelsight(...)
	if managers.player:has_category_upgrade("player", "steelsight_when_downed") then
		return PlayerBleedOut.super._check_action_steelsight(self, ...)
	end
	return false
end
function PlayerBleedOut:_start_action_state_standard(t)
	managers.player:set_player_state("standard")
end
function PlayerBleedOut._register_revive_SO(revive_SO_data, variant)
	if revive_SO_data.SO_id or not managers.navigation:is_data_ready() then
		return
	end
	local followup_objective = {
		type = "act",
		scan = true,
		action = {
			type = "act",
			body_part = 1,
			variant = "crouch",
			blocks = {
				action = -1,
				walk = -1,
				hurt = -1,
				heavy_hurt = -1,
				aim = -1
			}
		}
	}
	local objective = {
		type = "revive",
		follow_unit = revive_SO_data.unit,
		called = true,
		destroy_clbk_key = false,
		nav_seg = revive_SO_data.unit:movement():nav_tracker():nav_segment(),
		fail_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_rescue_SO_failed", revive_SO_data),
		complete_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_rescue_SO_completed", revive_SO_data),
		action_start_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_rescue_SO_started", revive_SO_data),
		scan = true,
		action = {
			type = "act",
			variant = variant,
			body_part = 1,
			blocks = {
				action = -1,
				walk = -1,
				light_hurt = -1,
				hurt = -1,
				heavy_hurt = -1,
				aim = -1
			},
			align_sync = true
		},
		action_duration = tweak_data.interaction[variant == "untie" and "free" or variant].timer,
		followup_objective = followup_objective
	}
	local so_descriptor = {
		objective = objective,
		base_chance = 1,
		chance_inc = 0,
		interval = 0,
		search_pos = revive_SO_data.unit:position(),
		usage_amount = 1,
		AI_group = "friendlies",
		admin_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_rescue_SO_administered", revive_SO_data)
	}
	revive_SO_data.variant = variant
	local so_id = "Playerrevive"
	revive_SO_data.SO_id = so_id
	managers.groupai:state():add_special_objective(so_id, so_descriptor)
	if not revive_SO_data.deathguard_SO_id then
		revive_SO_data.deathguard_SO_id = PlayerBleedOut._register_deathguard_SO(revive_SO_data.unit)
	end
end
function PlayerBleedOut:call_civilian(line, t, no_gesture, skip_alert, revive_SO_data)
	if not managers.player:has_category_upgrade("player", "civilian_reviver") or revive_SO_data and revive_SO_data.sympathy_civ then
		return
	end
	local detect_only = managers.statistics:session_total_civilian_kills() > 0
	local voice_type, plural, prime_target = self:_get_unit_intimidation_action(false, true, false, false, false, 0, true, detect_only)
	if prime_target then
		if detect_only then
			if not prime_target.unit:sound():speaking(t) then
				prime_target.unit:sound():say("_a01x_any", true)
			end
		else
			if not prime_target.unit:sound():speaking(t) then
				prime_target.unit:sound():say("stockholm_syndrome", true)
			end
			local queue_name = line .. "e_plu"
			self:_do_action_intimidate(t, not no_gesture and "cmd_come" or nil, queue_name, skip_alert)
			if Network:is_server() then
				if prime_target.unit:brain():is_available_for_assignment({type = "revive"}) then
					local followup_objective = {
						type = "free",
						interrupt_dis = -1,
						interrupt_health = 1,
						action = {
							type = "idle",
							body_part = 1,
							sync = true
						}
					}
					local objective = {
						type = "act",
						haste = "run",
						destroy_clbk_key = false,
						nav_seg = self._unit:movement():nav_tracker():nav_segment(),
						pos = self._unit:movement():nav_tracker():field_position(),
						fail_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_civ_revive_failed", revive_SO_data),
						complete_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_civ_revive_completed", revive_SO_data),
						action_start_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_civ_revive_started", revive_SO_data),
						action = {
							type = "act",
							variant = "revive",
							body_part = 1,
							blocks = {
								action = -1,
								walk = -1,
								light_hurt = -1,
								hurt = -1,
								heavy_hurt = -1,
								aim = -1
							},
							align_sync = true
						},
						action_duration = tweak_data.interaction.revive.timer,
						followup_objective = followup_objective
					}
					revive_SO_data.sympathy_civ = prime_target.unit
					prime_target.unit:brain():set_objective(objective)
				end
			end
		end
	end
end
function PlayerBleedOut:_unregister_revive_SO()
	if self._revive_SO_data.deathguard_SO_id then
		PlayerBleedOut._unregister_deathguard_SO(self._revive_SO_data.deathguard_SO_id)
		self._revive_SO_data.deathguard_SO_id = nil
	end
	if self._revive_SO_data.SO_id then
		managers.groupai:state():remove_special_objective(self._revive_SO_data.SO_id)
		self._revive_SO_data.SO_id = nil
	elseif self._revive_SO_data.rescuer then
		local rescuer = self._revive_SO_data.rescuer
		self._revive_SO_data.rescuer = nil
		if alive(rescuer) then
			rescuer:brain():set_objective(nil)
		end
	end
	if self._revive_SO_data.sympathy_civ then
		local sympathy_civ = self._revive_SO_data.sympathy_civ
		self._revive_SO_data.sympathy_civ = nil
		sympathy_civ:brain():set_objective(nil)
	end
end
function PlayerBleedOut._register_deathguard_SO(my_unit)
end
function PlayerBleedOut._unregister_deathguard_SO(so_id)
	managers.groupai:state():remove_special_objective(so_id)
end
function PlayerBleedOut:_start_action_bleedout(t)
	self:_interupt_action_running(t)
	self._state_data.ducking = true
	self:_stance_entered()
	self:_update_crosshair_offset()
	self._unit:kill_mover()
	self._unit:activate_mover(Idstring("duck"))
end
function PlayerBleedOut:_end_action_bleedout(t)
	if not self:_can_stand() then
		return
	end
	self._state_data.ducking = false
	self:_stance_entered()
	self:_update_crosshair_offset()
	self._unit:kill_mover()
	self._unit:activate_mover(Idstring("stand"))
end
function PlayerBleedOut:_update_movement(t, dt)
	if self._ext_network then
		local cur_pos = self._pos
		local move_dis = mvector3.distance_sq(cur_pos, self._last_sent_pos)
		if move_dis > 22500 or move_dis > 400 and t - self._last_sent_pos_t > 1.5 then
			self._ext_network:send("action_walk_nav_point", cur_pos)
			mvector3.set(self._last_sent_pos, cur_pos)
			self._last_sent_pos_t = t
		end
	end
end
function PlayerBleedOut:on_rescue_SO_administered(revive_SO_data, receiver_unit)
	if revive_SO_data.rescuer then
		debug_pause("[PlayerBleedOut:on_rescue_SO_administered] Already had a rescuer!!!!", receiver_unit, revive_SO_data.rescuer)
	end
	revive_SO_data.rescuer = receiver_unit
	revive_SO_data.SO_id = nil
end
function PlayerBleedOut:on_rescue_SO_failed(revive_SO_data, rescuer)
	if revive_SO_data.rescuer then
		revive_SO_data.rescuer = nil
		PlayerBleedOut._register_revive_SO(revive_SO_data, revive_SO_data.variant)
	end
end
function PlayerBleedOut:on_rescue_SO_completed(revive_SO_data, rescuer)
	if revive_SO_data.sympathy_civ then
		local objective = {
			type = "free",
			interrupt_dis = -1,
			interrupt_health = 1,
			action = {
				type = "idle",
				body_part = 1,
				sync = true
			}
		}
		revive_SO_data.sympathy_civ:brain():set_objective(objective)
	end
	revive_SO_data.rescuer = nil
end
function PlayerBleedOut:on_rescue_SO_started(revive_SO_data, rescuer)
	for c_key, criminal in pairs(managers.groupai:state():all_AI_criminals()) do
		if c_key ~= rescuer:key() then
			local obj = criminal.unit:brain():objective()
			if obj and obj.type == "revive" and obj.follow_unit:key() == revive_SO_data.unit:key() then
				criminal.unit:brain():set_objective(nil)
			end
		end
	end
end
function PlayerBleedOut:on_civ_revive_completed(revive_SO_data, sympathy_civ)
	if sympathy_civ ~= revive_SO_data.sympathy_civ then
		debug_pause_unit(sympathy_civ, "[PlayerBleedOut:on_civ_revive_completed] idiot thinks he is reviving", sympathy_civ)
		return
	end
	revive_SO_data.sympathy_civ = nil
	revive_SO_data.unit:character_damage():revive(sympathy_civ)
	if managers.player:has_category_upgrade("player", "civilian_gives_ammo") then
		managers.game_play_central:spawn_pickup({
			name = "ammo",
			position = sympathy_civ:position(),
			rotation = Rotation()
		})
	end
end
function PlayerBleedOut:on_civ_revive_started(revive_SO_data, sympathy_civ)
	if sympathy_civ ~= revive_SO_data.sympathy_civ then
		debug_pause_unit(sympathy_civ, "[PlayerBleedOut:on_civ_revive_started] idiot thinks he is reviving", sympathy_civ)
		return
	end
	revive_SO_data.unit:character_damage():pause_downed_timer()
	if revive_SO_data.SO_id then
		managers.groupai:state():remove_special_objective(revive_SO_data.SO_id)
		revive_SO_data.SO_id = nil
	elseif revive_SO_data.rescuer then
		local rescuer = revive_SO_data.rescuer
		revive_SO_data.rescuer = nil
		if alive(rescuer) then
			rescuer:brain():set_objective(nil)
		end
	end
end
function PlayerBleedOut:on_civ_revive_failed(revive_SO_data, sympathy_civ)
	if revive_SO_data.sympathy_civ then
		if sympathy_civ ~= revive_SO_data.sympathy_civ then
			debug_pause_unit(sympathy_civ, "[PlayerBleedOut:on_civ_revive_failed] idiot thinks he is reviving", sympathy_civ)
			return
		end
		revive_SO_data.unit:character_damage():unpause_downed_timer()
		revive_SO_data.sympathy_civ = nil
	end
end
function PlayerBleedOut:verif_clbk_is_unit_deathguard(enemy_unit)
	local char_tweak = tweak_data.character[enemy_unit:base()._tweak_table]
	return char_tweak.deathguard
end
function PlayerBleedOut:clbk_deathguard_administered(unit)
	unit:movement():set_cool(false)
end
function PlayerBleedOut:pre_destroy(unit)
	if Network:is_server() then
		self:_unregister_revive_SO()
	end
end
function PlayerBleedOut:destroy()
	if Network:is_server() then
		self:_unregister_revive_SO()
	end
end
