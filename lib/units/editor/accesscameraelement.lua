AccessCameraUnitElement = AccessCameraUnitElement or class(MissionElement)
function AccessCameraUnitElement:init(unit)
	AccessCameraUnitElement.super.init(self, unit)
	self._camera_unit = nil
	self:_add_text_options()
	self._hed.text_id = "debug_none"
	self._hed.yaw_limit = 25
	self._hed.pitch_limit = 25
	self._hed.camera_u_id = nil
	table.insert(self._save_values, "text_id")
	table.insert(self._save_values, "yaw_limit")
	table.insert(self._save_values, "pitch_limit")
	table.insert(self._save_values, "camera_u_id")
end
function AccessCameraUnitElement:layer_finished()
	AccessCameraUnitElement.super.layer_finished(self)
	if self._hed.camera_u_id then
		local unit = managers.worlddefinition:get_unit_on_load(self._hed.camera_u_id, callback(self, self, "load_unit"))
		if unit then
			self._camera_unit = unit
		end
	end
end
function AccessCameraUnitElement:load_unit(unit)
	if unit then
		self._camera_unit = unit
	end
end
function AccessCameraUnitElement:update_selected(t, dt, selected_unit, all_units)
	Application:draw_cone(self._unit:position(), self._unit:position() + self._unit:rotation():y() * 75, 35, 1, 1, 1)
	if alive(self._camera_unit) then
		self:_draw_link({
			from_unit = self._unit,
			to_unit = self._camera_unit,
			r = 0,
			g = 0.75,
			b = 0
		})
		Application:draw(self._camera_unit, 0, 0.75, 0)
	elseif self._hed.camera_u_id then
		self._hed.camera_u_id = nil
	end
end
function AccessCameraUnitElement:update_unselected(t, dt, selected_unit, all_units)
	if alive(self._camera_unit) then
	elseif self._hed.camera_u_id then
		self._hed.camera_u_id = nil
	end
end
function AccessCameraUnitElement:update_editing()
end
function AccessCameraUnitElement:_add_text_options()
	self._text_options = {"debug_none"}
	for _, id_string in ipairs(managers.localization:ids("strings/hud")) do
		local s = id_string:s()
		if string.find(s, "cam_") then
			table.insert(self._text_options, s)
		end
	end
	for _, id_string in ipairs(managers.localization:ids("strings/wip")) do
		local s = id_string:s()
		if string.find(s, "cam_") then
			table.insert(self._text_options, s)
		end
	end
end
function AccessCameraUnitElement:set_text()
	self._text:set_value(managers.localization:text(self._hed.text_id))
end
function AccessCameraUnitElement:add_camera_uid()
	print("AccessCameraUnitElement:add_camera_uid")
	local unit = SecurityCameraUnitElement._find_camera_raycast(self)
	print("unit", unit)
	if unit then
		if self._hed.camera_u_id and self._hed.camera_u_id == unit:unit_data().unit_id then
			self._hed.camera_u_id = nil
			self._camera_unit = nil
		else
			self._hed.camera_u_id = unit:unit_data().unit_id
			self._camera_unit = unit
		end
	end
end
function AccessCameraUnitElement:add_triggers(vc)
	vc:add_trigger(Idstring("lmb"), callback(self, self, "add_camera_uid"))
