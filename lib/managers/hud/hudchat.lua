HUDChat = HUDChat or class()
function HUDChat:init(ws, hud)
	self._ws = ws
	self._hud_panel = hud.panel
	self:set_channel_id(ChatManager.GAME)
	self._output_width = 300
	self._panel_width = 500
	self._lines = {}
	self._esc_callback = callback(self, self, "esc_key_callback")
	self._enter_callback = callback(self, self, "enter_key_callback")
	self._typing_callback = 0
	self._skip_first = false
	self._panel = self._hud_panel:panel({
		name = "chat_panel",
		x = 0,
		h = 500,
		w = self._panel_width,
		valign = "bottom"
	})
	self._panel:set_bottom(self._panel:parent():h() - 112)
	local output_panel = self._panel:panel({
		name = "output_panel",
		x = 0,
		h = 10,
		w = self._output_width,
		layer = 1
	})
	output_panel:gradient({
		name = "output_bg",
		gradient_points = {
			0,
			Color.white:with_alpha(0),
			0.2,
			Color.white:with_alpha(0.25),
			1,
			Color.white:with_alpha(0)
		},
		layer = -1,
		valign = "grow",
		blend_mode = "sub"
	})
	self:_create_input_panel()
	self:_layout_input_panel()
	self:_layout_output_panel()
end
function HUDChat:set_channel_id(channel_id)
	managers.chat:unregister_receiver(self._channel_id, self)
	self._channel_id = channel_id
	managers.chat:register_receiver(self._channel_id, self)
end
function HUDChat:esc_key_callback()
	managers.hud:set_chat_focus(false)
end
function HUDChat:enter_key_callback()
	local text = self._input_panel:child("input_text")
	local message = text:text()
	if string.len(message) > 0 then
		local u_name = managers.network.account:username()
		managers.chat:send_message(self._channel_id, u_name or "Offline", message)
	end
	text:set_text("")
	text:set_selection(0, 0)
	managers.hud:set_chat_focus(false)
end
function HUDChat:_create_input_panel()
	self._input_panel = self._panel:panel({
		alpha = 0,
		name = "input_panel",
		x = 0,
		h = 24,
		w = self._panel_width,
		layer = 1
	})
	self._input_panel:rect({
		name = "focus_indicator",
		visible = false,
		color = Color.white:with_alpha(0.2),
		layer = 0
	})
	local say = self._input_panel:text({
		name = "say",
		text = utf8.to_upper(managers.localization:text("debug_chat_say")),
		font = tweak_data.menu.small_font,
		font_size = tweak_data.menu.small_font_size,
		x = 0,
		y = 0,
		align = "left",
		halign = "left",
		vertical = "center",
		hvertical = "center",
		blend_mode = "normal",
		color = Color.white,
		layer = 1
	})
	local _, _, w, h = say:text_rect()
	say:set_size(w, self._input_panel:h())
	local input_text = self._input_panel:text({
		name = "input_text",
		text = "",
		font = tweak_data.menu.small_font_noshadow,
		font_size = tweak_data.menu.small_font_size,
		x = 0,
		y = 0,
		align = "left",
		halign = "left",
		vertical = "center",
		hvertical = "center",
		blend_mode = "normal",
		color = Color.white,
		layer = 1,
		wrap = true,
		word_wrap = false
	})
	local caret = self._input_panel:rect({
		name = "caret",
		layer = 2,
		x = 0,
		y = 0,
		w = 0,
		h = 0,
		color = Color(0.05, 1, 1, 1)
	})
	self._input_panel:gradient({
		name = "input_bg",
		gradient_points = {
			0,
			Color.white:with_alpha(0),
			0.2,
			Color.white:with_alpha(0.25),
			1,
			Color.white:with_alpha(0)
		},
		layer = -1,
		valign = "grow",
		blend_mode = "sub",
		h = self._input_panel:h()
	})
end
function HUDChat:_layout_output_panel()
	local output_panel = self._panel:child("output_panel")
	output_panel:set_w(self._output_width)
	local lines = 0
	for i = #self._lines, 1, -1 do
		local line = self._lines[i]
		line:set_w(output_panel:w())
		local _, _, w, h = line:text_rect()
		line:set_h(h)
		lines = lines + line:number_of_lines()
	end
	output_panel:set_h(21 * math.min(10, lines))
	local y = 0
	for i = #self._lines, 1, -1 do
		local line = self._lines[i]
		local _, _, w, h = line:text_rect()
		line:set_bottom(output_panel:h() - y)
		y = y + h
	end
	output_panel:set_bottom(self._input_panel:top())
end
function HUDChat:_layout_input_panel()
	self._input_panel:set_w(self._panel_width)
	local say = self._input_panel:child("say")
	local input_text = self._input_panel:child("input_text")
	input_text:set_left(say:right() + 4)
	input_text:set_w(self._input_panel:w() - input_text:left())
	local focus_indicator = self._input_panel:child("focus_indicator")
	focus_indicator:set_shape(input_text:shape())
	self._input_panel:set_y(self._input_panel:parent():h() - self._input_panel:h())
