core:import("CoreMenuItem")
core:import("CoreMenuItemOption")
MenuItemMaskExpand = MenuItemMaskExpand or class(MenuItemExpand)
MenuItemMaskExpand.TYPE = "weapon_expand"
function MenuItemMaskExpand:init(data_node, parameters)
	MenuItemMaskExpand.super.init(self, data_node, parameters)
	self._type = MenuItemMaskExpand.TYPE
	local data_node = {
		type = "MenuItemMaskAction",
		name = self._parameters.mask_id .. "buy",
		text_id = "menu_buy",
		action_type = "buy",
		callback = "buy_mask",
		visible_callback = "can_buy_mask",
		mask_id = self._parameters.mask_id
	}
	local item = CoreMenuNode.MenuNode.create_item(self, data_node)
	self:add_item(item)
	local data_node = {
		type = "MenuItemMaskAction",
		name = self._parameters.mask_id .. "equip",
		text_id = "menu_equip",
		action_type = "equip",
		callback = "equip_mask",
		visible_callback = "owns_mask",
		mask_id = self._parameters.mask_id
	}
	local item = CoreMenuNode.MenuNode.create_item(self, data_node)
	self:add_item(item)
end
function MenuItemMaskExpand:expand_value()
	return 0
end
function MenuItemMaskExpand:toggle(...)
	if not self:parameter("unlocked") then
	end
	MenuItemMaskExpand.super.toggle(self, ...)
end
function MenuItemMaskExpand:can_expand()
	return self:parameter("unlocked")
end
function MenuItemMaskExpand:setup_gui(node, row_item)
	local scaled_size = managers.gui_data:scaled_size()
	row_item.gui_panel = node.item_panel:panel({
		w = node.item_panel:w()
	})
	row_item.mask_name = node._text_item_part(node, row_item, row_item.gui_panel, node.align_line_padding(node))
	row_item.mask_name:set_font_size(22)
	local _, _, w, h = row_item.mask_name:text_rect()
	row_item.mask_name:set_h(h)
	row_item.gui_panel:set_left(node._mid_align(node) + self._parameters.expand_value)
	row_item.gui_panel:set_w(scaled_size.width - row_item.gui_panel:left())
	row_item.gui_panel:set_h(h)
	local texture, rect = tweak_data.hud_icons:get_icon_data("icon_equipped")
	row_item.equipped_icon = row_item.gui_panel:parent():bitmap({
		visible = self._parameters.equipped,
		texture = texture,
		texture_rect = rect,
		layer = node.layers.items
	})
	row_item.equipped_icon:set_center(h / 2, row_item.gui_panel:y() + h / 2)
	row_item.equipped_icon:set_right(row_item.gui_panel:x())
	local texture, rect = tweak_data.hud_icons:get_icon_data("icon_locked")
	row_item.locked_icon = row_item.gui_panel:bitmap({
		visible = not self._parameters.unlocked,
		texture = texture,
		texture_rect = rect,
		layer = node.layers.items
	})
	row_item.locked_icon:set_center(h / 2, h / 2)
	row_item.locked_icon:set_right(row_item.locked_icon:parent():w() - 4)
	if row_item.align == "right" then
		row_item.mask_name:set_right(row_item.locked_icon:left() - 10)
	end
	row_item.expanded_indicator = row_item.gui_panel:parent():bitmap({
		visible = false,
		texture = "guis/textures/menu_selected",
		x = 0,
		y = 0,
		layer = node.layers.items - 1
	})
	row_item.expanded_indicator:set_w(row_item.gui_panel:w())
	row_item.expanded_indicator:set_height(64 * row_item.gui_panel:height() / 32)
	row_item.bottom_line = row_item.gui_panel:parent():bitmap({
		texture = "guis/textures/headershadowdown",
		layer = node.layers.items + 1,
		color = Color.white,
		w = row_item.gui_panel:w(),
		y = 100
	})
