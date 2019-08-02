require("lib/units/beings/player/states/PlayerMovementState")
require("lib/units/beings/player/states/PlayerEmpty")
require("lib/units/beings/player/states/PlayerStandard")
require("lib/units/beings/player/states/PlayerClean")
require("lib/units/beings/player/states/PlayerMaskOff")
require("lib/units/beings/player/states/PlayerBleedOut")
require("lib/units/beings/player/states/PlayerFatal")
require("lib/units/beings/player/states/PlayerArrested")
require("lib/units/beings/player/states/PlayerTased")
require("lib/units/beings/player/states/PlayerIncapacitated")
require("lib/units/beings/player/states/PlayerCarry")
PlayerMovement = PlayerMovement or class()
PlayerMovement._STAMINA_INIT = tweak_data.player.movement_state.stamina.STAMINA_INIT or 10
PlayerMovement.OUT_OF_WORLD_Z = -4000
function PlayerMovement:init(unit)
	self._unit = unit
	unit:set_timer(managers.player:player_timer())
	unit:set_animation_timer(managers.player:player_timer())
	self._machine = self._unit:anim_state_machine()
	self._next_check_out_of_world_t = 1
	self._nav_tracker = nil
	self._pos_rsrv_id = nil
	self:set_driving("script")
	self._m_pos = unit:position()
	self._m_stand_pos = mvector3.copy(self._m_pos)
	mvector3.set_z(self._m_stand_pos, self._m_pos.z + 140)
	self._m_com = math.lerp(self._m_pos, self._m_stand_pos, 0.5)
	self._kill_overlay_t = managers.player:player_timer():time() + 5
	self._state_data = {ducking = false, in_air = false}
	self._synced_suspicion = false
	self._suspicion_ratio = false
	self._SO_access = managers.navigation:convert_access_flag("teamAI1")
	self._regenerate_timer = nil
	self._stamina = self:_max_stamina()
	self._underdog_skill_data = {
		chk_interval_active = 6,
		chk_interval_inactive = 1,
		chk_t = 6,
		nr_enemies = 2,
		max_dis_sq = 640000,
		has_dmg_dampener = managers.player:has_category_upgrade("temporary", "dmg_dampener_outnumbered"),
		has_dmg_mul = managers.player:has_category_upgrade("temporary", "dmg_multiplier_outnumbered")
	}
	if managers.player:has_category_upgrade("player", "morale_boost") or managers.player:has_category_upgrade("player", "long_dis_revive") then
		self._rally_skill_data = {
			range_sq = 490000,
			morale_boost_delay_t = managers.player:has_category_upgrade("player", "morale_boost") and 0 or nil,
			long_dis_revive = managers.player:has_category_upgrade("player", "long_dis_revive"),
			revive_chance = 0.5
		}
	end
end
function PlayerMovement:post_init()
	self._m_head_rot = self._unit:camera()._m_cam_rot
	self._m_head_pos = self._unit:camera()._m_cam_pos
	if managers.navigation:is_data_ready() and (not Global.running_simulation or Global.running_simulation_with_mission) then
		self._nav_tracker = managers.navigation:create_nav_tracker(self._unit:position())
		self._pos_rsrv_id = managers.navigation:get_pos_reservation_id()
	end
	self._unit:inventory():add_listener("PlayerMovement" .. tostring(self._unit:key()), {"add", "equip"}, callback(self, self, "inventory_clbk_listener"))
	self:_setup_states()
	self._attention_handler = CharacterAttentionObject:new(self._unit, true)
	self._enemy_weapons_hot_listen_id = "PlayerMovement" .. tostring(self._unit:key())
	managers.groupai:state():add_listener(self._enemy_weapons_hot_listen_id, {
		"enemy_weapons_hot"
	}, callback(self, self, "clbk_enemy_weapons_hot"))
	if managers.player:has_category_upgrade("player", "camouflage_bonus") then
		self._unit:base():set_detection_multiplier("camouflage_bonus", managers.player:upgrade_value("player", "camouflage_bonus", 1))
	end