end
function HUDChat:input_focus()
	return self._focus
end
function HUDChat:_on_focus()
	if self._focus then
		return
	end
	local output_panel = self._panel:child("output_panel")
	output_panel:stop()
	output_panel:animate(callback(self, self, "_animate_show_component"), output_panel:alpha())
	self._input_panel:stop()
	self._input_panel:animate(callback(self, self, "_animate_show_component"))
	self._focus = true
	self._input_panel:child("focus_indicator"):set_color(Color(0.8, 1, 0.8):with_alpha(0.2))
	self._ws:connect_keyboard(Input:keyboard())
	self._input_panel:key_press(callback(self, self, "key_press"))
	self._input_panel:key_release(callback(self, self, "key_release"))
	self._enter_text_set = false
	self._input_panel:child("input_bg"):animate(callback(self, self, "_animate_input_bg"))
	self:update_caret()
end
function HUDChat:_loose_focus()
	if not self._focus then
		return
	end
	self._focus = false
	self._input_panel:child("focus_indicator"):set_color(Color.white:with_alpha(0.2))
	self._ws:disconnect_keyboard()
	self._input_panel:key_press(nil)
	self._input_panel:enter_text(nil)
	self._input_panel:key_release(nil)
	self._panel:child("output_panel"):stop()
	self._panel:child("output_panel"):animate(callback(self, self, "_animate_fade_output"))
	self._input_panel:stop()
	self._input_panel:animate(callback(self, self, "_animate_hide_input"))
	local text = self._input_panel:child("input_text")
	text:stop()
	self._input_panel:child("input_bg"):stop()
	self:update_caret()
end
function HUDChat:_shift()
	local k = Input:keyboard()
	return not k:down("left shift") and not k:down("right shift") and k:has_button("shift") and k:down("shift")
end
function HUDChat.blink(o)
	while true do
		o:set_color(Color(0, 1, 1, 1))
		wait(0.3)
		o:set_color(Color.white)
		wait(0.3)
	end
end
function HUDChat:set_blinking(b)
	local caret = self._input_panel:child("caret")
	if b == self._blinking then
		return
	end
	if b then
		caret:animate(self.blink)
	else
		caret:stop()
	end
	self._blinking = b
	if not self._blinking then
		caret:set_color(Color.white)
	end
end
function HUDChat:update_caret()
	local text = self._input_panel:child("input_text")
	local caret = self._input_panel:child("caret")
	local s, e = text:selection()
	local x, y, w, h = text:selection_rect()
	if s == 0 and e == 0 then
		if text:align() == "center" then
			x = text:world_x() + text:w() / 2
		else
			x = text:world_x()
		end
		y = text:world_y()
	end
	h = text:h()
	if w < 3 then
		w = 3
	end
	if not self._focus then
		w = 0
		h = 0
	end
	caret:set_world_shape(x, y + 2, w, h - 4)
	self:set_blinking(s == e and self._focus)
	local mid = x / self._input_panel:child("input_bg"):w()
	self._input_panel:child("input_bg"):set_gradient_points({
		0,
		Color.white:with_alpha(0),
		mid,
		Color.white:with_alpha(0.25),
		1,
		Color.white:with_alpha(0)
	})
end
function HUDChat:enter_text(o, s)
	if managers.hud and managers.hud:showing_stats_screen() then
		return
	end
	if self._skip_first then
		self._skip_first = false
		return
	end
	local text = self._input_panel:child("input_text")
	if type(self._typing_callback) ~= "number" then
		self._typing_callback()
	end
	text:replace_text(s)
	local lbs = text:line_breaks()
	if #lbs > 1 then
		local s = lbs[2]
		local e = utf8.len(text:text())
		text:set_selection(s, e)
		text:replace_text("")
	end
	self:update_caret()
end
function HUDChat:update_key_down(o, k)
	wait(0.6)
	local text = self._input_panel:child("input_text")
	while self._key_pressed == k do
		local s, e = text:selection()
		local n = utf8.len(text:text())
		local d = math.abs(e - s)
		if self._key_pressed == Idstring("backspace") then
			if s == e and s > 0 then
				text:set_selection(s - 1, e)
			end
			text:replace_text("")
			if not (utf8.len(text:text()) < 1) or type(self._esc_callback) ~= "number" then
			end
		elseif self._key_pressed == Idstring("delete") then
			if s == e and s < n then
				text:set_selection(s, e + 1)
			end
			text:replace_text("")
			if not (utf8.len(text:text()) < 1) or type(self._esc_callback) ~= "number" then
			end
		elseif self._key_pressed == Idstring("left") then
			if s < e then
				text:set_selection(s, s)
			elseif s > 0 then
				text:set_selection(s - 1, s - 1)
			end
		elseif self._key_pressed == Idstring("right") then
			if s < e then
				text:set_selection(e, e)
			elseif s < n then
				text:set_selection(s + 1, s + 1)
			end
		else
			self._key_pressed = false
		end
		self:update_caret()
		wait(0.03)
	end
