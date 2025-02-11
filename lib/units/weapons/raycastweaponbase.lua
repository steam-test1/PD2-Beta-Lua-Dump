local mvec3_set = mvector3.set
local mvec3_add = mvector3.add
local mvec3_dot = mvector3.dot
local mvec3_sub = mvector3.subtract
local mvec3_mul = mvector3.multiply
local mvec3_norm = mvector3.normalize
local mvec3_dir = mvector3.direction
local mvec3_set_l = mvector3.set_length
local mvec3_len = mvector3.length
local math_clamp = math.clamp
local math_lerp = math.lerp
local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()
RaycastWeaponBase = RaycastWeaponBase or class(UnitBase)
RaycastWeaponBase.TRAIL_EFFECT = Idstring("effects/particles/weapons/weapon_trail")
function RaycastWeaponBase:init(unit)
	UnitBase.init(self, unit, false)
	self._unit = unit
	self._name_id = self.name_id or "test_raycast_weapon"
	self.name_id = nil
	self._bullet_slotmask = managers.slot:get_mask("bullet_impact_targets")
	self._blank_slotmask = managers.slot:get_mask("bullet_blank_impact_targets")
	self:_create_use_setups()
	self._setup = {}
	self:replenish()
	self._aim_assist_data = tweak_data.weapon[self._name_id].aim_assist
	self._autohit_data = tweak_data.weapon[self._name_id].autohit
	self._autohit_current = self._autohit_data.INIT_RATIO
	self._next_fire_allowed = -1000
	self._obj_fire = self._unit:get_object(Idstring("fire"))
	self._muzzle_effect = Idstring(self:weapon_tweak_data().muzzleflash or "effects/particles/test/muzzleflash_maingun")
	self._muzzle_effect_table = {
		effect = self._muzzle_effect,
		parent = self._obj_fire,
		force_synch = true
	}
	self._use_shell_ejection_effect = true
	self._obj_shell_ejection = self._unit:get_object(Idstring("a_shell"))
	self._shell_ejection_effect = Idstring(self:weapon_tweak_data().shell_ejection or "effects/payday2/particles/weapons/shells/shell_556")
	self._shell_ejection_effect_table = {
		effect = self._shell_ejection_effect,
		parent = self._obj_shell_ejection
	}
	self._sound_fire = SoundDevice:create_source("fire")
	self._sound_fire:link(self._unit:orientation_object())
	self._trail_effect_table = {
		effect = self.TRAIL_EFFECT,
		position = Vector3(),
		normal = Vector3()
	}
	self._shot_fired_stats_table = {
		hit = false,
		weapon_unit = self._unit
	}
end
function RaycastWeaponBase:change_fire_object(new_obj)
	self._obj_fire = new_obj
	self._muzzle_effect_table.parent = new_obj
end
function RaycastWeaponBase:get_name_id()
	return self._name_id
end
function RaycastWeaponBase:weapon_tweak_data()
	return tweak_data.weapon[self._name_id]
end
function RaycastWeaponBase:selection_index()
	return self:weapon_tweak_data().use_data.selection_index
end
function RaycastWeaponBase:_create_use_setups()
	local sel_index = tweak_data.weapon[self._name_id].use_data.selection_index
	local use_data = {}
	self._use_data = use_data
	local player_setup = {}
	use_data.player = player_setup
	player_setup.selection_index = sel_index
	player_setup.equip = {align_place = "right_hand"}
	player_setup.unequip = {align_place = "back"}
	local npc_setup = {}
	use_data.npc = npc_setup
	npc_setup.selection_index = sel_index
	npc_setup.equip = {align_place = "right_hand"}
	npc_setup.unequip = {}
end
function RaycastWeaponBase:get_use_data(character_setup)
	return self._use_data[character_setup]
