local mvec3_dis_sq = mvector3.distance_sq
local mvec3_set = mvector3.set
local mvec3_sub = mvector3.subtract
local mvec3_add = mvector3.add
local mvec3_mul = mvector3.multiply
local mvec3_norm = mvector3.normalize
PlayerStandard = PlayerStandard or class(PlayerMovementState)
PlayerStandard.MOVER_STAND = Idstring("stand")
PlayerStandard.MOVER_DUCK = Idstring("duck")
PlayerStandard.IDS_EQUIP = Idstring("equip")
PlayerStandard.IDS_MASK_EQUIP = Idstring("mask_equip")
PlayerStandard.IDS_UNEQUIP = Idstring("unequip")
PlayerStandard.IDS_RELOAD_EXIT = Idstring("reload_exit")
PlayerStandard.IDS_RELOAD_NOT_EMPTY_EXIT = Idstring("reload_not_empty_exit")
PlayerStandard.IDS_START_RUNNING = Idstring("start_running")
PlayerStandard.IDS_STOP_RUNNING = Idstring("stop_running")
PlayerStandard.IDS_MELEE = Idstring("melee")
PlayerStandard.IDS_MELEE_MISS = Idstring("melee_miss")
PlayerStandard.IDS_IDLE = Idstring("idle")
PlayerStandard.IDS_USE = Idstring("use")
PlayerStandard.IDS_RECOIL = Idstring("recoil")
PlayerStandard.IDS_RECOIL_STEELSIGHT = Idstring("recoil_steelsight")
PlayerStandard.IDS_RECOIL_ENTER = Idstring("recoil_enter")
PlayerStandard.IDS_RECOIL_LOOP = Idstring("recoil_loop")
PlayerStandard.IDS_RECOIL_EXIT = Idstring("recoil_exit")
function PlayerStandard:init(unit)
	PlayerMovementState.init(self, unit)
	self._tweak_data = tweak_data.player.movement_state.standard
	self._obj_com = self._unit:get_object(Idstring("rp_mover"))
	self._slotmask_gnd_ray = managers.slot:get_mask("AI_graph_obstacle_check")
	self._slotmask_fwd_ray = managers.slot:get_mask("bullet_impact_targets")
	self._slotmask_bullet_impact_targets = managers.slot:get_mask("bullet_impact_targets")
	self._slotmask_pickups = managers.slot:get_mask("pickups")
	self._slotmask_AI_visibility = managers.slot:get_mask("AI_visibility")
	self._slotmask_long_distance_interaction = managers.slot:get_mask("long_distance_interaction")
	self._ext_camera = unit:camera()
	self._ext_movement = unit:movement()
	self._ext_damage = unit:character_damage()
	self._ext_inventory = unit:inventory()
	self._ext_anim = unit:anim_data()
	self._ext_network = unit:network()
	self._camera_unit = self._ext_camera._camera_unit
	self._machine = unit:anim_state_machine()
	self._m_pos = self._ext_movement:m_pos()
	self._pos = Vector3()
	self._stick_move = Vector3()
	self._stick_look = Vector3()
	self._cam_fwd_flat = Vector3()
	self._walk_release_t = -100
	self._last_sent_pos = unit:position()
	self._last_sent_pos_t = 0
	self._state_data = unit:movement()._state_data
end
function PlayerStandard:enter(state_data, enter_data)
	PlayerMovementState.enter(self, state_data, enter_data)
	tweak_data:add_reload_callback(self, self.tweak_data_clbk_reload)
	self._state_data = state_data
	self._equipped_unit = self._ext_inventory:equipped_unit()
	local weapon = self._ext_inventory:equipped_unit()
	if not weapon or not weapon:base().weapon_hold or not weapon:base():weapon_hold() then
	end
	self._weapon_hold = weapon:base():get_name_id()
	self:inventory_clbk_listener(self._unit, "equip")
	self:_enter(enter_data)
	self:_update_ground_ray()
	self._controller = self._unit:base():controller()
	if not self._unit:mover() then
		self._unit:activate_mover(PlayerStandard.MOVER_STAND)
	end
	if enter_data and enter_data.wants_crouch and not self._state_data.ducking then
		self:_start_action_ducking(managers.player:player_timer():time())
	end
	self._ext_camera:clbk_fp_enter(self._unit:rotation():y())
	if self._ext_movement:nav_tracker() then
		self._pos_reservation = {
			position = self._ext_movement:m_pos(),
			radius = 100,
			filter = self._ext_movement:pos_rsrv_id()
		}
		self._pos_reservation_slow = {
			position = mvector3.copy(self._ext_movement:m_pos()),
			radius = 100,
			filter = self._ext_movement:pos_rsrv_id()
		}
		managers.navigation:add_pos_reservation(self._pos_reservation)
		managers.navigation:add_pos_reservation(self._pos_reservation_slow)
	end
	managers.hud:set_ammo_amount(self._equipped_unit:base():selection_index(), self._equipped_unit:base():ammo_info())
	managers.hud:set_weapon_name(tweak_data.weapon[self._equipped_unit:base():get_name_id()].name_id)
	if enter_data and enter_data.equip_weapon then
		self:_start_action_unequip_weapon(managers.player:player_timer():time(), {
			selection_wanted = enter_data.equip_weapon
		})
	end
	self:_reset_delay_action()
	self._last_velocity_xy = Vector3()
	if not enter_data or not enter_data.last_sent_pos_t then
	end
	self._last_sent_pos_t = managers.player:player_timer():time()
	if not enter_data or not enter_data.last_sent_pos then
	end
	self._last_sent_pos = mvector3.copy(self._pos)
end
function PlayerStandard:_enter(enter_data)
	self._unit:base():set_slot(self._unit, 2)
	if Network:is_server() and self._ext_movement:nav_tracker() then
		managers.groupai:state():on_player_weapons_hot()
	end
	if self._ext_movement:nav_tracker() then
		managers.groupai:state():on_criminal_recovered(self._unit)
	end
	local skip_equip = enter_data and enter_data.skip_equip
	if not self:_changing_weapon() and not skip_equip then
		if not self._state_data.mask_equipped then
			self._state_data.mask_equipped = true
			self:_start_action_equip(self.IDS_MASK_EQUIP, 1.6)
		else
			self:_start_action_equip(self.IDS_EQUIP)
		end
	end
	self._ext_camera:camera_unit():base():set_target_tilt(0)
	if self._ext_movement:nav_tracker() then
		self._standing_nav_seg_id = self._ext_movement:nav_tracker():nav_segment()
		local metadata = managers.navigation:get_nav_seg_metadata(self._standing_nav_seg_id)
		local location_id = metadata.location_id
		managers.hud:set_player_location(location_id)
		self._unit:base():set_suspicion_multiplier("area", metadata.suspicion_mul)
		self._unit:base():set_detection_multiplier("area", metadata.detection_mul and 1 / metadata.detection_mul or nil)
	end
	self._ext_inventory:set_mask_visibility(true)
	if not self._state_data.ducking then
		self._ext_movement:set_attention_settings({
			"pl_enemy_cbt",
			"pl_team_idle_std",
			"pl_civ_cbt"
		})
	end
	self._ext_network:send("set_stance", 2)
end
function PlayerStandard:exit(state_data, new_state_name)
	PlayerMovementState.exit(self, state_data)
	tweak_data:remove_reload_callback(self)
	self:_interupt_action_interact()
	self:_interupt_action_use_item()
	managers.environment_controller:set_dof_distance()
	if self._pos_reservation then
		managers.navigation:unreserve_pos(self._pos_reservation)
		managers.navigation:unreserve_pos(self._pos_reservation_slow)
		self._pos_reservation = nil
		self._pos_reservation_slow = nil
	end
	if self._running then
		self:_end_action_running(managers.player:player_timer():time())
		self:set_running(false)
	end
	if self._shooting then
		self._shooting = false
		self._equipped_unit:base():stop_shooting()
		self._camera_unit:base():stop_shooting()
	end
	self._headbob = 0
	self._target_headbob = 0
	self._ext_camera:set_shaker_parameter("headbob", "amplitude", 0)
	local exit_data = {
		last_sent_pos_t = self._last_sent_pos_t,
		last_sent_pos = self._last_sent_pos,
		ducking = self._state_data.ducking
	}
	return exit_data
end
function PlayerStandard:interaction_blocked()
	return self:is_deploying()
end
function PlayerStandard:update(t, dt)
	PlayerMovementState.update(self, t, dt)
	self:_calculate_standard_variables(t, dt)
	self:_update_ground_ray()
	self:_update_fwd_ray()
	self:_update_check_actions(t, dt)
	self:_update_movement(t, dt)
	self:_upd_nav_data()
	managers.hud:_update_crosshair_offset(t, dt)
end
function PlayerStandard:in_air()
	return self._state_data.in_air
end
function PlayerStandard:in_steelsight()
	return self._state_data.in_steelsight
end
local temp_vec1 = Vector3()
function PlayerStandard:_upd_nav_data()
	if mvec3_dis_sq(self._m_pos, self._pos) > 1 then
		if self._ext_movement:nav_tracker() then
			self._ext_movement:nav_tracker():move(self._pos)
			local nav_seg_id = self._ext_movement:nav_tracker():nav_segment()
			if self._standing_nav_seg_id ~= nav_seg_id then
				self._standing_nav_seg_id = nav_seg_id
				local metadata = managers.navigation:get_nav_seg_metadata(nav_seg_id)
				local location_id = metadata.location_id
				managers.hud:set_player_location(location_id)
				self._unit:base():set_suspicion_multiplier("area", metadata.suspicion_mul)
				self._unit:base():set_detection_multiplier("area", metadata.detection_mul and 1 / metadata.detection_mul or nil)
				managers.groupai:state():on_criminal_nav_seg_change(self._unit, nav_seg_id)
			end
		end
		if self._pos_reservation then
			managers.navigation:move_pos_rsrv(self._pos_reservation)
			local slow_dist = 100
			mvec3_set(temp_vec1, self._pos_reservation_slow.position)
			mvec3_sub(temp_vec1, self._pos_reservation.position)
			if slow_dist < mvec3_norm(temp_vec1) then
				mvec3_mul(temp_vec1, slow_dist)
				mvec3_add(temp_vec1, self._pos_reservation.position)
				mvec3_set(self._pos_reservation_slow.position, temp_vec1)
				managers.navigation:move_pos_rsrv(self._pos_reservation)
			end
		end
		self._ext_movement:set_m_pos(self._pos)
	end
