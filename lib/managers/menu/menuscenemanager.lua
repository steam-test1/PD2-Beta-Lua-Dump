local ids_unit = Idstring("unit")
MenuSceneManager = MenuSceneManager or class()
function MenuSceneManager:init()
	self._standard_fov = 50
	self._current_fov = 50
	self._camera_start_pos = Vector3()
	self._camera_start_rot = Rotation(-5, 0, 0)
	self._active_lights = {}
	self._fade_down_lights = {}
	self._character_yaw = 0
	self._character_pitch = 0
	self._item_yaw = 0
	self._item_pitch = 0
	self._item_roll = 0
	self._item_rot = Rotation()
	self._item_rot_mod = Rotation(0, 0, 0)
	self._item_rot_temp = Rotation()
	self._use_item_grab = false
	self._use_character_grab = false
	self._current_scene_template = ""
	self._global_poses = {}
	self._global_poses.generic = {
		"husk_generic1",
		"husk_generic2",
		"husk_generic3",
		"husk_generic4"
	}
	self._global_poses.assault_rifle = {
		"husk_rifle1",
		"husk_rifle2"
	}
	self._global_poses.pistol = {
		"husk_pistol1"
	}
	self._global_poses.saw = {"husk_saw1"}
	self._global_poses.shotgun = {
		"husk_shotgun1"
	}
	self._weapon_units = {}
	self:_setup_bg()
	self:_set_up_templates()
	self:_setup_gui()
	self._transition_bezier = {
		0,
		0,
		1,
		1
	}
	self._transition_time = 0
	self._weapon_transition_time = 0
	self._transition_done_callback_handler = CoreEvent.CallbackEventHandler:new()
end
function MenuSceneManager:_setup_gui()
	self._workspace = Overlay:gui():create_screen_workspace()
	managers.gui_data:layout_workspace(self._workspace)
	self._main_panel = self._workspace:panel():panel({layer = 0})
	local scaled_size = managers.gui_data:scaled_size()
	self._main_panel:set_shape(0, 0, scaled_size.width, scaled_size.height)
	self._item_grab = self._main_panel:panel({
		w = self._main_panel:w(),
		h = self._main_panel:h() - 64
	})
	self._character_grab = self._main_panel:panel({
		w = 550,
		h = self._main_panel:h() - 64
	})
end
function MenuSceneManager:_set_up_templates()
	local ref = self._bg_unit:get_object(Idstring("a_camera_reference"))
	local c_ref = self._bg_unit:get_object(Idstring("a_reference"))
	local target_pos = Vector3(0, 0, ref:position().z)
	local offset = Vector3(ref:position().x, ref:position().y, 0)
	self._scene_templates = {}
	self._scene_templates.standard = {}
	self._scene_templates.standard.use_character_grab = true
	self._scene_templates.standard.camera_pos = ref:position()
	self._scene_templates.standard.target_pos = target_pos
	self._scene_templates.standard.character_pos = c_ref:position()
	local l_pos = self._scene_templates.standard.camera_pos
	local rot = Rotation(self._scene_templates.standard.target_pos - l_pos, math.UP)
	local l1_pos = l_pos + rot:x() * -200 + rot:y() * 200
	self._scene_templates.standard.lights = {
		self:_create_light({
			far_range = 400,
			color = Vector3(0.86, 0.37, 0.21) * 4,
			position = Vector3(80, 33, 20)
		}),
		self:_create_light({
			far_range = 180,
			color = Vector3(0.3, 0.5, 0.8) * 6,
			position = Vector3(-120, -6, 32),
			specular_multiplier = 8
		}),
		self:_create_light({
			far_range = 800,
			color = Vector3(1, 1, 1) * 0.35,
			position = Vector3(160, -250, -40),
			specular_multiplier = 0
		})
	}
	self._scene_templates.blackmarket = {}
	self._scene_templates.blackmarket.fov = 20
	self._scene_templates.blackmarket.use_item_grab = true
	self._scene_templates.blackmarket.camera_pos = offset:rotate_with(Rotation(90))
	self._scene_templates.blackmarket.target_pos = Vector3(-100, -100, 0) + self._camera_start_rot:x() * 100 + self._camera_start_rot:y() * 6 + self._camera_start_rot:z() * 0
	self._scene_templates.blackmarket.lights = {}
	self._scene_templates.blackmarket_item = {}
	self._scene_templates.blackmarket_item.fov = 40
	self._scene_templates.blackmarket_item.use_item_grab = true
	self._scene_templates.blackmarket_item.camera_pos = offset:rotate_with(Rotation(45)) + Vector3(0, 0, 200)
	self._scene_templates.blackmarket_item.target_pos = target_pos + Vector3(0, 0, 200)
	self._scene_templates.blackmarket_item.character_pos = c_ref:position() + Vector3(0, 500, 0)
	local l_pos = self._scene_templates.blackmarket_item.camera_pos
	local rot = Rotation(self._scene_templates.blackmarket_item.target_pos - l_pos, math.UP)
	local l1_pos = l_pos + rot:x() * 50 + rot:y() * 50
	local l2_pos = l_pos + rot:x() * -50 + rot:y() * 100
	self._scene_templates.blackmarket_item.lights = {
		self:_create_light({
			far_range = 270,
			color = Vector3(0.86, 0.67, 0.31) * 3,
			position = Vector3(160, -130, 220),
			specular_multiplier = 155
		}),
		self:_create_light({
			far_range = 270,
			color = Vector3(0.86, 0.67, 0.41) * 2,
			position = Vector3(50, -150, 220),
			specular_multiplier = 155
		}),
		self:_create_light({
			far_range = 270,
			color = Vector3(0.86, 0.67, 0.41) * 2,
			position = Vector3(160, 0, 220),
			specular_multiplier = 155
		}),
		self:_create_light({
			far_range = 250,
			color = Vector3(0.5, 1.5, 2) * 2,
			position = Vector3(50, -100, 280),
			specular_multiplier = 55
		}),
		self:_create_light({
			far_range = 370,
			color = Vector3(1, 0.4, 0.04) * 1.5,
			position = Vector3(200, 60, 180),
			specular_multiplier = 55
		})
	}
	self._scene_templates.blackmarket_mask = {}
	self._scene_templates.blackmarket_mask.fov = 40
	self._scene_templates.blackmarket_mask.use_item_grab = true
	self._scene_templates.blackmarket_mask.camera_pos = offset:rotate_with(Rotation(45)) + Vector3(0, 0, 200)
	self._scene_templates.blackmarket_mask.target_pos = target_pos + Vector3(0, 0, 200)
	self._scene_templates.blackmarket_mask.character_pos = c_ref:position() + Vector3(0, 500, 0)
	local l_pos = self._scene_templates.blackmarket_mask.camera_pos
	local rot = Rotation(self._scene_templates.blackmarket_mask.target_pos - l_pos, math.UP)
	local l1_pos = l_pos + rot:x() * 50 + rot:y() * 50
	local l2_pos = l_pos + rot:x() * -50 + rot:y() * 100
	self._scene_templates.blackmarket_mask.lights = {
		self:_create_light({
			far_range = 250,
			color = Vector3(0.2, 0.5, 1) * 4.3,
			position = Vector3(0, -200, 280),
			specular_multiplier = 55
		}),
		self:_create_light({
			far_range = 370,
			color = Vector3(1, 0.7, 0.5) * 2.3,
			position = Vector3(200, 60, 280),
			specular_multiplier = 55
		}),
		self:_create_light({
			far_range = 270,
			color = Vector3(1, 1, 1) * 0.8,
			position = Vector3(160, -130, 220),
			specular_multiplier = 0
		})
	}
	self._scene_templates.character_customization = {}
	self._scene_templates.character_customization.use_character_grab = true
	self._scene_templates.character_customization.camera_pos = Vector3(-73.1618, -168.021, -35.0786)
	self._scene_templates.character_customization.target_pos = Vector3(-73.1618, -168.021, -35.0786) + Vector3(0.31113, 0.944697, -0.103666) * 100
	self._scene_templates.character_customization.lights = {}
	self._scene_templates.play_online = {}
	self._scene_templates.play_online.camera_pos = offset:rotate_with(Rotation(90))
	self._scene_templates.play_online.target_pos = Vector3(-206.4, 56.0677, -135.539) + Vector3(-0.418134, 0.889918, 0.182234) * 100
	self._scene_templates.play_online.lights = {}
	self._scene_templates.options = {}
	self._scene_templates.options.use_character_grab = true
	self._scene_templates.options.camera_pos = Vector3(0, 60, -60)
	self._scene_templates.options.target_pos = self._camera_start_rot:y() * 100 + self._camera_start_rot:x() * -6 + self._camera_start_rot:z() * -60
	self._scene_templates.options.lights = {}
	self._scene_templates.lobby = {}
	self._scene_templates.lobby.use_character_grab = false
	self._scene_templates.lobby.camera_pos = offset:rotate_with(Rotation(90))
	self._scene_templates.lobby.target_pos = target_pos
	self._scene_templates.lobby.character_pos = c_ref:position() + Vector3(0, 500, 0)
	self._scene_templates.lobby.fov = 40
	self._scene_templates.lobby.lights = {
		self:_create_light({
			far_range = 300,
			color = Vector3(0.86, 0.57, 0.31) * 3,
			position = Vector3(56, 100, -10)
		}),
		self:_create_light({
			far_range = 3000,
			color = Vector3(1, 2.5, 4.5) * 3,
			position = Vector3(-1000, -300, 800),
			specular_multiplier = 6
		}),
		self:_create_light({
			far_range = 800,
			color = Vector3(1, 1, 1) * 0.35,
			position = Vector3(300, 100, 0),
			specular_multiplier = 0
		})
	}
	self._scene_templates.lobby1 = {}
	self._scene_templates.lobby1.use_character_grab = false
	self._scene_templates.lobby1.camera_pos = Vector3(-90.5634, -157.226, -28.6729)
	self._scene_templates.lobby1.target_pos = Vector3(-90.5634, -157.226, -28.6729) + Vector3(-0.58315, 0.781811, 0.220697) * 100
	self._scene_templates.lobby1.fov = 30
	self._scene_templates.lobby1.lights = clone(self._scene_templates.lobby.lights)
	self._scene_templates.lobby2 = {}
	self._scene_templates.lobby2.use_character_grab = false
	self._scene_templates.lobby2.camera_pos = Vector3(-21.2779, -264.36, -56.7304)
	self._scene_templates.lobby2.target_pos = Vector3(-21.2779, -264.36, -56.7304) + Vector3(-0.633319, 0.758269, 0.154709) * 100
	self._scene_templates.lobby2.fov = 30
	self._scene_templates.lobby2.lights = clone(self._scene_templates.lobby.lights)
	self._scene_templates.lobby3 = {}
	self._scene_templates.lobby3.use_character_grab = false
	self._scene_templates.lobby3.camera_pos = Vector3(149.695, -363.069, -110.613)
	self._scene_templates.lobby3.target_pos = Vector3(149.695, -363.069, -110.613) + Vector3(-0.648856, 0.748553, 0.136579) * 100
	self._scene_templates.lobby3.fov = 30
	self._scene_templates.lobby3.lights = clone(self._scene_templates.lobby.lights)
	self._scene_templates.lobby4 = {}
	self._scene_templates.lobby4.use_character_grab = false
	self._scene_templates.lobby4.camera_pos = Vector3(210.949, -449.61, -126.709)
	self._scene_templates.lobby4.target_pos = Vector3(210.949, -449.61, -126.709) + Vector3(-0.668524, 0.734205, 0.118403) * 100
	self._scene_templates.lobby4.fov = 30
	self._scene_templates.lobby4.lights = clone(self._scene_templates.lobby.lights)
