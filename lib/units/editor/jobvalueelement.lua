JobValueUnitElement = JobValueUnitElement or class(MissionElement)
JobValueUnitElement.SAVE_UNIT_POSITION = false
JobValueUnitElement.SAVE_UNIT_ROTATION = false
function JobValueUnitElement:init(unit)
	JobValueUnitElement.super.init(self, unit)
	self._hed.key = "none"
	self._hed.value = 0
	self._hed.save = nil
	table.insert(self._save_values, "key")
	table.insert(self._save_values, "value")
	table.insert(self._save_values, "save")
end
function JobValueUnitElement:_build_panel(panel, panel_sizer)
	self:_create_panel()
	panel = panel or self._panel
	panel_sizer = panel_sizer or self._panel_sizer
	local key_sizer = EWS:BoxSizer("HORIZONTAL")
	panel_sizer:add(key_sizer, 0, 0, "EXPAND")
	local key_name = EWS:StaticText(panel, "Key:", 0, "")
	key_sizer:add(key_name, 1, 0, "ALIGN_CENTER_VERTICAL")
	local key = EWS:TextCtrl(panel, self._hed.key, "", "TE_PROCESS_ENTER")
	key_sizer:add(key, 2, 0, "ALIGN_CENTER_VERTICAL")
	key:connect("EVT_COMMAND_TEXT_ENTER", callback(self, self, "set_element_data"), {ctrlr = key, value = "key"})
	key:connect("EVT_KILL_FOCUS", callback(self, self, "set_element_data"), {ctrlr = key, value = "key"})
	local value_sizer = EWS:BoxSizer("HORIZONTAL")
	panel_sizer:add(value_sizer, 0, 0, "EXPAND")
	local value_name = EWS:StaticText(panel, "Value:", 0, "")
	value_sizer:add(value_name, 1, 0, "ALIGN_CENTER_VERTICAL")
	local value = EWS:TextCtrl(panel, self._hed.value, "", "TE_PROCESS_ENTER")
	value_sizer:add(value, 2, 0, "ALIGN_CENTER_VERTICAL")
	value:connect("EVT_COMMAND_TEXT_ENTER", callback(self, self, "set_element_data"), {ctrlr = value, value = "value"})
	value:connect("EVT_KILL_FOCUS", callback(self, self, "set_element_data"), {ctrlr = value, value = "value"})
	local save = EWS:CheckBox(panel, "Save", "")
	save:set_value(self._hed.save)
	save:connect("EVT_COMMAND_CHECKBOX_CLICKED", callback(self, self, "set_element_data"), {ctrlr = save, value = "save"})
	panel_sizer:add(save, 0, 0, "EXPAND")
end
JobValueFilterUnitElement = JobValueFilterUnitElement or class(MissionElement)
JobValueFilterUnitElement.SAVE_UNIT_POSITION = false
JobValueFilterUnitElement.SAVE_UNIT_ROTATION = false
function JobValueFilterUnitElement:init(unit)
	JobValueFilterUnitElement.super.init(self, unit)
	self._hed.key = "none"
	self._hed.value = 0
	self._hed.save = nil
	self._hed.check_type = "equal"
	table.insert(self._save_values, "key")
	table.insert(self._save_values, "value")
	table.insert(self._save_values, "save")
	table.insert(self._save_values, "check_type")