end
function PlayerMovement:attention_handler()
	return self._attention_handler
end
function PlayerMovement:nav_tracker()
	return self._nav_tracker
end
function PlayerMovement:pos_rsrv_id()
	return self._pos_rsrv_id
end
function PlayerMovement:warp_to(pos, rot)
	self._unit:warp_to(rot, pos)
end
function PlayerMovement:_setup_states()
	local unit = self._unit
	self._states = {
		empty = PlayerEmpty:new(unit),
		standard = PlayerStandard:new(unit),
		mask_off = PlayerMaskOff:new(unit),
		bleed_out = PlayerBleedOut:new(unit),
		fatal = PlayerFatal:new(unit),
		arrested = PlayerArrested:new(unit),
		tased = PlayerTased:new(unit),
		incapacitated = PlayerIncapacitated:new(unit),
		clean = PlayerClean:new(unit),
		carry = PlayerCarry:new(unit)
	}
end
function PlayerMovement:set_character_anim_variables()
	local char_name = managers.criminals:character_name_by_unit(self._unit)
	local mesh_names
	local lvl_tweak_data = Global.level_data and Global.level_data.level_id and tweak_data.levels[Global.level_data.level_id]
	local unit_suit = lvl_tweak_data and lvl_tweak_data.unit_suit or "suit"
	if not lvl_tweak_data then
		mesh_names = {
			russian = "",
			american = "",
			german = "",
			spanish = ""
		}
	elseif unit_suit == "cat_suit" then
		mesh_names = {
			russian = "",
			american = "",
			german = "",
			spanish = "_chains"
		}
	elseif managers.player._player_mesh_suffix == "_scrubs" then
		mesh_names = {
			russian = "",
			american = "",
			german = "",
			spanish = "_chains"
		}
	else
		mesh_names = {
			russian = "_dallas",
			american = "_hoxton",
			german = "",
			spanish = "_chains"
		}
	end
	local mesh_name = Idstring("g_fps_hand" .. mesh_names[char_name] .. managers.player._player_mesh_suffix)
	local mesh_obj = self._unit:camera():camera_unit():get_object(mesh_name)
	if mesh_obj then
		if self._plr_mesh_name then
			local old_mesh_obj = self._unit:camera():camera_unit():get_object(self._plr_mesh_name)
			if old_mesh_obj then
				old_mesh_obj:set_visibility(false)
			end
		end
		self._plr_mesh_name = mesh_name
		mesh_obj:set_visibility(true)
	end
	local camera_unit = self._unit:camera():camera_unit()
	if camera_unit:damage() then
		local character = CriminalsManager.convert_old_to_new_character_workname(char_name)
		local sequence = tweak_data.blackmarket.characters.locked[character].sequence
		camera_unit:damage():run_sequence_simple(sequence)
	end
end
function PlayerMovement:set_driving(mode)
	self._unit:set_driving(mode)
end
function PlayerMovement:change_state(name)
	local exit_data
	if self._current_state then
		exit_data = self._current_state:exit(self._state_data, name)
	end
	local new_state = self._states[name]
	self._current_state = new_state
	self._current_state_name = name
	self._state_enter_t = managers.player:player_timer():time()
	new_state:enter(self._state_data, exit_data)
	self._unit:network():send("sync_player_movement_state", self._current_state_name, self._unit:character_damage():down_time(), self._unit:id())
end
function PlayerMovement:update(unit, t, dt)
	self:_calculate_m_pose()
	if self:_check_out_of_world(t) then
		return
	end
	self:_upd_underdog_skill(t)
	if self._current_state then
		self._current_state:update(t, dt)
	end
	if self._kill_overlay_t and t > self._kill_overlay_t then
		self._kill_overlay_t = nil
		managers.overlay_effect:stop_effect()
	end
	self:update_stamina(t, dt)