end
function PlayerStandard:_calculate_standard_variables(t, dt)
	self._gnd_ray = nil
	self._gnd_ray_chk = nil
	self._unit:m_position(self._pos)
	self._rot = self._unit:rotation()
	self._cam_fwd = self._ext_camera:forward()
	mvector3.set(self._cam_fwd_flat, self._cam_fwd)
	mvector3.set_z(self._cam_fwd_flat, 0)
	mvector3.normalize(self._cam_fwd_flat)
	local last_vel_xy = self._last_velocity_xy
	local sampled_vel_dir = self._unit:sampled_velocity()
	mvector3.set_z(sampled_vel_dir, 0)
	local sampled_vel_len = mvector3.normalize(sampled_vel_dir)
	if sampled_vel_len == 0 then
		mvector3.set_zero(self._last_velocity_xy)
	else
		local fwd_dot = mvector3.dot(sampled_vel_dir, last_vel_xy)
		mvector3.set(self._last_velocity_xy, sampled_vel_dir)
		if sampled_vel_len < fwd_dot then
			mvector3.multiply(self._last_velocity_xy, sampled_vel_len)
		else
			mvector3.multiply(self._last_velocity_xy, math.max(0, fwd_dot))
		end
	end
	self._setting_hold_to_run = managers.user:get_setting("hold_to_run")
	self._setting_hold_to_duck = managers.user:get_setting("hold_to_duck")
end
local tmp_ground_from_vec = Vector3()
local tmp_ground_to_vec = Vector3()
local up_offset_vec = math.UP * 30
local down_offset_vec = math.UP * -40
function PlayerStandard:_update_ground_ray()
	local hips_pos = tmp_ground_from_vec
	local down_pos = tmp_ground_to_vec
	mvector3.set(hips_pos, self._pos)
	mvector3.add(hips_pos, up_offset_vec)
	mvector3.set(down_pos, hips_pos)
	mvector3.add(down_pos, down_offset_vec)
	self._gnd_ray = World:raycast("ray", hips_pos, down_pos, "slot_mask", self._slotmask_gnd_ray, "ray_type", "body mover", "sphere_cast_radius", 29, "report")
	self._gnd_ray_chk = true
end
function PlayerStandard:_update_fwd_ray()
	local from = self._unit:movement():m_head_pos()
	local to = self._cam_fwd * 4000
	mvector3.add(to, from)
	self._fwd_ray = World:raycast("ray", from, to, "slot_mask", self._slotmask_fwd_ray)
	managers.environment_controller:set_dof_distance(math.max(0, (self._fwd_ray and self._fwd_ray.distance or 4000) - 200), self._state_data.in_steelsight)
end
local win32 = SystemInfo:platform() == Idstring("WIN32")
function PlayerStandard:_get_input(t, dt)
	if self._state_data.controller_enabled ~= self._controller:enabled() and self._state_data.controller_enabled then
		local input = {
			btn_steelsight_release = true,
			btn_interact_release = true,
			btn_use_item_release = true
		}
		self._state_data.controller_enabled = self._controller:enabled()
		return input
	end
	self._state_data.controller_enabled = self._controller:enabled()
	local pressed = self._controller:get_any_input_pressed()
	local released = self._controller:get_any_input_released()
	local downed = self._controller:get_any_input()
	if not pressed and not released and not downed then
		return {}
	end
	local input = {
		btn_stats_screen_press = pressed and not self._unit:base():stats_screen_visible() and self._controller:get_input_pressed("stats_screen"),
		btn_stats_screen_release = released and self._unit:base():stats_screen_visible() and self._controller:get_input_released("stats_screen"),
		btn_duck_press = pressed and self._controller:get_input_pressed("duck"),
		btn_duck_release = released and self._controller:get_input_released("duck"),
		btn_jump_press = pressed and self._controller:get_input_pressed("jump"),
		btn_primary_attack_press = pressed and self._controller:get_input_pressed("primary_attack"),
		btn_primary_attack_state = downed and self._controller:get_input_bool("primary_attack"),
		btn_reload_press = pressed and self._controller:get_input_pressed("reload"),
		btn_steelsight_press = pressed and self._controller:get_input_pressed("secondary_attack"),
		btn_steelsight_release = released and self._controller:get_input_released("secondary_attack"),
		btn_steelsight_state = downed and self._controller:get_input_bool("secondary_attack"),
		btn_interact_press = pressed and self._controller:get_input_pressed("interact"),
		btn_interact_release = released and self._controller:get_input_released("interact"),
		btn_run_press = pressed and self._controller:get_input_pressed("run"),
		btn_run_release = released and self._controller:get_input_released("run"),
		btn_run_state = downed and self._controller:get_input_bool("run"),
		btn_switch_weapon_press = pressed and self._controller:get_input_pressed("switch_weapon"),
		btn_use_item_press = pressed and self._controller:get_input_pressed("use_item"),
		btn_use_item_release = released and self._controller:get_input_released("use_item"),
		btn_melee_press = pressed and self._controller:get_input_pressed("melee"),
		btn_weapon_gadget_press = pressed and self._controller:get_input_pressed("weapon_gadget")
	}
	if win32 then
		local i = 1
		while i < 3 do
			if self._controller:get_input_pressed("primary_choice" .. i) then
				input.btn_primary_choice = i
				break
			end
			i = i + 1
		end
	end
	return input
end
function PlayerStandard:_determine_move_direction()
	self._stick_move = self._controller:get_input_axis("move")
	if mvector3.length(self._stick_move) < 0.1 or self:_interacting() then
		self._move_dir = nil
	else
		self._move_dir = mvector3.copy(self._stick_move)
		local cam_flat_rot = Rotation(self._cam_fwd_flat, math.UP)
		mvector3.rotate_with(self._move_dir, cam_flat_rot)
	end
end
function PlayerStandard:update_check_actions_paused(t, dt)
	self:_update_check_actions(Application:time(), 0.1)
end
function PlayerStandard:_update_check_actions(t, dt)
	local input = self:_get_input()
	self:_determine_move_direction()
	self:_update_interaction_timers(t)
	self:_update_reload_timers(t, dt, input)
	self:_update_melee_timers(t, input)
	self:_update_use_item_timers(t, input)
	self:_update_equip_weapon_timers(t, input)
	self:_update_running_timers(t)
	if self._change_item_expire_t and t >= self._change_item_expire_t then
		self._change_item_expire_t = nil
	end
	if self._change_weapon_pressed_expire_t and t >= self._change_weapon_pressed_expire_t then
		self._change_weapon_pressed_expire_t = nil
	end
	if input.btn_stats_screen_press then
		self._unit:base():set_stats_screen_visible(true)
	elseif input.btn_stats_screen_release then
		self._unit:base():set_stats_screen_visible(false)
	end
	self:_update_foley(t, input)
	local new_action
	local anim_data = self._ext_anim
	new_action = new_action or self:_check_action_weapon_gadget(t, input)
	new_action = new_action or self:_check_action_melee(t, input)
	new_action = new_action or self:_check_action_reload(t, input)
	new_action = new_action or self:_check_change_weapon(t, input)
	new_action = new_action or self:_check_action_primary_attack(t, input)
	new_action = new_action or self:_check_action_equip(t, input)
	new_action = new_action or self:_check_use_item(t, input)
	new_action = new_action or self:_check_action_interact(t, input)
	self:_check_action_jump(t, input)
	self:_check_action_run(t, input)
	self:_check_action_duck(t, input)
	self:_check_action_steelsight(t, input)
	self:_find_pickups(t)
end
local mvec_pos_new = Vector3()
local mvec_achieved_walk_vel = Vector3()
local mvec_move_dir_normalized = Vector3()
function PlayerStandard:_update_movement(t, dt)
	local anim_data = self._unit:anim_data()
	local pos_new
	self._target_headbob = self._target_headbob or 0
	self._headbob = self._headbob or 0
	if self._move_dir then
		local enter_moving = not self._moving
		self._moving = true
		if enter_moving then
			self._last_sent_pos_t = t
			self:_update_crosshair_offset()
		end
		local WALK_SPEED_MAX = self:_get_max_walk_speed(t)
		mvector3.set(mvec_move_dir_normalized, self._move_dir)
		mvector3.normalize(mvec_move_dir_normalized)
		local wanted_walk_speed = WALK_SPEED_MAX * math.min(1, self._move_dir:length())
		local acceleration = self._state_data.in_air and 700 or self._running and 5000 or 3000
		local achieved_walk_vel = mvec_achieved_walk_vel
		if self._jump_vel_xy and self._state_data.in_air and 0 < mvector3.dot(self._jump_vel_xy, self._last_velocity_xy) then
			local input_move_vec = wanted_walk_speed * self._move_dir
			local jump_dir = mvector3.copy(self._last_velocity_xy)
			local jump_vel = mvector3.normalize(jump_dir)
			local fwd_dot = jump_dir:dot(input_move_vec)
			if jump_vel > fwd_dot then
				local sustain_dot = input_move_vec:normalized() * jump_vel:dot(jump_dir)
				local new_move_vec = input_move_vec + jump_dir * (sustain_dot - fwd_dot)
				mvector3.step(achieved_walk_vel, self._last_velocity_xy, new_move_vec, 700 * dt)
			else
				mvector3.multiply(mvec_move_dir_normalized, wanted_walk_speed)
				mvector3.step(achieved_walk_vel, self._last_velocity_xy, wanted_walk_speed * self._move_dir:normalized(), acceleration * dt)
			end
			local fwd_component
		else
			mvector3.multiply(mvec_move_dir_normalized, wanted_walk_speed)
			mvector3.step(achieved_walk_vel, self._last_velocity_xy, mvec_move_dir_normalized, acceleration * dt)
		end
		if mvector3.is_zero(self._last_velocity_xy) then
			mvector3.set_length(achieved_walk_vel, math.max(achieved_walk_vel:length(), 100))
		end
		pos_new = mvec_pos_new
		mvector3.set(pos_new, achieved_walk_vel)
		mvector3.multiply(pos_new, dt)
		mvector3.add(pos_new, self._pos)
		self._target_headbob = self:_get_walk_headbob()
		self._target_headbob = self._target_headbob * self._move_dir:length()
	elseif not mvector3.is_zero(self._last_velocity_xy) then
		local decceleration = self._state_data.in_air and 250 or math.lerp(2000, 1500, math.min(self._last_velocity_xy:length() / tweak_data.player.movement_state.standard.movement.speed.RUNNING_MAX, 1))
		local achieved_walk_vel = math.step(self._last_velocity_xy, Vector3(), decceleration * dt)
		pos_new = mvec_pos_new
		mvector3.set(pos_new, achieved_walk_vel)
		mvector3.multiply(pos_new, dt)
		mvector3.add(pos_new, self._pos)
		self._target_headbob = 0
	elseif self._moving then
		self._target_headbob = 0
		self._moving = false
		self:_update_crosshair_offset()
	end
	if self._headbob ~= self._target_headbob then
		self._headbob = math.step(self._headbob, self._target_headbob, dt / 4)
		self._ext_camera:set_shaker_parameter("headbob", "amplitude", self._headbob)
	end
	if pos_new then
		self._unit:movement():set_position(pos_new)
		mvector3.set(self._last_velocity_xy, pos_new)
		mvector3.subtract(self._last_velocity_xy, self._pos)
		mvector3.set_z(self._last_velocity_xy, 0)
		mvector3.divide(self._last_velocity_xy, dt)
	else
		mvector3.set_static(self._last_velocity_xy, 0, 0, 0)
	end
	local cur_pos = pos_new or self._pos
	local move_dis = mvector3.distance_sq(cur_pos, self._last_sent_pos)
	if move_dis > 22500 or move_dis > 400 and (t - self._last_sent_pos_t > 1.5 or not pos_new) then
		self._ext_network:send("action_walk_nav_point", cur_pos)
		mvector3.set(self._last_sent_pos, cur_pos)
		self._last_sent_pos_t = t
		if self._move_dir and self._running and not self._state_data.ducking and not managers.groupai:state():enemy_weapons_hot() then
			local alert_epicenter = mvector3.copy(self._last_sent_pos)
			mvector3.set_z(alert_epicenter, alert_epicenter.z + 150)
			local alert_rad = 450 * mvector3.length(self._move_dir)
			local footstep_alert = {
				"footstep",
				alert_epicenter,
				alert_rad,
				managers.groupai:state():get_unit_type_filter("civilians_enemies"),
				self._unit
			}
			managers.groupai:state():propagate_alert(footstep_alert)
		end
	end
