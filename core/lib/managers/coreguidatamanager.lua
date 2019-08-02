if core then
	core:module("CoreGuiDataManager")
end
GuiDataManager = GuiDataManager or class()
function GuiDataManager:init(scene_gui, res, safe_rect_pixels, safe_rect, static_aspect_ratio)
	self._scene_gui = scene_gui
	self._static_resolution = res
	self._safe_rect_pixels = safe_rect_pixels
	self._safe_rect = safe_rect
	self._static_aspect_ratio = static_aspect_ratio
	self:_setup_workspace_data()
end
function GuiDataManager:destroy()
end
function GuiDataManager:create_saferect_workspace()
	local ws = self._scene_gui or Overlay:gui():create_scaled_screen_workspace(10, 10, 10, 10, 10)
	self:layout_workspace(ws)
	return ws
end
function GuiDataManager:create_fullscreen_workspace()
	local ws = self._scene_gui or Overlay:gui():create_scaled_screen_workspace(10, 10, 10, 10, 10)
	self:layout_fullscreen_workspace(ws)
	return ws
end
function GuiDataManager:create_fullscreen_16_9_workspace()
	local ws = self._scene_gui or Overlay:gui():create_scaled_screen_workspace(10, 10, 10, 10, 10)
	self:layout_fullscreen_16_9_workspace(ws)
	return ws
end
function GuiDataManager:destroy_workspace(ws)
	self._scene_gui or Overlay:gui():destroy_workspace(ws)
end
function GuiDataManager:_get_safe_rect_pixels()
	if self._safe_rect_pixels then
		return self._safe_rect_pixels
	end
	return managers.viewport:get_safe_rect_pixels()
end
function GuiDataManager:_get_safe_rect()
	if self._safe_rect then
		return self._safe_rect
	end
	return managers.viewport:get_safe_rect()
end
function GuiDataManager:_aspect_ratio()
	if self._static_aspect_ratio then
		return self._static_aspect_ratio
	end
	return managers.viewport:aspect_ratio()
end
local base_res = {x = 1280, y = 720}
function GuiDataManager:_setup_workspace_data()
	print("[GuiDataManager:_setup_workspace_data]")
	self._saferect_data = {}
	self._corner_saferect_data = {}
	self._fullrect_data = {}
	self._fullrect_16_9_data = {}
	local safe_rect = self:_get_safe_rect_pixels()
	local scaled_size = self:scaled_size()
	local res = self._static_resolution or RenderSettings.resolution
	local w = scaled_size.width
	local h = scaled_size.height
	local sh = math.min(safe_rect.height, safe_rect.width / (w / h))
	local sw = math.min(safe_rect.width, safe_rect.height * (w / h))
	local x = res.x / 2 - sh * (w / h) / 2
	local y = res.y / 2 - sw / (w / h) / 2
	self._safe_x = x
	self._safe_y = y
	self._saferect_data.w = w
	self._saferect_data.h = h
	self._saferect_data.width = self._saferect_data.w
	self._saferect_data.height = self._saferect_data.h
	self._saferect_data.x = x
	self._saferect_data.y = y
	self._saferect_data.on_screen_width = sw
	local h_c = w / (safe_rect.width / safe_rect.height)
	local w_c = h * (safe_rect.width / safe_rect.height)
	self._corner_saferect_data.w = w
	self._corner_saferect_data.h = h_c
	self._corner_saferect_data.width = self._corner_saferect_data.w
	self._corner_saferect_data.height = self._corner_saferect_data.h
	self._corner_saferect_data.x = safe_rect.x
	self._corner_saferect_data.y = safe_rect.y
	self._corner_saferect_data.on_screen_width = safe_rect.width
	self._fullrect_data.w = base_res.x
	self._fullrect_data.h = base_res.x / self:_aspect_ratio()
	self._fullrect_data.width = self._fullrect_data.w
	self._fullrect_data.height = self._fullrect_data.h
	self._fullrect_data.x = 0
	self._fullrect_data.y = 0
	self._fullrect_data.on_screen_width = res.x
	self._fullrect_data.convert_x = math.floor((base_res.x - self._saferect_data.w) / 2)
	self._fullrect_data.convert_y = (base_res.x / self:_aspect_ratio() - scaled_size.height) / 2
	self._fullrect_data.corner_convert_y = math.floor((self._fullrect_data.height - self._corner_saferect_data.height) / 2)
	w = base_res.x
	h = base_res.y
	sh = math.min(res.y, res.x / (w / h))
	sw = math.min(res.x, res.y * (w / h))
	x = res.x / 2 - sh * (w / h) / 2
	y = res.y / 2 - sw / (w / h) / 2
	self._fullrect_16_9_data.w = w
	self._fullrect_16_9_data.h = h
	self._fullrect_16_9_data.width = self._fullrect_16_9_data.w
	self._fullrect_16_9_data.height = self._fullrect_16_9_data.h
	self._fullrect_16_9_data.x = x
	self._fullrect_16_9_data.y = y
	self._fullrect_16_9_data.on_screen_width = sw
	self._fullrect_16_9_data.convert_x = math.floor((self._fullrect_16_9_data.w - self._saferect_data.w) / 2)
	self._fullrect_16_9_data.convert_y = (self._fullrect_16_9_data.h - self._saferect_data.h) / 2