end
function JobValueFilterUnitElement:_build_panel(panel, panel_sizer)
	JobValueUnitElement._build_panel(self, panel, panel_sizer)
	panel = panel or self._panel
	panel_sizer = panel_sizer or self._panel_sizer
	local check_type_params = {
		name = "Check type:",
		panel = panel,
		sizer = panel_sizer,
		options = {
			"equal",
			"less_than",
			"greater_than",
			"less_or_equal",
			"greater_or_equal",
			"has_key",
			"not_has_key"
		},
		value = self._hed.check_type,
		tooltip = "Select which check operation to berform",
		name_proportions = 1,
		ctrlr_proportions = 2,
		sorted = true
	}
	local check_type = CoreEWS.combobox(check_type_params)
	check_type:connect("EVT_COMMAND_COMBOBOX_SELECTED", callback(self, self, "set_element_data"), {ctrlr = check_type, value = "check_type"})
	local help = {}
	help.text = "Key is what to check. Value is what it is supposed to be to pass the filter. Different check types can be used i the value is known to be a number, for example, greater_then checks if the stored value is greater then the input value."
	help.panel = panel
	help.sizer = panel_sizer
	self:add_help_text(help)
end
ApplyJobValueUnitElement = ApplyJobValueUnitElement or class(MissionElement)
ApplyJobValueUnitElement.SAVE_UNIT_POSITION = false
ApplyJobValueUnitElement.SAVE_UNIT_ROTATION = false
function ApplyJobValueUnitElement:init(unit)
	ApplyJobValueUnitElement.super.init(self, unit)
	self._hed.key = "none"
	self._hed.save = nil
	self._hed.elements = {}
	table.insert(self._save_values, "key")
	table.insert(self._save_values, "save")
	table.insert(self._save_values, "elements")
end
function ApplyJobValueUnitElement:update_editing()
end
function ApplyJobValueUnitElement:draw_links(t, dt, selected_unit, all_units)
	ApplyJobValueUnitElement.super.draw_links(self, t, dt, selected_unit)
	for _, id in ipairs(self._hed.elements) do
		local unit = all_units[id]
		local draw = not selected_unit or unit == selected_unit or self._unit == selected_unit
		if draw then
			self:_draw_link({
				from_unit = self._unit,
				to_unit = unit,
				r = 0.85,
				g = 0.85,
				b = 0.25
			})
		end
	end
end
function ApplyJobValueUnitElement:add_element()
	local ray = managers.editor:unit_by_raycast({mask = 10, ray_type = "editor"})
	if ray and ray.unit then
		local id = ray.unit:unit_data().unit_id
		if table.contains(self._hed.elements, id) then
			table.delete(self._hed.elements, id)
		else
			table.insert(self._hed.elements, id)
		end
	end
end
function ApplyJobValueUnitElement:remove_links(unit)
	for _, id in ipairs(self._hed.elements) do
		if id == unit:unit_data().unit_id then
			table.delete(self._hed.elements, id)
		end
	end
end
function ApplyJobValueUnitElement:add_triggers(vc)
	vc:add_trigger(Idstring("lmb"), callback(self, self, "add_element"))
end
function ApplyJobValueUnitElement:_build_panel(panel, panel_sizer)
	self:_create_panel()
	panel = panel or self._panel
	panel_sizer = panel_sizer or self._panel_sizer
	local key_sizer = EWS:BoxSizer("HORIZONTAL")
	panel_sizer:add(key_sizer, 0, 0, "EXPAND")
	local key_name = EWS:StaticText(panel, "Key:", 0, "")
	key_sizer:add(key_name, 1, 0, "ALIGN_CENTER_VERTICAL")
	local key = EWS:TextCtrl(panel, self._hed.key, "", "TE_PROCESS_ENTER")
	key_sizer:add(key, 2, 0, "ALIGN_CENTER_VERTICAL")
	key:connect("EVT_COMMAND_TEXT_ENTER", callback(self, self, "set_element_data"), {ctrlr = key, value = "key"})
	key:connect("EVT_KILL_FOCUS", callback(self, self, "set_element_data"), {ctrlr = key, value = "key"})
	local save = EWS:CheckBox(panel, "Save", "")
	save:set_value(self._hed.save)
	save:connect("EVT_COMMAND_CHECKBOX_CLICKED", callback(self, self, "set_element_data"), {ctrlr = save, value = "save"})
	panel_sizer:add(save, 0, 0, "EXPAND")
end