end
function PlayerStandard:_get_walk_headbob()
	if self._state_data.in_steelsight then
		return 0
	elseif self._state_data.in_air then
		return 0
	elseif self._state_data.ducking then
		return 0.0125
	elseif self._running then
		return 0.1
	end
	return 0.025
end
function PlayerStandard:_update_foley(t, input)
	if not self._gnd_ray then
		if not self._state_data.in_air then
			self._state_data.in_air = true
			self._state_data.enter_air_pos_z = self._pos.z
			self:_interupt_action_running(t)
			self._unit:set_driving("orientation_object")
		end
	elseif self._state_data.in_air then
		self._unit:set_driving("script")
		self._state_data.in_air = false
		local from = self._pos + math.UP * 10
		local to = self._pos - math.UP * 30
		local material_name, pos, norm = World:pick_decal_material(from, to, self._slotmask_bullet_impact_targets)
		self._unit:sound():play_land(material_name)
		if self._unit:character_damage():damage_fall({
			height = self._state_data.enter_air_pos_z - self._pos.z
		}) then
			self._running_wanted = false
			managers.rumble:play("hard_land")
			self._ext_camera:play_shaker("player_fall_damage")
			self:_start_action_ducking(t)
		elseif input.btn_run_state then
			self._running_wanted = true
		end
		self._jump_t = nil
		self._jump_vel_xy = nil
		self._ext_camera:play_shaker("player_land", 0.5)
		managers.rumble:play("land")
	elseif self._jump_vel_xy and t - self._jump_t > 0.3 then
		self._jump_vel_xy = nil
		if input.btn_run_state then
			self._running_wanted = true
		end
	end
	self:_check_step(t)
end
function PlayerStandard:_check_step(t)
	if self._state_data.in_air then
		return
	end
	self._last_step_pos = self._last_step_pos or Vector3()
	local step_length = self._state_data.in_steelsight and 100 or self._state_data.ducking and 125 or self._running and 175 or 150
	if mvector3.distance_sq(self._last_step_pos, self._pos) > step_length * step_length then
		mvector3.set(self._last_step_pos, self._pos)
		self._unit:base():anim_data_clbk_footstep()
	end
end
function PlayerStandard:_update_crosshair_offset(t)
	do return end
	if not alive(self._equipped_unit) then
		return
	end
	local name_id = self._equipped_unit:base():get_name_id()
	if not tweak_data.weapon[name_id].crosshair then
		return
	end
	if self._state_data.in_steelsight then
		managers.hud:set_crosshair_visible(not tweak_data.weapon[name_id].crosshair.steelsight.hidden)
		managers.hud:set_crosshair_offset(tweak_data.weapon[name_id].crosshair.steelsight.offset)
		return
	end
	local spread_multiplier = self._equipped_unit:base():spread_multiplier()
	managers.hud:set_crosshair_visible(not tweak_data.weapon[name_id].crosshair[self._state_data.ducking and "crouching" or "standing"].hidden)
	if self._moving then
		managers.hud:set_crosshair_offset(tweak_data.weapon[name_id].crosshair[self._state_data.ducking and "crouching" or "standing"].moving_offset * spread_multiplier)
		return
	else
		managers.hud:set_crosshair_offset(tweak_data.weapon[name_id].crosshair[self._state_data.ducking and "crouching" or "standing"].offset * spread_multiplier)
	end
end
function PlayerStandard:_stance_entered(unequipped)
	local stance_standard = tweak_data.player.stances.default[managers.player:current_state()] or tweak_data.player.stances.default.standard
	local head_stance = self._state_data.ducking and tweak_data.player.stances.default.crouched.head or stance_standard.head
	local weapon_id
	local stance_mod = {
		translation = Vector3(0, 0, 0)
	}
	if not unequipped then
		weapon_id = self._equipped_unit:base():get_name_id()
		stance_mod = self._state_data.in_steelsight and self._equipped_unit:base().stance_mod and self._equipped_unit:base():stance_mod() or stance_mod
	end
	local stances = tweak_data.player.stances[weapon_id] or tweak_data.player.stances.default
	local misc_attribs = self._state_data.in_steelsight and stances.steelsight or self._state_data.ducking and stances.crouched or stances.standard
	local duration = tweak_data.player.TRANSITION_DURATION + (self._equipped_unit:base():transition_duration() or 0)
	local duration_multiplier = self._state_data.in_steelsight and 1 / self._equipped_unit:base():enter_steelsight_speed_multiplier() or 1
	local new_fov = self:get_zoom_fov(misc_attribs) + 0
	self._camera_unit:base():clbk_stance_entered(misc_attribs.shoulders, head_stance, misc_attribs.vel_overshot, new_fov, misc_attribs.shakers, stance_mod, duration_multiplier, duration)
	managers.menu:set_mouse_sensitivity(new_fov < (misc_attribs.FOV or 75))
end
function PlayerStandard:update_fov_external()
	if not alive(self._equipped_unit) then
		return
	end
	local weapon_id = self._equipped_unit:base():get_name_id()
	local stances = tweak_data.player.stances[weapon_id] or tweak_data.player.stances.default
	local misc_attribs = self._state_data.in_steelsight and stances.steelsight or self._state_data.ducking and stances.crouched or stances.standard
	local new_fov = self:get_zoom_fov(misc_attribs) + 0
	self._camera_unit:base():set_fov_instant(new_fov)
end
function PlayerStandard:_get_max_walk_speed(t)
	if self._state_data.in_steelsight then
		return self._tweak_data.movement.speed.STEELSIGHT_MAX
	end
	if self._state_data.ducking then
		return self._tweak_data.movement.speed.CROUCHING_MAX * managers.player:upgrade_value("player", "crouch_speed_multiplier", 1)
	end
	if self._state_data.in_air then
		return self._tweak_data.movement.speed.INAIR_MAX
	end
	local morale_boost_bonus = self._ext_movement:morale_boost()
	morale_boost_bonus = morale_boost_bonus and morale_boost_bonus.move_speed_bonus or 1
	local armor_penalty = managers.player:body_armor_movement_penalty()
	return (self._running and self._tweak_data.movement.speed.RUNNING_MAX * managers.player:upgrade_value("player", "run_speed_multiplier", 1) or self._tweak_data.movement.speed.STANDARD_MAX * managers.player:upgrade_value("player", "walk_speed_multiplier", 1)) * morale_boost_bonus * armor_penalty
end
function PlayerStandard:_start_action_steelsight(t)
	if self:_changing_weapon() or self:_is_reloading() or self:_interacting() or self._melee_expire_t or self._use_item_expire_t then
		self._steelsight_wanted = true
		return
	end
	if self._running and not self._end_running_expire_t then
		self:_interupt_action_running(t)
		self._steelsight_wanted = true
		return
	end
	self:_break_intimidate_redirect()
	self._steelsight_wanted = false
	self._state_data.in_steelsight = true
	self:_update_crosshair_offset()
	self:_stance_entered()
	self:_interupt_action_running(t)
	self._equipped_unit:base():play_tweak_data_sound("enter_steelsight")
	if managers.controller:get_default_wrapper_type() ~= "pc" and managers.user:get_setting("aim_assist") then
		local closest_ray = self._equipped_unit:base():check_autoaim(self._ext_camera:position(), self._ext_camera:forward(), nil, true)
		self._camera_unit:base():clbk_aim_assist(closest_ray)
	end
	self._ext_network:send("set_stance", 3)
end
function PlayerStandard:_end_action_steelsight(t)
	self._state_data.in_steelsight = false
	managers.environment_controller:set_dof_distance()
	self:_stance_entered()
	self:_update_crosshair_offset()
	self._equipped_unit:base():play_tweak_data_sound("leave_steelsight")
	self._camera_unit:base():clbk_stop_aim_assist()
	self._ext_network:send("set_stance", 2)
end
function PlayerStandard:_interupt_action_steelsight(t)
	self._steelsight_wanted = false
	if self._state_data.in_steelsight then
		self:_end_action_steelsight(t)
	end
end
function PlayerStandard:_start_action_running(t)
	if not self._move_dir then
		self._running_wanted = true
		return
	end
	if self._shooting or self:_changing_weapon() or self._melee_expire_t or self._use_item_expire_t or self._state_data.in_air then
		self._running_wanted = true
		return
	end
	if self._state_data.ducking and not self:_can_stand() then
		self._running_wanted = true
		return
	end
	if not self:_can_run_directional() then
		return
	end
	self._running_wanted = false
	if managers.player:get_player_rule("no_run") then
		return
	end
	if not self._unit:movement():is_above_stamina_threshold() then
		return
	end
	self:set_running(true)
	self._end_running_expire_t = nil
	self._start_running_t = t
	self._ext_camera:play_redirect(self.IDS_START_RUNNING)
	self:_interupt_action_reload(t)
	self:_interupt_action_steelsight(t)
	self:_interupt_action_ducking(t)
end
function PlayerStandard:_end_action_running(t)
	if not self._end_running_expire_t then
		local speed_multiplier = self._equipped_unit:base():exit_run_speed_multiplier()
		self._end_running_expire_t = t + 0.4 / speed_multiplier
		self._ext_camera:play_redirect(self.IDS_STOP_RUNNING, speed_multiplier)
	end
end
function PlayerStandard:_interupt_action_running(t)
	if self._running and not self._end_running_expire_t then
		self:_end_action_running(t)
	end