end
function RaycastWeaponBase:setup(setup_data)
	self._autoaim = setup_data.autoaim
	local stats = tweak_data.weapon[self._name_id].stats
	self._alert_events = setup_data.alert_AI and {} or nil
	self._alert_fires = {}
	local weapon_stats = tweak_data.weapon.stats
	if stats then
		self._zoom = self._zoom or weapon_stats.zoom[stats.zoom]
		self._alert_size = self._alert_size or weapon_stats.alert_size[stats.alert_size]
		self._suppression = self._suppression or weapon_stats.suppression[stats.suppression]
		self._spread = self._spread or weapon_stats.spread[stats.spread]
		self._recoil = self._recoil or weapon_stats.recoil[stats.recoil]
		self._spread_moving = self._spread_moving or weapon_stats.spread_moving[stats.spread_moving]
		self._concealment = self._concealment or weapon_stats.concealment[stats.concealment]
		self._value = self._value or weapon_stats.value[stats.value]
		for i, _ in pairs(weapon_stats) do
			local stat = self["_" .. tostring(i)]
			if not stat then
				self["_" .. tostring(i)] = weapon_stats[i][5]
				debug_pause("[RaycastWeaponBase] Weapon \"" .. tostring(self._name_id) .. "\" is missing stat \"" .. tostring(i) .. "\"!")
			end
		end
	else
		debug_pause("[RaycastWeaponBase] Weapon \"" .. tostring(self._name_id) .. "\" is missing stats block!")
		self._zoom = 60
		self._alert_size = 5000
		self._suppression = 1
		self._spread = 1
		self._recoil = 1
		self._spread_moving = 1
	end
	self._bullet_slotmask = setup_data.hit_slotmask or self._bullet_slotmask
	self._setup = setup_data
end
function RaycastWeaponBase:fire_mode()
	return tweak_data.weapon[self._name_id].auto and "auto" or "single"
end
function RaycastWeaponBase:dryfire()
	self:play_tweak_data_sound("dryfire")
end
function RaycastWeaponBase:recoil_wait()
	return self:fire_mode() == "auto" and self:weapon_tweak_data().auto.fire_rate or nil
end
function RaycastWeaponBase:_fire_sound()
	self:play_tweak_data_sound("fire")
end
function RaycastWeaponBase:start_shooting_allowed()
	return self._next_fire_allowed <= Application:time()
end
function RaycastWeaponBase:start_shooting()
	self:_fire_sound()
	self._next_fire_allowed = math.max(self._next_fire_allowed, Application:time())
	self._shooting = true
end
function RaycastWeaponBase:stop_shooting()
	self:play_tweak_data_sound("stop_fire")
	self._shooting = nil
end
function RaycastWeaponBase:trigger_pressed(...)
	local fired
	if self._next_fire_allowed <= Application:time() then
		fired = self:fire(...)
		if fired then
			local next_fire = (tweak_data.weapon[self._name_id].single and tweak_data.weapon[self._name_id].single.fire_rate or 0) / self:fire_rate_multiplier()
			self._next_fire_allowed = self._next_fire_allowed + next_fire
		end
	end
	return fired
end
function RaycastWeaponBase:trigger_held(...)
	local fired
	if self._next_fire_allowed <= Application:time() then
		fired = self:fire(...)
		if fired then
			self._next_fire_allowed = self._next_fire_allowed + tweak_data.weapon[self._name_id].auto.fire_rate / self:fire_rate_multiplier()
		end
	end
	return fired
