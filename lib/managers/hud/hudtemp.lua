HUDTemp = HUDTemp or class()
function HUDTemp:init(hud)
	self._hud_panel = hud.panel
	if self._hud_panel:child("temp_panel") then
		self._hud_panel:remove(self._hud_panel:child("temp_panel"))
	end
	self._temp_panel = self._hud_panel:panel({
		visible = true,
		name = "temp_panel",
		y = 0,
		valign = "scale",
		layer = 0
	})
	local throw_instruction = self._temp_panel:text({
		name = "throw_instruction",
		text = "",
		visible = false,
		alpha = 0.85,
		align = "right",
		vertical = "bottom",
		halign = "right",
		valign = "bottom",
		w = 300,
		h = 40,
		layer = 1,
		x = 8,
		y = 2,
		color = Color.white,
		font = "fonts/font_medium_mf",
		font_size = 24
	})
	self:set_throw_bag_text()
	local bag_panel = self._temp_panel:panel({
		visible = false,
		name = "bag_panel",
		halign = "right",
		valign = "bottom",
		layer = 10
	})
	self._bg_box = HUDBGBox_create(bag_panel, {
		w = 142,
		h = 56,
		x = 0,
		y = 0
	})
	bag_panel:set_size(self._bg_box:size())
	self._bg_box:text({
		name = "bag_text",
		text = [[
CARRYING:
CIRCUIT BOARDS]],
		vertical = "left",
		valign = "center",
		layer = 1,
		x = 8,
		y = 2,
		color = Color.white,
		font = "fonts/font_medium_mf",
		font_size = 24
	})
	local bag_text = bag_panel:text({
		name = "bag_text",
		visible = false,
		text = "HEJ",
		font = "fonts/font_large_mf",
		align = "center",
		vertical = "center",
		font_size = 42,
		halign = "scale",
		valign = "scale",
		color = Color.black,
		w = 256,
		h = 128
	})
	bag_text:set_size(bag_panel:size())
	bag_text:set_position(0, 4)
	self._bag_panel_w = bag_panel:w()
	self._bag_panel_h = bag_panel:h()
	bag_panel:set_right(self._temp_panel:w())
	bag_panel:set_bottom(self:_bag_panel_bottom())
	throw_instruction:set_bottom(bag_panel:top())
	throw_instruction:set_right(bag_panel:right())
	self._curr_stamina = 0
	self._max_stamina = 0
	self._stamina_panel = self._temp_panel:panel({
		visable = true,
		name = "stamina_panel",
		layer = 0,
		w = 16,
		h = 128,
		halign = "right",
		valign = "center",
		alpha = 0
	})
	local stamina_bar_bg = self._stamina_panel:rect({
		name = "stamina_bar_bg",
		color = Color(0.6, 0.6, 0.6),
		alpha = 0.25
	})
	local low_stamina_bar = self._stamina_panel:rect({
		name = "low_stamina_bar",
		color = Color(0.6, 0.6, 0.6),
		alpha = 0
	})
	local stamina_bar = self._stamina_panel:rect({
		name = "stamina_bar",
		color = Color(0.6, 0.6, 0.6),
		layer = 1
	})
	local stamina_threshold = self._stamina_panel:rect({
		name = "stamina_threshold",
		color = Color(1, 1, 1),
		layer = 2,
		h = 2
	})
	self._stamina_panel:rect({
		name = "top_border",
		color = Color(),
		layer = 3,
		h = 2
	}):set_top(0)
	self._stamina_panel:rect({
		name = "bottom_border",
		color = Color(),
		layer = 3,
		h = 2
	}):set_bottom(128)
	self._stamina_panel:rect({
		name = "left_border",
		color = Color(),
		layer = 3,
		w = 2
	}):set_left(0)
	self._stamina_panel:rect({
		name = "right_border",
		color = Color(),
		layer = 3,
		w = 2
	}):set_right(16)
	self._stamina_panel:set_right(self._temp_panel:w())
	self._stamina_panel:set_center_y(self._temp_panel:center_y())