end
function PlayerMovement:update_stamina(t, dt, ignore_running)
	if not ignore_running and self._is_running then
		self:subtract_stamina(dt * tweak_data.player.movement_state.stamina.STAMINA_DRAIN_RATE)
	elseif self._regenerate_timer then
		self._regenerate_timer = self._regenerate_timer - dt
		if self._regenerate_timer < 0 then
			self:add_stamina(dt * tweak_data.player.movement_state.stamina.STAMINA_REGEN_RATE)
			if self._stamina >= self:_max_stamina() then
				self._regenerate_timer = nil
			end
		end
	end
end
function PlayerMovement:set_position(pos)
	self._unit:set_position(pos)
end
function PlayerMovement:set_m_pos(pos)
	mvector3.set(self._m_pos, pos)
	mvector3.set(self._m_stand_pos, pos)
	mvector3.set_z(self._m_stand_pos, pos.z + 140)
end
function PlayerMovement:m_pos()
	return self._m_pos
end
function PlayerMovement:m_stand_pos()
	return self._m_stand_pos
end
function PlayerMovement:m_com()
	return self._m_com
end
function PlayerMovement:m_head_pos()
	return self._m_head_pos
end
function PlayerMovement:m_head_rot()
	return self._m_head_rot
end
function PlayerMovement:m_detect_pos()
	return self._m_head_pos
end
function PlayerMovement:get_object(object_name)
	return self._unit:get_object(object_name)
end
function PlayerMovement:downed()
	return self._current_state_name == "bleed_out" or self._current_state_name == "fatal" or self._current_state_name == "arrested" or self._current_state_name == "incapacitated"
end
function PlayerMovement:current_state()
	return self._current_state
end
function PlayerMovement:_calculate_m_pose()
	mvector3.lerp(self._m_com, self._m_pos, self._m_head_pos, 0.5)
end
function PlayerMovement:_check_out_of_world(t)
	if t > self._next_check_out_of_world_t then
		self._next_check_out_of_world_t = t + 1
		if mvector3.z(self._m_pos) < PlayerMovement.OUT_OF_WORLD_Z then
			managers.player:on_out_of_world()
			return true
		end
	end
	return false
end
function PlayerMovement:play_redirect(redirect_name, at_time)
	local result = self._unit:play_redirect(Idstring(redirect_name), at_time)
	return result ~= Idstring("") and result
end
function PlayerMovement:play_state(state_name, at_time)
	local result = self._unit:play_state(Idstring(state_name), at_time)
	return result ~= Idstring("") and result
end
function PlayerMovement:chk_action_forbidden(action_type)
	return self._current_state.chk_action_forbidden and self._current_state:chk_action_forbidden(action_type)
end
function PlayerMovement:get_melee_damage_result(...)
	return self._current_state.get_melee_damage_result and self._current_state:get_melee_damage_result(...)
end
function PlayerMovement:linked(state, physical, parent_unit)
	if state then
		self._link_data = {physical = physical, parent = parent_unit}
		parent_unit:base():add_destroy_listener("PlayerMovement" .. tostring(self._unit:key()), callback(self, self, "parent_clbk_unit_destroyed"))
	else
		self._link_data = nil
	end
end
function PlayerMovement:parent_clbk_unit_destroyed(parent_unit, key)
	self._link_data = nil
	parent_unit:base():remove_destroy_listener("PlayerMovement" .. tostring(self._unit:key()))
end
function PlayerMovement:is_physically_linked()
	return self._link_data and self._link_data.physical
end
function PlayerMovement:on_cuffed()
	if self._unit:character_damage()._god_mode then
		return
	end
	if self._current_state_name == "standard" or self._current_state_name == "bleed_out" or self._current_state_name == "carry" or self._current_state_name == "mask_off" or self._current_state_name == "clean" then
		managers.player:set_player_state("arrested")
	else
		debug_pause("[PlayerMovement:on_cuffed] transition failed", self._current_state_name)
	end
