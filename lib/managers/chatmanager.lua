ChatManager = ChatManager or class()
ChatManager.GAME = 1
ChatManager.CREW = 2
ChatManager.GLOBAL = 3
function ChatManager:init()
	self:_setup()
end
function ChatManager:_setup()
	self._chatlog = {}
	self._receivers = {}
end
function ChatManager:register_receiver(channel_id, receiver)
	self._receivers[channel_id] = self._receivers[channel_id] or {}
	table.insert(self._receivers[channel_id], receiver)
end
function ChatManager:unregister_receiver(channel_id, receiver)
	if not self._receivers[channel_id] then
		return
	end
	for i, rec in ipairs(self._receivers[channel_id]) do
		if rec == receiver then
			table.remove(self._receivers[channel_id], i)
		else
		end
	end
end
function ChatManager:send_message(channel_id, sender, message)
	if managers.network:session() then
		sender = managers.network:session():local_peer()
		managers.network:session():send_to_peers_ip_verified("send_chat_message", channel_id, message)
		self:receive_message_by_peer(channel_id, sender, message)
	else
		self:receive_message_by_name(channel_id, sender, message)
	end
end
function ChatManager:receive_message_by_peer(channel_id, peer, message)
	local color_id = peer:id()
	local color = tweak_data.chat_colors[color_id]
	self:_receive_message(channel_id, peer:name(), message, tweak_data.chat_colors[color_id])
end
function ChatManager:receive_message_by_name(channel_id, name, message)
	self:_receive_message(channel_id, name, message, tweak_data.chat_colors[1])
end
function ChatManager:_receive_message(channel_id, name, message, color)
	if not self._receivers[channel_id] then
		return
	end
	for i, receiver in ipairs(self._receivers[channel_id]) do
		receiver:receive_message(name, message, color)
	end
end
function ChatManager:save(data)
end
function ChatManager:load(data)
end
ChatBase = ChatBase or class()
function ChatBase:init()
end
function ChatBase:receive_message(name, message, color)
end
ChatGui = ChatGui or class(ChatBase)
function ChatGui:init(ws)
	self._ws = ws
	self._hud_panel = ws:panel()
	self:set_channel_id(ChatManager.GAME)
	self._output_width = self._hud_panel:w() * 0.5 - 10
	self._panel_width = self._hud_panel:w() * 0.5 - 10
	self._panel_height = 500
	self._max_lines = 15
	self._lines = {}
	self._esc_callback = callback(self, self, "esc_key_callback")
	self._enter_callback = callback(self, self, "enter_key_callback")
	self._typing_callback = 0
	self._skip_first = false
	self._panel = self._hud_panel:panel({
		name = "chat_panel",
		x = 0,
		h = self._panel_height,
		w = self._panel_width,
		valign = "bottom"
	})
	self:set_leftbottom(0, 70)
	self._panel:set_layer(20)
	local output_panel = self._panel:panel({
		name = "output_panel",
		x = 20,
		h = 10,
		w = self._output_width - 20,
		layer = 1
	})
	local scroll_panel = output_panel:panel({
		name = "scroll_panel",
		x = 0,
		h = 10,
		w = self._output_width
	})
	self._scroll_indicator_box_class = BoxGuiObject:new(output_panel, {
		sides = {
			0,
			0,
			0,
			0
		}
	})
	local scroll_up_indicator_shade = output_panel:bitmap({
		name = "scroll_up_indicator_shade",
		texture = "guis/textures/headershadow",
		rotation = 180,
		layer = 2,
		color = Color.white,
		w = output_panel:w()
	})
	local texture, rect = tweak_data.hud_icons:get_icon_data("scroll_up")
	local scroll_up_indicator_arrow = self._panel:bitmap({
		name = "scroll_up_indicator_arrow",
		texture = texture,
		texture_rect = rect,
		layer = 2,
		color = Color.white
	})
	local scroll_down_indicator_shade = output_panel:bitmap({
		name = "scroll_down_indicator_shade",
		texture = "guis/textures/headershadow",
		layer = 2,
		color = Color.white,
		w = output_panel:w()
	})
	local texture, rect = tweak_data.hud_icons:get_icon_data("scroll_dn")
	local scroll_down_indicator_arrow = self._panel:bitmap({
		name = "scroll_down_indicator_arrow",
		texture = texture,
		texture_rect = rect,
		layer = 2,
		color = Color.white
	})
	local bar_h = scroll_down_indicator_arrow:top() - scroll_up_indicator_arrow:bottom()
	local texture, rect = tweak_data.hud_icons:get_icon_data("scrollbar")
	local scroll_bar = self._panel:panel({
		name = "scroll_bar",
		layer = 2,
		h = bar_h,
		w = 15
	})
	local scroll_bar_box_panel = scroll_bar:panel({
		name = "scroll_bar_box_panel",
		w = 4,
		x = 5,
		halign = "scale",
		valign = "scale"
	})
	self._scroll_bar_box_class = BoxGuiObject:new(scroll_bar_box_panel, {
		sides = {
			2,
			2,
			0,
			0
		}
	})
	self._enabled = true
	output_panel:set_x(scroll_down_indicator_arrow:w() + 4)
	self:_create_input_panel()
	self:_layout_input_panel()
	self:_layout_output_panel()
