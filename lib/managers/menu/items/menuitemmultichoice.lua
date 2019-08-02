core:import("CoreMenuItem")
core:import("CoreMenuItemOption")
MenuItemMultiChoice = MenuItemMultiChoice or class(CoreMenuItem.Item)
MenuItemMultiChoice.TYPE = "multi_choice"
function MenuItemMultiChoice:init(data_node, parameters)
	CoreMenuItem.Item.init(self, data_node, parameters)
	self._type = MenuItemMultiChoice.TYPE
	self._options = {}
	self._current_index = 1
	self._all_options = {}
	if data_node then
		for _, c in ipairs(data_node) do
			local type = c._meta
			if type == "option" then
				local option = CoreMenuItemOption.ItemOption:new(c)
				self:add_option(option)
				local visible_callback = c.visible_callback
				if visible_callback then
					option.visible_callback_names = string.split(visible_callback, " ")
				end
			end
		end
	end
	self._enabled = true
	self:_show_options(nil)
end
function MenuItemMultiChoice:set_enabled(enabled)
	self._enabled = enabled
	self:dirty()
end
function MenuItemMultiChoice:set_callback_handler(callback_handler)
	MenuItemMultiChoice.super.set_callback_handler(self, callback_handler)
end
function MenuItemMultiChoice:visible(...)
	self:_show_options(self._callback_handler)
	return MenuItemMultiChoice.super.visible(self, ...)
end
function MenuItemMultiChoice:_show_options(callback_handler)
	local selected_value = self:selected_option() and self:selected_option():value()
	self._options = {}
	for _, option in ipairs(self._all_options) do
		local show = true
		if callback_handler and option.visible_callback_names then
			for _, id in ipairs(option.visible_callback_names) do
				if not callback_handler[id](callback_handler, option) then
					show = false
				else
				end
			end
		end
		if show then
			table.insert(self._options, option)
		end
	end
	if selected_value then
		self:set_current_index(1)
		self:set_value(selected_value)
	end
end
function MenuItemMultiChoice:add_option(option)
	table.insert(self._all_options, option)
end
function MenuItemMultiChoice:options()
	return self._options
end
function MenuItemMultiChoice:selected_option()
	return self._options[self._current_index]
end
function MenuItemMultiChoice:current_index()
	return self._current_index
end
function MenuItemMultiChoice:set_current_index(index)
	self._current_index = index
	self:dirty()
end
function MenuItemMultiChoice:set_value(value)
	for i, option in ipairs(self._options) do
		if option:parameters().value == value then
			self._current_index = i
		else
		end
	end
	self:dirty()
end
function MenuItemMultiChoice:value()
	local value = ""
	local selected_option = self:selected_option()
	if selected_option then
		value = selected_option:parameters().value
	end
	return value
end
function MenuItemMultiChoice:_highest_option_index()
	local index = 1
	for i, option in ipairs(self._options) do
		if not option:parameters().exclude then
			index = i
		end
	end
	return index
end
function MenuItemMultiChoice:_lowest_option_index()
	for i, option in ipairs(self._options) do
		if not option:parameters().exclude then
			return i
		end
	end
end
function MenuItemMultiChoice:next()
	if not self._enabled then
		return
	end
	if #self._options < 2 then
		return
	end
	if self._current_index == self:_highest_option_index() then
		return
	end
	repeat
		self._current_index = self._current_index == #self._options and 1 or self._current_index + 1
	until not self._options[self._current_index]:parameters().exclude
	return true
end
function MenuItemMultiChoice:previous()
	if not self._enabled then
		return
	end
	if #self._options < 2 then
		return
	end
	if self._current_index == self:_lowest_option_index() then
		return
	end
	repeat
		self._current_index = self._current_index == 1 and #self._options or self._current_index - 1
	until not self._options[self._current_index]:parameters().exclude
	return true
end
function MenuItemMultiChoice:left_arrow_visible()
	return self._current_index > self:_lowest_option_index() and self._enabled
end
function MenuItemMultiChoice:right_arrow_visible()
	return self._current_index < self:_highest_option_index() and self._enabled
end
function MenuItemMultiChoice:arrow_visible()
	return #self._options > 1
