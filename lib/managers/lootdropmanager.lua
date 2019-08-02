LootDropManager = LootDropManager or class()
function LootDropManager:init()
	self:_setup()
end
function LootDropManager:_setup()
	if not Global.lootdrop_manager then
		Global.lootdrop_manager = {}
		self:_setup_items()
	end
	self._global = Global.lootdrop_manager
end
function LootDropManager:_setup_items()
	local pc_items = {}
	Global.lootdrop_manager.pc_items = pc_items
	local function sort_pc(type, data)
		for id, item_data in pairs(data) do
			if item_data.pc then
				pc_items[item_data.pc] = pc_items[item_data.pc] or {}
				pc_items[item_data.pc][type] = pc_items[item_data.pc][type] or {}
				table.insert(pc_items[item_data.pc][type], id)
			end
			if item_data.pcs then
				for _, pc in ipairs(item_data.pcs) do
					pc_items[pc] = pc_items[pc] or {}
					pc_items[pc][type] = pc_items[pc][type] or {}
					table.insert(pc_items[pc][type], id)
				end
			end
		end
	end
	for type, data in pairs(tweak_data.blackmarket) do
		sort_pc(type, data)
	end
end
function LootDropManager:debug_drop(amount, add_to_inventory, stars)
	amount = amount or 10
	add_to_inventory = add_to_inventory or false
	local debug_infamous = 0
	local debug_max_pc = 0
	if stars == "random" then
	else
		stars = stars or 5
	end
	self._debug_drop_result = {}
	for i = 1, amount do
		local s = stars == "random" and math.random(10) or stars
		local global_value, category, id, pc = self:_make_drop(true, add_to_inventory, s)
		self._debug_drop_result[global_value] = self._debug_drop_result[global_value] or {}
		self._debug_drop_result[global_value][category] = self._debug_drop_result[global_value][category] or {}
		self._debug_drop_result[global_value][category][id] = (self._debug_drop_result[global_value][category][id] or 0) + 1
		if global_value == "infamous" then
			debug_infamous = debug_infamous + 1
		end
		if pc == tweak_data.lootdrop.STARS[s].pcs[1] then
			debug_max_pc = debug_max_pc + 1
		end
	end
	if stars ~= "random" then
		Application:debug(debug_max_pc .. " dropped at PC " .. stars, "infamous items dropped: " .. debug_infamous)
	end
end
function LootDropManager:make_drop(return_data)
	if type(return_data) ~= "table" or not return_data then
		return_data = {}
	end
	self:_make_drop(false, true, nil, return_data)