end
function PlayerMovement:on_uncovered(enemy_unit)
	if self._current_state_name ~= "mask_off" and self._current_state_name ~= "clean" then
		return
	end
	self._state_data.uncovered = true
	managers.player:set_player_state("standard")
	self._state_data.uncovered = nil
end
function PlayerMovement:on_SPOOCed()
	if self._unit:character_damage()._god_mode then
		return
	end
	if self._current_state_name == "standard" or self._current_state_name == "bleed_out" then
		managers.player:set_player_state("incapacitated")
	end
end
function PlayerMovement:on_non_lethal_electrocution()
	self._state_data.non_lethal_electrocution = true
end
function PlayerMovement:on_tase_ended()
	if self._current_state_name == "tased" then
		self._unit:character_damage():erase_tase_data()
		self._current_state:on_tase_ended()
	end
end
function PlayerMovement:tased()
	return self._current_state_name == "tased"
end
function PlayerMovement:current_state_name()
	return self._current_state_name
end
function PlayerMovement:state_enter_time()
	return self._state_enter_t
end
function PlayerMovement:_create_attention_setting_from_descriptor(setting_desc, setting_name)
	local setting = clone(setting_desc)
	setting.id = setting_name
	setting.filter = managers.groupai:state():get_unit_type_filter(setting.filter)
	setting.reaction = AIAttentionObject[setting.reaction]
	if setting.notice_clbk then
		if self[setting.notice_clbk] then
			setting.notice_clbk = callback(self, self, setting.notice_clbk)
		else
			debug_pause("[PlayerMovement:_create_attention_setting_from_descriptor] no notice_clbk defined in class", self._unit, setting.notice_clbk)
		end
	end
	if self._apply_attention_setting_modifications then
		self:_apply_attention_setting_modifications(setting)
	end
	return setting
end
function PlayerMovement:_apply_attention_setting_modifications(setting)
	setting.detection = self._unit:base():detection_settings()
end
function PlayerMovement:set_attention_settings(setting_names)
	local changes = self._attention_handler:chk_settings_diff(setting_names)
	if not changes then
		return
	end
	local all_attentions
	local function _add_attentions_to_all(names)
		for _, setting_name in ipairs(names) do
			local setting_desc = tweak_data.attention.settings[setting_name]
			if setting_desc then
				all_attentions = all_attentions or {}
				local setting = self:_create_attention_setting_from_descriptor(setting_desc, setting_name)
				all_attentions[setting_name] = setting
			else
				debug_pause_unit(self._unit, "[PlayerMovement:set_attention_settings] invalid setting", setting_name, self._unit)
			end
		end
	end
	if changes.added then
		_add_attentions_to_all(changes.added)
	end
	if changes.maintained then
		_add_attentions_to_all(changes.maintained)
	end
	self._attention_handler:set_settings_set(all_attentions)
	if Network:is_client() then
		if changes.added then
			for _, id in ipairs(changes.added) do
				local index = tweak_data.attention:get_attention_index(id)
				self._unit:network():send_to_host("set_attention_enabled", index, true)
			end
		end
		if changes.removed then
			for _, id in ipairs(changes.removed) do
				local index = tweak_data.attention:get_attention_index(id)
				self._unit:network():send_to_host("set_attention_enabled", index, false)
			end
		end
	end
end
function PlayerMovement:set_attention_setting_enabled(setting_name, state, sync)
	if state then
		local setting_desc = tweak_data.attention.settings[setting_name]
		if setting_desc then
			local setting = self:_create_attention_setting_from_descriptor(setting_desc, setting_name)
			self._unit:movement():attention_handler():add_attention(setting)
		else
			debug_pause_unit(self._unit, "[PlayerMovement:add_attention_setting] invalid setting", setting_name, self._unit)
		end
	else
		self._unit:movement():attention_handler():remove_attention(setting_name)
	end
	if sync then
		local index = tweak_data.player:get_attention_index("player", setting_name)
		self._ext_network:send_to_host("set_attention_enabled", index, state)
	end