end
function MenuSceneManager:update(t, dt)
	if self._camera_values and self._transition_time then
		self._transition_time = math.min(self._transition_time + dt, 1)
		local bezier_value = math.bezier(self._transition_bezier, self._transition_time)
		if self._transition_time == 1 then
			self._transition_time = nil
			self:dispatch_transition_done()
			managers.skilltree:check_reset_message()
		end
		local camera_pos = math.lerp(self._camera_values.camera_pos_current, self._camera_values.camera_pos_target, bezier_value)
		local target_pos = math.lerp(self._camera_values.target_pos_current, self._camera_values.target_pos_target, bezier_value)
		local fov = math.lerp(self._camera_values.fov_current, self._camera_values.fov_target, bezier_value)
		self._current_fov = fov
		local speed = dt * 5
		self:_set_camera_position(camera_pos)
		self:_set_target_position(target_pos)
		if self._character_values then
			local character_pos = math.lerp(self._character_values.pos_current, self._character_values.pos_target, bezier_value)
			self._character_unit:set_position(character_pos)
		end
	end
	if self._camera_object then
		if self._new_fov ~= self._current_fov + (self._fov_mod or 0) then
			self._new_fov = self._current_fov + (self._fov_mod or 0)
			self._camera_object:set_fov(self._new_fov)
		end
	end
	if self._weapon_transition_time then
		self._weapon_transition_time = math.min(self._weapon_transition_time + dt, 1)
		local bezier_value = math.bezier(self._transition_bezier, self._weapon_transition_time)
		if self._item_offset_target then
			self._item_offset = math.lerp(self._item_offset_current, self._item_offset_target, bezier_value)
		end
	end
	if alive(self._item_unit) then
		if not self._item_grabbed then
			self._item_yaw = (self._item_yaw + 5 * dt) % 360
			self._item_pitch = math.lerp(self._item_pitch, 0, 10 * dt)
			self._item_roll = math.lerp(self._item_roll, 0, 10 * dt)
			mrotation.set_yaw_pitch_roll(self._item_rot_temp, self._item_yaw, self._item_pitch, self._item_roll)
			mrotation.set_zero(self._item_rot)
			mrotation.multiply(self._item_rot, self._camera_object:rotation())
			mrotation.multiply(self._item_rot, self._item_rot_temp)
			mrotation.multiply(self._item_rot, self._item_rot_mod)
			self._item_unit:set_rotation(self._item_rot)
			local new_pos = self._item_rot_pos + self._item_offset:rotate_with(self._item_rot)
			self._item_unit:set_position(new_pos)
			self._item_unit:set_moving(2)
		end
		if alive(self._temp_upgrade_object) then
		end
	end
	if not self._character_grabbed then
	end
	if self._fade_down_lights then
		for _, light in ipairs(self._fade_down_lights) do
			light:set_multiplier(0)
		end
	end
	if self._active_lights then
		for _, light in ipairs(self._active_lights) do
			light:set_multiplier(0.8)
		end
	end
	if alive(self._vp) then
		self._vp:feed_params()
	end