end
function PlayerStandard:_start_action_ducking(t)
	if self:_interacting() then
		return
	end
	self:_interupt_action_running(t)
	self._state_data.ducking = true
	self:_stance_entered()
	self:_update_crosshair_offset()
	local velocity = self._unit:mover():velocity()
	self._unit:kill_mover()
	self._unit:activate_mover(PlayerStandard.MOVER_DUCK, velocity)
	self._ext_network:send("set_pose", 2)
	local crh_attention
	if managers.groupai:state():whisper_mode() then
		crh_attention = "pl_enemy_sneak"
	else
		crh_attention = "pl_enemy_cbt_crh"
	end
	self._ext_movement:set_attention_settings({
		crh_attention,
		"pl_team_idle_std",
		"pl_civ_sneak"
	})
end
function PlayerStandard:_end_action_ducking(t)
	if not self:_can_stand() then
		return
	end
	self._state_data.ducking = false
	self:_stance_entered()
	self:_update_crosshair_offset()
	local velocity = self._unit:mover():velocity()
	self._unit:kill_mover()
	self._unit:activate_mover(PlayerStandard.MOVER_STAND, velocity)
	self._ext_network:send("set_pose", 1)
	self._ext_movement:set_attention_settings({
		"pl_enemy_cbt",
		"pl_team_idle_std",
		"pl_civ_cbt"
	})
end
function PlayerStandard:_interupt_action_ducking(t)
	if self._state_data.ducking then
		self:_end_action_ducking(t)
	end
end
function PlayerStandard:_can_stand()
	local offset = 50
	local radius = 30
	local hips_pos = self._obj_com:position() + math.UP * offset
	local up_pos = math.UP * (160 - offset)
	mvector3.add(up_pos, hips_pos)
	local ray = World:raycast("ray", hips_pos, up_pos, "slot_mask", self._slotmask_gnd_ray, "ray_type", "body mover", "sphere_cast_radius", radius, "bundle", 20)
	if ray then
		managers.hint:show_hint("cant_stand_up", 2)
		return false
	end
	return true
end
function PlayerStandard:_can_run_directional()
	if managers.player:has_category_upgrade("player", "can_free_run") then
		return true
	end
	local running_angle = managers.player:has_category_upgrade("player", "can_strafe_run") and 92 or 50
	return running_angle >= mvector3.angle(self._stick_move, math.Y)
end
function PlayerStandard:_start_action_equip(redirect, extra_time)
	local tweak_data = self._equipped_unit:base():weapon_tweak_data()
	self._equip_weapon_expire_t = managers.player:player_timer():time() + ((tweak_data.timers.equip or 0.7) + (extra_time or 0))
	local result = self._ext_camera:play_redirect(redirect or self.IDS_EQUIP)
end
function PlayerStandard:_check_action_interact(t, input)
	local new_action, timer, interact_object
	local interaction_wanted = input.btn_interact_press
	if interaction_wanted then
		local action_forbidden = self:chk_action_forbidden("interact") or self._unit:base():stats_screen_visible() or self:_interacting() or self._ext_movement:has_carry_restriction() or self:is_deploying() or self:_changing_weapon()
		if not action_forbidden then
			new_action, timer, interact_object = managers.interaction:interact(self._unit)
			if new_action then
				self:_play_interact_redirect(t, input)
			end
			if timer then
				new_action = true
				self._ext_camera:camera_unit():base():set_limits(80, 50)
				self:_start_action_interact(t, input, timer, interact_object)
			end
			new_action = new_action or self:_start_action_intimidate(t)
		end
	end
	if input.btn_interact_release then
		self:_interupt_action_interact()
	end
	return new_action
end
function PlayerStandard:_start_action_interact(t, input, timer, interact_object)
	self:_interupt_action_reload(t)
	self:_interupt_action_steelsight(t)
	self:_interupt_action_running(t)
	self._interact_expire_t = t + timer
	self._interact_params = {
		object = interact_object,
		timer = timer,
		tweak_data = interact_object:interaction().tweak_data
	}
	self._ext_camera:play_redirect(self.IDS_UNEQUIP)
	self._equipped_unit:base():tweak_data_anim_play("unequip")
	managers.hud:show_interaction_bar(0, timer)
	self._unit:base():set_detection_multiplier("interact", 0.5)
	managers.network:session():send_to_peers_loaded("sync_teammate_progress", 1, true, self._interact_params.tweak_data, timer, false)
end
function PlayerStandard:_interupt_action_interact(t, input, complete)
	if self._interact_expire_t then
		self._interact_expire_t = nil
		if alive(self._interact_params.object) then
			self._interact_params.object:interaction():interact_interupt(self._unit, complete)
		end
		self._ext_camera:camera_unit():base():remove_limits()
		managers.interaction:interupt_action_interact(self._unit)
		managers.network:session():send_to_peers_loaded("sync_teammate_progress", 1, false, self._interact_params.tweak_data, 0, complete and true or false)
		self._interact_params = nil
		local tweak_data = self._equipped_unit:base():weapon_tweak_data()
		self._equip_weapon_expire_t = managers.player:player_timer():time() + (tweak_data.timers.equip or 0.7)
		local result = self._ext_camera:play_redirect(self.IDS_EQUIP)
		managers.hud:hide_interaction_bar(complete)
		self._equipped_unit:base():tweak_data_anim_stop("unequip")
		self._unit:base():set_detection_multiplier("interact", nil)
	end
end
function PlayerStandard:_end_action_interact()
	self:_interupt_action_interact(nil, nil, true)
	managers.interaction:end_action_interact(self._unit)
	self._unit:base():set_detection_multiplier("interact", nil)
end
function PlayerStandard:_interacting()
	return self._interact_expire_t
end
function PlayerStandard:_update_interaction_timers(t)
	if self._interact_expire_t then
		if not alive(self._interact_params.object) or self._interact_params.object ~= managers.interaction:active_object() or self._interact_params.tweak_data ~= self._interact_params.object:interaction().tweak_data then
			self:_interupt_action_interact(t)
		else
			managers.hud:set_interaction_bar_width(self._interact_params.timer - (self._interact_expire_t - t), self._interact_params.timer)
			if t >= self._interact_expire_t then
				self:_end_action_interact(t)
				self._interact_expire_t = nil
			end
		end
	end
end
function PlayerStandard:_check_action_weapon_gadget(t, input)
	if input.btn_weapon_gadget_press and self._equipped_unit:base().toggle_gadget and self._equipped_unit:base():has_gadget() then
		self._equipped_unit:base():toggle_gadget()
		self._unit:network():send("set_weapon_gadget_state", self._equipped_unit:base()._gadget_on)
	end
end
function PlayerStandard:_check_action_melee(t, input)
	local action_wanted = input.btn_melee_press
	if not action_wanted then
		return
	end
	local action_forbidden = self._melee_expire_t or self._use_item_expire_t or self:_changing_weapon() or self:_interacting()
	if action_forbidden then
		return
	end
	self._equipped_unit:base():tweak_data_anim_stop("fire")
	self:_interupt_action_reload(t)
	self:_interupt_action_steelsight(t)
	self:_interupt_action_running(t)
	managers.network:session():send_to_peers("play_distance_interact_redirect", self._unit, "melee")
	self._ext_camera:play_shaker("player_melee")
	self._melee_expire_t = t + 0.6
	local range = 175
	local from = self._unit:movement():m_head_pos()
	local to = from + self._unit:movement():m_head_rot():y() * range
	local sphere_cast_radius = 20
	local col_ray = self._unit:raycast("ray", from, to, "slot_mask", self._slotmask_bullet_impact_targets, "sphere_cast_radius", sphere_cast_radius, "ray_type", "body melee")
	if col_ray then
		self._ext_camera:play_redirect(self.IDS_MELEE)
		local damage, damage_effect = self._equipped_unit:base():melee_damage_info()
		damage_effect = damage_effect * managers.player:upgrade_value("player", "melee_knockdown_mul", 1)
		col_ray.sphere_cast_radius = sphere_cast_radius
		local hit_unit = col_ray.unit
		if not hit_unit:character_damage() or not hit_unit:character_damage()._no_blood then
			managers.game_play_central:play_impact_flesh({col_ray = col_ray})
		end
		if hit_unit:character_damage() then
			self._unit:sound():play("melee_hit_body", nil, false)
		end
		if hit_unit:damage() and col_ray.body:extension() and col_ray.body:extension().damage then
			col_ray.body:extension().damage:damage_melee(self._unit, col_ray.normal, col_ray.position, col_ray.direction, damage)
			if hit_unit:id() ~= -1 then
				managers.network:session():send_to_peers_synched("sync_body_damage_melee", col_ray.body, self._unit, col_ray.normal, col_ray.position, col_ray.direction, damage)
			end
		end
		managers.rumble:play("melee_hit")
		managers.game_play_central:physics_push(col_ray)
		local character_unit, shield_knock
		local can_shield_knock = managers.player:has_category_upgrade("player", "shield_knock")
		if can_shield_knock and hit_unit:in_slot(8) and alive(hit_unit:parent()) then
			shield_knock = true
			character_unit = hit_unit:parent()
		end
		character_unit = character_unit or hit_unit
		if character_unit:character_damage() and character_unit:character_damage().damage_melee then
			local dmg_multiplier = 1
			if not managers.enemy:is_civilian(character_unit) and not managers.groupai:state():is_enemy_special(character_unit) then
				dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "non_special_melee_multiplier", 1)
			end
			dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "melee_damage_multiplier", 1)
			local health_ratio = self._ext_damage:health_ratio()
			if health_ratio <= tweak_data.upgrades.player_damage_health_ratio_threshold then
				local damage_ratio = 1 - health_ratio / math.max(0.01, tweak_data.upgrades.player_damage_health_ratio_threshold)
				dmg_multiplier = dmg_multiplier * (1 + managers.player:upgrade_value("player", "melee_damage_health_ratio_multiplier", 0) * damage_ratio)
			end
			local action_data = {}
			action_data.variant = "melee"
			action_data.damage = shield_knock and 0 or damage * dmg_multiplier
			action_data.damage_effect = damage_effect
			action_data.attacker_unit = self._unit
			action_data.col_ray = col_ray
			action_data.shield_knock = can_shield_knock
			local defense_data = character_unit:character_damage():damage_melee(action_data)
			return defense_data
		else
		end
	else
		self._ext_camera:play_redirect(self.IDS_MELEE_MISS)
	end
	return true
end
function PlayerStandard:_interupt_action_melee(t)
	self._melee_expire_t = nil
end
function PlayerStandard:_update_melee_timers(t, input)
	if self._melee_expire_t and t >= self._melee_expire_t then
		self._melee_expire_t = nil
		if self._equipped_unit and input.btn_steelsight_state then
			self._steelsight_wanted = true
		end
	end
