CriminalsManager = CriminalsManager or class()
CriminalsManager.MAX_NR_TEAM_AI = 2
function CriminalsManager:init()
	self._characters = {
		{
			taken = false,
			name = "american",
			unit = nil,
			peer_id = 0,
			static_data = {
				ai_character_id = "ai_hoxton",
				ssuffix = "d",
				color_id = 1,
				voice = "rb2",
				ai_mask_id = "hoxton",
				mask_id = 1
			},
			data = {}
		},
		{
			taken = false,
			name = "german",
			unit = nil,
			peer_id = 0,
			static_data = {
				ai_character_id = "ai_wolf",
				ssuffix = "c",
				color_id = 2,
				voice = "rb3",
				ai_mask_id = "wolf",
				mask_id = 2
			},
			data = {}
		},
		{
			taken = false,
			name = "russian",
			unit = nil,
			peer_id = 0,
			static_data = {
				ai_character_id = "ai_dallas",
				ssuffix = "a",
				color_id = 3,
				voice = "rb4",
				ai_mask_id = "dallas",
				mask_id = 3
			},
			data = {}
		},
		{
			taken = false,
			name = "spanish",
			unit = nil,
			peer_id = 0,
			static_data = {
				ai_character_id = "ai_chains",
				ssuffix = "b",
				color_id = 4,
				voice = "rb1",
				ai_mask_id = "chains",
				mask_id = 4
			},
			data = {}
		}
	}
end
function CriminalsManager.convert_old_to_new_character_workname(workname)
	local t = {
		american = "hoxton",
		german = "wolf",
		russian = "dallas",
		spanish = "chains"
	}
	return t[workname]
end
function CriminalsManager.character_names()
	return {
		"russian",
		"german",
		"spanish",
		"american"
	}
end
function CriminalsManager.character_workname_by_peer_id(peer_id)
	local t = {
		"russian",
		"german",
		"spanish",
		"american"
	}
	return t[peer_id]
end
function CriminalsManager:on_simulation_ended()
	for id, data in pairs(self._characters) do
		self:_remove(id)
	end
end
function CriminalsManager:local_character_name()
	return self._local_character
end
function CriminalsManager:characters()
	return self._characters
end
function CriminalsManager:get_any_unit()
	for id, data in pairs(self._characters) do
		if data.taken and alive(data.unit) and data.unit:id() ~= -1 then
			return data.unit
		end
	end
end
function CriminalsManager:_remove(id)
	local data = self._characters[id]
	print("[CriminalsManager:_remove]", inspect(data))
	if data.name == self._local_character then
		self._local_character = nil
	end
	if data.unit then
		managers.hud:remove_mugshot_by_character_name(data.name)
	else
		managers.hud:remove_teammate_panel_by_name_id(data.name)
	end
	data.taken = false
	data.unit = nil
	data.peer_id = 0
	data.data = {}
end
function CriminalsManager:add_character(name, unit, peer_id, ai)
	print("[CriminalsManager:add_character]", name, unit, peer_id, ai)
	Application:stack_dump()
	if unit then
		unit:base()._tweak_table = name
	end
	for id, data in pairs(self._characters) do
		if data.name == name then
			if data.taken then
				Application:error("[CriminalsManager:set_character] Error: Trying to take a unit slot that has already been taken!")
				Application:stack_dump()
				Application:error("[CriminalsManager:set_character] -----")
				self:_remove(id)
			end
			data.taken = true
			data.unit = unit
			data.peer_id = peer_id
			data.data.ai = ai or false
			data.data.mask_obj = tweak_data.blackmarket.masks[data.static_data.ai_mask_id].unit
			data.data.mask_id = nil
			data.data.mask_blueprint = nil
			if not ai and unit then
				local mask_id = managers.network:session():peer(peer_id):mask_id()
				data.data.mask_obj = managers.blackmarket:mask_unit_name_by_mask_id(mask_id, peer_id)
				data.data.mask_id = mask_id
				data.data.mask_blueprint = managers.network:session():peer(peer_id):mask_blueprint()
			end
			managers.hud:remove_mugshot_by_character_name(name)
			if unit then
				data.data.mugshot_id = managers.hud:add_mugshot_by_unit(unit)
				if unit:base().is_local_player then
					self._local_character = name
					managers.hud:reset_player_hpbar()
				end
				unit:sound():set_voice(data.static_data.voice)
				unit:inventory():set_mask_visibility(unit:inventory()._mask_visibility)
			else
				if not ai or not managers.localization:text("menu_" .. name) then
				end
				data.data.mugshot_id = managers.hud:add_mugshot_without_unit(name, ai, peer_id, (managers.network:session():peer(peer_id):name()))
			end
		else
		end
	end