end
function MenuItemMaskExpand:on_item_position(row_item, node)
	row_item.expanded_indicator:set_position(row_item.gui_panel:position())
	row_item.expanded_indicator:set_center_y(row_item.gui_panel:center_y())
	row_item.equipped_icon:set_center_y(row_item.gui_panel:center_y())
	row_item.expand_line:set_lefttop(row_item.gui_panel:leftbottom())
	row_item.expand_line:set_left(row_item.expand_line:left())
end
function MenuItemMaskExpand:on_item_positions_done(row_item, node)
	if self:expanded() then
		local child = self._items[#self._items]
		local row_child = node.row_item(node, child)
		if row_child then
			row_item.bottom_line:set_lefttop(row_child.gui_panel:leftbottom())
			row_item.bottom_line:set_top(row_item.bottom_line:top() - 1)
		end
	end
end
function MenuItemMaskExpand:on_buy(node)
	self:update_expanded_items(node)
end
function MenuItemMaskExpand:on_equip(node)
	for _, item in ipairs(self:parameters().parent_item:items()) do
		local row_item = node:row_item(item)
		item:reload(row_item, node)
	end
end
function MenuItemMaskExpand:on_repair(node, condition)
	local row_item = node:row_item(self)
	self._parameters.condition = condition
end
function MenuItemMaskExpand:_repair_circle_color(condition)
	return condition < 4 and Color(1, 0.5, 0) or Color.white
end
function MenuItemMaskExpand:get_h(row_item, node)
	local h = row_item.gui_panel:h()
	if self:expanded() then
		print(#self:items())
		for _, item in ipairs(self:items()) do
			local child_row_item = node:row_item(item)
			if child_row_item then
				h = h + child_row_item.gui_panel:h()
			end
		end
	end
	return h
end
function MenuItemMaskExpand:reload(row_item, node)
	MenuItemMaskExpand.super.reload(self, row_item, node)
	row_item.expanded_indicator:set_position(row_item.gui_panel:position())
	row_item.expanded_indicator:set_center_y(row_item.gui_panel:center_y())
	row_item.expanded_indicator:set_visible(self:expanded())
	row_item.expand_line:set_w(row_item.gui_panel:w())
	row_item.bottom_line:set_visible(self:expanded() and self:parameter("unlocked"))
	self._parameters.equipped = Global.blackmarket_manager.masks[self:parameter("mask_id")].equipped
	row_item.equipped_icon:set_visible(self._parameters.equipped)
	if self:expanded() then
		row_item.expanded_indicator:set_color(node.row_item_color)
		row_item.menu_unselected:set_color(node.row_item_hightlight_color)
	else
		row_item.menu_unselected:set_color(node.row_item_color)
	end
	self:_set_row_item_state(node, row_item)
end
function MenuItemMaskExpand:highlight_row_item(node, row_item, mouse_over)
	self:_set_row_item_state(node, row_item)
	row_item.mask_name:set_color(row_item.color)
	row_item.mask_name:set_font(tweak_data.menu.default_font_no_outline_id)
end
function MenuItemMaskExpand:fade_row_item(node, row_item, mouse_over)
	self:_set_row_item_state(node, row_item)
end
function MenuItemMaskExpand:_set_row_item_state(node, row_item)
	if self:expanded() or row_item.highlighted then
		row_item.mask_name:set_color(node.row_item_hightlight_color)
		row_item.mask_name:set_font(tweak_data.menu.default_font_no_outline_id)
	else
		row_item.mask_name:set_color(self:parameter("owned") and self:parameter("unlocked") and row_item.color or node.row_item_color)
		row_item.mask_name:set_font(tweak_data.menu.default_font_id)
	end
end
function MenuItemMaskExpand:on_delete_row_item(row_item, ...)
	MenuItemMaskExpand.super.on_delete_row_item(self, row_item, ...)
	row_item.gui_panel:parent():remove(row_item.equipped_icon)
	row_item.gui_panel:parent():remove(row_item.bottom_line)
end
MenuItemMaskAction = MenuItemMaskAction or class(MenuItemExpandAction)