end
function MenuItemMultiChoice:setup_gui(node, row_item)
	local right_align = node._right_align(node)
	row_item.gui_panel = node.item_panel:panel({
		w = node.item_panel:w()
	})
	row_item.gui_text = node._text_item_part(node, row_item, row_item.gui_panel, right_align, row_item.align)
	row_item.gui_text:set_wrap(true)
	row_item.gui_text:set_word_wrap(true)
	local choice_text_align = row_item.align == "left" and "right" or row_item.align == "right" and "left" or row_item.align
	row_item.choice_panel = row_item.gui_panel:panel({
		w = node.item_panel:w()
	})
	row_item.choice_text = row_item.choice_panel:text({
		font_size = row_item.font_size,
		x = 0,
		y = 0,
		align = "center",
		vertical = "center",
		font = row_item.font,
		color = node.row_item_hightlight_color,
		layer = node.layers.items,
		blend_mode = node.row_item_blend_mode,
		text = utf8.to_upper(""),
		render_template = Idstring("VertexColorTextured")
	})
	local w = 20
	local h = 20
	local base = 20
	local height = 15
	row_item.arrow_left = row_item.gui_panel:bitmap({
		texture = "guis/textures/menu_arrows",
		texture_rect = {
			0,
			0,
			24,
			24
		},
		color = Color(0.5, 0.5, 0.5),
		visible = self:arrow_visible(),
		x = 0,
		y = 0,
		layer = node.layers.items
	})
	row_item.arrow_right = row_item.gui_panel:bitmap({
		texture = "guis/textures/menu_arrows",
		texture_rect = {
			24,
			0,
			-24,
			24
		},
		color = Color(0.5, 0.5, 0.5),
		visible = self:arrow_visible(),
		x = 0,
		y = 0,
		layer = node.layers.items
	})
	if self:info_panel() == "lobby_campaign" then
		node._create_lobby_campaign(node, row_item)
	elseif self:info_panel() == "lobby_difficulty" then
		node._create_lobby_difficulty(node, row_item)
	elseif row_item.help_text then
	end
	self:_layout(node, row_item)
	return true
end
function MenuItemMultiChoice:reload(row_item, node)
	if not row_item then
		return
	end
	if node.localize_strings and self:selected_option():parameters().localize ~= false then
		row_item.option_text = managers.localization:text(self:selected_option():parameters().text_id)
	else
		row_item.option_text = self:selected_option():parameters().text_id
	end
	row_item.choice_text:set_text(utf8.to_upper(row_item.option_text))
	if self:selected_option():parameters().stencil_image then
		managers.menu:active_menu().renderer:set_stencil_image(self:selected_option():parameters().stencil_image)
	end
	if self:selected_option():parameters().stencil_align then
		managers.menu:active_menu().renderer:set_stencil_align(self:selected_option():parameters().stencil_align, self:selected_option():parameters().stencil_align_percent)
	end
	row_item.arrow_left:set_visible(self:arrow_visible())
	row_item.arrow_right:set_visible(self:arrow_visible())
	row_item.arrow_left:set_color(self:left_arrow_visible() and tweak_data.screen_color_blue or tweak_data.screen_color_blue:with_alpha(0.5))
	row_item.arrow_right:set_color(self:right_arrow_visible() and tweak_data.screen_color_blue or tweak_data.screen_color_blue:with_alpha(0.5))
	if self:info_panel() == "lobby_campaign" then
		node._reload_lobby_campaign(node, row_item)
	elseif self:info_panel() == "lobby_difficulty" then
		node._reload_lobby_difficulty(node, row_item)
	end
	return true
end
function MenuItemMultiChoice:highlight_row_item(node, row_item, mouse_over)
	row_item.gui_text:set_color(row_item.color)
	row_item.arrow_left:set_image("guis/textures/menu_arrows", 24, 0, 24, 24)
	row_item.arrow_right:set_image("guis/textures/menu_arrows", 48, 0, -24, 24)
	row_item.arrow_left:set_color(self:left_arrow_visible() and tweak_data.screen_color_blue or tweak_data.screen_color_blue:with_alpha(0.5))
	row_item.arrow_right:set_color(self:right_arrow_visible() and tweak_data.screen_color_blue or tweak_data.screen_color_blue:with_alpha(0.5))
	if self:info_panel() == "lobby_campaign" then
		node._highlight_lobby_campaign(node, row_item)
	elseif self:info_panel() == "lobby_difficulty" then
		node._highlight_lobby_difficulty(node, row_item)
	elseif row_item.gui_info_panel then
		row_item.gui_info_panel:set_visible(true)
	end
	return true