end
function ChatGui:set_leftbottom(left, bottom)
	self._panel:set_left(left)
	self._panel:set_bottom(self._panel:parent():h() - bottom)
end
function ChatGui:set_max_lines(max_lines)
	self._max_lines = max_lines
	self:_layout_output_panel()
end
function ChatGui:set_params(params)
	if params.max_lines then
		self:set_max_lines(params.max_lines)
	end
	if params.left and params.bottom then
		self:set_leftbottom(params.left, params.bottom)
	end
end
function ChatGui:set_enabled(enabled)
	if not enabled then
		self:_loose_focus()
	end
	self._enabled = enabled
end
function ChatGui:hide()
	self._panel:hide()
	self:set_enabled(false)
	local text = self._input_panel:child("input_text")
	text:set_text("")
	text:set_selection(0, 0)
end
function ChatGui:show()
	self._panel:show()
	self:set_enabled(true)
end
function ChatGui:set_layer(layer)
	self._panel:set_layer(layer)
end
function ChatGui:set_channel_id(channel_id)
	managers.chat:unregister_receiver(self._channel_id, self)
	self._channel_id = channel_id
	managers.chat:register_receiver(self._channel_id, self)
end
function ChatGui:esc_key_callback()
	if not self._enabled then
		return
	end
	self._esc_focus_delay = true
	self:_loose_focus()
end
function ChatGui:enter_key_callback()
	if not self._enabled then
		return
	end
	local text = self._input_panel:child("input_text")
	local message = text:text()
	if Idstring(message) == Idstring("/ready") then
		managers.menu_component:on_ready_pressed_mission_briefing_gui()
	elseif string.len(message) > 0 then
		local u_name = managers.network.account:username()
		managers.chat:send_message(self._channel_id, u_name or "Offline", message)
	else
		self._enter_loose_focus_delay = true
		self:_loose_focus()
	end
	text:set_text("")
	text:set_selection(0, 0)