end
function HUDTemp:set_throw_bag_text()
	self._temp_panel:child("throw_instruction"):set_text(utf8.to_upper(managers.localization:text("hud_instruct_throw_bag", {
		BTN_USE_ITEM = managers.localization:btn_macro("use_item")
	})))
end
function HUDTemp:_bag_panel_bottom()
	return self._temp_panel:h() - managers.hud:teampanels_height()
end
function HUDTemp:show_carry_bag(carry_id, value)
	local bag_panel = self._temp_panel:child("bag_panel")
	local carry_data = tweak_data.carry[carry_id]
	local type_text = carry_data.name_id and managers.localization:text(carry_data.name_id)
	local bag_text = bag_panel:child("bag_text")
	bag_text:set_text(utf8.to_upper(type_text .. [[
 
 ]] .. managers.experience:cash_string(value)))
	bag_panel:set_x(self._temp_panel:parent():w() / 2)
	bag_panel:set_visible(true)
	self._bg_box:child("bag_text"):set_visible(false)
	local carrying_text = managers.localization:text("hud_carrying")
	self._bg_box:child("bag_text"):set_text(utf8.to_upper(carrying_text .. "\n" .. type_text))
	self._bg_box:set_w(self._bag_panel_w, self._bag_panel_h)
	self._bg_box:set_position(0, 0)
	bag_panel:stop()
	bag_panel:animate(callback(self, self, "_animate_show_bag_panel"))
end
function HUDTemp:hide_carry_bag()
	local bag_panel = self._temp_panel:child("bag_panel")
	bag_panel:stop()
	self._temp_panel:child("throw_instruction"):set_visible(false)
	bag_panel:animate(callback(self, self, "_animate_hide_bag_panel"))
end
function HUDTemp:_animate_hide_bag_panel(bag_panel)
	local bag_text = self._bg_box:child("bag_text")
	bag_text:stop()
	bag_text:animate(callback(self, self, "_animate_hide_text"))
	wait(0.5)
	local function close_done()
		bag_panel:set_visible(false)
	end
	self._bg_box:animate(callback(nil, _G, "HUDBGBox_animate_close_left"), close_done)
end
function HUDTemp:_animate_show_bag_panel(bag_panel)
	local w, h = self._bag_panel_w, self._bag_panel_h
	local scx = self._temp_panel:w() / 2
	local ecx = self._temp_panel:w() - w / 2
	local scy = self._temp_panel:h() / 2
	local ecy = self:_bag_panel_bottom() - self._bag_panel_h / 2
	local bottom = bag_panel:bottom()
	local center_y = bag_panel:center_y()
	local bag_text = self._bg_box:child("bag_text")
	local function open_done()
		bag_text:stop()
		bag_text:set_visible(true)
		bag_text:animate(callback(self, self, "_animate_show_text"))
	end
	self._bg_box:stop()
	self._bg_box:animate(callback(nil, _G, "HUDBGBox_animate_open_center"), nil, w, open_done)
	bag_panel:set_size(w, h)
	bag_panel:set_center_x(scx)
	bag_panel:set_center_y(scy)
	wait(1)
	local TOTAL_T = 0.5
	local t = TOTAL_T
	while t > 0 do
		local dt = coroutine.yield()
		t = t - dt
		bag_panel:set_center_x(math.lerp(scx, ecx, 1 - t / TOTAL_T))
		bag_panel:set_center_y(math.lerp(scy, ecy, 1 - t / TOTAL_T))
	end
	self._temp_panel:child("throw_instruction"):set_visible(true)
	bag_panel:set_size(w, h)
	bag_panel:set_center_x(ecx)
	bag_panel:set_center_y(ecy)