end
function MenuSceneManager:on_blackmarket_reset()
	for character_id, data in pairs(tweak_data.blackmarket.characters) do
		if Global.blackmarket_manager.characters[character_id].equipped then
			self:set_character(character_id)
		else
		end
	end
	self:_set_character_equipment()
end
function MenuSceneManager:_setup_bg()
	local yaw = 180
	self._bg_unit = World:spawn_unit(Idstring("units/menu/menu_scene/menu_cylinder"), Vector3(0, 0, 0), Rotation(yaw, 0, 0))
	World:spawn_unit(Idstring("units/menu/menu_scene/menu_cylinder_pattern"), Vector3(0, 0, 0), Rotation(yaw, 0, 0))
	World:spawn_unit(Idstring("units/menu/menu_scene/menu_smokecylinder1"), Vector3(0, 0, 0), Rotation(yaw, 0, 0))
	World:spawn_unit(Idstring("units/menu/menu_scene/menu_smokecylinder2"), Vector3(0, 0, 0), Rotation(yaw, 0, 0))
	World:spawn_unit(Idstring("units/menu/menu_scene/menu_smokecylinder3"), Vector3(0, 0, 0), Rotation(yaw, 0, 0))
	World:spawn_unit(Idstring("units/menu/menu_scene/menu_logo"), Vector3(0, 0, 0), Rotation(yaw, 0, 0))
	for character_id, data in pairs(tweak_data.blackmarket.characters) do
		if Global.blackmarket_manager.characters[character_id].equipped then
			self:set_character(character_id)
		end
	end
	self:_setup_lobby_characters()
end
function MenuSceneManager:_set_player_character_unit(unit_name)
	self._character_unit = self:_set_character_unit(unit_name, self._character_unit)
	self:_set_character_equipment()
end
function MenuSceneManager:_set_character_unit(unit_name, unit)
	if alive(unit) then
		self:_delete_character_mask(unit)
		self:_delete_character_weapon(unit, "all")
		World:delete_unit(unit)
	end
	local a = self._bg_unit:get_object(Idstring("a_reference"))
	unit = World:spawn_unit(Idstring(unit_name), a:position(), a:rotation())
	self._character_yaw = a:rotation():yaw()
	self._character_pitch = a:rotation():pitch()
	self:_set_character_unit_pose("husk_rifle1", unit)
	return unit
end
function MenuSceneManager:_set_character_unit_pose(pose, unit)
	if self._current_character_pose then
		unit:anim_state_machine():set_global(self._current_character_pose, 0)
	end
	self._current_character_pose = pose
	unit:anim_state_machine():set_global(self._current_character_pose, 1)
	unit:play_redirect(Idstring("idle_menu"))