end
function LootDropManager:_make_drop(debug, add_to_inventory, debug_stars, return_data)
	local human_players = managers.network:game() and managers.network:game():amount_of_alive_players() or 1
	local all_humans = human_players == 4
	local plvl = managers.experience:current_level()
	local stars = debug_stars or managers.job:current_job_stars()
	return_data = return_data or {}
	return_data.job_stars = stars
	return_data.player_level = plvl
	local difficulty = Global.game_settings.difficulty or "easy"
	local difficulty_id = math.max(0, (tweak_data:difficulty_to_index(difficulty) or 0) - 2)
	stars = stars + difficulty_id
	local player_stars = math.max(math.ceil(plvl / 10), 1)
	difficulty_id = math.min(difficulty_id, stars - return_data.job_stars)
	if all_humans then
	end
	if not debug then
		print("Total stars", stars)
	end
	stars = player_stars
	return_data.player_stars = player_stars
	return_data.difficulty_stars = difficulty_id
	return_data.total_stars = stars
	local pc = math.lerp(0, 100, stars / 10)
	return_data.payclass = pc
	if not debug then
		print("Pay class", pc)
	end
	local pcs = tweak_data.lootdrop.STARS[stars].pcs
	if math.rand(1) <= tweak_data.lootdrop.joker_chance then
		pcs = deep_clone(pcs)
		for i = 1, #pcs do
			local new_value = pcs[i] + math.random(5) * 10 - 30
			if new_value >= 5 and new_value <= 100 then
				pcs[i] = new_value
			end
		end
		return_data.joker = true
		if not debug then
			Application:debug("JOKER")
		end
	end
	if not debug then
		print("num of pcs", #pcs)
	end
	local chance_risk_mod = tweak_data.lootdrop.risk_pc_multiplier[difficulty_id] or 0
	local chance_curve = tweak_data.lootdrop.STARS_CURVES[stars]
	local start_chance = tweak_data.lootdrop.PC_CHANCE[stars]
	if not debug then
		print("start_chance before skills: ", start_chance)
	end
	start_chance = start_chance * managers.player:upgrade_value("player", "passive_loot_drop_multiplier", 1) * managers.player:upgrade_value("player", "loot_drop_multiplier", 1)
	if not debug then
		print("start_chance after skills: ", start_chance)
	end
	local no_pcs = #pcs
	local pc
	for i = 1, no_pcs do
		local chance = math.lerp(start_chance, 1, math.pow((i - 1) / (no_pcs - 1), chance_curve))
		if not debug then
			print("chance for", i, pcs[i], "is", chance)
		end
		local roll = math.rand(1)
		if not debug then
			print(" roll,", roll)
		end
		if chance >= roll then
			if not debug then
				print(" got it at", i, pcs[i])
			end
			pc = pcs[i]
			return_data.item_payclass = pc
			break
		end
	end
	if not debug then
		print("Select from pc", pc)
	end
	local pc_items = self._global.pc_items[pc]
	local i_pc_items = {}
	if not debug then
		print(" Random from type:")
	end
	local weighted_type_chance = tweak_data.lootdrop.WEIGHTED_TYPE_CHANCE[pc]
	local sum = 0
	for type, items in pairs(pc_items) do
		sum = sum + weighted_type_chance[type]
		if not debug then
			print("added", type, weighted_type_chance[type], "to sum", sum)
		end
	end
	if not debug then
		print("sum", sum)
	end
	local normalized_chance = {}
	for type, items in pairs(pc_items) do
		normalized_chance[type] = weighted_type_chance[type] / sum
	end
	if not debug then
		print("normalized_chance", inspect(normalized_chance))
	end
	local has_result
	while not has_result do
		local type_items = self:_get_type_items(normalized_chance, debug)
		if not debug then
			print(" Type result", type_items)
		end
		local items = pc_items[type_items]
		local item_entry = items[math.random(#items)]
		local global_value = "normal"
		if not tweak_data.blackmarket[type_items][item_entry].qlvl or plvl >= tweak_data.blackmarket[type_items][item_entry].qlvl then
			local global_value_chance = math.rand(1)
			if tweak_data.blackmarket[type_items][item_entry].infamous and global_value_chance < tweak_data.lootdrop.global_values.infamous.chance then
				global_value = "infamous"
			elseif global_value_chance < tweak_data.lootdrop.global_values.exceptional.chance then
			elseif global_value_chance < tweak_data.lootdrop.global_values.superior.chance then
			end
			if not tweak_data.blackmarket[type_items][item_entry].infamous or global_value == "infamous" then
				has_result = true
				if not debug then
					print("You got", item_entry, "of type", type_items, "with global value", global_value)
				end
				if add_to_inventory then
					if type_items == "cash" then
						managers.blackmarket:add_to_inventory(global_value, type_items, item_entry)
					else
						managers.blackmarket:add_to_inventory(global_value, type_items, item_entry)
					end
					return_data.global_value = global_value
					return_data.type_items = type_items
					return_data.item_entry = item_entry
				end
				if not debug then
					print(inspect(tweak_data.blackmarket[type_items][item_entry]))
				end
				if global_value == "infamous" then
				end
				return global_value, type_items, item_entry, pc
			end
		end
	end
end
function LootDropManager:_get_type_items(normalized_chance, debug)
	local seed = math.rand(1)
	if not debug then
		print("seed", seed)
	end
	for type, weight in pairs(normalized_chance) do
		seed = seed - weight
		if not debug then
			print("   sub seed", type, weight, seed)
		end
		if seed <= 0 then
			if not debug then
				print("RETURN TYPE", type)
			end
			return type
		end
	end
	return next(normalized_chance)
end
function LootDropManager:reset()
	Global.lootdrop_manager = nil
	self:_setup()
end
function LootDropManager:debug_check_items(check_type)
	for type, data in pairs(tweak_data.blackmarket) do
		if not check_type or type == check_type then
			for id, item_data in pairs(data) do
				if not item_data.pc and not item_data.pcs then
					print("Item", id, "of type", type, "hasn't been assigned a pay class")
				end
			end
		end
	end
end
function LootDropManager:debug_print_pc_items(check_type)
	for type, data in pairs(tweak_data.blackmarket) do
		if not check_type or type == check_type then
			for id, item_data in pairs(data) do
				if check_type ~= "weapon_mods" or item_data.pc or item_data.pcs then
					local name = item_data.name_id and managers.localization:text(item_data.name_id) or "NO NAME"
					local pcs = "" .. (item_data.pc or "")
					if item_data.pcs then
						for _, pc in ipairs(item_data.pcs) do
							pcs = pcs .. " " .. pc
						end
					end
					local infamous = item_data.infamous and "infamous" or ""
					print(name, id, pcs, infamous)
				end
			end
		end
	end
end
function LootDropManager:save(data)
	data.LootDropManager = self._global
end
function LootDropManager:load(data)
	self._global = data.LootDropManager
end