end
function PlayerMovement:clbk_attention_notice_sneak(observer_unit, status)
	self:on_suspicion(observer_unit, status)
end
function PlayerMovement:on_suspicion(observer_unit, status)
	if Network:is_server() then
		self._suspicion_debug = self._suspicion_debug or {}
		self._suspicion_debug[observer_unit:key()] = {
			unit = observer_unit,
			name = observer_unit:name(),
			status = status
		}
		local visible_status
		if managers.groupai:state():whisper_mode() then
			visible_status = status
		else
			visible_status = false
		end
		self._suspicion = self._suspicion or {}
		if visible_status == false or visible_status == true then
			self._suspicion[observer_unit:key()] = nil
			if not next(self._suspicion) then
				self._suspicion = nil
			end
		elseif type(visible_status) == "number" then
			self._suspicion[observer_unit:key()] = visible_status
		else
			return
		end
		self:_calc_suspicion_ratio_and_sync(observer_unit, visible_status)
		managers.groupai:state():on_criminal_suspicion_progress(self._unit, observer_unit, visible_status)
	else
		self._suspicion_ratio = status
	end
	self:_feed_suspicion_to_hud()
end
function PlayerMovement:_feed_suspicion_to_hud()
	managers.hud:set_suspicion(self._suspicion_ratio)
end
function PlayerMovement:_calc_suspicion_ratio_and_sync(observer_unit, status)
	local suspicion_sync
	if self._suspicion and status ~= true then
		local max_suspicion
		for u_key, val in pairs(self._suspicion) do
			if not max_suspicion or val > max_suspicion then
				max_suspicion = val
			end
		end
		if max_suspicion then
			self._suspicion_ratio = max_suspicion
			suspicion_sync = math.ceil(self._suspicion_ratio * 254)
		else
			self._suspicion_ratio = false
			suspicion_sync = false
		end
	elseif type(status) == "boolean" then
		self._suspicion_ratio = status
		suspicion_sync = status and 255 or 0
	else
		self._suspicion_ratio = false
		suspicion_sync = 0
	end
	if suspicion_sync ~= self._synced_suspicion then
		self._synced_suspicion = suspicion_sync
		local member = managers.network:game():member_from_unit(self._unit)
		if member then
			local member_id = member:peer():id()
			managers.network:session():send_to_peers_synched("suspicion", member_id, suspicion_sync)
		end
	end
end
function PlayerMovement.clbk_msg_overwrite_suspicion(overwrite_data, msg_queue, msg_name, suspect_peer_id, suspicion)
	if msg_queue then
		if overwrite_data.indexes[suspect_peer_id] then
			local index = overwrite_data.indexes[suspect_peer_id]
			local old_msg = msg_queue[index]
			old_msg[3] = suspicion
		else
			table.insert(msg_queue, {
				msg_name,
				suspect_peer_id,
				suspicion
			})
			overwrite_data.indexes[suspect_peer_id] = #msg_queue
		end
	else
		overwrite_data.indexes = {}
	end
end
function PlayerMovement:clbk_enemy_weapons_hot()
	if self._current_state_name == "mask_off" or self._current_state_name == "clean" then
		self:on_uncovered(nil)
	end
	self._suspicion_ratio = false
	self._suspicion = false
	if Network:is_server() and self._synced_suspicion ~= 0 then
		self._synced_suspicion = 0
		local member = managers.network:game():member_from_unit(self._unit)
		if member then
			local member_id = member:peer():id()
			managers.network:session():send_to_peers_synched("suspicion", member_id, 0)
		end
	end
	self:_feed_suspicion_to_hud()
end
function PlayerMovement:inventory_clbk_listener(unit, event)
	if event == "add" then
		local data = self._unit:inventory():get_latest_addition_hud_data()
		managers.hud:add_weapon(data)
	end
	if self._current_state and self._current_state.inventory_clbk_listener then
		self._current_state:inventory_clbk_listener(unit, event)
	end