end
function MenuSceneManager:_select_character_pose()
	if math.rand(1) < 0.25 then
		local pose = self._global_poses.generic[math.random(#self._global_poses.generic)]
		self:_set_character_unit_pose(pose, self._character_unit)
		return
	end
	local primary = managers.blackmarket:equipped_primary()
	if primary then
		local category = tweak_data.weapon[primary.weapon_id].category
		local pose
		if category == "shotgun" then
			pose = self._global_poses.shotgun[math.random(#self._global_poses.shotgun)]
		elseif category == "assault_rifle" then
			pose = self._global_poses.assault_rifle[math.random(#self._global_poses.assault_rifle)]
		elseif category == "saw" then
			pose = self._global_poses.saw[math.random(#self._global_poses.saw)]
		end
		if pose then
			self:_set_character_unit_pose(pose, self._character_unit)
			return
		end
	end
	local secondary = managers.blackmarket:equipped_secondary()
	if secondary then
		local category = tweak_data.weapon[secondary.weapon_id].category
		local pose
		if category == "pistol" then
			pose = self._global_poses.pistol[math.random(#self._global_poses.pistol)]
		end
		if pose then
			self:_set_character_unit_pose(pose, self._character_unit)
			return
		end
	end
end
function MenuSceneManager:_set_character_equipment()
	local equipped_mask = managers.blackmarket:equipped_mask()
	if equipped_mask.mask_id then
		self:set_character_mask_by_id(equipped_mask.mask_id, equipped_mask.blueprint)
	end
	for armor_id, data in pairs(tweak_data.blackmarket.armors) do
		if Global.blackmarket_manager.armors[armor_id].equipped then
			self:set_character_armor(armor_id)
		else
		end
	end
	local secondary = managers.blackmarket:equipped_secondary()
	if secondary then
		self:set_character_equipped_weapon(nil, secondary.factory_id, secondary.blueprint, "secondary")
	else
		self:_delete_character_weapon(self._character_unit, "secondary")
	end
	local primary = managers.blackmarket:equipped_primary()
	if primary then
		self:set_character_equipped_weapon(nil, primary.factory_id, primary.blueprint, "primary")
	else
		self:_delete_character_weapon(self._character_unit, "primary")
	end
end
function MenuSceneManager:_setup_lobby_characters()
	if self._lobby_characters then
		for _, unit in ipairs(self._lobby_characters) do
			self:_delete_character_mask(unit)
			World:delete_unit(unit)
		end
	end
	self._lobby_characters = {}
	self._characters_offset = Vector3(0, -200, -130)
	self._characters_rotation = {
		-89,
		-73,
		-56,
		-106,
		-89,
		-64,
		-35,
		-115
	}
	local masks = {
		"dallas",
		"dallas",
		"dallas",
		"dallas"
	}
	local mvec = Vector3()
	local math_up = math.UP
	local pos = Vector3()
	local rot = Rotation()
	for i = 1, 4 do
		mrotation.set_yaw_pitch_roll(rot, self._characters_rotation[i], 0, 0)
		mvector3.set(pos, self._characters_offset)
		mvector3.rotate_with(pos, rot)
		mvector3.set(mvec, pos)
		mvector3.negate(mvec)
		mvector3.set_z(mvec, 0)
		mrotation.set_look_at(rot, mvec, math_up)
		local unit_name = tweak_data.blackmarket.characters.locked.menu_unit
		local unit = World:spawn_unit(Idstring(unit_name), pos, rot)
		self:_init_character(unit, i)
		self:set_character_mask(tweak_data.blackmarket.masks[masks[i]].unit, unit)
		table.insert(self._lobby_characters, unit)
		self:set_lobby_character_visible(i, false, true)
	end
end
function MenuSceneManager:_init_character(unit, peer_id)
	unit:anim_state_machine():set_global("husk" .. peer_id, 1)
	unit:anim_state_machine():set_global("pistol", 1)
	local current_state_name = unit:anim_state_machine():segment_state(Idstring("base"))
	unit:play_state(current_state_name)
	unit:play_redirect(Idstring("idle_menu"))
end
function MenuSceneManager:change_lobby_character(i, character_id)
	local unit = self._lobby_characters[i]
	local unit_name = tweak_data.blackmarket.characters[character_id].menu_unit
	if not alive(unit) or Idstring(unit_name) ~= unit:name() then
		print("different unit")
		local pos = unit:position()
		local rot = unit:rotation()
		if alive(unit) then
			self:_delete_character_mask(unit)
			World:delete_unit(unit)
		end
		unit = World:spawn_unit(Idstring(unit_name), pos, rot)
		self:_init_character(unit, i)
		self._lobby_characters[i] = unit
	end
	local sequence = managers.blackmarket:character_sequence_by_character_id(character_id, i)
	unit:damage():run_sequence_simple(sequence)
end
function MenuSceneManager:test_show_all_lobby_characters()
	local mvec = Vector3()
	local math_up = math.UP
	local pos = Vector3()
	local rot = Rotation()
	self._ti = (self._ti or 0) + 1
	self._ti = (self._ti - 1) % 4 + 1
	for i = 1, 4 do
		local is_me = i == self._ti
		local unit = self._lobby_characters[i]
		if unit and alive(unit) then
			mrotation.set_yaw_pitch_roll(rot, self._characters_rotation[(is_me and 4 or 0) + i], 0, 0)
			mvector3.set(pos, self._characters_offset)
			if is_me then
				mvector3.set_y(pos, mvector3.y(pos) + 100)
				print(i)
			end
			mvector3.rotate_with(pos, rot)
			mvector3.set(mvec, pos)
			mvector3.negate(mvec)
			mvector3.set_z(mvec, 0)
			mrotation.set_look_at(rot, mvec, math_up)
			unit:set_position(pos)
			unit:set_rotation(rot)
			self:set_lobby_character_visible(i, true)
		end
	end
end
function MenuSceneManager:hide_all_lobby_characters()
	for i = 1, 4 do
		self:set_lobby_character_visible(i, false, true)
	end
end
function MenuSceneManager:set_lobby_character_visible(i, visible, no_state)
	local unit = self._lobby_characters[i]
	unit:set_visible(visible)
	local mask_unit = self._mask_units[unit:key()]
	mask_unit:set_visible(visible)
	for _, linked_unit in ipairs(mask_unit:children()) do
		linked_unit:set_visible(visible)
	end
	if not no_state then
		local i = 1
		for j, unit in ipairs(self._lobby_characters) do
			i = unit:visible() and j or i
		end
	end
	if self._current_profile_slot == i then
		managers.menu_component:close_lobby_profile_gui()
		self._current_profile_slot = 0
	end
end
function MenuSceneManager:update_menu_character_text(i)
	if managers.menu_component then
		managers.menu_component:update_contract_character(i)
	end
end
function MenuSceneManager:set_lobby_character_out_fit(i, outfit_string)
	local outfit = managers.blackmarket:unpack_outfit_from_string(outfit_string)
	print("MenuSceneManager:set_lobby_character_out_fit", i, outfit_string, inspect(outfit))
	self:change_lobby_character(i, outfit.character)
	local unit = self._lobby_characters[i]
	local mask_blueprint = managers.blackmarket:mask_blueprint_from_outfit_string(outfit_string)
	self:set_character_mask_by_id(outfit.mask.mask_id, outfit.mask.blueprint, unit, i)
	self:set_character_armor(outfit.armor, unit)
	local is_me = i == managers.network:session():local_peer():id()
	local mvec = Vector3()
	local math_up = math.UP
	local pos = Vector3()
	local rot = Rotation()
	mrotation.set_yaw_pitch_roll(rot, self._characters_rotation[(is_me and 4 or 0) + i], 0, 0)
	mvector3.set(pos, self._characters_offset)
	if is_me then
		mvector3.set_y(pos, mvector3.y(pos) + 100)
	end
	mvector3.rotate_with(pos, rot)
	mvector3.set(mvec, pos)
	mvector3.negate(mvec)
	mvector3.set_z(mvec, 0)
	mrotation.set_look_at(rot, mvec, math_up)
	unit:set_position(pos)
	unit:set_rotation(rot)
	self:set_lobby_character_visible(i, true)
	print("MenuSceneManager:set_lobby_character_out_fit done")
end
function MenuSceneManager:set_character_mask_by_id(mask_id, blueprint, unit, peer_id)
	local unit_name = managers.blackmarket:mask_unit_name_by_mask_id(mask_id, peer_id)
	local mask_unit = self:set_character_mask(unit_name, unit)
	mask_unit:base():apply_blueprint(blueprint)
end
function MenuSceneManager:set_character_mask(mask_unit_name, unit)
	self._mask_units = self._mask_units or {}
	unit = unit or self._character_unit
	local mask_align = unit:get_object(Idstring("Head"))
	local mask_unit = self:_spawn_mask(mask_unit_name, false, mask_align:position(), mask_align:rotation())
	self:_delete_character_mask(unit)
	unit:link(mask_align:name(), mask_unit, mask_unit:orientation_object():name())
	self._mask_units[unit:key()] = mask_unit
	return mask_unit
end
function MenuSceneManager:set_character_armor(armor_id, unit)
	unit = unit or self._character_unit
	local sequence = tweak_data.blackmarket.armors[armor_id].sequence
	unit:damage():run_sequence_simple(sequence)
end
function MenuSceneManager:set_character_equipped_weapon(unit, wpn_factory_id, blueprint, type)
	print("set_character_equipped_weapon", unit, wpn_factory_id, blueprint, type)
	unit = unit or self._character_unit
	local weapon_unit
	if wpn_factory_id then
		weapon_unit = self:_spawn_equip_weapon(wpn_factory_id, blueprint)
		local align_name = type == "primary" and Idstring("a_weapon_right_front") or Idstring("a_weapon_left_front")
		unit:link(align_name, weapon_unit, weapon_unit:orientation_object():name())
	end
	self:_delete_character_weapon(unit, type)
	self._weapon_units[unit:key()] = self._weapon_units[unit:key()] or {}
	self._weapon_units[unit:key()][type] = weapon_unit
	self:_select_character_pose()
end
function MenuSceneManager:_spawn_mask(mask_unit_name, as_item, pos, rot)
	print("_spawn_mask", mask_unit_name)
	local ids_unit_name = Idstring(mask_unit_name)
	managers.dyn_resource:load(ids_unit, ids_unit_name, DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	local mask_unit = World:spawn_unit(ids_unit_name, pos, rot)
	local back_name = as_item and "units/payday2/masks/msk_fps_back_straps/msk_fps_back_straps" or "units/payday2/masks/msk_backside/msk_backside"
	local backside = World:spawn_unit(Idstring(back_name), pos, rot)
	if as_item then
		backside:anim_set_time(Idstring("mask_on"), backside:anim_length(Idstring("mask_on")))
	end
	mask_unit:link(mask_unit:orientation_object():name(), backside, backside:orientation_object():name())
	return mask_unit
end
function MenuSceneManager:_delete_character_mask(owner)
	local old_mask_unit = self._mask_units[owner:key()]
	if alive(old_mask_unit) then
		for _, linked_unit in ipairs(old_mask_unit:children()) do
			linked_unit:unlink()
			World:delete_unit(linked_unit)
		end
		local name = old_mask_unit:name()
		old_mask_unit:unlink()
		World:delete_unit(old_mask_unit)
		managers.dyn_resource:unload(ids_unit, name, DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	end
	self._mask_units[owner:key()] = nil
end
function MenuSceneManager:_delete_character_weapon(owner, type)
	print("_delete_character_weapon", owner, type)
	local weapons = {}
	self._weapon_units[owner:key()] = self._weapon_units[owner:key()] or {}
	if type == "all" then
		table.insert(weapons, self._weapon_units[owner:key()].primary)
		table.insert(weapons, self._weapon_units[owner:key()].secondary)
		self._weapon_units[owner:key()] = nil
	else
		table.insert(weapons, self._weapon_units[owner:key()][type])
		self._weapon_units[owner:key()][type] = nil
	end
	for _, old_weapon_unit in ipairs(weapons) do
		print("old_weapon_unit", old_weapon_unit)
		if alive(old_weapon_unit) then
			local name = old_weapon_unit:name()
			old_weapon_unit:unlink()
			old_weapon_unit:set_slot(0)
			World:delete_unit(old_weapon_unit)
			managers.dyn_resource:unload(ids_unit, name, DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
		end
	end
end
function MenuSceneManager:set_main_character_outfit(outfit_string)
	local data = string.split(outfit_string, " ")
	self:set_character(data[managers.blackmarket:outfit_string_index("character")])
	self:set_character_mask(tweak_data.blackmarket.masks[data[managers.blackmarket:outfit_string_index("mask")]].unit)
end
function MenuSceneManager:on_set_preferred_character()
	local sequence = managers.blackmarket:character_sequence_by_character_id(managers.blackmarket:equipped_character())
	self._character_unit:damage():run_sequence_simple(sequence)
	local equipped_mask = managers.blackmarket:equipped_mask()
	if equipped_mask.mask_id then
		self:set_character_mask_by_id(equipped_mask.mask_id, equipped_mask.blueprint)
	end
end
function MenuSceneManager:set_character(character_id)
	local unit_name = tweak_data.blackmarket.characters[character_id].menu_unit
	if not alive(self._character_unit) or Idstring(unit_name) ~= self._character_unit:name() then
		self:_set_player_character_unit(unit_name, self._character_unit)
	end
	local sequence = managers.blackmarket:character_sequence_by_character_id(character_id)
	self._character_unit:damage():run_sequence_simple(sequence)
end
function MenuSceneManager:_create_light(params)
	local light = World:create_light("omni|specular")
	light:set_far_range(params.far_range or 200)
	light:set_color(params.color or Vector3())
	light:set_position(params.position or Vector3())
	light:set_enable(false)
	light:set_multiplier(0)
	light:set_specular_multiplier(params.specular_multiplier or 4)
	return light
end
function MenuSceneManager:setup_camera()
	if self._camera_values then
		return
	end
	local ref = self._bg_unit:get_object(Idstring("a_camera_reference"))
	local target_pos = Vector3(0, 0, ref:position().z)
	self._camera_values = {}
	self._camera_values.camera_pos_current = ref:position():rotate_with(Rotation(90))
	self._camera_values.camera_pos_target = self._camera_values.camera_pos_current
	self._camera_values.target_pos_current = target_pos
	self._camera_values.target_pos_target = self._camera_values.target_pos_current
	self._camera_values.fov_current = self._standard_fov
	self._camera_values.fov_target = self._camera_values.fov_current
	self._camera_object = World:create_camera()
	self._camera_object:set_near_range(3)
	self._camera_object:set_far_range(250000)
	self._camera_object:set_fov(self._standard_fov)
	self._camera_object:set_rotation(self._camera_start_rot)
	self._vp = managers.viewport:new_vp(0, 0, 1, 1, "menu_main")
	self._vp:set_width_mul_enabled()
	self._director = self._vp:director()
	self._shaker = self._director:shaker()
	self._camera_controller = self._director:make_camera(self._camera_object, Idstring("menu"))
	self._director:set_camera(self._camera_controller)
	self._director:position_as(self._camera_object)
	self._camera_controller:set_both(self._camera_object)
	self._camera_controller:set_target(self._camera_start_rot:y() * 100 + self._camera_start_rot:x() * 6)
	self:_set_camera_position(self._camera_values.camera_pos_current)
	self:_set_target_position(self._camera_values.camera_pos_target)
	self._vp:set_camera(self._camera_object)
	managers.viewport:preload_environment("environments/env_menu/env_menu")
	managers.environment_area:set_default_environment("environments/env_menu/env_menu")
	self._vp:set_environment(managers.environment_area:default_environment())
	self._vp:set_active(true)
	managers.environment_controller:set_default_color_grading("color_matrix")
	managers.environment_controller:refresh_render_settings()
	self._vp:camera():set_width_multiplier(CoreMath.width_mul(1.7777778))
	self:_set_dimensions()
	self._shaker:play("breathing", 0.2)
	self._resolution_changed_callback_id = managers.viewport:add_resolution_changed_func(callback(self, self, "_resolution_changed"))
	self._environment_modifier_id = managers.viewport:viewports()[1]:create_environment_modifier(false, function(interface)
		return self:_sky_rotation_modifier(interface)
	end, "sky_orientation")
end
function MenuSceneManager:_resolution_changed()
	self:_set_dimensions()
	managers.gui_data:layout_workspace(self._workspace)
end
function MenuSceneManager:_real_aspect_ratio()
	if SystemInfo:platform() == Idstring("WIN32") then
		return RenderSettings.aspect_ratio
	else
		local screen_res = Application:screen_resolution()
		local screen_pixel_aspect = screen_res.x / screen_res.y
		return screen_pixel_aspect
	end
end
function MenuSceneManager:_set_dimensions()
	local aspect_ratio = self:_real_aspect_ratio()
	local y = (1 - aspect_ratio / 1.7777778) / 2
	local h = aspect_ratio / 1.7777778
	self._vp._vp:set_dimensions(0, y, 1, h)
end
function MenuSceneManager:_sky_rotation_modifier()
	return 345 + math.sin(Application:time() * 30) * 10
end
function MenuSceneManager:add_transition_done_callback(callback_func)
	self._transition_done_callback_handler:add(callback_func)
end
function MenuSceneManager:remove_transition_done_callback(callback_func)
	self._transition_done_callback_handler:remove(callback_func)
end
function MenuSceneManager:_set_camera_position(pos)
	self._camera_controller:set_camera(pos)
end
function MenuSceneManager:_set_target_position(pos)
	self._camera_controller:set_target(pos)
end
function MenuSceneManager:set_scene_template(template, data, custom_name)
	if self._current_scene_template == template or self._current_scene_template == custom_name then
		return
	end
	self._fov_mod = 0
	self._camera_object:set_fov(self._current_fov + (self._fov_mod or 0))
	local template_data = data or self._scene_templates[template]
	self._current_scene_template = custom_name or template
	self._character_values = self._character_values or {}
	self._character_values.pos_current = self._character_values.pos_target or template_data.character_pos
	self._character_values.pos_target = template_data.character_pos or self._character_values.pos_current
	self._camera_values.camera_pos_current = self._camera_values.camera_pos_target
	self._camera_values.target_pos_current = self._camera_values.target_pos_target
	self._camera_values.fov_current = self._camera_values.fov_target
	if self._transition_time then
		self:dispatch_transition_done()
	end
	self._transition_time = 1
	self._camera_values.camera_pos_target = template_data.camera_pos or self._camera_values.camera_pos_current
	self._camera_values.target_pos_target = template_data.target_pos or self._camera_values.target_pos_current
	self._camera_values.fov_target = template_data.fov or self._standard_fov
	self:_release_item_grab()
	self:_release_character_grab()
	self._use_item_grab = template_data.use_item_grab
	self._use_character_grab = template_data.use_character_grab
	if template_data.upgrade_object then
		self._temp_upgrade_object = template_data.upgrade_object
		self:_set_item_offset(template_data.upgrade_object:oobb())
	elseif self._use_item_grab and alive(self._item_unit) then
		managers.menu_scene:_set_weapon_upgrades(self._current_weapon_id)
		self:_set_item_offset(self._current_item_oobb_object:oobb())
	end
	local fade_lights = {}
	for _, light in ipairs(self._fade_down_lights) do
		if light:multiplier() ~= 0 and template_data.lights and not table.contains(template_data.lights, light) then
			table.insert(fade_lights, light)
		end
	end
	for _, light in ipairs(self._active_lights) do
		table.insert(fade_lights, light)
	end
	self._fade_down_lights = fade_lights
	self._active_lights = {}
	if template_data.lights then
		for _, light in ipairs(template_data.lights) do
			light:set_enable(true)
			table.insert(self._active_lights, light)
		end
	end
end
function MenuSceneManager:dispatch_transition_done()
	self._transition_done_callback_handler:dispatch()
	self._transition_done_callback_handler:clear()
end
function MenuSceneManager:clicked_blackmarket_item()
	managers.menu_scene:set_scene_template("blackmarket_item")
end
function MenuSceneManager:clicked_masks()
	managers.menu_scene:set_scene_template(nil, {
		camera_pos = Vector3(-24.0303, 63.8565, 1.49128),
		target_pos = Vector3(-24.0303, 63.8565, 2.49128) + Vector3(0.5091, 0.852881, 0.115804) * 100,
		fov = 50,
		use_character_grab = true,
		lights = self._scene_templates.character_customization.lights
	}, "mask")
end
function MenuSceneManager:clicked_armor()
	managers.menu_scene:set_scene_template(nil, {
		camera_pos = Vector3(-44.5502, 18.1584, -40.7396),
		target_pos = Vector3(-44.5502, 18.1584, -40.7396) + Vector3(0.5091, 0.852881, 0.115804) * 100,
		fov = 50,
		use_character_grab = true,
		lights = self._scene_templates.character_customization.lights
	}, "armor")
end
function MenuSceneManager:clicked_upper_body()
	managers.menu_scene:set_scene_template(nil, {
		camera_pos = Vector3(-75.5435, -27.7427, -42.5198),
		target_pos = Vector3(-75.5435, -27.7427, -42.5198) + Vector3(0.525678, 0.845068, 0.0975835) * 100,
		fov = 50,
		use_character_grab = true,
		lights = self._scene_templates.character_customization.lights
	}, "upper_body")
end
function MenuSceneManager:clicked_lower_body()
	managers.menu_scene:set_scene_template(nil, {
		camera_pos = Vector3(-87.9057, -49.0395, -106.341),
		target_pos = Vector3(-87.9057, -49.0395, -106.341) + Vector3(0.548727, 0.83587, 0.0148322) * 100,
		fov = 50,
		use_character_grab = true,
		lights = self._scene_templates.character_customization.lights
	}, "lower_body")
end
function MenuSceneManager:clicked_customize_character_category()
	self:set_scene_template("character_customization")
end
function MenuSceneManager:clicked_weapon_upgrade_type(type)
	managers.menu_scene:_set_weapon_upgrades(self._current_weapon_id)
	local fov = 5 + math.max(100 - self._item_max_size, 0) / 10
	if type == "scopes" then
		local obj = self._item_unit:get_object(Idstring("g_sight"))
		managers.menu_scene:set_scene_template(nil, {
			camera_pos = self._scene_templates.blackmarket.camera_pos,
			target_pos = self._scene_templates.blackmarket.target_pos + Vector3(0, 5, 1),
			fov = fov,
			use_item_grab = true,
			upgrade_object = obj,
			lights = self._scene_templates.blackmarket.lights
		}, type)
	elseif type == "barrels" then
		local obj = self._item_unit:get_object(Idstring("fire"))
		managers.menu_scene:set_scene_template(nil, {
			camera_pos = self._scene_templates.blackmarket.camera_pos,
			target_pos = self._scene_templates.blackmarket.target_pos + Vector3(0, 5, 1),
			fov = fov,
			use_item_grab = true,
			upgrade_object = obj,
			lights = self._scene_templates.blackmarket.lights
		}, type)
	elseif type == "grips" then
		local obj = self._item_unit:get_object(Idstring("g_mag"))
		managers.menu_scene:set_scene_template(nil, {
			camera_pos = self._scene_templates.blackmarket.camera_pos,
			target_pos = self._scene_templates.blackmarket.target_pos + Vector3(0, 5, 1),
			fov = fov,
			use_item_grab = true,
			upgrade_object = obj,
			lights = self._scene_templates.blackmarket.lights
		}, type)
	end
end
function MenuSceneManager:remove_item()
	if alive(self._item_unit) then
		for _, linked_unit in ipairs(self._item_unit:children()) do
			if not managers.dyn_resource:has_resource(ids_unit, linked_unit:name(), DynamicResourceManager.DYN_RESOURCES_PACKAGE) then
				print("DELETE LINKED UNIT", linked_unit)
				linked_unit:unlink()
				World:delete_unit(linked_unit)
			end
		end
		if managers.dyn_resource:has_resource(ids_unit, self._item_unit:name(), DynamicResourceManager.DYN_RESOURCES_PACKAGE) then
			managers.dyn_resource:unload(ids_unit, self._item_unit:name(), DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
		end
		World:delete_unit(self._item_unit)
	end
	Application:stack_dump()
end
function MenuSceneManager:spawn_item_weapon(factory_id, blueprint)
	self:destroy_item_weapon()
	local factory_weapon = tweak_data.weapon.factory[factory_id]
	local ids_unit_name = Idstring(factory_weapon.unit)
	managers.dyn_resource:load(Idstring("unit"), ids_unit_name, DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	self._item_pos = Vector3(0, 0, 0)
	mrotation.set_zero(self._item_rot_mod)
	self._item_yaw = 0
	self._item_pitch = 0
	self._item_roll = 0
	mrotation.set_zero(self._item_rot)
	local new_unit = World:spawn_unit(ids_unit_name, self._item_pos, self._item_rot)
	new_unit:base():set_factory_data(factory_id)
	if blueprint then
		new_unit:base():assemble_from_blueprint(factory_id, blueprint, true)
	else
		new_unit:base():assemble(factory_id, true)
	end
	self._test_weapon = new_unit
	self:_set_item_unit(self._test_weapon)
	mrotation.set_yaw_pitch_roll(self._item_rot_mod, -90, 0, 0)
	return new_unit
end
function MenuSceneManager:destroy_item_weapon()
	if not alive(self._test_weapon) then
		return
	end
	local name = self._test_weapon:name()
	if managers.dyn_resource:has_resource(Idstring("unit"), name, "packages/dyn_resources") then
		self._test_weapon:set_slot(0)
		World:delete_unit(self._test_weapon)
		managers.dyn_resource:unload(Idstring("unit"), name, "packages/dyn_resources", false)
	end
end
function MenuSceneManager:_set_item_unit(unit, oobb_object, max_mod, type)
	self:remove_item()
	self._current_weapon_id = nil
	local scene_template = type == "mask" and self._scene_templates.blackmarket_mask or self._scene_templates.blackmarket_item
	self._item_pos = Vector3(0, 0, 200)
	self._item_yaw = self._item_yaw or 0
	self._item_pitch = self._item_yaw or 0
	self._item_roll = self._item_yaw or 0
	mrotation.set_yaw_pitch_roll(self._item_rot, self._item_yaw, self._item_pitch, self._item_roll)
	mrotation.multiply(self._item_rot, self._item_rot_mod)
	self._item_unit = unit
	self._item_unit:set_position(self._item_pos)
	self._item_unit:set_rotation(self._item_rot)
	self._item_unit:set_moving(2)
	local oobb = oobb_object and self._item_unit:get_object(Idstring(oobb_object)):oobb() or self._item_unit:oobb()
	self._current_item_oobb_object = oobb_object and self._item_unit:get_object(Idstring(oobb_object)) or self._item_unit
	local oobb_size = oobb:size()
	local max = math.max(oobb_size.x, oobb_size.y)
	max = math.max(max, oobb_size.z)
	print("size", oobb:size(), max)
	local offset_dir = scene_template.target_pos - scene_template.camera_pos:normalized()
	self._item_max_size = math.max(max * (max_mod or 1), 20)
	local pos = Vector3(0, self._item_pos.y, self._item_pos.z)
	pos = pos - offset_dir * (150 - self._item_max_size)
	self._item_rot_pos = pos
	self:_set_item_offset(oobb, true)
end
function MenuSceneManager:_spawn_item(unit_name, oobb_object, max_mod, type)
	self._current_weapon_id = nil
	self._item_pos = Vector3(0, 0, 0)
	mrotation.set_zero(self._item_rot_mod)
	self._item_yaw = 0
	self._item_pitch = 0
	self._item_roll = 0
	mrotation.set_zero(self._item_rot)
	local unit
	if type == "mask" then
		unit = self:_spawn_mask(unit_name, true, self._item_pos, self._item_rot)
	else
		unit = World:spawn_unit(Idstring(unit_name), self._item_pos, self._item_rot)
	end
	self:_set_item_unit(unit, oobb_object, max_mod, type)
end
function MenuSceneManager:_set_weapon_upgrades(weapon_id)
	if not weapon_id or not tweak_data.upgrades.visual.upgrade[weapon_id] then
		return
	end
	for obj, visible in pairs(tweak_data.upgrades.visual.upgrade[weapon_id].objs) do
		local object = self._item_unit:get_object(Idstring(obj))
		if object then
			object:set_visibility(visible)
		end
	end
	local weapon_upgrades = Global.blackmarket_manager.weapon_upgrades[weapon_id]
	if not weapon_upgrades then
		return
	end
	for name, upgrade_data in pairs(weapon_upgrades) do
		if upgrade_data.attached then
			local visual_upgrade = tweak_data.weapon_upgrades.upgrades[name].visual_upgrade
			local vis_upgrade = tweak_data.upgrades.visual.upgrade[visual_upgrade]
			local objs = vis_upgrade and vis_upgrade.objs
			if objs then
				for obj, visible in pairs(objs) do
					self._item_unit:get_object(Idstring(obj)):set_visibility(visible)
				end
			end
		end
	end
end
function MenuSceneManager:_set_item_offset(oobb, instant)
	local center = oobb:center()
	local offset = self._item_unit:orientation_object():position() - center:rotate_with(self._item_rot:inverse())
	print("offset", offset)
	self._weapon_transition_time = self._weapon_transition_time and (self._weapon_transition_time == 1 and 0 or 1 - self._weapon_transition_time) or 0
	if instant then
		self._weapon_transition_time = 1
	end
	self._item_offset_current = self._item_offset_target or offset
	self._item_offset_target = offset
	self._item_offset = self._item_offset or offset
end
function MenuSceneManager:view_weapon_upgrade(weapon_id, visual_upgrade)
	local vis_upgrade = tweak_data.upgrades.visual.upgrade[visual_upgrade]
	local objs = vis_upgrade and vis_upgrade.objs
	if objs then
		for obj, visible in pairs(objs) do
			self._item_unit:get_object(Idstring(obj)):set_visibility(visible)
		end
	end
end
function MenuSceneManager:spawn_mask(mask_id, blueprint)
	self:remove_item()
	if not mask_id then
		return
	end
	local mask_unit_name = managers.blackmarket:mask_unit_name_by_mask_id(mask_id)
	self:_spawn_item(mask_unit_name, nil, nil, "mask")
	if blueprint then
		self._item_unit:base():apply_blueprint(blueprint)
	end
	mrotation.set_yaw_pitch_roll(self._item_rot_mod, 0, 90, 0)
end
function MenuSceneManager:spawn_or_update_mask(mask_id, blueprint)
	if alive(self._item_unit) then
		self:update_mask(blueprint)
	else
		self:spawn_mask(mask_id, blueprint)
	end
end
function MenuSceneManager:update_mask(blueprint)
	if alive(self._item_unit) and blueprint then
		self._item_unit:base():apply_blueprint(blueprint)
	end
end
function MenuSceneManager:spawn_armor(armor_id)
	self:remove_item()
	if not armor_id then
		return
	end
	self:_spawn_item("units/menu/menu_character/menu_character_test", nil)
end
function MenuSceneManager:character_screen_position(peer_id)
	local unit = self._lobby_characters[peer_id]
	if unit and alive(unit) then
		local is_me = peer_id == managers.network:session():local_peer():id()
		local peer_3_x_offset = 0
		if peer_id == 3 then
			peer_3_x_offset = is_me and -20 or -40
		end
		local spine_pos = unit:get_object(Idstring("Spine")):position() + Vector3(peer_3_x_offset, 0, 5 * (peer_id % 4))
		return self._workspace:world_to_screen(self._camera_object, spine_pos)
	end
end
function MenuSceneManager:_release_item_grab()
	self._item_grabbed = false
end
function MenuSceneManager:_release_character_grab()
	self._character_grabbed = false
end
function MenuSceneManager:controller_move(x, y)
	if alive(self._item_unit) then
		local diff = -y * 90
		self._item_yaw = (self._item_yaw + x * 75) % 360
		local yaw_sin = math.sin(self._item_yaw)
		local yaw_cos = math.cos(self._item_yaw)
		local treshhold = math.sin(45)
		if yaw_cos > -treshhold and yaw_cos < treshhold then
		else
			self._item_pitch = math.clamp(self._item_pitch + diff * yaw_cos, -30, 30)
		end
		if yaw_sin > -treshhold and yaw_sin < treshhold then
		else
			self._item_roll = math.clamp(self._item_roll - diff * yaw_sin, -30, 30)
		end
		mrotation.set_yaw_pitch_roll(self._item_rot_temp, self._item_yaw, self._item_pitch, self._item_roll)
		mrotation.set_zero(self._item_rot)
		mrotation.multiply(self._item_rot, self._camera_object:rotation())
		mrotation.multiply(self._item_rot, self._item_rot_temp)
		mrotation.multiply(self._item_rot, self._item_rot_mod)
		self._item_unit:set_rotation(self._item_rot)
		local new_pos = self._item_rot_pos + self._item_offset:rotate_with(self._item_rot)
		self._item_unit:set_position(new_pos)
		self._item_unit:set_moving(2)
	end
	self._item_grabbed = true
end
function MenuSceneManager:stop_controller_move()
	self._item_grabbed = false
end
function MenuSceneManager:controller_zoom(zoom)
	self:change_fov("out", zoom * 20)
end
function MenuSceneManager:stop_controller_zoom()
end
function MenuSceneManager:change_fov(zoom, amount)
	if self._current_scene_template == "blackmarket_item" or self._current_scene_template == "blackmarket_mask" then
		if zoom == "in" then
			self._fov_mod = math.clamp((self._fov_mod or 0) + (amount or 0.45), -20, 1)
		elseif zoom == "out" then
			self._fov_mod = math.clamp((self._fov_mod or 0) - (amount or 0.45), -20, 1)
		end
	end
end
function MenuSceneManager:mouse_pressed(o, button, x, y)
	if managers.menu_component:input_focus() then
		return
	end
	if button == Idstring("mouse wheel down") then
		self:change_fov("in")
	elseif button == Idstring("mouse wheel up") then
		self:change_fov("out")
	end
	if button == Idstring("0") then
		local pos = self._workspace:screen_to_world(self._camera_object, Vector3(x, y, 0))
		local to = self._workspace:screen_to_world(self._camera_object, Vector3(x, y, 1000))
		local data = World:raycast("ray", pos, to, "slot_mask", 16)
		if data and data.unit then
			local slot
			for i, unit in ipairs(self._lobby_characters) do
				if unit == data.unit and unit:visible() then
					slot = i
				end
			end
			if slot then
				if self._current_profile_slot == slot then
					managers.menu_component:close_lobby_profile_gui()
					self._current_profile_slot = 0
				else
					local pos = data.unit:get_object(Idstring("Spine")):position()
					pos = self._workspace:world_to_screen(self._camera_object, pos)
					self._current_profile_slot = slot
				end
			end
		end
		if self._use_character_grab and self._character_grab:inside(x, y) then
			self._character_grabbed = true
			self._character_grabbed_current_x = x
			self._character_grabbed_current_y = y
			return true
		end
	end
	if not self._use_item_grab then
		return
	end
	if button == Idstring("0") and self._item_grab:inside(x, y) then
		self._item_grabbed = true
		self._item_grabbed_current_x = x
		self._item_grabbed_current_y = y
		return false
	end
end
function MenuSceneManager:mouse_released(o, button, x, y)
	if button == Idstring("0") then
		self:_release_item_grab()
		self:_release_character_grab()
	end
end
function MenuSceneManager:mouse_moved(o, x, y)
	if self._character_grabbed then
		self._character_yaw = self._character_yaw + (x - self._character_grabbed_current_x) / 4
		self._character_unit:set_rotation(Rotation(self._character_yaw, self._character_pitch))
		self._character_grabbed_current_x = x
		self._character_grabbed_current_y = y
		return true, "grab"
	end
	if self._item_grabbed then
		if alive(self._item_unit) then
			local diff = (y - self._item_grabbed_current_y) / 4
			self._item_yaw = (self._item_yaw + (x - self._item_grabbed_current_x) / 4) % 360
			local yaw_sin = math.sin(self._item_yaw)
			local yaw_cos = math.cos(self._item_yaw)
			local treshhold = math.sin(45)
			if yaw_cos > -treshhold and yaw_cos < treshhold then
			else
				self._item_pitch = math.clamp(self._item_pitch + diff * yaw_cos, -30, 30)
			end
			if yaw_sin > -treshhold and yaw_sin < treshhold then
			else
				self._item_roll = math.clamp(self._item_roll - diff * yaw_sin, -30, 30)
			end
			mrotation.set_yaw_pitch_roll(self._item_rot_temp, self._item_yaw, self._item_pitch, self._item_roll)
			mrotation.set_zero(self._item_rot)
			mrotation.multiply(self._item_rot, self._camera_object:rotation())
			mrotation.multiply(self._item_rot, self._item_rot_temp)
			mrotation.multiply(self._item_rot, self._item_rot_mod)
			self._item_unit:set_rotation(self._item_rot)
			local new_pos = self._item_rot_pos + self._item_offset:rotate_with(self._item_rot)
			self._item_unit:set_position(new_pos)
			self._item_unit:set_moving(2)
		end
		self._item_grabbed_current_x = x
		self._item_grabbed_current_y = y
		return true, "grab"
	end
	if self._use_item_grab and self._item_grab:inside(x, y) then
		return false, "hand"
	end
	if self._use_character_grab and self._character_grab:inside(x, y) then
		return false, "hand"
	end
end
function MenuSceneManager:pre_unload()
	self._mask_names = {}
	for _, mask_unit in pairs(self._mask_units) do
		table.insert(self._mask_names, mask_unit:name())
	end
	self._weapon_names = {}
	for _, weapon_units in pairs(self._weapon_units) do
		for _, weapon_unit in pairs(weapon_units) do
			table.insert(self._weapon_names, weapon_unit:name())
			World:delete_unit(weapon_unit)
		end
	end
end
function MenuSceneManager:unload()
	print("MenuSceneManager:destroy()")
	for _, mask_name in ipairs(self._mask_names) do
		managers.dyn_resource:unload(ids_unit, mask_name, DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	end
	for _, weapon_name in ipairs(self._weapon_names) do
		managers.dyn_resource:unload(ids_unit, weapon_name, DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	end
end
function MenuSceneManager:set_server_loading()
end
function MenuSceneManager:set_lobby_character_stance(i, stance)
	local unit = self._lobby_characters[i]
	unit:play_redirect(Idstring(stance))
end
function MenuSceneManager:_spawn_equip_weapon(factory_id, blueprint)
	local factory_weapon = tweak_data.weapon.factory[factory_id]
	local ids_unit_name = Idstring(factory_weapon.unit)
	managers.dyn_resource:load(Idstring("unit"), ids_unit_name, DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	self._item_pos = Vector3(0, 0, 0)
	mrotation.set_zero(self._item_rot_mod)
	self._item_yaw = 0
	self._item_pitch = 0
	self._item_roll = 0
	mrotation.set_zero(self._item_rot)
	local new_unit = World:spawn_unit(ids_unit_name, self._item_pos, self._item_rot)
	new_unit:base():set_npc(true)
	new_unit:base():set_factory_data(factory_id)
	if blueprint then
		new_unit:base():assemble_from_blueprint(factory_id, blueprint)
	else
		new_unit:base():assemble(factory_id)
	end
	return new_unit
end
