NewShotgunBase = NewShotgunBase or class(NewRaycastWeaponBase)
function NewShotgunBase:init(...)
	NewShotgunBase.super.init(self, ...)
	self._damage_near = tweak_data.weapon[self._name_id].damage_near
	self._damage_far = tweak_data.weapon[self._name_id].damage_far
	self._rays = tweak_data.weapon[self._name_id].rays or 6
	self._range = self._damage_far
end
function NewShotgunBase:_create_use_setups()
	local use_data = {}
	local player_setup = {}
	player_setup.selection_index = tweak_data.weapon[self._name_id].use_data.selection_index
	player_setup.equip = {
		align_place = tweak_data.weapon[self._name_id].use_data.align_place or "left_hand"
	}
	player_setup.unequip = {align_place = "back"}
	use_data.player = player_setup
	self._use_data = use_data
end
local mvec_to = Vector3()
local mvec_direction = Vector3()
local mvec_spread_direction = Vector3()
function NewShotgunBase:_fire_raycast(user_unit, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul)
	local result = {}
	local hit_enemies = {}
	local hit_something, col_rays
	if self._alert_events then
		col_rays = {}
	end
	local damage = self:_get_current_damage(dmg_mul)
	local autoaim, dodge_enemies = self:check_autoaim(from_pos, direction, self._range)
	local weight = 0.1
	local enemy_died = false
	local function hit_enemy(col_ray)
		if col_ray.unit:character_damage() and col_ray.unit:character_damage().is_head then
			local enemy_key = col_ray.unit:key()
			if not hit_enemies[enemy_key] or col_ray.unit:character_damage():is_head(col_ray.body) then
				hit_enemies[enemy_key] = col_ray
			end
		else
			InstantBulletBase:on_collision(col_ray, self._unit, user_unit, damage)
		end
	end
	local spread = self:_get_spread(user_unit)
	mvector3.set(mvec_direction, direction)
	if spread then
	end
	for i = 1, self._rays do
		mvector3.set(mvec_spread_direction, mvec_direction)
		if spread then
			mvector3.spread(mvec_spread_direction, spread * (spread_mul or 1))
		end
		mvector3.set(mvec_to, mvec_spread_direction)
		mvector3.multiply(mvec_to, 20000)
		mvector3.add(mvec_to, from_pos)
		local col_ray = World:raycast("ray", from_pos, mvec_to, "slot_mask", self._bullet_slotmask, "ignore_unit", self._setup.ignore_units)
		if col_rays then
			if col_ray then
				table.insert(col_rays, col_ray)
			else
				local ray_to = mvector3.copy(mvec_to)
				local spread_direction = mvector3.copy(mvec_spread_direction)
				table.insert(col_rays, {position = ray_to, ray = spread_direction})
			end
		end
		if self._autoaim and autoaim then
			if col_ray and col_ray.unit:in_slot(managers.slot:get_mask("enemies")) then
				self._autohit_current = (self._autohit_current + weight) / (1 + weight)
				hit_enemy(col_ray)
				autoaim = false
			else
				autoaim = false
				local autohit = self:check_autoaim(from_pos, direction, self._range)
				if autohit then
					local autohit_chance = 1 - math.clamp((self._autohit_current - self._autohit_data.MIN_RATIO) / (self._autohit_data.MAX_RATIO - self._autohit_data.MIN_RATIO), 0, 1)
					if autohit_chance > math.random() then
						self._autohit_current = (self._autohit_current + weight) / (1 + weight)
						hit_something = true
						hit_enemy(autohit)
					else
						self._autohit_current = self._autohit_current / (1 + weight)
					end
				elseif col_ray then
					hit_something = true
					hit_enemy(col_ray)
				end
			end
		elseif col_ray then
			hit_something = true
			hit_enemy(col_ray)
		end
	end
	for _, col_ray in pairs(hit_enemies) do
		local dist = mvector3.distance(col_ray.unit:position(), user_unit:position())
		damage = (1 - math.min(1, math.max(0, dist - self._damage_near) / self._damage_far)) * damage
		local result = InstantBulletBase:on_collision(col_ray, self._unit, user_unit, damage)
		if result and result.type == "death" and col_ray.distance < 500 then
			if col_ray.unit:movement()._active_actions[1] and col_ray.unit:movement()._active_actions[1]:type() == "hurt" then
				col_ray.unit:movement()._active_actions[1]:force_ragdoll()
			end
			local scale = math.clamp(1 - col_ray.distance / 500, 0.5, 1)
			local unit = col_ray.unit
			local height = mvector3.distance(col_ray.position, col_ray.unit:position()) - 100
			local twist_dir = math.random(2) == 1 and 1 or -1
			local rot_acc = (col_ray.ray:cross(math.UP) + math.UP * (0.5 * twist_dir)) * (-1000 * math.sign(height))
			local rot_time = 1 + math.rand(2)
			local nr_u_bodies = unit:num_bodies()
			local i_u_body = 0
			while nr_u_bodies > i_u_body do
				local u_body = unit:body(i_u_body)
				if u_body:enabled() and u_body:dynamic() then
					local body_mass = u_body:mass()
					World:play_physic_effect(Idstring("physic_effects/shotgun_hit"), u_body, Vector3(col_ray.ray.x, col_ray.ray.y, col_ray.ray.z + 0.5) * 600 * scale, 4 * body_mass / math.random(2), rot_acc, rot_time)
				end
				i_u_body = i_u_body + 1
			end
		end
	end
	if dodge_enemies and self._suppression then
		for enemy_data, dis_error in pairs(dodge_enemies) do
			enemy_data.unit:character_damage():build_suppression(suppr_mul * dis_error * self._suppression)
		end
	end
	result.hit_enemy = next(hit_enemies) and true or false
	if self._alert_events then
		result.rays = #col_rays > 0 and col_rays
	end
	managers.statistics:shot_fired({
		hit = result.hit_enemy,
		weapon_unit = self._unit
	})
	return result