end
function PlayerMovement:chk_play_mask_on_slow_mo(state_data)
	if not state_data.uncovered and managers.enemy:chk_any_unit_in_slotmask_visible(managers.slot:get_mask("enemies"), self._unit:camera():position(), self._nav_trakcer) then
		local effect_id_world = "world_MaskOn_Peer" .. tostring(managers.network:session():local_peer():id())
		managers.time_speed:play_effect(effect_id_world, tweak_data.timespeed.mask_on)
		local effect_id_player = "player_MaskOn_Peer" .. tostring(managers.network:session():local_peer():id())
		managers.time_speed:play_effect(effect_id_player, tweak_data.timespeed.mask_on_player)
	end
end
function PlayerMovement:SO_access()
	return self._SO_access
end
function PlayerMovement:rally_skill_data()
	return self._rally_skill_data
end
function PlayerMovement:_upd_underdog_skill(t)
	local data = self._underdog_skill_data
	if not self._attackers or not data.has_dmg_dampener and not data.has_dmg_mul or t < self._underdog_skill_data.chk_t then
		return
	end
	local my_pos = self._m_pos
	local nr_guys = 0
	local activated
	for u_key, attacker_unit in pairs(self._attackers) do
		if not alive(attacker_unit) then
			self._attackers[u_key] = nil
			return
		end
		local attacker_pos = attacker_unit:movement():m_pos()
		local dis_sq = mvector3.distance_sq(attacker_pos, my_pos)
		if dis_sq < data.max_dis_sq and math.abs(attacker_pos.z - my_pos.z) < 250 then
			nr_guys = nr_guys + 1
			if nr_guys >= data.nr_enemies then
				activated = true
				if data.has_dmg_mul then
					managers.player:activate_temporary_upgrade("temporary", "dmg_multiplier_outnumbered")
				end
				if data.has_dmg_dampener then
					managers.player:activate_temporary_upgrade("temporary", "dmg_dampener_outnumbered")
				end
			end
		else
		end
	end
	data.chk_t = t + (activated and data.chk_interval_active or data.chk_interval_inactive)
end
function PlayerMovement:on_targetted_for_attack(state, attacker_unit)
	if state then
		self._attackers = self._attackers or {}
		self._attackers[attacker_unit:key()] = attacker_unit
	elseif self._attackers then
		self._attackers[attacker_unit:key()] = nil
		if not next(self._attackers) then
			self._attackers = nil
		end
	end
end
function PlayerMovement:set_carry_restriction(state)
	self._carry_restricted = state
end
function PlayerMovement:has_carry_restriction()
	return self._carry_restricted
end
function PlayerMovement:object_interaction_blocked()
	return self._current_state:interaction_blocked()
end
function PlayerMovement:on_morale_boost(benefactor_unit)
	if self._morale_boost then
		managers.enemy:reschedule_delayed_clbk(self._morale_boost.expire_clbk_id, managers.player:player_timer():time() + 30)
	else
		self._morale_boost = {
			expire_clbk_id = "PlayerMovement_morale_boost" .. tostring(self._unit:key()),
			move_speed_bonus = 1.1,
			suppression_resistance = 0.9
		}
		managers.enemy:add_delayed_clbk(self._morale_boost.expire_clbk_id, callback(self, self, "clbk_morale_boost_expire"), managers.player:player_timer():time() + 30)
	end
end
function PlayerMovement:morale_boost()
	return self._morale_boost
end
function PlayerMovement:clbk_morale_boost_expire()
	self._morale_boost = nil
end
function PlayerMovement:push(vel)
	if self._current_state.push then
		self._current_state:push(vel)
	end