end
function GuiDataManager:layout_workspace(ws)
	ws:set_screen(self._saferect_data.w, self._saferect_data.h, self._saferect_data.x, self._saferect_data.y, self._saferect_data.on_screen_width)
end
function GuiDataManager:layout_fullscreen_workspace(ws)
	ws:set_screen(self._fullrect_data.w, self._fullrect_data.h, self._fullrect_data.x, self._fullrect_data.y, self._fullrect_data.on_screen_width)
end
function GuiDataManager:layout_fullscreen_16_9_workspace(ws)
	ws:set_screen(self._fullrect_16_9_data.w, self._fullrect_16_9_data.h, self._fullrect_16_9_data.x, self._fullrect_16_9_data.y, self._fullrect_16_9_data.on_screen_width)
end
function GuiDataManager:layout_corner_saferect_workspace(ws)
	ws:set_screen(self._corner_saferect_data.w, self._corner_saferect_data.h, self._corner_saferect_data.x, self._corner_saferect_data.y, self._corner_saferect_data.on_screen_width)
end
function GuiDataManager:scaled_size()
	local w = math.round(self:_get_safe_rect().width * base_res.x)
	local h = math.round(self:_get_safe_rect().height * base_res.y)
	return {
		width = w,
		height = h,
		x = 0,
		y = 0
	}
end
function GuiDataManager:safe_scaled_size()
	return self._saferect_data
end
function GuiDataManager:corner_scaled_size()
	return self._corner_saferect_data
end
function GuiDataManager:full_scaled_size()
	return self._fullrect_data
end
function GuiDataManager:full_16_9_size()
	return self._fullrect_16_9_data
end
function GuiDataManager:safe_to_full_16_9(in_x, in_y)
	return self._fullrect_16_9_data.convert_x + in_x, self._fullrect_16_9_data.convert_y + in_y
end
function GuiDataManager:full_16_9_to_safe(in_x, in_y)
	return in_x - self._fullrect_16_9_data.convert_x, in_y - self._fullrect_16_9_data.convert_y
end
function GuiDataManager:safe_to_full(in_x, in_y)
	return self._fullrect_data.convert_x + in_x, self._fullrect_data.convert_y + in_y
end
function GuiDataManager:full_to_safe(in_x, in_y)
	return in_x - self._fullrect_data.convert_x, in_y - self._fullrect_data.convert_y
end
function GuiDataManager:corner_safe_to_full(in_x, in_y)
	return self._fullrect_data.convert_x + in_x, self._fullrect_data.corner_convert_y + in_y
end
function GuiDataManager:y_safe_to_full(in_y)
	return self._fullrect_data.convert_y + in_y
end
function GuiDataManager:resolution_changed()
	self:_setup_workspace_data()
end
