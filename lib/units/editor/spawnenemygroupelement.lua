SpawnEnemyGroupUnitElement = SpawnEnemyGroupUnitElement or class(MissionElement)
SpawnEnemyGroupUnitElement.SAVE_UNIT_POSITION = false
SpawnEnemyGroupUnitElement.SAVE_UNIT_ROTATION = false
function SpawnEnemyGroupUnitElement:init(unit)
	MissionElement.init(self, unit)
	self._hed.random = false
	self._hed.ignore_disabled = false
	self._hed.amount = 0
	self._hed.elements = {}
	self._hed.interval = 0
	table.insert(self._save_values, "elements")
	table.insert(self._save_values, "random")
	table.insert(self._save_values, "ignore_disabled")
	table.insert(self._save_values, "amount")
	table.insert(self._save_values, "preferred_spawn_groups")
	table.insert(self._save_values, "interval")
end
function SpawnEnemyGroupUnitElement:draw_links(t, dt, selected_unit, all_units)
	MissionElement.draw_links(self, t, dt, selected_unit, all_units)
end
function SpawnEnemyGroupUnitElement:update_editing()
end
function SpawnEnemyGroupUnitElement:update_selected(t, dt, selected_unit, all_units)
	for _, id in ipairs(self._hed.elements) do
		local unit = all_units[id]
		local draw = not selected_unit or unit == selected_unit or self._unit == selected_unit
		if draw then
			self:_draw_link({
				from_unit = self._unit,
				to_unit = unit,
				r = 0,
				g = 0.75,
				b = 0
			})
		end
	end
end
function SpawnEnemyGroupUnitElement:add_element()
	local ray = managers.editor:unit_by_raycast({mask = 10, ray_type = "editor"})
	if ray and ray.unit and string.find(ray.unit:name():s(), "ai_spawn_enemy", 1, true) then
		local id = ray.unit:unit_data().unit_id
		if table.contains(self._hed.elements, id) then
			table.delete(self._hed.elements, id)
		else
			table.insert(self._hed.elements, id)
		end
	end
end
function SpawnEnemyGroupUnitElement:remove_links(unit)
	for _, id in ipairs(self._hed.elements) do
		if id == unit:unit_data().unit_id then
			table.delete(self._hed.elements, id)
		end
	end
end
function SpawnEnemyGroupUnitElement:add_triggers(vc)
	vc:add_trigger(Idstring("lmb"), callback(self, self, "add_element"))
end
function SpawnEnemyGroupUnitElement:_build_panel(panel, panel_sizer)
	self:_create_panel()
	panel = panel or self._panel
	panel_sizer = panel_sizer or self._panel_sizer
	local random = EWS:CheckBox(panel, "Random", "")
	random:set_tool_tip("Select spawn points randomly")
	random:set_value(self._hed.random)
	random:connect("EVT_COMMAND_CHECKBOX_CLICKED", callback(self, self, "set_element_data"), {ctrlr = random, value = "random"})
	panel_sizer:add(random, 0, 0, "EXPAND")
	local ignore_disabled = EWS:CheckBox(panel, "Ignore disabled", "")
	ignore_disabled:set_tool_tip("Select if disabled spawn points should be ignored or not")
	ignore_disabled:set_value(self._hed.ignore_disabled)
	ignore_disabled:connect("EVT_COMMAND_CHECKBOX_CLICKED", callback(self, self, "set_element_data"), {
		ctrlr = ignore_disabled,
		value = "ignore_disabled"
	})
	panel_sizer:add(ignore_disabled, 0, 0, "EXPAND")
	local amount_params = {
		name = "Amount :",
		panel = panel,
		sizer = panel_sizer,
		value = self._hed.amount,
		floats = 0,
		tooltip = "Specify amount of enemies to spawn from group",
		min = 0,
		name_proportions = 1,
		ctrlr_proportions = 2
	}
	local amount = CoreEWS.number_controller(amount_params)
	amount:connect("EVT_COMMAND_TEXT_ENTER", callback(self, self, "set_element_data"), {ctrlr = amount, value = "amount"})
	amount:connect("EVT_KILL_FOCUS", callback(self, self, "set_element_data"), {ctrlr = amount, value = "amount"})
	local interval_params = {
		name = "Interval:",
		panel = panel,
		sizer = panel_sizer,
		value = self._hed.interval,
		floats = 0,
		tooltip = "Used to specify how often this spawn can be used. 0 means no interval",
		min = 0,
		name_proportions = 1,
		ctrlr_proportions = 2
	}
	local interval = CoreEWS.number_controller(interval_params)
	interval:connect("EVT_COMMAND_TEXT_ENTER", callback(self, self, "set_element_data"), {ctrlr = interval, value = "interval"})
	interval:connect("EVT_KILL_FOCUS", callback(self, self, "set_element_data"), {ctrlr = interval, value = "interval"})
	local opt_sizer = panel_sizer
	local filter_sizer = EWS:BoxSizer("HORIZONTAL")
	local opt1_sizer = EWS:BoxSizer("VERTICAL")
	local opt2_sizer = EWS:BoxSizer("VERTICAL")
	local opt3_sizer = EWS:BoxSizer("VERTICAL")
	local opt = NavigationManager.ACCESS_FLAGS
	local opt = {}
	for cat_name, team in pairs(tweak_data.group_ai.enemy_spawn_groups) do
		table.insert(opt, cat_name)
	end
	for i, o in ipairs(opt) do
		local check = EWS:CheckBox(panel, o, "")
		if self._hed.preferred_spawn_groups and table.contains(self._hed.preferred_spawn_groups, o) then
			check:set_value(true)
		else
			check:set_value(false)
		end
		check:connect("EVT_COMMAND_CHECKBOX_CLICKED", callback(self, self, "on_preferred_spawn_groups_checkbox_changed"), {ctrlr = check, name = o})
		if i <= math.round(#opt / 3) then
			opt1_sizer:add(check, 0, 0, "EXPAND")
		elseif i <= math.round(#opt / 3) * 2 then
			opt2_sizer:add(check, 0, 0, "EXPAND")
		else
			opt3_sizer:add(check, 0, 0, "EXPAND")
		end
	end
	filter_sizer:add(opt1_sizer, 1, 0, "EXPAND")
	filter_sizer:add(opt2_sizer, 1, 0, "EXPAND")
	filter_sizer:add(opt3_sizer, 1, 0, "EXPAND")
	opt_sizer:add(filter_sizer, 1, 0, "EXPAND")
end
function SpawnEnemyGroupUnitElement:on_preferred_spawn_groups_checkbox_changed(params)
	local value = params.ctrlr:get_value()
	if value then
		self._hed.preferred_spawn_groups = self._hed.preferred_spawn_groups or {}
		if table.contains(self._hed.preferred_spawn_groups, params.name) then
			return
		end
		table.insert(self._hed.preferred_spawn_groups, params.name)
	elseif self._hed.preferred_spawn_groups then
		table.delete(self._hed.preferred_spawn_groups, params.name)
		if not next(self._hed.preferred_spawn_groups) then
			self._hed.preferred_spawn_groups = nil
		end
	end
end