end
function NewShotgunBase:reload_expire_t()
	return math.min(self._ammo_total - self._ammo_remaining_in_clip, self._ammo_max_per_clip - self._ammo_remaining_in_clip) * 17 / 30
end
function NewShotgunBase:reload_enter_expire_t()
	return 0.3
end
function NewShotgunBase:reload_exit_expire_t()
	return 1.3
end
function NewShotgunBase:reload_not_empty_exit_expire_t()
	return 1
end
function NewShotgunBase:start_reload(...)
	NewShotgunBase.super.start_reload(self, ...)
	self._started_reload_empty = self:clip_empty()
	local speed_multiplier = self:reload_speed_multiplier()
	self._next_shell_reloded_t = managers.player:player_timer():time() + 0.23666665 / speed_multiplier
end
function NewShotgunBase:started_reload_empty()
	return self._started_reload_empty
end
function NewShotgunBase:update_reloading(t, dt, time_left)
	if t > self._next_shell_reloded_t then
		local speed_multiplier = self:reload_speed_multiplier()
		self._next_shell_reloded_t = self._next_shell_reloded_t + 0.56666666 / speed_multiplier
		self._ammo_remaining_in_clip = math.min(self._ammo_max_per_clip, self._ammo_remaining_in_clip + 1)
		return true
	end
end
function NewShotgunBase:reload_interuptable()
	return true
end
SaigaShotgun = SaigaShotgun or class(NewShotgunBase)
function SaigaShotgun:reload_expire_t()
	return nil
end
function SaigaShotgun:reload_enter_expire_t()
	return nil
end
function SaigaShotgun:reload_exit_expire_t()
	return nil
end
function SaigaShotgun:reload_not_empty_exit_expire_t()
	return nil
end
function SaigaShotgun:update_reloading(t, dt, time_left)
end