end
function CriminalsManager:set_unit(name, unit)
	print("[CriminalsManager:set_unit] name", name, "unit", unit)
	Application:stack_dump()
	unit:base()._tweak_table = name
	for id, data in pairs(self._characters) do
		if data.name == name then
			if not data.taken then
				Application:error("[CriminalsManager:set_character] Error: Trying to set a unit on a slot that has not been taken!")
				Application:stack_dump()
				return
			end
			data.unit = unit
			managers.hud:remove_mugshot_by_character_name(data.name)
			data.data.mugshot_id = managers.hud:add_mugshot_by_unit(unit)
			data.data.mask_obj = tweak_data.blackmarket.masks[data.static_data.ai_mask_id].unit
			data.data.mask_id = nil
			data.data.mask_blueprint = nil
			if not data.data.ai then
				local mask_id = managers.network:session():peer(data.peer_id):mask_id()
				data.data.mask_obj = managers.blackmarket:mask_unit_name_by_mask_id(mask_id, data.peer_id)
				data.data.mask_id = mask_id
				data.data.mask_blueprint = managers.network:session():peer(data.peer_id):mask_blueprint()
			end
			if unit:base().is_local_player then
				self._local_character = name
				managers.hud:reset_player_hpbar()
			end
			unit:sound():set_voice(data.static_data.voice)
		else
		end
	end
end
function CriminalsManager:is_taken(name)
	for _, data in pairs(self._characters) do
		if name == data.name then
			return data.taken
		end
	end
	return false
end
function CriminalsManager:character_name_by_peer_id(peer_id)
	for _, data in pairs(self._characters) do
		if data.taken and peer_id == data.peer_id then
			return data.name
		end
	end
end
function CriminalsManager:character_color_id_by_peer_id(peer_id)
	local workname = self.character_workname_by_peer_id(peer_id)
	return self:character_color_id_by_name(workname)
end
function CriminalsManager:character_color_id_by_unit(unit)
	local search_key = unit:key()
	for id, data in pairs(self._characters) do
		if data.unit and data.taken and search_key == data.unit:key() then
			if data.data.ai then
				return 5
			end
			return data.peer_id
		end
	end
end
function CriminalsManager:character_color_id_by_name(name)
	for id, data in pairs(self._characters) do
		if name == data.name then
			return data.static_data.color_id
		end
	end
end
function CriminalsManager:character_data_by_name(name)
	for _, data in pairs(self._characters) do
		if data.taken and name == data.name then
			return data.data
		end
	end
end
function CriminalsManager:character_data_by_peer_id(peer_id)
	for _, data in pairs(self._characters) do
		if data.taken and peer_id == data.peer_id then
			return data.data
		end
	end
end
function CriminalsManager:character_data_by_unit(unit)
	local search_key = unit:key()
	for id, data in pairs(self._characters) do
		if data.unit and data.taken and search_key == data.unit:key() then
			return data.data
		end
	end
end
function CriminalsManager:character_static_data_by_name(name)
	for _, data in pairs(self._characters) do
		if name == data.name then
			return data.static_data
		end
	end
end
function CriminalsManager:character_unit_by_name(name)
	for _, data in pairs(self._characters) do
		if data.taken and name == data.name then
			return data.unit
		end
	end
end
function CriminalsManager:character_taken_by_name(name)
	for _, data in pairs(self._characters) do
		if name == data.name then
			return data.taken
		end
	end
end
function CriminalsManager:character_peer_id_by_name(name)
	for _, data in pairs(self._characters) do
		if data.taken and name == data.name then
			return data.peer_id
		end
	end
end
function CriminalsManager:get_free_character_name()
	local available = {}
	for id, data in pairs(self._characters) do
		local taken = data.taken
		if not taken then
			for _, member in pairs(managers.network:game():all_members()) do
				if member._assigned_name == data.name then
					taken = true
				else
				end
			end
		end
		if not taken then
			table.insert(available, data.name)
		end
	end
	if #available > 0 then
		return available[math.random(#available)]
	end
end
function CriminalsManager:get_num_player_criminals()
	local num = 0
	for id, data in pairs(self._characters) do
		if data.taken and not data.data.ai then
			num = num + 1
		end
	end
	return num
end
function CriminalsManager:remove_character_by_unit(unit)
	if type_name(unit) ~= "Unit" then
		return
	end
	local rem_u_key = unit:key()
	for id, data in pairs(self._characters) do
		if data.unit and data.taken and rem_u_key == data.unit:key() then
			self:_remove(id)
			return
		end
	end
end
function CriminalsManager:remove_character_by_peer_id(peer_id)
	for id, data in pairs(self._characters) do
		if data.taken and peer_id == data.peer_id then
			self:_remove(id)
			return
		end
	end
end
function CriminalsManager:remove_character_by_name(name)
	for id, data in pairs(self._characters) do
		if data.taken and name == data.name then
			self:_remove(id)
			return
		end
	end
end
function CriminalsManager:character_name_by_unit(unit)
	if type_name(unit) ~= "Unit" then
		return nil
	end
	local search_key = unit:key()
	for id, data in pairs(self._characters) do
		if data.unit and data.taken and search_key == data.unit:key() then
			return data.name
		end
	end
end
function CriminalsManager:character_name_by_panel_id(panel_id)
	for id, data in pairs(self._characters) do
		if data.taken and data.data.panel_id == panel_id then
			return data.name
		end
	end
end
function CriminalsManager:character_static_data_by_unit(unit)
	if type_name(unit) ~= "Unit" then
		return nil
	end
	local search_key = unit:key()
	for id, data in pairs(self._characters) do
		if data.unit and data.taken and search_key == data.unit:key() then
			return data.static_data
		end
	end
end
function CriminalsManager:nr_AI_criminals()
	local nr_AI_criminals = 0
	for i, char_data in pairs(self._characters) do
		if char_data.data.ai then
			nr_AI_criminals = nr_AI_criminals + 1
		end
	end
	return nr_AI_criminals
end