end
function PlayerStandard:_check_action_reload(t, input)
	local new_action
	local action_wanted = input.btn_reload_press
	if action_wanted then
		local action_forbidden = self:_is_reloading() or self:_changing_weapon() or self._melee_expire_t or self._use_item_expire_t or self:_interacting()
		if not action_forbidden and self._equipped_unit and not self._equipped_unit:base():clip_full() then
			self:_start_action_reload_enter(t)
			new_action = true
		end
	end
	return new_action
end
function PlayerStandard:_update_reload_timers(t, dt, input)
	if self._state_data.reload_enter_expire_t and t >= self._state_data.reload_enter_expire_t then
		self._state_data.reload_enter_expire_t = nil
		self:_start_action_reload(t)
	end
	if self._state_data.reload_expire_t then
		local interupt
		if self._equipped_unit:base():update_reloading(t, dt, self._state_data.reload_expire_t - t) then
			managers.hud:set_ammo_amount(self._equipped_unit:base():selection_index(), self._equipped_unit:base():ammo_info())
			local speed_multiplier = self._equipped_unit:base():reload_speed_multiplier()
			if self._queue_reload_interupt then
				self._queue_reload_interupt = nil
				interupt = true
			end
		end
		if t >= self._state_data.reload_expire_t or interupt then
			self._state_data.reload_expire_t = nil
			if self._equipped_unit:base():reload_exit_expire_t() then
				local speed_multiplier = self._equipped_unit:base():reload_speed_multiplier()
				if self._equipped_unit:base():started_reload_empty() then
					self._state_data.reload_exit_expire_t = t + self._equipped_unit:base():reload_exit_expire_t() / speed_multiplier
					self._ext_camera:play_redirect(self.IDS_RELOAD_EXIT, speed_multiplier)
					self._equipped_unit:base():tweak_data_anim_play("reload_exit", speed_multiplier)
				else
					self._state_data.reload_exit_expire_t = t + self._equipped_unit:base():reload_not_empty_exit_expire_t() / speed_multiplier
					self._ext_camera:play_redirect(self.IDS_RELOAD_NOT_EMPTY_EXIT, speed_multiplier)
				end
			elseif self._equipped_unit then
				if not interupt then
					self._equipped_unit:base():on_reload()
				end
				managers.statistics:reloaded()
				managers.hud:set_ammo_amount(self._equipped_unit:base():selection_index(), self._equipped_unit:base():ammo_info())
				if input.btn_steelsight_state then
					self._steelsight_wanted = true
				end
			end
		end
	end
	if self._state_data.reload_exit_expire_t and t >= self._state_data.reload_exit_expire_t then
		self._state_data.reload_exit_expire_t = nil
		if self._equipped_unit then
			managers.statistics:reloaded()
			managers.hud:set_ammo_amount(self._equipped_unit:base():selection_index(), self._equipped_unit:base():ammo_info())
			if input.btn_steelsight_state then
				self._steelsight_wanted = true
			end
		end
	end
end
function PlayerStandard:_check_use_item(t, input)
	local new_action
	local action_wanted = input.btn_use_item_press
	if action_wanted then
		local action_forbidden = self._use_item_expire_t or self:_interacting() or self:_changing_weapon()
		if not action_forbidden and managers.player:can_use_selected_equipment(self._unit) then
			self:_start_action_use_item(t)
			new_action = true
		end
	end
	if input.btn_use_item_release then
		self:_interupt_action_use_item()
	end
	return new_action
end
function PlayerStandard:_update_use_item_timers(t, input)
	if self._use_item_expire_t then
		local valid = managers.player:check_selected_equipment_placement_valid(self._unit)
		local deploy_timer = managers.player:selected_equipment_deploy_timer()
		managers.hud:set_progress_timer_bar_valid(valid, not valid and "hud_deploy_valid_help")
		managers.hud:set_progress_timer_bar_width(deploy_timer - (self._use_item_expire_t - t), deploy_timer)
		if t >= self._use_item_expire_t then
			self:_end_action_use_item(valid)
			self._use_item_expire_t = nil
		end
	end
end
function PlayerStandard:is_deploying()
	return self._use_item_expire_t and true or false
end
function PlayerStandard:_start_action_use_item(t)
	self:_interupt_action_reload(t)
	self:_interupt_action_steelsight(t)
	self:_interupt_action_running(t)
	local deploy_timer = managers.player:selected_equipment_deploy_timer()
	self._use_item_expire_t = t + deploy_timer
	self._ext_camera:play_redirect(self.IDS_UNEQUIP)
	self._equipped_unit:base():tweak_data_anim_play("unequip")
	managers.hud:show_progress_timer_bar(0, deploy_timer)
	local text = managers.localization:text("hud_deploying_equipment", {
		EQUIPMENT = managers.player:selected_equipment_name()
	})
	managers.hud:show_progress_timer({text = text, icon = nil})
	local equipment_id = managers.player:selected_equipment_id()
	managers.network:session():send_to_peers_loaded("sync_teammate_progress", 2, true, equipment_id, deploy_timer, false)
end
function PlayerStandard:_end_action_use_item(valid)
	local result = managers.player:use_selected_equipment(self._unit)
	self:_interupt_action_use_item(nil, nil, valid)
end
function PlayerStandard:_interupt_action_use_item(t, input, complete)
	if self._use_item_expire_t then
		self._use_item_expire_t = nil
		local tweak_data = self._equipped_unit:base():weapon_tweak_data()
		self._equip_weapon_expire_t = managers.player:player_timer():time() + (tweak_data.timers.equip or 0.7)
		local result = self._ext_camera:play_redirect(self.IDS_EQUIP)
		self._equipped_unit:base():tweak_data_anim_stop("unequip")
		managers.hud:hide_progress_timer_bar(complete)
		managers.hud:remove_progress_timer()
		self._unit:equipment():on_deploy_interupted()
		managers.network:session():send_to_peers_loaded("sync_teammate_progress", 2, false, "", 0, complete and true or false)
	end
end
function PlayerStandard:_check_change_weapon(t, input)
	local new_action
	local action_wanted = input.btn_switch_weapon_press
	if action_wanted then
		local action_forbidden = self:_changing_weapon()
		action_forbidden = action_forbidden or self._melee_expire_t or self._use_item_expire_t or self._change_item_expire_t
		action_forbidden = action_forbidden or self._unit:inventory():num_selections() == 1 or self:_interacting()
		if not action_forbidden then
			local data = {}
			data.next = true
			self._change_weapon_pressed_expire_t = t + 0.33
			self:_start_action_unequip_weapon(t, data)
			new_action = true
		end
	end
	return new_action
end
function PlayerStandard:_update_equip_weapon_timers(t, input)
	if self._unequip_weapon_expire_t and t >= self._unequip_weapon_expire_t then
		self._unequip_weapon_expire_t = nil
		self:_start_action_equip_weapon(t)
	end
	if self._equip_weapon_expire_t and t >= self._equip_weapon_expire_t then
		self._equip_weapon_expire_t = nil
		if input.btn_steelsight_state then
			self._steelsight_wanted = true
		end
	end
end
function PlayerStandard:is_equipping()
	return self._equip_weapon_expire_t
end
function PlayerStandard:_add_unit_to_char_table(char_table, unit, unit_type, interaction_dist, interaction_through_walls, tight_area, priority, my_head_pos, cam_fwd)
	if unit:unit_data().disable_shout and not unit:brain():interaction_voice() then
		return
	end
	local u_head_pos = unit:movement():m_head_pos() + math.UP * 30
	local vec = u_head_pos - my_head_pos
	local dis = mvector3.normalize(vec)
	local max_dis = interaction_dist
	if dis < max_dis then
		local max_angle = math.max(8, math.lerp(tight_area and 30 or 90, tight_area and 10 or 30, dis / 1200))
		local angle = vec:angle(cam_fwd)
		if max_angle > angle then
			local ing_wgt = dis * dis * (1 - vec:dot(cam_fwd)) / priority
			if interaction_through_walls then
				table.insert(char_table, {
					unit = unit,
					inv_wgt = ing_wgt,
					unit_type = unit_type
				})
			else
				local ray = World:raycast("ray", my_head_pos, u_head_pos, "slot_mask", self._slotmask_AI_visibility, "ray_type", "ai_vision")
				if not ray or 30 > mvector3.distance(ray.position, u_head_pos) then
					table.insert(char_table, {
						unit = unit,
						inv_wgt = ing_wgt,
						unit_type = unit_type
					})
				end
			end
		end
	end
end
function PlayerStandard:_get_interaction_target(char_table, my_head_pos, cam_fwd)
	local prime_target
	local ray = World:raycast("ray", my_head_pos, my_head_pos + cam_fwd * 100 * 100, "slot_mask", self._slotmask_long_distance_interaction)
	if ray then
		for _, char in pairs(char_table) do
			if ray.unit == char.unit then
				prime_target = char
			else
			end
		end
	end
	if not prime_target then
		local low_wgt
		for _, char in pairs(char_table) do
			local inv_wgt = char.inv_wgt
			if not low_wgt or low_wgt > inv_wgt then
				low_wgt = inv_wgt
				prime_target = char
			end
		end
	end
	return prime_target