end
function ChatGui:_create_input_panel()
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
		color = Color.black:with_alpha(0.2),
		layer = 0
	})
	local say = self._input_panel:text({
		name = "say",
		text = utf8.to_upper(managers.localization:text("debug_chat_say")),
		font = tweak_data.menu.pd2_small_font,
		font_size = tweak_data.menu.pd2_small_font_size,
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
		font = tweak_data.menu.pd2_small_font,
		font_size = tweak_data.menu.pd2_small_font_size,
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
	self._input_panel:rect({
		name = "input_bg",
		color = Color.black:with_alpha(0.5),
		layer = -1,
		valign = "grow",
		h = self._input_panel:h()
	})
	self._input_panel:child("input_bg"):set_w(self._input_panel:w() - w)
	self._input_panel:child("input_bg"):set_x(w)
	self._input_panel:stop()
	self._input_panel:animate(callback(self, self, "_animate_hide_input"))
end
function ChatGui:_layout_output_panel()
	local output_panel = self._panel:child("output_panel")
	local scroll_panel = output_panel:child("scroll_panel")
	scroll_panel:set_w(self._output_width)
	output_panel:set_w(self._output_width)
	local lines = 0
	for i = #self._lines, 1, -1 do
		local line = self._lines[i][1]
		local line_bg = self._lines[i][2]
		line:set_w(output_panel:w())
		local _, _, w, h = line:text_rect()
		line:set_h(h)
		line_bg:set_w(w + 2)
		line_bg:set_h(h)
		lines = lines + line:number_of_lines()
	end
	local line_height = 22
	local max_lines = self._max_lines
	local scroll_at_bottom = scroll_panel:bottom() == output_panel:h()
	output_panel:set_h(math.round(line_height * math.min(max_lines, lines)))
	scroll_panel:set_h(math.round(line_height * lines))
	local y = 0
	for i = #self._lines, 1, -1 do
		local line = self._lines[i][1]
		local line_bg = self._lines[i][2]
		local _, _, w, h = line:text_rect()
		line:set_bottom(scroll_panel:h() - y)
		line_bg:set_bottom(line:bottom())
		line:set_left(line:left())
		y = y + h
	end
	output_panel:set_bottom(math.round(self._input_panel:top()))
	if lines <= max_lines or scroll_at_bottom then
		scroll_panel:set_bottom(output_panel:h())
	end
	self:set_scroll_indicators()
end
function ChatGui:_layout_input_panel()
	self._input_panel:set_w(self._panel_width - self._input_panel:x())
	local say = self._input_panel:child("say")
	local input_text = self._input_panel:child("input_text")
	input_text:set_left(say:right() + 4)
	input_text:set_w(self._input_panel:w() - input_text:left())
	self._input_panel:child("input_bg"):set_w(input_text:w())
	self._input_panel:child("input_bg"):set_x(input_text:x())
	local focus_indicator = self._input_panel:child("focus_indicator")
	focus_indicator:set_shape(input_text:shape())
	self._input_panel:set_y(self._input_panel:parent():h() - self._input_panel:h())
	self._input_panel:set_x(self._panel:child("output_panel"):x())
end
function ChatGui:set_scroll_indicators()
	local output_panel = self._panel:child("output_panel")
	local scroll_panel = output_panel:child("scroll_panel")
	local scroll_up_indicator_shade = output_panel:child("scroll_up_indicator_shade")
	local scroll_up_indicator_arrow = self._panel:child("scroll_up_indicator_arrow")
	local scroll_down_indicator_shade = output_panel:child("scroll_down_indicator_shade")
	local scroll_down_indicator_arrow = self._panel:child("scroll_down_indicator_arrow")
	local scroll_bar = self._panel:child("scroll_bar")
	scroll_up_indicator_shade:set_top(0)
	scroll_down_indicator_shade:set_bottom(output_panel:h())
	scroll_up_indicator_arrow:set_righttop(output_panel:left() - 2, output_panel:top() + 2)
	scroll_down_indicator_arrow:set_rightbottom(output_panel:left() - 2, output_panel:bottom() - 2)
	local bar_h = scroll_down_indicator_arrow:top() - scroll_up_indicator_arrow:bottom()
	if scroll_panel:h() ~= 0 then
		local old_h = scroll_bar:h()
		scroll_bar:set_h(bar_h * output_panel:h() / scroll_panel:h())
		if old_h ~= scroll_bar:h() then
			self._scroll_bar_box_class:create_sides(scroll_bar:child("scroll_bar_box_panel"), {
				sides = {
					2,
					2,
					0,
					0
				}
			})
		end
	end
	local sh = scroll_panel:h() ~= 0 and scroll_panel:h() or 1
	scroll_bar:set_y(scroll_up_indicator_arrow:bottom() - scroll_panel:y() * (output_panel:h() - scroll_up_indicator_arrow:h() * 2) / sh)
	scroll_bar:set_center_x(scroll_up_indicator_arrow:center_x())
	local visible = scroll_panel:h() > output_panel:h()
	local scroll_up_visible = visible and 0 > scroll_panel:top()
	local scroll_dn_visible = visible and scroll_panel:bottom() > output_panel:h()
	self:_layout_input_panel()
	scroll_bar:set_visible(visible)
	local update_scroll_indicator_box = false
	if scroll_up_indicator_arrow:visible() ~= scroll_up_visible then
		scroll_up_indicator_shade:set_visible(false)
		scroll_up_indicator_arrow:set_visible(scroll_up_visible)
		update_scroll_indicator_box = true
	end
	if scroll_down_indicator_arrow:visible() ~= scroll_dn_visible then
		scroll_down_indicator_shade:set_visible(false)
		scroll_down_indicator_arrow:set_visible(scroll_dn_visible)
		update_scroll_indicator_box = true
	end
	if update_scroll_indicator_box then
		self._scroll_indicator_box_class:create_sides(output_panel, {
			sides = {
				0,
				0,
				scroll_up_visible and 2 or 0,
				scroll_dn_visible and 2 or 0
			}
		})
	end
end
function ChatGui:set_size(x, y)
	ChatGui.super.set_size(self, x, y)
	self:_layout_output_panel()
	self:_layout_input_panel()
end
function ChatGui:input_focus()
	if self._esc_focus_delay then
		self._esc_focus_delay = nil
		return 1
	end
	if self._enter_loose_focus_delay then
		self._enter_loose_focus_delay = nil
		return true
	end
	return self._focus
end
function ChatGui:mouse_moved(x, y)
	if not self._enabled then
		return
	end
	local inside = self._input_panel:inside(x, y)
	self._input_panel:child("focus_indicator"):set_visible(inside or self._focus)
	if self:moved_scroll_bar(x, y) then
		return true, "grab"
	elseif self._panel:child("scroll_bar"):visible() and self._panel:child("scroll_bar"):inside(x, y) or self._panel:child("scroll_down_indicator_arrow"):visible() and self._panel:child("scroll_down_indicator_arrow"):inside(x, y) or self._panel:child("scroll_up_indicator_arrow"):visible() and self._panel:child("scroll_up_indicator_arrow"):inside(x, y) then
		return false, "hand"
	end
	return false, inside and "arrow"
end
function ChatGui:moved_scroll_bar(x, y)
	if self._grabbed_scroll_bar then
		self._current_y = self:scroll_with_bar(y, self._current_y)
		return true
	end
	return false
end
function ChatGui:scroll_with_bar(target_y, current_y)
	local line_height = 22
	local diff = current_y - target_y
	if diff == 0 then
		return current_y
	end
	local dir = diff / math.abs(diff)
	while line_height <= math.abs(current_y - target_y) do
		current_y = current_y - line_height * dir
		if dir > 0 then
			self:scroll_up()
			self:set_scroll_indicators()
		elseif dir < 0 then
			self:scroll_down()
			self:set_scroll_indicators()
		end
	end
	return current_y
end
function ChatGui:mouse_released(o, button, x, y)
	if not self._enabled then
		return
	end
	self:release_scroll_bar()
end
function ChatGui:mouse_pressed(button, x, y)
	if not self._enabled then
		return
	end
	local inside = self._input_panel:inside(x, y)
	if inside then
		self:_on_focus()
		return true
	end
	if self._panel:child("output_panel"):inside(x, y) then
		if button == Idstring("mouse wheel down") then
			if self:mouse_wheel_down(x, y) then
				self:_on_focus()
			end
		elseif button == Idstring("mouse wheel up") then
			if self:mouse_wheel_up(x, y) then
				self:_on_focus()
			end
		elseif button == Idstring("0") and self:check_grab_scroll_panel(x, y) then
			self:_on_focus()
		end
		self:set_scroll_indicators()
		return true
	elseif button == Idstring("0") and self:check_grab_scroll_bar(x, y) then
		self:set_scroll_indicators()
		self:_on_focus()
		return true
	end
	self:_loose_focus()
end
function ChatGui:check_grab_scroll_panel(x, y)
	return false
end
function ChatGui:check_grab_scroll_bar(x, y)
	local scroll_bar = self._panel:child("scroll_bar")
	if scroll_bar:visible() and scroll_bar:inside(x, y) then
		self._grabbed_scroll_bar = true
		self._current_y = y
		return true
	end
	if self._panel:child("scroll_up_indicator_arrow"):visible() and self._panel:child("scroll_up_indicator_arrow"):inside(x, y) then
		self:scroll_up(x, y)
		self._pressing_arrow_up = true
		return true
	end
	if self._panel:child("scroll_down_indicator_arrow"):visible() and self._panel:child("scroll_down_indicator_arrow"):inside(x, y) then
		self:scroll_down(x, y)
		self._pressing_arrow_down = true
		return true
	end
	return false
end
function ChatGui:release_scroll_bar()
	self._pressing_arrow_up = nil
	self._pressing_arrow_down = nil
	if self._grabbed_scroll_bar then
		self._grabbed_scroll_bar = nil
		return true
	end
	return false
end
function ChatGui:scroll_up()
	local output_panel = self._panel:child("output_panel")
	local scroll_panel = output_panel:child("scroll_panel")
	if scroll_panel:h() > output_panel:h() then
		if scroll_panel:top() == 0 then
			self._one_scroll_dn_delay = true
		end
		scroll_panel:set_top(math.min(0, scroll_panel:top() + 22))
		return true
	end
end
function ChatGui:scroll_down()
	local output_panel = self._panel:child("output_panel")
	local scroll_panel = output_panel:child("scroll_panel")
	if scroll_panel:h() > output_panel:h() then
		if scroll_panel:bottom() == output_panel:h() then
			self._one_scroll_up_delay = true
		end
		scroll_panel:set_bottom(math.max(scroll_panel:bottom() - 22, output_panel:h()))
		return true
	end
end
function ChatGui:mouse_wheel_up(x, y)
	if not self._enabled then
		return
	end
	local output_panel = self._panel:child("output_panel")
	local scroll_panel = output_panel:child("scroll_panel")
	if self._one_scroll_up_delay then
		self._one_scroll_up_delay = nil
		return true
	end
	return self:scroll_up()
end
function ChatGui:mouse_wheel_down(x, y)
	if not self._enabled then
		return
	end
	local output_panel = self._panel:child("output_panel")
	local scroll_panel = output_panel:child("scroll_panel")
	if self._one_scroll_dn_delay then
		self._one_scroll_dn_delay = nil
		return true
	end
	return self:scroll_down()
end
function ChatGui:open_page()
end
function ChatGui:close_page()
	self:_loose_focus()
end
function ChatGui:_on_focus()
	if not self._enabled then
		return
	end
	if self._focus then
		return
	end
	local output_panel = self._panel:child("output_panel")
	output_panel:stop()
	output_panel:animate(callback(self, self, "_animate_show_component"), output_panel:alpha())
	self._input_panel:stop()
	self._input_panel:animate(callback(self, self, "_animate_show_input"))
	self._focus = true
	self._input_panel:child("focus_indicator"):set_color(Color(0, 0, 0):with_alpha(0.2))
	self._ws:connect_keyboard(Input:keyboard())
	self._input_panel:key_press(callback(self, self, "key_press"))
	self._input_panel:key_release(callback(self, self, "key_release"))
	self._enter_text_set = false
	self._input_panel:child("input_bg"):animate(callback(self, self, "_animate_input_bg"))
	self:update_caret()
end
function ChatGui:_loose_focus()
	if not self._focus then
		return
	end
	self._one_scroll_up_delay = nil
	self._one_scroll_dn_delay = nil
	self._focus = false
	self._input_panel:child("focus_indicator"):set_color(Color.black:with_alpha(0.2))
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
function ChatGui:_shift()
	local k = Input:keyboard()
	return not k:down("left shift") and not k:down("right shift") and k:has_button("shift") and k:down("shift")
end
function ChatGui.blink(o)
	while true do
		o:set_color(Color(0, 1, 1, 1))
		wait(0.3)
		o:set_color(Color.white)
		wait(0.3)
	end
end
function ChatGui:set_blinking(b)
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
function ChatGui:update_caret()
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
	self._input_panel:child("input_bg"):set_color(Color.black:with_alpha(0.4))
end
function ChatGui:enter_text(o, s)
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
function ChatGui:update_key_down(o, k)
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
function ChatGui:key_release(o, k)
	if self._key_pressed == k then
		self._key_pressed = false
	end
end
function ChatGui:key_press(o, k)
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
function ChatGui:send_message(name, message)
end
function ChatGui:receive_message(name, message, color)
	if not alive(self._panel) then
		return
	end
	local output_panel = self._panel:child("output_panel")
	local scroll_panel = output_panel:child("scroll_panel")
	local len = utf8.len(name) + 1
	local line = scroll_panel:text({
		text = name .. ": " .. message,
		font = tweak_data.menu.pd2_small_font,
		font_size = tweak_data.menu.pd2_small_font_size,
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
	local line_bg = scroll_panel:rect({
		color = Color.black:with_alpha(0.5),
		layer = -1,
		halign = "left",
		hvertical = "top"
	})
	line_bg:set_h(h)
	table.insert(self._lines, {line, line_bg})
	self:_layout_output_panel()
	if not self._focus then
		output_panel:stop()
		output_panel:animate(callback(self, self, "_animate_show_component"), output_panel:alpha())
		output_panel:animate(callback(self, self, "_animate_fade_output"))
	end
end
function ChatGui:_animate_fade_output()
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
function ChatGui:_animate_show_component(panel, start_alpha)
	local TOTAL_T = 0.25
	local t = 0
	start_alpha = start_alpha or 0
	while TOTAL_T > t do
		local dt = coroutine.yield()
		t = t + dt
		panel:set_alpha(start_alpha + t / TOTAL_T * (1 - start_alpha))
	end
	panel:set_alpha(1)
end
function ChatGui:_animate_show_input(input_panel)
	local TOTAL_T = 0.2
	local start_alpha = input_panel:alpha()
	local end_alpha = 1
	over(TOTAL_T, function(p)
		input_panel:set_alpha(math.lerp(start_alpha, end_alpha, p))
	end)
end
function ChatGui:_animate_hide_input(input_panel)
	local TOTAL_T = 0.2
	local start_alpha = input_panel:alpha()
	local end_alpha = 0.7
	over(TOTAL_T, function(p)
		input_panel:set_alpha(math.lerp(start_alpha, end_alpha, p))
	end)
end
function ChatGui:_animate_input_bg(input_bg)
	local t = 0
	while true do
		local dt = coroutine.yield()
		t = t + dt
		local a = 0.75 + (1 + math.sin(t * 200)) / 8
		input_bg:set_alpha(a)
	end
end
function ChatGui:set_output_alpha(alpha)
	self._panel:child("output_panel"):set_alpha(alpha)
end
function ChatGui:close(...)
	self._panel:child("output_panel"):stop()
	self._input_panel:stop()
	self._hud_panel:remove(self._panel)
	managers.chat:unregister_receiver(self._channel_id, self)
end