end
function AccessCameraUnitElement:_build_panel(panel, panel_sizer)
	self:_create_panel()
	panel = panel or self._panel
	panel_sizer = panel_sizer or self._panel_sizer
	local text_params = {
		name = "Text id:",
		panel = panel,
		sizer = panel_sizer,
		options = self._text_options,
		value = self._hed.text_id,
		tooltip = "Select a text id from the combobox",
		name_proportions = 1,
		ctrlr_proportions = 2,
		sorted = true
	}
	local text = CoreEWS.combobox(text_params)
	text:connect("EVT_COMMAND_COMBOBOX_SELECTED", callback(self, self, "set_element_data"), {ctrlr = text, value = "text_id"})
	text:connect("EVT_COMMAND_COMBOBOX_SELECTED", callback(self, self, "set_text"), nil)
	local text_sizer = EWS:BoxSizer("HORIZONTAL")
	text_sizer:add(EWS:StaticText(panel, "Text: ", "", ""), 1, 2, "ALIGN_CENTER_VERTICAL,RIGHT,EXPAND")
	self._text = EWS:StaticText(panel, managers.localization:text(self._hed.text_id), "", "")
	text_sizer:add(self._text, 2, 2, "RIGHT,TOP,EXPAND")
	panel_sizer:add(text_sizer, 0, 4, "EXPAND,BOTTOM")
	local yaw_limit_params = {
		name = "Yaw limit:",
		panel = panel,
		sizer = panel_sizer,
		value = self._hed.yaw_limit,
		floats = 0,
		tooltip = "Specify a yaw limit.",
		min = -1,
		name_proportions = 1,
		ctrlr_proportions = 2,
		sorted = false
	}
	local yaw_limit = CoreEWS.number_controller(yaw_limit_params)
	yaw_limit:connect("EVT_COMMAND_TEXT_ENTER", callback(self, self, "set_element_data"), {ctrlr = yaw_limit, value = "yaw_limit"})
	yaw_limit:connect("EVT_KILL_FOCUS", callback(self, self, "set_element_data"), {ctrlr = yaw_limit, value = "yaw_limit"})
	local pitch_limit_params = {
		name = "Pitch limit:",
		panel = panel,
		sizer = panel_sizer,
		value = self._hed.pitch_limit,
		floats = 0,
		tooltip = "Specify a pitch limit.",
		min = -1,
		name_proportions = 1,
		ctrlr_proportions = 2,
		sorted = false
	}
	local pitch_limit = CoreEWS.number_controller(pitch_limit_params)
	pitch_limit:connect("EVT_COMMAND_TEXT_ENTER", callback(self, self, "set_element_data"), {
		ctrlr = pitch_limit,
		value = "pitch_limit"
	})
	pitch_limit:connect("EVT_KILL_FOCUS", callback(self, self, "set_element_data"), {
		ctrlr = pitch_limit,
		value = "pitch_limit"
	})
end
AccessCameraOperatorUnitElement = AccessCameraOperatorUnitElement or class(MissionElement)
function AccessCameraOperatorUnitElement:init(unit)
	AccessCameraOperatorUnitElement.super.init(self, unit)
	self._hed.operation = "none"
	self._hed.elements = {}
	table.insert(self._save_values, "operation")
	table.insert(self._save_values, "elements")
end
function AccessCameraOperatorUnitElement:draw_links(t, dt, selected_unit, all_units)
	AccessCameraOperatorUnitElement.super.draw_links(self, t, dt, selected_unit)
	for _, id in ipairs(self._hed.elements) do
		local unit = all_units[id]
		local draw = not selected_unit or unit == selected_unit or self._unit == selected_unit
		if draw then
			self:_draw_link({
				from_unit = self._unit,
				to_unit = unit,
				r = 0.75,
				g = 0.75,
				b = 0.25
			})
		end
	end
end
function AccessCameraOperatorUnitElement:update_editing()
end
function AccessCameraOperatorUnitElement:add_element()
	local ray = managers.editor:unit_by_raycast({mask = 10, ray_type = "editor"})
	if ray and ray.unit and (ray.unit:name() == Idstring("units/dev_tools/mission_elements/point_access_camera/point_access_camera") or ray.unit:name() == Idstring("units/dev_tools/mission_elements/ai_security_camera/ai_security_camera")) then
		local id = ray.unit:unit_data().unit_id
		if table.contains(self._hed.elements, id) then
			table.delete(self._hed.elements, id)
		else
			table.insert(self._hed.elements, id)
		end
	end
end
function AccessCameraOperatorUnitElement:remove_links(unit)
	for _, id in ipairs(self._hed.elements) do
		if id == unit:unit_data().unit_id then
			table.delete(self._hed.elements, id)
		end
	end
end
function AccessCameraOperatorUnitElement:add_triggers(vc)
	vc:add_trigger(Idstring("lmb"), callback(self, self, "add_element"))