end
function PlayerMovement:save(data)
	local peer_id = managers.network:game():member_from_unit(self._unit):peer():id()
	data.movement = {
		state_name = self._current_state_name,
		look_fwd = self._m_head_rot:y(),
		peer_id = peer_id,
		character_name = managers.criminals:character_name_by_unit(self._unit),
		attentions = {},
		outfit = managers.network:session():peer(peer_id):profile("outfit_string")
	}
	if self._current_state_name == "clean" or self._current_state_name == "mask_off" then
	elseif self._state_data.in_steelsight then
		data.movement.stance = 3
	else
		data.movement.stance = 2
	end
	data.movement.pose = self._state_data.ducking and 2 or 1
	if Network:is_client() then
		for _, settings in ipairs(self._attention_handler:attention_data()) do
			local index = tweak_data.player:get_attention_index("player", settings.id)
			table.insert(data.movement.attentions, index)
		end
	end
	data.down_time = self._unit:character_damage():down_time()
	self._current_state:save(data.movement)
end
function PlayerMovement:pre_destroy(unit)
	self._attention_handler:set_attention(nil)
	self._current_state:pre_destroy(unit)
	if self._nav_tracker then
		managers.navigation:destroy_nav_tracker(self._nav_tracker)
		self._nav_tracker = nil
	end
	if self._enemy_weapons_hot_listen_id then
		managers.groupai:state():remove_listener(self._enemy_weapons_hot_listen_id)
		self._enemy_weapons_hot_listen_id = nil
	end
end
function PlayerMovement:destroy(unit)
	if self._link_data then
		self._link_data.parent:base():remove_destroy_listener("PlayerMovement" .. tostring(self._unit:key()))
	end
	self._current_state:destroy(unit)
	managers.hud:set_suspicion(false)
	SoundDevice:set_rtpc("suspicion", 0)
	SoundDevice:set_rtpc("stamina", 100)
end
function PlayerMovement:_max_stamina()
	local max_stamina = self._STAMINA_INIT * managers.player:upgrade_value("player", "stamina_multiplier", 1) * managers.player:team_upgrade_value("stamina", "multiplier", 1) * managers.player:team_upgrade_value("stamina", "passive_multiplier", 1)
	managers.hud:set_max_stamina(max_stamina)
	return max_stamina
end
function PlayerMovement:_change_stamina(value)
	local max_stamina = self:_max_stamina()
	local stamina_maxed = self._stamina == max_stamina
	self._stamina = math.clamp(self._stamina + value, 0, max_stamina)
	managers.hud:set_stamina_value(self._stamina)
	if stamina_maxed and max_stamina > self._stamina then
		self._unit:sound():play("fatigue_breath")
	elseif not stamina_maxed and max_stamina <= self._stamina then
		self._unit:sound():play("fatigue_breath_stop")
	end
	local stamina_to_threshold = max_stamina - tweak_data.player.movement_state.stamina.MIN_STAMINA_THRESHOLD
	local stamina_breath = math.clamp((self._stamina - tweak_data.player.movement_state.stamina.MIN_STAMINA_THRESHOLD) / stamina_to_threshold, 0, 1) * 100
	SoundDevice:set_rtpc("stamina", stamina_breath)
end
function PlayerMovement:subtract_stamina(value)
	self:_change_stamina(-math.abs(value))
end
function PlayerMovement:add_stamina(value)
	self:_change_stamina(math.abs(value) * managers.player:upgrade_value("player", "stamina_regen_multiplier", 1))
end
function PlayerMovement:is_above_stamina_threshold()
	return self._stamina > tweak_data.player.movement_state.stamina.MIN_STAMINA_THRESHOLD
end
function PlayerMovement:is_stamina_drained()
	return self._stamina <= 0
end
function PlayerMovement:set_running(running)
	self._is_running = running
	self._regenerate_timer = (tweak_data.player.movement_state.stamina.REGENERATE_TIME or 5) * managers.player:upgrade_value("player", "stamina_regen_timer_multiplier", 1)
end
function PlayerMovement:running()
	return self._is_running
end