end
function PlayerStandard:_get_intimidation_action(prime_target, char_table, amount, primary_only, detect_only)
	local voice_type, new_action, plural
	local unit_type_enemy = 0
	local unit_type_civilian = 1
	local unit_type_teammate = 2
	local is_whisper_mode = managers.groupai:state():whisper_mode()
	if prime_target then
		if prime_target.unit_type == unit_type_teammate then
			local is_human_player, record
			if not detect_only then
				record = managers.groupai:state():all_criminals()[prime_target.unit:key()]
				if record.ai then
					prime_target.unit:movement():set_cool(false)
					prime_target.unit:brain():on_long_dis_interacted(0, self._unit)
				else
					is_human_player = true
				end
			end
			local amount = 0
			local rally_skill_data = self._ext_movement:rally_skill_data()
			if rally_skill_data and rally_skill_data.range_sq > mvector3.distance_sq(self._pos, record.m_pos) then
				local needs_revive, is_arrested
				if prime_target.unit:base().is_husk_player then
					is_arrested = prime_target.unit:movement():current_state_name() == "arrested"
					needs_revive = prime_target.unit:interaction():active() and prime_target.unit:movement():need_revive() and not is_arrested
				else
					is_arrested = prime_target.unit:character_damage():arrested()
					needs_revive = prime_target.unit:character_damage():need_revive()
				end
				if needs_revive and rally_skill_data.long_dis_revive then
					voice_type = "revive"
				elseif not is_arrested and not needs_revive and rally_skill_data.morale_boost_delay_t and managers.player:player_timer():time() > rally_skill_data.morale_boost_delay_t then
					voice_type = "boost"
					amount = 1
				end
			end
			if is_human_player then
				prime_target.unit:network():send_to_unit({
					"long_dis_interaction",
					prime_target.unit,
					amount,
					self._unit
				})
			elseif voice_type == "revive" then
			elseif voice_type == "boost" then
				if Network:is_server() then
					prime_target.unit:brain():on_long_dis_interacted(amount, self._unit)
				else
					managers.network:session():send_to_host("long_dis_interaction", prime_target.unit, amount, self._unit)
				end
			end
			voice_type = voice_type or "come"
			plural = false
		else
			local prime_target_key = prime_target.unit:key()
			if prime_target.unit_type == unit_type_enemy then
				plural = false
				if prime_target.unit:anim_data().hands_back then
					voice_type = "cuff_cop"
				elseif prime_target.unit:anim_data().surrender then
					voice_type = "down_cop"
				elseif is_whisper_mode and prime_target.unit:movement():cool() and tweak_data.character[prime_target.unit:base()._tweak_table].silent_priority_shout then
					voice_type = "mark_cop_quiet"
				elseif tweak_data.character[prime_target.unit:base()._tweak_table].priority_shout then
					voice_type = "mark_cop"
				else
					voice_type = "stop_cop"
				end
			elseif tweak_data.character[prime_target.unit:base()._tweak_table].is_escort then
				plural = false
				local e_guy = prime_target.unit
				if e_guy:anim_data().move then
					voice_type = "escort_keep"
				elseif e_guy:anim_data().panic then
					voice_type = "escort_go"
				else
					voice_type = "escort"
				end
			else
				if prime_target.unit:anim_data().move then
					voice_type = "stop"
				elseif prime_target.unit:anim_data().drop then
					voice_type = "down_stay"
				else
					voice_type = "down"
				end
				local num_affected = 0
				for _, char in pairs(char_table) do
					if char.unit_type == unit_type_civilian then
						if voice_type == "stop" and char.unit:anim_data().move then
							num_affected = num_affected + 1
						elseif voice_type == "down_stay" and char.unit:anim_data().drop then
							num_affected = num_affected + 1
						elseif voice_type == "down" and not char.unit:anim_data().move and not char.unit:anim_data().drop then
							num_affected = num_affected + 1
						end
					end
				end
				plural = num_affected > 1 and true or false
			end
			local max_inv_wgt = 0
			for _, char in pairs(char_table) do
				if max_inv_wgt < char.inv_wgt then
					max_inv_wgt = char.inv_wgt
				end
			end
			if max_inv_wgt < 1 then
				max_inv_wgt = 1
			end
			if detect_only then
				voice_type = "come"
			else
				for _, char in pairs(char_table) do
					if char.unit_type ~= unit_type_teammate and (not is_whisper_mode or not char.unit:movement():cool()) then
						if char.unit_type == unit_type_civilian then
							amount = (amount or tweak_data.player.long_dis_interaction.intimidate_strength) * managers.player:upgrade_value("player", "civ_intimidation_mul", 1)
						end
						if prime_target_key == char.unit:key() then
							voice_type = char.unit:brain():on_intimidated(amount or tweak_data.player.long_dis_interaction.intimidate_strength, self._unit) or voice_type
						elseif not primary_only and char.unit_type ~= unit_type_enemy then
							char.unit:brain():on_intimidated((amount or tweak_data.player.long_dis_interaction.intimidate_strength) * char.inv_wgt / max_inv_wgt, self._unit)
						end
					end
				end
			end
		end
	end
	return voice_type, plural, prime_target
end
function PlayerStandard:_get_unit_intimidation_action(intimidate_enemies, intimidate_civilians, intimidate_teammates, only_special_enemies, intimidate_escorts, intimidation_amount, primary_only, detect_only)
	local char_table = {}
	local unit_type_enemy = 0
	local unit_type_civilian = 1
	local unit_type_teammate = 2
	local cam_fwd = self._ext_camera:forward()
	local my_head_pos = self._ext_movement:m_head_pos()
	local range_mul = managers.player:upgrade_value("player", "intimidate_range_mul", 1) * managers.player:upgrade_value("player", "passive_intimidate_range_mul", 1)
	local intimidate_range_civ = tweak_data.player.long_dis_interaction.intimidate_range_civilians * range_mul
	local intimidate_range_ene = tweak_data.player.long_dis_interaction.intimidate_range_enemies * range_mul
	local highlight_range = tweak_data.player.long_dis_interaction.highlight_range * range_mul
	if intimidate_enemies then
		local enemies = managers.enemy:all_enemies()
		for u_key, u_data in pairs(enemies) do
			if not u_data.is_converted and not u_data.unit:anim_data().hands_tied and (u_data.char_tweak.priority_shout or not only_special_enemies) then
				if managers.groupai:state():whisper_mode() then
					if u_data.char_tweak.silent_priority_shout and u_data.unit:movement():cool() then
						self:_add_unit_to_char_table(char_table, u_data.unit, unit_type_enemy, highlight_range, false, false, 0.01, my_head_pos, cam_fwd)
					elseif not u_data.unit:movement():cool() then
						self:_add_unit_to_char_table(char_table, u_data.unit, unit_type_enemy, intimidate_range_ene, false, false, 10000, my_head_pos, cam_fwd)
					end
				elseif u_data.char_tweak.priority_shout then
					self:_add_unit_to_char_table(char_table, u_data.unit, unit_type_enemy, highlight_range, false, false, 0.01, my_head_pos, cam_fwd)
				else
					self:_add_unit_to_char_table(char_table, u_data.unit, unit_type_enemy, intimidate_range_ene, false, false, 10000, my_head_pos, cam_fwd)
				end
			end
		end
	end
	if intimidate_civilians then
		local civilians = managers.enemy:all_civilians()
		for u_key, u_data in pairs(civilians) do
			if u_data.unit:in_slot(21) then
				local is_escort = u_data.char_tweak.is_escort
				if not is_escort or intimidate_escorts then
					local dist = is_escort and 300 or intimidate_range_civ
					local prio = is_escort and 100000 or 0.001
					self:_add_unit_to_char_table(char_table, u_data.unit, unit_type_civilian, dist, false, false, prio, my_head_pos, cam_fwd)
				end
			end
		end
	end
	if intimidate_teammates and not managers.groupai:state():whisper_mode() then
		local criminals = managers.groupai:state():all_char_criminals()
		for u_key, u_data in pairs(criminals) do
			local added
			if u_key ~= self._unit:key() then
				local rally_skill_data = self._ext_movement:rally_skill_data()
				if rally_skill_data and rally_skill_data.long_dis_revive and rally_skill_data.range_sq > mvector3.distance_sq(self._pos, u_data.m_pos) then
					local needs_revive
					if u_data.unit:base().is_husk_player then
						needs_revive = u_data.unit:interaction():active() and u_data.unit:movement():need_revive() and u_data.unit:movement():current_state_name() ~= "arrested"
					else
						needs_revive = u_data.unit:character_damage():need_revive()
					end
					if needs_revive then
						added = true
						self:_add_unit_to_char_table(char_table, u_data.unit, unit_type_teammate, 100000, true, true, 0.01, my_head_pos, cam_fwd)
					end
				end
			end
			if not added and not u_data.is_deployable and not u_data.unit:movement():downed() and not u_data.unit:base().is_local_player then
				self:_add_unit_to_char_table(char_table, u_data.unit, unit_type_teammate, 100000, true, true, 0.01, my_head_pos, cam_fwd)
			end
		end
	end
	local prime_target = self:_get_interaction_target(char_table, my_head_pos, cam_fwd)
	return self:_get_intimidation_action(prime_target, char_table, intimidation_amount, primary_only, detect_only)
end
function PlayerStandard:_start_action_intimidate(t)
	if not self._intimidate_t or t - self._intimidate_t > tweak_data.player.movement_state.interaction_delay then
		local skip_alert = managers.groupai:state():whisper_mode()
		local voice_type, plural, prime_target = self:_get_unit_intimidation_action(true, true, true, false, true, nil, nil, nil)
		local interact_type, sound_name
		local sound_suffix = plural and "plu" or "sin"
		if voice_type == "stop" then
			interact_type = "cmd_stop"
			sound_name = "f02x_" .. sound_suffix
		elseif voice_type == "stop_cop" then
			interact_type = "cmd_stop"
			sound_name = "l01x_" .. sound_suffix
		elseif voice_type == "mark_cop" or voice_type == "mark_cop_quiet" then
			interact_type = "cmd_point"
			if voice_type == "mark_cop_quiet" then
				sound_name = tweak_data.character[prime_target.unit:base()._tweak_table].silent_priority_shout .. "x_any"
			else
				sound_name = tweak_data.character[prime_target.unit:base()._tweak_table].priority_shout .. "x_any"
			end
			if managers.player:has_category_upgrade("player", "special_enemy_highlight") then
				local marked_extra_damage = managers.player:has_category_upgrade("player", "marked_enemy_extra_damage") or false
				managers.game_play_central:add_enemy_contour(prime_target.unit, marked_extra_damage)
				managers.network:session():send_to_peers_synched("mark_enemy", prime_target.unit, marked_extra_damage)
				managers.challenges:set_flag("eagle_eyes")
			end
		elseif voice_type == "down" then
			interact_type = "cmd_down"
			sound_name = "f02x_" .. sound_suffix
			self._shout_down_t = t
		elseif voice_type == "down_cop" then
			interact_type = "cmd_down"
			sound_name = "l02x_" .. sound_suffix
		elseif voice_type == "cuff_cop" then
			interact_type = "cmd_down"
			sound_name = "l03x_" .. sound_suffix
		elseif voice_type == "down_stay" then
			interact_type = "cmd_down"
			if self._shout_down_t and t < self._shout_down_t + 2 then
				sound_name = "f03b_any"
			else
				sound_name = "f03a_" .. sound_suffix
			end
		elseif voice_type == "come" then
			interact_type = "cmd_come"
			local static_data = managers.criminals:character_static_data_by_unit(prime_target.unit)
			if not static_data then
				return
			end
			local character_code = static_data.ssuffix
			sound_name = "f21" .. character_code .. "_sin"
		elseif voice_type == "revive" then
			interact_type = "cmd_get_up"
			local static_data = managers.criminals:character_static_data_by_unit(prime_target.unit)
			if not static_data then
				return
			end
			local character_code = static_data.ssuffix
			sound_name = "f35x_any"
			if math.random() < self._ext_movement:rally_skill_data().revive_chance then
				prime_target.unit:interaction():interact(self._unit)
			end
			self._ext_movement:rally_skill_data().morale_boost_delay_t = managers.player:player_timer():time() + 3.5
		elseif voice_type == "boost" then
			interact_type = "cmd_gogo"
			local static_data = managers.criminals:character_static_data_by_unit(prime_target.unit)
			if not static_data then
				return
			end
			local character_code = static_data.ssuffix
			sound_name = "f36x_any"
		elseif voice_type == "escort" then
			interact_type = "cmd_point"
			sound_name = "e01x_" .. sound_suffix
		elseif voice_type == "escort_keep" then
			interact_type = "cmd_point"
			sound_name = "e05x_" .. sound_suffix
		elseif voice_type == "escort_go" then
			interact_type = "cmd_point"
			local e_guy = prime_target.unit
			local stopped_t = 0
			if t < stopped_t + 2 then
				sound_name = "e02x_" .. sound_suffix
			else
				sound_name = "e03x_" .. sound_suffix
			end
		elseif voice_type == "bridge_codeword" then
			sound_name = "bri_14"
			interact_type = "cmd_point"
		elseif voice_type == "bridge_chair" then
			sound_name = "bri_29"
			interact_type = "cmd_point"
		elseif voice_type == "undercover_interrogate" then
			sound_name = "und_18"
			interact_type = "cmd_point"
		end
		self:_do_action_intimidate(t, interact_type, sound_name, skip_alert)
	end