end
function AccessCameraOperatorUnitElement:_build_panel(panel, panel_sizer)
	self:_create_panel()
	panel = panel or self._panel
	panel_sizer = panel_sizer or self._panel_sizer
	local operation_params = {
		name = "Operation:",
		panel = panel,
		sizer = panel_sizer,
		default = "none",
		options = {"destroy"},
		value = self._hed.operation,
		tooltip = "Select an operation for the selected elements",
		name_proportions = 1,
		ctrlr_proportions = 2,
		sorted = true
	}
	local operation = CoreEWS.combobox(operation_params)
	operation:connect("EVT_COMMAND_COMBOBOX_SELECTED", callback(self, self, "set_element_data"), {ctrlr = operation, value = "operation"})
	local help = {}
	help.text = "This element can modify point_access_camera element. Select elements to modify using insert and clicking on them."
	help.panel = panel
	help.sizer = panel_sizer
	self:add_help_text(help)
end
AccessCameraTriggerUnitElement = AccessCameraTriggerUnitElement or class(MissionElement)
CounterTriggerUnitElement = CounterTriggerUnitElement or class(AccessCameraTriggerUnitElement)
function CounterTriggerUnitElement:init(...)
	CounterTriggerUnitElement.super.init(self, ...)
end
function AccessCameraTriggerUnitElement:init(unit)
	AccessCameraTriggerUnitElement.super.init(self, unit)
	self._hed.trigger_type = "accessed"
	self._hed.elements = {}
	table.insert(self._save_values, "trigger_type")
	table.insert(self._save_values, "elements")
end
function AccessCameraTriggerUnitElement:draw_links(t, dt, selected_unit, all_units)
	AccessCameraTriggerUnitElement.super.draw_links(self, t, dt, selected_unit)
	for _, id in ipairs(self._hed.elements) do
		local unit = all_units[id]
		local draw = not selected_unit or unit == selected_unit or self._unit == selected_unit
		if draw then
			self:_draw_link({
				from_unit = unit,
				to_unit = self._unit,
				r = 0.85,
				g = 0.85,
				b = 0.25
			})
		end
	end
end
function AccessCameraTriggerUnitElement:update_editing()
end
function AccessCameraTriggerUnitElement:add_element()
	local ray = managers.editor:unit_by_raycast({mask = 10, ray_type = "editor"})
	if ray and ray.unit and (ray.unit:name() == Idstring("units/dev_tools/mission_elements/point_access_camera/point_access_camera") or ray.unit:name() == Idstring("units/dev_tools/mission_elements/ai_security_camera/ai_security_camera")) then
		local id = ray.unit:unit_data().unit_id
		if table.contains(self._hed.elements, id) then
			table.delete(self._hed.elements, id)
		else
			table.insert(self._hed.elements, id)
		end
	end
end
function AccessCameraTriggerUnitElement:remove_links(unit)
	for _, id in ipairs(self._hed.elements) do
		if id == unit:unit_data().unit_id then
			table.delete(self._hed.elements, id)
		end
	end
end
function AccessCameraTriggerUnitElement:add_triggers(vc)
	vc:add_trigger(Idstring("lmb"), callback(self, self, "add_element"))
end
function AccessCameraTriggerUnitElement:_build_panel(panel, panel_sizer)
	self:_create_panel()
	panel = panel or self._panel
	panel_sizer = panel_sizer or self._panel_sizer
	local trigger_type_params = {
		name = "Trigger Type:",
		panel = panel,
		sizer = panel_sizer,
		default = "none",
		options = {
			"accessed",
			"destroyed",
			"alarm"
		},
		value = self._hed.trigger_type,
		tooltip = "Select a trigger type for the selected elements",
		name_proportions = 1,
		ctrlr_proportions = 2,
		sorted = true
	}
	local trigger_type = CoreEWS.combobox(trigger_type_params)
	trigger_type:connect("EVT_COMMAND_COMBOBOX_SELECTED", callback(self, self, "set_element_data"), {
		ctrlr = trigger_type,
		value = "trigger_type"
	})
	local help = {}
	help.text = "This element is a trigger to point_access_camera element."
	help.panel = panel
	help.sizer = panel_sizer
	self:add_help_text(help)
end