end
function HUDChat:key_release(o, k)
	if self._key_pressed == k then
		self._key_pressed = false
	end
end
function HUDChat:key_press(o, k)
	if self._skip_first then
		if k == Idstring("enter") then
			self._skip_first = false
		end
		return
	end
	if not self._enter_text_set then
		self._input_panel:enter_text(callback(self, self, "enter_text"))
		self._enter_text_set = true
	end
	local text = self._input_panel:child("input_text")
	local s, e = text:selection()
	local n = utf8.len(text:text())
	local d = math.abs(e - s)
	self._key_pressed = k
	text:stop()
	text:animate(callback(self, self, "update_key_down"), k)
	if k == Idstring("backspace") then
		if s == e and s > 0 then
			text:set_selection(s - 1, e)
		end
		text:replace_text("")
		if not (utf8.len(text:text()) < 1) or type(self._esc_callback) ~= "number" then
		end
	elseif k == Idstring("delete") then
		if s == e and s < n then
			text:set_selection(s, e + 1)
		end
		text:replace_text("")
		if not (utf8.len(text:text()) < 1) or type(self._esc_callback) ~= "number" then
		end
	elseif k == Idstring("left") then
		if s < e then
			text:set_selection(s, s)
		elseif s > 0 then
			text:set_selection(s - 1, s - 1)
		end
	elseif k == Idstring("right") then
		if s < e then
			text:set_selection(e, e)
		elseif s < n then
			text:set_selection(s + 1, s + 1)
		end
	elseif self._key_pressed == Idstring("end") then
		text:set_selection(n, n)
	elseif self._key_pressed == Idstring("home") then
		text:set_selection(0, 0)
	elseif k == Idstring("enter") then
		if type(self._enter_callback) ~= "number" then
			self._enter_callback()
		end
	elseif k == Idstring("esc") and type(self._esc_callback) ~= "number" then
		text:set_text("")
		text:set_selection(0, 0)
		self._esc_callback()
	end
	self:update_caret()
end
function HUDChat:send_message(name, message)
end
function HUDChat:receive_message(name, message, color)
	local output_panel = self._panel:child("output_panel")
	local len = utf8.len(name) + 1
	local line = output_panel:text({
		text = name .. ": " .. message,
		font = tweak_data.menu.small_font,
		font_size = tweak_data.menu.small_font_size,
		x = 0,
		y = 0,
		align = "left",
		halign = "left",
		vertical = "top",
		hvertical = "top",
		blend_mode = "normal",
		wrap = true,
		word_wrap = true,
		color = color,
		layer = 0
	})
	local total_len = utf8.len(line:text())
	line:set_range_color(0, len, color)
	line:set_range_color(len, total_len, Color.white)
	local _, _, w, h = line:text_rect()
	line:set_h(h)
	table.insert(self._lines, line)
	self:_layout_output_panel()
	if not self._focus then
		local output_panel = self._panel:child("output_panel")
		output_panel:stop()
		output_panel:animate(callback(self, self, "_animate_show_component"), output_panel:alpha())
		output_panel:animate(callback(self, self, "_animate_fade_output"))
	end
end
function HUDChat:_animate_fade_output()
	local wait_t = 10
	local fade_t = 1
	local t = 0
	while wait_t > t do
		local dt = coroutine.yield()
		t = t + dt
	end
	local t = 0
	while fade_t > t do
		local dt = coroutine.yield()
		t = t + dt
		self:set_output_alpha(1 - t / fade_t)
	end
	self:set_output_alpha(0)
end
function HUDChat:_animate_show_component(input_panel, start_alpha)
	local TOTAL_T = 0.25
	local t = 0
	start_alpha = start_alpha or 0
	while TOTAL_T > t do
		local dt = coroutine.yield()
		t = t + dt
		input_panel:set_alpha(start_alpha + t / TOTAL_T * (1 - start_alpha))
	end
	input_panel:set_alpha(1)
end
function HUDChat:_animate_hide_input(input_panel)
	local TOTAL_T = 0.25
	local t = 0
	while TOTAL_T > t do
		local dt = coroutine.yield()
		t = t + dt
		input_panel:set_alpha(1 - t / TOTAL_T)
	end
	input_panel:set_alpha(0)
end
function HUDChat:_animate_input_bg(input_bg)
	local t = 0
	while true do
		local dt = coroutine.yield()
		t = t + dt
		local a = 0.75 + (1 + math.sin(t * 200)) / 8
		input_bg:set_alpha(a)
	end
end
function HUDChat:set_output_alpha(alpha)
	self._panel:child("output_panel"):set_alpha(alpha)
end
function HUDChat:remove()
	self._panel:child("output_panel"):stop()
	self._input_panel:stop()
	self._hud_panel:remove(self._panel)
	managers.chat:unregister_receiver(self._channel_id, self)
end