end
function MenuItemMultiChoice:fade_row_item(node, row_item, mouse_over)
	row_item.gui_text:set_color(node.row_item_color)
	row_item.arrow_left:set_image("guis/textures/menu_arrows", 0, 0, 24, 24)
	row_item.arrow_right:set_image("guis/textures/menu_arrows", 24, 0, -24, 24)
	row_item.arrow_left:set_color(self:left_arrow_visible() and tweak_data.screen_color_blue or tweak_data.screen_color_blue:with_alpha(0.5))
	row_item.arrow_right:set_color(self:right_arrow_visible() and tweak_data.screen_color_blue or tweak_data.screen_color_blue:with_alpha(0.5))
	if self:info_panel() == "lobby_campaign" then
		node._fade_lobby_campaign(node, row_item)
	elseif self:info_panel() == "lobby_difficulty" then
		node._fade_lobby_difficulty(node, row_item)
	elseif row_item.gui_info_panel then
		row_item.gui_info_panel:set_visible(false)
	end
	return true
end
local xl_pad = 64
function MenuItemMultiChoice:_layout(node, row_item)
	local safe_rect = managers.gui_data:scaled_size()
	local right_align = node._right_align(node)
	local left_align = node._left_align(node)
	if self:parameters().filter then
	end
	row_item.gui_panel:set_width(safe_rect.width - node._mid_align(node))
	row_item.gui_panel:set_x(node._mid_align(node))
	row_item.arrow_right:set_size(24 * tweak_data.scale.multichoice_arrow_multiplier, 24 * tweak_data.scale.multichoice_arrow_multiplier)
	row_item.arrow_left:set_size(24 * tweak_data.scale.multichoice_arrow_multiplier, 24 * tweak_data.scale.multichoice_arrow_multiplier)
	if row_item.align == "right" then
		row_item.arrow_left:set_left(right_align - row_item.gui_panel:x() + (self:parameters().expand_value or 0))
		row_item.arrow_right:set_left(row_item.arrow_left:right() + 2 * (1 - tweak_data.scale.multichoice_arrow_multiplier))
	else
		row_item.arrow_right:set_right(row_item.gui_panel:w())
		row_item.arrow_left:set_right(row_item.arrow_right:left() + 2 * (1 - tweak_data.scale.multichoice_arrow_multiplier))
	end
	local x, y, w, h = row_item.gui_text:text_rect()
	row_item.gui_text:set_h(h)
	row_item.gui_text:set_width(w + 5)
	row_item.choice_panel:set_w(row_item.gui_panel:width() * 0.4)
	row_item.choice_panel:set_h(h)
	if row_item.align == "right" then
		row_item.choice_panel:set_left(row_item.arrow_left:right() + node._align_line_padding)
		row_item.arrow_right:set_left(row_item.choice_panel:right())
	else
		row_item.choice_panel:set_right(row_item.arrow_right:left() - node._align_line_padding)
		row_item.arrow_left:set_right(row_item.choice_panel:left())
	end
	row_item.choice_text:set_w(row_item.choice_panel:w())
	row_item.choice_text:set_h(h)
	row_item.choice_text:set_left(0)
	row_item.arrow_right:set_center_y(row_item.choice_panel:center_y())
	row_item.arrow_left:set_center_y(row_item.choice_panel:center_y())
	if row_item.align == "right" then
		row_item.gui_text:set_right(row_item.gui_panel:w())
	else
		row_item.gui_text:set_left(node._right_align(node) - row_item.gui_panel:x() + (self:parameters().expand_value or 0))
	end
	row_item.gui_text:set_height(h)
	row_item.gui_panel:set_height(h)
	if row_item.gui_info_panel then
		node._align_item_gui_info_panel(node, row_item.gui_info_panel)
		if self:info_panel() == "lobby_campaign" then
			node._align_lobby_campaign(node, row_item)
		elseif self:info_panel() == "lobby_difficulty" then
			node._align_lobby_difficulty(node, row_item)
		else
			node._align_info_panel(node, row_item)
		end
	end
	return true
end