end
function RaycastWeaponBase:fire(from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
	if not managers.player:has_activate_temporary_upgrade("temporary", "no_ammo_cost") then
		if self._ammo_remaining_in_clip == 0 then
			return
		end
		self._ammo_remaining_in_clip = self._ammo_remaining_in_clip - 1
		self._ammo_total = self._ammo_total - 1
	end
	local user_unit = self._setup.user_unit
	self:_check_ammo_total(user_unit)
	if alive(self._obj_fire) then
		World:effect_manager():spawn(self._muzzle_effect_table)
	end
	if self._use_shell_ejection_effect then
		World:effect_manager():spawn(self._shell_ejection_effect_table)
	end
	local ray_res = self:_fire_raycast(user_unit, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
	if self._alert_events and ray_res.rays then
		self:_check_alert(ray_res.rays, from_pos, direction, user_unit)
	end
	if ray_res.enemies_in_cone then
		for enemy_data, dis_error in pairs(ray_res.enemies_in_cone) do
			if not enemy_data.unit:movement():cool() then
				enemy_data.unit:character_damage():build_suppression(suppr_mul * dis_error * self._suppression)
			end
		end
	end
	return ray_res
end
function RaycastWeaponBase:_check_ammo_total(unit)
	if self._ammo_total <= 0 and unit:base().is_local_player and unit:inventory():all_out_of_ammo() then
		PlayerStandard.say_line(unit:sound(), "g81x_plu")
	end
end
local mvec_to = Vector3()
local mvec_spread_direction = Vector3()
function RaycastWeaponBase:_fire_raycast(user_unit, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul)
	local result = {}
	local hit_unit
	local spread = self:_get_spread(user_unit)
	mvector3.set(mvec_spread_direction, direction)
	if spread then
		mvector3.spread(mvec_spread_direction, spread * (spread_mul or 1))
	end
	mvector3.set(mvec_to, mvec_spread_direction)
	mvector3.multiply(mvec_to, 20000)
	mvector3.add(mvec_to, from_pos)
	local damage = self:_get_current_damage(dmg_mul)
	local col_ray = World:raycast("ray", from_pos, mvec_to, "slot_mask", self._bullet_slotmask, "ignore_unit", self._setup.ignore_units)
	local autoaim, suppression_enemies = self:check_autoaim(from_pos, direction)
	if self._autoaim then
		local weight = 0.1
		if col_ray and col_ray.unit:in_slot(managers.slot:get_mask("enemies")) then
			self._autohit_current = (self._autohit_current + weight) / (1 + weight)
			hit_unit = InstantBulletBase:on_collision(col_ray, self._unit, user_unit, damage)
		elseif autoaim then
			local autohit_chance = 1 - math.clamp((self._autohit_current - self._autohit_data.MIN_RATIO) / (self._autohit_data.MAX_RATIO - self._autohit_data.MIN_RATIO), 0, 1)
			if autohit_mul then
				autohit_chance = autohit_chance * autohit_mul
			end
			if autohit_chance > math.random() then
				self._autohit_current = (self._autohit_current + weight) / (1 + weight)
				hit_unit = InstantBulletBase:on_collision(autoaim, self._unit, user_unit, damage)
			else
				self._autohit_current = self._autohit_current / (1 + weight)
			end
		elseif col_ray then
			hit_unit = InstantBulletBase:on_collision(col_ray, self._unit, user_unit, damage)
		end
		self._shot_fired_stats_table.hit = hit_unit and true or false
		managers.statistics:shot_fired(self._shot_fired_stats_table)
	elseif col_ray then
		hit_unit = InstantBulletBase:on_collision(col_ray, self._unit, user_unit, damage)
	end
	if suppression_enemies and self._suppression then
		result.enemies_in_cone = suppression_enemies
	end
	if (col_ray and col_ray.distance > 600 or not col_ray) and alive(self._obj_fire) then
		self._obj_fire:m_position(self._trail_effect_table.position)
		mvector3.set(self._trail_effect_table.normal, mvec_spread_direction)
		local trail = World:effect_manager():spawn(self._trail_effect_table)
		if col_ray then
			World:effect_manager():set_remaining_lifetime(trail, math.clamp((col_ray.distance - 600) / 10000, 0, col_ray.distance))
		end
	end
	result.hit_enemy = hit_unit
	if self._alert_events then
		result.rays = {col_ray}
	end
	return result
end
function RaycastWeaponBase:check_autoaim(from_pos, direction, max_dist, use_aim_assist)
	local autohit = use_aim_assist and self._aim_assist_data or self._autohit_data
	local autohit_near_angle = autohit.near_angle
	local autohit_far_angle = autohit.far_angle
	local far_dis = autohit.far_dis
	local closest_error, closest_ray
	local tar_vec = tmp_vec1
	local ignore_units = self._setup.ignore_units
	local slotmask = self._bullet_slotmask
	local enemies = managers.enemy:all_enemies()
	local suppression_near_angle = 50
	local suppression_far_angle = 5
	local suppression_enemies
	for u_key, enemy_data in pairs(enemies) do
		local enemy = enemy_data.unit
		if enemy:base():lod_stage() == 1 then
			local com = enemy:movement():m_com()
			mvec3_set(tar_vec, com)
			mvec3_sub(tar_vec, from_pos)
			local tar_aim_dot = mvec3_dot(direction, tar_vec)
			if tar_aim_dot > 0 and (not max_dist or max_dist > tar_aim_dot) then
				local tar_vec_len = math_clamp(mvec3_norm(tar_vec), 1, far_dis)
				local error_dot = mvec3_dot(direction, tar_vec)
				local error_angle = math.acos(error_dot)
				local dis_lerp = math.pow(tar_aim_dot / far_dis, 0.25)
				local suppression_min_angle = math_lerp(suppression_near_angle, suppression_far_angle, dis_lerp)
				if error_angle < suppression_min_angle then
					suppression_enemies = suppression_enemies or {}
					local percent_error = error_angle / suppression_min_angle
					suppression_enemies[enemy_data] = percent_error
				end
				local autohit_min_angle = math_lerp(autohit_near_angle, autohit_far_angle, dis_lerp)
				if error_angle < autohit_min_angle then
					local percent_error = error_angle / autohit_min_angle
					if not closest_error or closest_error > percent_error then
						tar_vec_len = tar_vec_len + 100
						mvec3_mul(tar_vec, tar_vec_len)
						mvec3_add(tar_vec, from_pos)
						local vis_ray = World:raycast("ray", from_pos, tar_vec, "slot_mask", slotmask, "ignore_unit", ignore_units)
						if vis_ray and vis_ray.unit:key() == u_key and (not closest_error or closest_error > error_angle) then
							closest_error = error_angle
							closest_ray = vis_ray
						end
					end
				end
			end
		end
	end
	return closest_ray, suppression_enemies
end
local mvec_from_pos = Vector3()
function RaycastWeaponBase:_check_alert(rays, fire_pos, direction, user_unit)
	local group_ai = managers.groupai:state()
	local t = TimerManager:game():time()
	local exp_t = t + 1.5
	local mvec3_dis = mvector3.distance_sq
	local all_alerts = self._alert_events
	local alert_rad = self._alert_size / 4
	local from_pos = mvec_from_pos
	local tolerance = 250000
	mvector3.set(from_pos, direction)
	mvector3.multiply(from_pos, -alert_rad)
	mvector3.add(from_pos, fire_pos)
	for i = #all_alerts, 1, -1 do
		if t > all_alerts[i][3] then
			table.remove(all_alerts, i)
		end
	end
	if #rays > 0 then
		for _, ray in ipairs(rays) do
			local event_pos = ray.position
			for i = #all_alerts, 1, -1 do
				if tolerance > mvec3_dis(all_alerts[i][1], event_pos) and tolerance > mvec3_dis(all_alerts[i][2], from_pos) then
					event_pos = nil
					break
				end
			end
			if event_pos then
				table.insert(all_alerts, {
					event_pos,
					from_pos,
					exp_t
				})
				local new_alert = {
					"bullet",
					event_pos,
					alert_rad,
					self._setup.alert_filter,
					user_unit,
					from_pos
				}
				group_ai:propagate_alert(new_alert)
			end
		end
	end
	local fire_alerts = self._alert_fires
	local cached = false
	for i = #fire_alerts, 1, -1 do
		if t > fire_alerts[i][2] then
			table.remove(fire_alerts, i)
		elseif tolerance > mvec3_dis(fire_alerts[i][1], fire_pos) then
			cached = true
			break
		end
	end
	if not cached then
		table.insert(fire_alerts, {fire_pos, exp_t})
		local new_alert = {
			"bullet",
			fire_pos,
			self._alert_size,
			self._setup.alert_filter,
			user_unit,
			from_pos
		}
		group_ai:propagate_alert(new_alert)
	end
end
function RaycastWeaponBase:damage_player(col_ray, from_pos, direction)
	local unit = managers.player:player_unit()
	if not unit then
		return
	end
	local ray_data = {}
	ray_data.ray = direction
	ray_data.normal = -direction
	local head_pos = unit:movement():m_head_pos()
	local head_dir = tmp_vec1
	local head_dis = mvec3_dir(head_dir, from_pos, head_pos)
	local shoot_dir = tmp_vec2
	mvec3_set(shoot_dir, col_ray and col_ray.ray or direction)
	local cos_f = mvec3_dot(shoot_dir, head_dir)
	if cos_f <= 0.1 then
		return
	end
	local b = head_dis / cos_f
	if not col_ray or b < col_ray.distance then
		if col_ray and b - col_ray.distance < 60 then
			unit:character_damage():build_suppression(self._suppression)
		end
		mvec3_set_l(shoot_dir, b)
		mvec3_mul(head_dir, head_dis)
		mvec3_sub(shoot_dir, head_dir)
		local proj_len = mvec3_len(shoot_dir)
		ray_data.position = head_pos + shoot_dir
		if not col_ray and proj_len < 60 then
			unit:character_damage():build_suppression(self._suppression)
		end
		if proj_len < 30 then
			if World:raycast("ray", from_pos, head_pos, "slot_mask", self._bullet_slotmask, "ignore_unit", self._setup.ignore_units, "report") then
				return nil, ray_data
			else
				return true, ray_data
			end
		elseif proj_len < 100 and b > 500 then
			unit:character_damage():play_whizby(ray_data.position)
		end
	elseif b - col_ray.distance < 60 then
		unit:character_damage():build_suppression(self._suppression)
	end
	return nil, ray_data
end
function RaycastWeaponBase:force_hit(from_pos, direction, user_unit, impact_pos, impact_normal, hit_unit, hit_body)
	self._ammo_remaining_in_clip = math.max(0, self._ammo_remaining_in_clip - 1)
	local col_ray = {
		position = impact_pos,
		ray = direction,
		normal = impact_normal,
		unit = hit_unit,
		body = hit_body or hit_unit:body(0)
	}
	InstantBulletBase:on_collision(col_ray, self._unit, user_unit, self._damage)
end
function RaycastWeaponBase:tweak_data_anim_play(anim, ...)
	if self:weapon_tweak_data().animations[anim] then
		self:anim_play(self:weapon_tweak_data().animations[anim], ...)
		return true
	end
	return false
end
function RaycastWeaponBase:anim_play(anim, speed_multiplier)
	if anim then
		local length = self._unit:anim_length(Idstring(anim))
		speed_multiplier = speed_multiplier or 1
		self._unit:anim_stop(Idstring(anim))
		self._unit:anim_play_to(Idstring(anim), length, speed_multiplier)
	end
end
function RaycastWeaponBase:tweak_data_anim_stop(anim, ...)
	if self:weapon_tweak_data().animations[anim] then
		self:anim_stop(self:weapon_tweak_data().animations[anim], ...)
		return true
	end
	return false
end
function RaycastWeaponBase:anim_stop(anim)
	self._unit:anim_stop(Idstring(anim))
end
function RaycastWeaponBase:replenish()
	local ammo_max_multiplier = managers.player:upgrade_value("player", "extra_ammo_multiplier", 1)
	ammo_max_multiplier = ammo_max_multiplier * managers.player:upgrade_value(self:weapon_tweak_data().category, "extra_ammo_multiplier", 1)
	self._ammo_max_per_clip = self:get_ammo_max_per_clip()
	self._ammo_max = math.round((tweak_data.weapon[self._name_id].AMMO_MAX + managers.player:upgrade_value(self._name_id, "clip_amount_increase") * self._ammo_max_per_clip) * ammo_max_multiplier)
	self._ammo_total = self._ammo_max
	self._ammo_remaining_in_clip = self._ammo_max_per_clip
	self._ammo_pickup = tweak_data.weapon[self._name_id].AMMO_PICKUP
	self:update_damage()
end
function RaycastWeaponBase:upgrade_blocked(category, upgrade)
	if not self:weapon_tweak_data().upgrade_blocks then
		return false
	end
	if not self:weapon_tweak_data().upgrade_blocks[category] then
		return false
	end
	return table.contains(self:weapon_tweak_data().upgrade_blocks[category], upgrade)
end
function RaycastWeaponBase:get_ammo_max_per_clip()
	local ammo = tweak_data.weapon[self._name_id].CLIP_AMMO_MAX
	ammo = ammo + managers.player:upgrade_value(self._name_id, "clip_ammo_increase")
	if not self:upgrade_blocked("weapon", "clip_ammo_increase") then
		ammo = ammo + managers.player:upgrade_value("weapon", "clip_ammo_increase", 0)
	end
	return ammo
end
function RaycastWeaponBase:_get_current_damage(dmg_mul)
	local damage = self._damage * (dmg_mul or 1)
	damage = damage * managers.player:temporary_upgrade_value("temporary", "combat_medic_damage_multiplier", 1)
	return damage
end
function RaycastWeaponBase:update_damage()
	self._damage = tweak_data.weapon[self._name_id].DAMAGE * self:damage_multiplier()
end
function RaycastWeaponBase:recoil()
	return self._recoil
end
function RaycastWeaponBase:spread_moving()
	return self._spread_moving
end
function RaycastWeaponBase:reload_speed_multiplier()
	local multiplier = managers.player:upgrade_value(self:weapon_tweak_data().category, "reload_speed_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value("weapon", "passive_reload_speed_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value(self._name_id, "reload_speed_multiplier", 1)
	return multiplier
end
function RaycastWeaponBase:damage_multiplier()
	local multiplier = managers.player:upgrade_value(self:weapon_tweak_data().category, "damage_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value(self._name_id, "damage_multiplier", 1)
	return multiplier
end
function RaycastWeaponBase:melee_damage_multiplier()
	return managers.player:upgrade_value(self._name_id, "melee_multiplier", 1)
end
function RaycastWeaponBase:spread_multiplier()
	local multiplier = managers.player:upgrade_value(self:weapon_tweak_data().category, "spread_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value("weapon", self:fire_mode() .. "_spread_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value(self._name_id, "spread_multiplier", 1)
	return multiplier
end
function RaycastWeaponBase:exit_run_speed_multiplier()
	local multiplier = managers.player:upgrade_value(self:weapon_tweak_data().category, "exit_run_speed_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value(self._name_id, "exit_run_speed_multiplier", 1)
	return multiplier
end
function RaycastWeaponBase:recoil_multiplier()
	local category = self:weapon_tweak_data().category
	local multiplier = managers.player:upgrade_value(category, "recoil_multiplier", 1)
	if managers.player:has_team_category_upgrade(category, "recoil_multiplier") then
		multiplier = multiplier * managers.player:team_upgrade_value(category, "recoil_multiplier", 1)
	elseif managers.player:player_unit() and managers.player:player_unit():character_damage():is_suppressed() then
		multiplier = multiplier * managers.player:team_upgrade_value(category, "suppression_recoil_multiplier", 1)
	end
	multiplier = multiplier * managers.player:upgrade_value(self._name_id, "recoil_multiplier", 1)
	return multiplier
end
function RaycastWeaponBase:enter_steelsight_speed_multiplier()
	local multiplier = managers.player:upgrade_value(self:weapon_tweak_data().category, "enter_steelsight_speed_multiplier", 1)
	multiplier = multiplier * managers.player:temporary_upgrade_value("temporary", "combat_medic_enter_steelsight_speed_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value(self._name_id, "enter_steelsight_speed_multiplier", 1)
	return multiplier
end
function RaycastWeaponBase:fire_rate_multiplier()
	local multiplier = managers.player:upgrade_value(self:weapon_tweak_data().category, "fire_rate_multiplier", 1)
	multiplier = multiplier * managers.player:upgrade_value(self._name_id, "fire_rate_multiplier", 1)
	return multiplier
end
function RaycastWeaponBase:upgrade_value(value, default)
	return managers.player:upgrade_value(self._name_id, value, default)
end
function RaycastWeaponBase:transition_duration()
	return self:weapon_tweak_data().transition_duration
end
function RaycastWeaponBase:melee_damage_info()
	local my_tweak_data = self:weapon_tweak_data()
	local dmg = my_tweak_data.damage_melee * self:melee_damage_multiplier()
	local dmg_effect = dmg * my_tweak_data.damage_melee_effect_mul
	return dmg, dmg_effect
end
function RaycastWeaponBase:ammo_info()
	return self._ammo_max_per_clip, self._ammo_remaining_in_clip, self._ammo_total, self._ammo_max
end
function RaycastWeaponBase:set_ammo(ammo)
	local ammo_num = math.floor(ammo * self._ammo_max)
	self._ammo_total = ammo_num
	self._ammo_remaining_in_clip = math.min(self._ammo_max_per_clip, ammo_num)
end
function RaycastWeaponBase:ammo_full()
	return self._ammo_total == self._ammo_max
end
function RaycastWeaponBase:clip_full()
	return self._ammo_remaining_in_clip == self._ammo_max_per_clip
end
function RaycastWeaponBase:clip_empty()
	return self._ammo_remaining_in_clip == 0
end
function RaycastWeaponBase:clip_not_empty()
	return self._ammo_remaining_in_clip > 0
end
function RaycastWeaponBase:remaining_full_clips()
	return math.max(math.floor((self._ammo_total - self._ammo_remaining_in_clip) / self._ammo_max_per_clip), 0)
end
function RaycastWeaponBase:zoom()
	return self._zoom
end
function RaycastWeaponBase:reload_expire_t()
	return nil
end
function RaycastWeaponBase:reload_enter_expire_t()
	return nil
end
function RaycastWeaponBase:reload_exit_expire_t()
	return nil
end
function RaycastWeaponBase:update_reloading(t, dt, time_left)
end
function RaycastWeaponBase:start_reload()
end
function RaycastWeaponBase:reload_interuptable()
	return false
end
function RaycastWeaponBase:on_reload()
	if self._setup.expend_ammo then
		self._ammo_remaining_in_clip = math.min(self._ammo_total, self._ammo_max_per_clip)
	else
		self._ammo_remaining_in_clip = self._ammo_max_per_clip
		self._ammo_total = self._ammo_max_per_clip
	end
end
function RaycastWeaponBase:ammo_max()
	return self._ammo_max == self._ammo_total
end
function RaycastWeaponBase:out_of_ammo()
	return self._ammo_total == 0
end
function RaycastWeaponBase:can_reload()
	return self._ammo_total > self._ammo_remaining_in_clip
end
function RaycastWeaponBase:add_ammo()
	if self:ammo_max() then
		return false
	end
	local multiplier = managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1)
	local add_amount = math.max(0, math.round(math.lerp(self._ammo_pickup[1] * multiplier, self._ammo_pickup[2] * multiplier, math.random())))
	self._ammo_total = math.clamp(self._ammo_total + add_amount, 0, self._ammo_max)
	return true
end
function RaycastWeaponBase:add_ammo_from_bag(availible)
	if self:ammo_max() then
		return 0
	end
	local wanted = 1 - self._ammo_total / self._ammo_max
	local can_have = math.min(wanted, availible)
	self._ammo_total = math.min(self._ammo_max, self._ammo_total + math.ceil(can_have * self._ammo_max))
	return can_have
end
function RaycastWeaponBase:on_equip()
end
function RaycastWeaponBase:on_unequip()
end
function RaycastWeaponBase:on_enabled()
	self._enabled = true
end
function RaycastWeaponBase:on_disabled()
	self._enabled = false
end
function RaycastWeaponBase:play_tweak_data_sound(event)
	if tweak_data.weapon[self._name_id].sounds[event] then
		self:play_sound(tweak_data.weapon[self._name_id].sounds[event])
	end
end
function RaycastWeaponBase:play_sound(event)
	self._sound_fire:post_event(event)
end
function RaycastWeaponBase:destroy(unit)
	RaycastWeaponBase.super.pre_destroy(self, unit)
	if self._shooting then
		self:stop_shooting()
	end
end
function RaycastWeaponBase:_get_spread(user_unit)
	local spread_multiplier = self:spread_multiplier()
	local current_state = user_unit:movement()._current_state
	if current_state._moving then
		spread_multiplier = spread_multiplier * managers.player:upgrade_value(self:weapon_tweak_data().category, "move_spread_multiplier", 1)
	end
	if current_state:in_steelsight() then
		return self._spread * tweak_data.weapon[self._name_id].spread[current_state._moving and "moving_steelsight" or "steelsight"] * spread_multiplier
	end
	spread_multiplier = spread_multiplier * managers.player:upgrade_value(self:weapon_tweak_data().category, "hip_fire_spread_multiplier", 1)
	if current_state._state_data.ducking then
		return self._spread * tweak_data.weapon[self._name_id].spread[current_state._moving and "moving_crouching" or "crouching"] * spread_multiplier
	end
	return self._spread * tweak_data.weapon[self._name_id].spread[current_state._moving and "moving_standing" or "standing"] * spread_multiplier
end
function RaycastWeaponBase:set_visibility_state(state)
	self._unit:set_visible(state)
end
function RaycastWeaponBase:set_bullet_hit_slotmask(new_slotmask)
	self._bullet_slotmask = new_slotmask
end
function RaycastWeaponBase:flashlight_state_changed()
end
function RaycastWeaponBase:set_flashlight_enabled(enabled)
end
InstantBulletBase = InstantBulletBase or class()
function InstantBulletBase:on_collision(col_ray, weapon_unit, user_unit, damage, blank)
	local hit_unit = col_ray.unit
	if not hit_unit:character_damage() or not hit_unit:character_damage()._no_blood then
		managers.game_play_central:play_impact_flesh({col_ray = col_ray})
		self:play_impact_sound_and_effects(col_ray)
	end
	if hit_unit:damage() and col_ray.body:extension() and col_ray.body:extension().damage then
		local local_damage = not blank or hit_unit:id() == -1
		local sync_damage = not blank and hit_unit:id() ~= -1
		if local_damage then
			col_ray.body:extension().damage:damage_bullet(user_unit, col_ray.normal, col_ray.position, col_ray.direction, 1)
			col_ray.body:extension().damage:damage_damage(user_unit, col_ray.normal, col_ray.position, col_ray.direction, damage)
		end
		if sync_damage then
			if user_unit:id() == -1 then
				managers.network:session():send_to_peers_synched("sync_body_damage_bullet_no_attacker", col_ray.body, col_ray.normal, col_ray.position, col_ray.direction, math.min(100, damage))
			else
				managers.network:session():send_to_peers_synched("sync_body_damage_bullet", col_ray.body, user_unit, col_ray.normal, col_ray.position, col_ray.direction, math.min(100, damage))
			end
		end
	end
	managers.game_play_central:physics_push(col_ray)
	if hit_unit:character_damage() and hit_unit:character_damage().damage_bullet then
		return self:give_impact_damage(col_ray, weapon_unit, user_unit, damage)
	else
	end
	return nil
end
function InstantBulletBase:on_hit_player(col_ray, weapon_unit, user_unit, damage)
	col_ray.unit = managers.player:player_unit()
	return self:give_impact_damage(col_ray, weapon_unit, user_unit, damage)
end
function InstantBulletBase:play_impact_sound_and_effects(col_ray)
	managers.game_play_central:play_impact_sound_and_effects({col_ray = col_ray})
end
function InstantBulletBase:give_impact_damage(col_ray, weapon_unit, user_unit, damage)
	local action_data = {}
	action_data.variant = "bullet"
	action_data.damage = damage
	action_data.weapon_unit = weapon_unit
	action_data.attacker_unit = user_unit
	action_data.col_ray = col_ray
	local defense_data = col_ray.unit:character_damage():damage_bullet(action_data)
	return defense_data
end