end
function PlayerStandard:_do_action_intimidate(t, interact_type, sound_name, skip_alert)
	if sound_name then
		self._intimidate_t = t
		self:say_line(sound_name, skip_alert)
		if interact_type then
			self:_play_distance_interact_redirect(t, interact_type)
		end
	end
end
function PlayerStandard:say_line(sound_name, skip_alert)
	self._unit:sound():say(sound_name, nil, true)
	skip_alert = skip_alert or managers.groupai:state():whisper_mode()
	if not skip_alert then
		local alert_rad = 500
		local new_alert = {
			"vo_cbt",
			self._unit:movement():m_head_pos(),
			alert_rad,
			self._unit:movement():SO_access(),
			self._unit
		}
		managers.groupai:state():propagate_alert(new_alert)
	end
end
function PlayerStandard:_play_distance_interact_redirect(t, variant)
	managers.network:session():send_to_peers("play_distance_interact_redirect", self._unit, variant)
	if self._state_data.in_steelsight then
		return
	end
	if self._shooting or not self._equipped_unit:base():start_shooting_allowed() then
		return
	end
	if self:_is_reloading() or self:_changing_weapon() or self._melee_expire_t or self._use_item_expire_t then
		return
	end
	if self._running then
		return
	end
	self._ext_camera:play_redirect(Idstring(variant))
end
function PlayerStandard:_break_intimidate_redirect(t)
	if self._shooting then
		return
	end
	self._ext_camera:play_redirect(self.IDS_IDLE)
end
function PlayerStandard:_play_interact_redirect(t)
	if self._shooting or not self._equipped_unit:base():start_shooting_allowed() then
		return
	end
	if self:_is_reloading() or self:_changing_weapon() or self._melee_expire_t then
		return
	end
	if self._running then
		return
	end
	self._ext_camera:play_redirect(self.IDS_USE)
end
function PlayerStandard:_break_interact_redirect(t)
	self._ext_camera:play_redirect(self.IDS_IDLE)
end
function PlayerStandard:_check_action_equip(t, input)
	local new_action
	local selection_wanted = input.btn_primary_choice
	if selection_wanted then
		local action_forbidden = self:chk_action_forbidden("equip")
		action_forbidden = action_forbidden or not self._ext_inventory:is_selection_available(selection_wanted) or self._melee_expire_t or self._use_item_expire_t or self:_changing_weapon() or self:_interacting()
		if not action_forbidden then
			local new_action = not self._ext_inventory:is_equipped(selection_wanted)
			if new_action then
				self:_start_action_unequip_weapon(t, {selection_wanted = selection_wanted})
			end
		end
	end
	return new_action
end
function PlayerStandard:_check_action_jump(t, input)
	local new_action
	local action_wanted = input.btn_jump_press
	if action_wanted then
		local action_forbidden = self._jump_t and t < self._jump_t + 0.55
		action_forbidden = action_forbidden or self._unit:base():stats_screen_visible() or self._state_data.in_air or self:_interacting()
		if not action_forbidden then
			if self._state_data.ducking then
				self:_interupt_action_ducking(t)
			else
				local action_start_data = {}
				local jump_vel_z = tweak_data.player.movement_state.standard.movement.jump_velocity.z
				action_start_data.jump_vel_z = jump_vel_z
				if self._move_dir then
					local is_running = self._running and self._unit:movement():is_above_stamina_threshold() and t - self._start_running_t > 0.4
					local jump_vel_xy = tweak_data.player.movement_state.standard.movement.jump_velocity.xy[is_running and "run" or "walk"]
					action_start_data.jump_vel_xy = jump_vel_xy
					if is_running then
						self._unit:movement():subtract_stamina(tweak_data.player.movement_state.stamina.JUMP_STAMINA_DRAIN)
					end
				end
				new_action = self:_start_action_jump(t, action_start_data)
			end
		end
	end
	return new_action
end
function PlayerStandard:_start_action_jump(t, action_start_data)
	self:_interupt_action_running(t)
	self._jump_t = t
	local jump_vec = action_start_data.jump_vel_z * math.UP
	self._unit:mover():jump()
	if self._move_dir then
		local move_dir_clamp = self._move_dir:normalized() * math.min(1, self._move_dir:length())
		self._last_velocity_xy = move_dir_clamp * action_start_data.jump_vel_xy
		self._jump_vel_xy = mvector3.copy(self._last_velocity_xy)
	else
		self._last_velocity_xy = Vector3()
	end
	self:_perform_jump(jump_vec)
end
function PlayerStandard:_perform_jump(jump_vec)
	self._unit:mover():set_velocity(jump_vec)
end
function PlayerStandard:_check_action_run(t, input)
	if self._setting_hold_to_run and input.btn_run_release or self._running and not self._move_dir then
		self._running_wanted = false
		if self._running then
			self:_end_action_running(t)
			if input.btn_steelsight_state and not self._state_data.in_steelsight then
				self._steelsight_wanted = true
			end
		end
	elseif not self._setting_hold_to_run and input.btn_run_release and not self._move_dir then
		self._running_wanted = false
	elseif input.btn_run_press or self._running_wanted then
		if not self._running or self._end_running_expire_t then
			self:_start_action_running(t)
		elseif self._running and not self._setting_hold_to_run then
			self:_end_action_running(t)
			if input.btn_steelsight_state and not self._state_data.in_steelsight then
				self._steelsight_wanted = true
			end
		end
	end
end
function PlayerStandard:_update_running_timers(t)
	if self._end_running_expire_t then
		if t >= self._end_running_expire_t then
			self._end_running_expire_t = nil
			self:set_running(false)
		end
	elseif self._running and (self._unit:movement():is_stamina_drained() or not self:_can_run_directional()) then
		self:_interupt_action_running(t)
	end
end
function PlayerStandard:set_running(running)
	self._running = running
	self._unit:movement():set_running(self._running)
end
function PlayerStandard:_check_action_duck(t, input)
	if self._setting_hold_to_duck and input.btn_duck_release then
		if self._state_data.ducking then
			self:_end_action_ducking(t)
		end
	elseif input.btn_duck_press and not self._unit:base():stats_screen_visible() then
		if not self._state_data.ducking then
			self:_start_action_ducking(t)
		elseif self._state_data.ducking then
			self:_end_action_ducking(t)
		end
	end
end
function PlayerStandard:_check_action_steelsight(t, input)
	local new_action
	if managers.user:get_setting("hold_to_steelsight") and input.btn_steelsight_release then
		self._steelsight_wanted = false
		if self._state_data.in_steelsight then
			self:_end_action_steelsight(t)
			new_action = true
		end
	elseif input.btn_steelsight_press or self._steelsight_wanted then
		if self._state_data.in_steelsight then
			self:_end_action_steelsight(t)
			new_action = true
		elseif not self._state_data.in_steelsight then
			self:_start_action_steelsight(t)
			new_action = true
		end
	end
	return new_action
end
function PlayerStandard:shooting()
	return self._shooting
end
function PlayerStandard:running()
	return self._running
end
function PlayerStandard:get_zoom_fov(stance_data)
	local fov = stance_data and stance_data.FOV or 75
	local fov_multiplier = managers.user:get_setting("fov_multiplier")
	if self._state_data.in_steelsight then
		fov = self._equipped_unit:base():zoom()
		fov_multiplier = 1 + (fov_multiplier - 1) / 2
	end
	return fov * fov_multiplier