end
function HUDTemp:_animate_show_bag_panel_old(bag_panel)
	local w, h = self._bag_panel_w, self._bag_panel_h
	local scx = self._temp_panel:w() / 2
	local ecx = self._temp_panel:w() - w / 2
	local scy = self._temp_panel:h() / 2
	local ecy = self:_bag_panel_bottom() - self._bag_panel_h / 2
	local bottom = bag_panel:bottom()
	local center_y = bag_panel:center_y()
	local scale = 2
	bag_panel:set_size(w * scale, h * scale)
	local font_size = 24
	local bag_text = bag_panel:child("bag_text")
	bag_text:set_font_size(font_size * scale)
	bag_text:set_rotation(360)
	local _, _, tw, th = bag_text:text_rect()
	font_size = font_size * math.min(1, bag_panel:w() / (tw * 1.15))
	local TOTAL_T = 0.25
	local t = TOTAL_T
	while t > 0 do
		local dt = coroutine.yield()
		t = t - dt
		local wm = math.lerp(0, w * scale, 1 - t / TOTAL_T)
		local hm = math.lerp(0, h * scale, 1 - t / TOTAL_T)
		bag_panel:set_size(wm, hm)
		bag_panel:set_center_x(scx)
		bag_panel:set_center_y(scy)
		bag_text:set_font_size(math.lerp(0, font_size * scale, 1 - t / TOTAL_T))
	end
	wait(0.5)
	local TOTAL_T = 0.5
	local t = TOTAL_T
	while t > 0 do
		local dt = coroutine.yield()
		t = t - dt
		local wm = math.lerp(w * scale, w, 1 - t / TOTAL_T)
		local hm = math.lerp(h * scale, h, 1 - t / TOTAL_T)
		bag_panel:set_size(wm, hm)
		bag_panel:set_center_x(math.lerp(scx, ecx, 1 - t / TOTAL_T))
		bag_panel:set_center_y(math.lerp(scy, ecy, 1 - t / TOTAL_T))
		bag_text:set_font_size(math.lerp(font_size * scale, font_size, 1 - t / TOTAL_T))
	end
	bag_panel:set_size(w, h)
	bag_panel:set_center_x(ecx)
	bag_panel:set_center_y(ecy)
	bag_text:set_font_size(font_size)
end
function HUDTemp:_animate_show_text(text)
	local TOTAL_T = 0.5
	local t = TOTAL_T
	while t > 0 do
		local dt = coroutine.yield()
		t = t - dt
		local alpha = math.round(math.abs((math.sin(t * 360 * 3))))
		text:set_alpha(alpha)
	end
	text:set_alpha(1)
end
function HUDTemp:_animate_hide_text(text)
	local TOTAL_T = 0.5
	local t = TOTAL_T
	while t > 0 do
		local dt = coroutine.yield()
		t = t - dt
		local vis = math.round(math.abs((math.cos(t * 360 * 3))))
		text:set_alpha(vis)
	end
	text:set_alpha(1)
	text:set_visible(false)
end
function HUDTemp:set_stamina_value(value)
	self._curr_stamina = value
	self._stamina_panel:child("stamina_bar"):set_h(value / math.max(1, self._max_stamina) * self._stamina_panel:h())
	self._stamina_panel:child("stamina_bar"):set_bottom(self._stamina_panel:h())
	if self._curr_stamina < tweak_data.player.movement_state.stamina.MIN_STAMINA_THRESHOLD then
		self._stamina_panel:animate(callback(self, self, "_animate_low_stamina"))
	else
		self._stamina_panel:child("low_stamina_bar"):set_alpha(0)
		self._stamina_panel:stop()
	end
end
function HUDTemp:set_max_stamina(value)
	self._max_stamina = value
	self._stamina_panel:child("stamina_threshold"):set_center_y(self._stamina_panel:h() - tweak_data.player.movement_state.stamina.MIN_STAMINA_THRESHOLD / math.max(1, self._max_stamina) * self._stamina_panel:h())
end
function HUDTemp:_animate_low_stamina(input_panel)
	local low_stamina_bar = input_panel:child("low_stamina_bar")
	while true do
		local a = 0.25 + (math.sin(Application:time() * 750) + 1) / 4
		low_stamina_bar:set_alpha(a)
		low_stamina_bar:set_color(Color(a, 0, 0.8 - a))
		coroutine.yield()
	end
end