end
function PlayerStandard:_check_action_primary_attack(t, input)
	local new_action
	local action_wanted = input.btn_primary_attack_state
	if action_wanted then
		local action_forbidden = self:_is_reloading() or self:_changing_weapon() or self._melee_expire_t or self._use_item_expire_t or self:_interacting()
		if not action_forbidden then
			self._queue_reload_interupt = nil
			self._ext_inventory:equip_selected_primary(false)
			if self._equipped_unit then
				local weap_base = self._equipped_unit:base()
				local fire_mode = weap_base:fire_mode()
				if weap_base:out_of_ammo() then
					if input.btn_primary_attack_press then
						weap_base:dryfire()
					end
				elseif weap_base.clip_empty and weap_base:clip_empty() then
					if fire_mode == "single" then
						if input.btn_primary_attack_press then
							self:_start_action_reload_enter(t)
						end
					else
						new_action = true
						self:_start_action_reload_enter(t)
					end
				elseif self._running then
					self:_interupt_action_running(t)
				else
					if not self._shooting then
						if weap_base:start_shooting_allowed() then
							local start = fire_mode == "single" and input.btn_primary_attack_press
							start = start or fire_mode ~= "single" and input.btn_primary_attack_state
							if start then
								weap_base:start_shooting()
								self._camera_unit:base():start_shooting()
								self._shooting = true
								if fire_mode == "auto" then
									self._unit:camera():play_redirect(self.IDS_RECOIL_ENTER)
								end
							end
						else
							return false
						end
					end
					local suppression_ratio = self._unit:character_damage():effective_suppression_ratio()
					local spread_mul = math.lerp(1, tweak_data.player.suppression.spread_mul, suppression_ratio)
					local autohit_mul = math.lerp(1, tweak_data.player.suppression.autohit_chance_mul, suppression_ratio)
					local suppression_mul = managers.player:upgrade_value("player", "suppression_multiplier", 1) * managers.player:upgrade_value("player", "suppression_multiplier2", 1) * managers.player:upgrade_value("player", "passive_suppression_multiplier", 1)
					local dmg_mul = managers.player:temporary_upgrade_value("temporary", "dmg_multiplier_outnumbered", 1)
					dmg_mul = dmg_mul * managers.player:upgrade_value("player", "passive_damage_multiplier", 1)
					local weapon_category = weap_base:weapon_tweak_data().category
					if managers.player:has_category_upgrade("player", "overkill_all_weapons") or weapon_category == "shotgun" or weapon_category == "saw" then
						dmg_mul = dmg_mul * managers.player:temporary_upgrade_value("temporary", "overkill_damage_multiplier", 1)
					end
					local health_ratio = self._ext_damage:health_ratio()
					if health_ratio <= tweak_data.upgrades.player_damage_health_ratio_threshold then
						local upgrade_name = weapon_category == "saw" and "melee_damage_health_ratio_multiplier" or "damage_health_ratio_multiplier"
						local damage_ratio = 1 - health_ratio / math.max(0.01, tweak_data.upgrades.player_damage_health_ratio_threshold)
						dmg_mul = dmg_mul * (1 + managers.player:upgrade_value("player", upgrade_name, 0) * damage_ratio)
					end
					local fired
					if fire_mode == "single" then
						if input.btn_primary_attack_press then
							fired = weap_base:trigger_pressed(self._ext_camera:position(), self._ext_camera:forward(), dmg_mul, nil, spread_mul, autohit_mul, suppression_mul)
						end
					elseif input.btn_primary_attack_state then
						fired = weap_base:trigger_held(self._ext_camera:position(), self._ext_camera:forward(), dmg_mul, nil, spread_mul, autohit_mul, suppression_mul)
					end
					new_action = true
					if fired then
						managers.rumble:play("weapon_fire")
						local weap_tweak_data = tweak_data.weapon[weap_base:get_name_id()]
						local shake_multiplier = weap_tweak_data.shake[self._state_data.in_steelsight and "fire_steelsight_multiplier" or "fire_multiplier"]
						self._ext_camera:play_shaker("fire_weapon_rot", 1 * shake_multiplier)
						self._ext_camera:play_shaker("fire_weapon_kick", 1 * shake_multiplier, 1, 0.15)
						if not self._state_data.in_steelsight or not weap_base:tweak_data_anim_play("fire_steelsight", weap_base:fire_rate_multiplier()) then
							weap_base:tweak_data_anim_play("fire", weap_base:fire_rate_multiplier())
						end
						if fire_mode == "single" then
							if not self._state_data.in_steelsight then
								self._ext_camera:play_redirect(self.IDS_RECOIL, 1)
							elseif weap_tweak_data.animations.recoil_steelsight then
								self._ext_camera:play_redirect(self.IDS_RECOIL_STEELSIGHT, 1)
							end
						end
						local recoil_multiplier = weap_base:recoil() * weap_base:recoil_multiplier()
						local up, down, left, right = unpack(weap_tweak_data.kick[self._state_data.in_steelsight and "steelsight" or self._state_data.ducking and "crouching" or "standing"])
						self._camera_unit:base():recoil_kick(up * recoil_multiplier, down * recoil_multiplier, left * recoil_multiplier, right * recoil_multiplier)
						managers.hud:set_ammo_amount(weap_base:selection_index(), weap_base:ammo_info())
						local impact = not fired.hit_enemy
						self._ext_network:send("shot_blank", impact)
					elseif fire_mode == "single" then
						new_action = false
					end
				end
			end
		elseif self:_is_reloading() and self._equipped_unit:base():reload_interuptable() and input.btn_primary_attack_press then
			self._queue_reload_interupt = true
		end
	else
	end
	if not new_action and self._shooting then
		self._equipped_unit:base():stop_shooting()
		self._camera_unit:base():stop_shooting(self._equipped_unit:base():recoil_wait())
		local weap_base = self._equipped_unit:base()
		local fire_mode = weap_base:fire_mode()
		if fire_mode == "auto" and not self:_is_reloading() then
			self._unit:camera():play_redirect(self.IDS_RECOIL_EXIT)
		end
		self._shooting = false
	end
	return new_action
end
function PlayerStandard:_start_action_reload_enter(t)
	if self._equipped_unit:base():can_reload() then
		self:_interupt_action_steelsight(t)
		self:_interupt_action_running(t)
		if self._equipped_unit:base():reload_enter_expire_t() then
			local speed_multiplier = self._equipped_unit:base():reload_speed_multiplier()
			self._ext_camera:play_redirect(Idstring("reload_enter_" .. self._equipped_unit:base().name_id), speed_multiplier)
			self._state_data.reload_enter_expire_t = t + self._equipped_unit:base():reload_enter_expire_t() / speed_multiplier
			return
		end
		self:_start_action_reload(t)
	end
end
function PlayerStandard:_start_action_reload(t)
	if self._equipped_unit:base():can_reload() then
		self._equipped_unit:base():tweak_data_anim_stop("fire")
		local speed_multiplier = self._equipped_unit:base():reload_speed_multiplier()
		local tweak_data = self._equipped_unit:base():weapon_tweak_data()
		local reload_anim = "reload"
		if self._equipped_unit:base():clip_empty() then
			local result = self._ext_camera:play_redirect(Idstring("reload_" .. self._equipped_unit:base().name_id), speed_multiplier)
			self._state_data.reload_expire_t = t + (tweak_data.timers.reload_empty or self._equipped_unit:base():reload_expire_t() or 2.6) / speed_multiplier
		else
			reload_anim = "reload_not_empty"
			local result = self._ext_camera:play_redirect(Idstring("reload_not_empty_" .. self._equipped_unit:base().name_id), speed_multiplier)
			self._state_data.reload_expire_t = t + (tweak_data.timers.reload_not_empty or self._equipped_unit:base():reload_expire_t() or 2.2) / speed_multiplier
		end
		self._equipped_unit:base():start_reload()
		if not self._equipped_unit:base():tweak_data_anim_play(reload_anim, speed_multiplier) then
			self._equipped_unit:base():tweak_data_anim_play("reload", speed_multiplier)
		end
		self._ext_network:send("reload_weapon")
	end
end
function PlayerStandard:_interupt_action_reload(t)
	if self:_is_reloading() then
		self._equipped_unit:base():tweak_data_anim_stop("reload")
		self._equipped_unit:base():tweak_data_anim_stop("reload_not_empty")
		self._equipped_unit:base():tweak_data_anim_stop("reload_exit")
	end
	self._state_data.reload_enter_expire_t = nil
	self._state_data.reload_expire_t = nil
	self._state_data.reload_exit_expire_t = nil
end
function PlayerStandard:_is_reloading()
	return self._state_data.reload_expire_t or self._state_data.reload_enter_expire_t or self._state_data.reload_exit_expire_t
end
function PlayerStandard:_get_swap_speed_multiplier()
	local multiplier = 1
	multiplier = multiplier * managers.player:upgrade_value("weapon", "swap_speed_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value("weapon", "passive_swap_speed_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value(self._equipped_unit:base():weapon_tweak_data().category, "swap_speed_multiplier", 1)
	return multiplier
end
function PlayerStandard:_start_action_unequip_weapon(t, data)
	local speed_multiplier = self:_get_swap_speed_multiplier()
	self._equipped_unit:base():tweak_data_anim_play("unequip", speed_multiplier)
	local tweak_data = self._equipped_unit:base():weapon_tweak_data()
	self._change_weapon_data = data
	self._unequip_weapon_expire_t = t + (tweak_data.timers.unequip or 0.5) / speed_multiplier
	self:_interupt_action_running(t)
	local result = self._ext_camera:play_redirect(self.IDS_UNEQUIP, speed_multiplier)
	self:_interupt_action_reload(t)
	self:_interupt_action_steelsight(t)
end
function PlayerStandard:_start_action_equip_weapon(t)
	local speed_multiplier = self:_get_swap_speed_multiplier()
	if self._change_weapon_data.next then
		self._ext_inventory:equip_next(false)
	elseif self._change_weapon_data.previous then
		self._ext_inventory:equip_previous(false)
	elseif self._change_weapon_data.selection_wanted then
		self._ext_inventory:equip_selection(self._change_weapon_data.selection_wanted, false)
	end
	local tweak_data = self._equipped_unit:base():weapon_tweak_data()
	self._equip_weapon_expire_t = t + (tweak_data.timers.equip or 0.7) / speed_multiplier
	self._ext_camera:play_redirect(self.IDS_EQUIP, speed_multiplier)
	managers.upgrades:setup_current_weapon()
end
function PlayerStandard:_changing_weapon()
	return self._unequip_weapon_expire_t or self._equip_weapon_expire_t
end
function PlayerStandard:_find_pickups(t)
	local pickups = World:find_units_quick("sphere", self._unit:movement():m_pos(), 200, self._slotmask_pickups)
	for _, pickup in ipairs(pickups) do
		if pickup:base():pickup(self._unit) then
			for id, weapon in pairs(self._unit:inventory():available_selections()) do
				managers.hud:set_ammo_amount(id, weapon.unit:base():ammo_info())
			end
		end
	end
end
function PlayerStandard:get_melee_damage_result(attack_data)
end
function PlayerStandard:get_bullet_damage_result(attack_data)
end
function PlayerStandard:push(vel)
	self._last_velocity_xy = self._last_velocity_xy + vel
	self._unit:mover():set_velocity(self._last_velocity_xy)
	self:_start_action_ducking(managers.player:player_timer():time())
end
function PlayerStandard:_get_dir_str_from_vec(fwd, dir_vec)
	local att_dir_spin = dir_vec:to_polar_with_reference(fwd, math.UP).spin
	local abs_spin = math.abs(att_dir_spin)
	if abs_spin < 45 then
		return "fwd"
	elseif abs_spin > 135 then
		return "bwd"
	elseif att_dir_spin < 0 then
		return "right"
	else
		return "left"
	end
end
function PlayerStandard:inventory_clbk_listener(unit, event)
	if event == "equip" then
		local weapon = self._ext_inventory:equipped_unit()
		if self._weapon_hold then
			self._camera_unit:anim_state_machine():set_global(self._weapon_hold, 0)
		end
		self._weapon_hold = weapon:base().weapon_hold and weapon:base():weapon_hold() or weapon:base():get_name_id()
		self._camera_unit:anim_state_machine():set_global(self._weapon_hold, 1)
		self._equipped_unit = weapon
		weapon:base():on_equip()
		managers.hud:set_weapon_selected_by_inventory_index(self._ext_inventory:equipped_selection())
		for id, weapon in pairs(self._ext_inventory:available_selections()) do
			managers.hud:set_ammo_amount(id, weapon.unit:base():ammo_info())
		end
		managers.hud:set_weapon_name(tweak_data.weapon[weapon:base():get_name_id()].name_id)
		self:_update_crosshair_offset()
		self:_stance_entered()
	end
end
function PlayerStandard:save(data)
	if self._state_data.ducking then
		data.pose = 2
	else
		data.pose = 1
	end
end
function PlayerStandard:destroy()
	if self._pos_reservation then
		managers.navigation:unreserve_pos(self._pos_reservation)
		self._pos_reservation = nil
		managers.navigation:unreserve_pos(self._pos_reservation_slow)
		self._pos_reservation_slow = nil
	end
end
function PlayerStandard:tweak_data_clbk_reload()
	self._tweak_data = tweak_data.player.movement_state.standard
end
