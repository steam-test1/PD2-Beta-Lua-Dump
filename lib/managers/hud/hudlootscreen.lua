require("lib/managers/menu/MenuBackdropGUI")
HUDLootScreen = HUDLootScreen or class()
function HUDLootScreen:init(hud, workspace, saved_lootdrop, saved_selected, saved_chosen)
	self._backdrop = MenuBackdropGUI:new(workspace)
	self._backdrop:create_black_borders()
	self._active = false
	self._hud = hud
	self._workspace = workspace
	local massive_font = tweak_data.menu.pd2_massive_font
	local large_font = tweak_data.menu.pd2_large_font
	local medium_font = tweak_data.menu.pd2_medium_font
	local small_font = tweak_data.menu.pd2_small_font
	local massive_font_size = tweak_data.menu.pd2_massive_font_size
	local large_font_size = tweak_data.menu.pd2_large_font_size
	local medium_font_size = tweak_data.menu.pd2_medium_font_size
	local small_font_size = tweak_data.menu.pd2_small_font_size
	self._background_layer_safe = self._backdrop:get_new_background_layer()
	self._background_layer_full = self._backdrop:get_new_background_layer()
	self._foreground_layer_safe = self._backdrop:get_new_foreground_layer()
	self._foreground_layer_full = self._backdrop:get_new_foreground_layer()
	self._baselayer_two = self._backdrop:get_new_base_layer()
	self._backdrop:set_panel_to_saferect(self._background_layer_safe)
	self._backdrop:set_panel_to_saferect(self._foreground_layer_safe)
	self._callback_handler = {}
	local lootscreen_string = managers.localization:to_upper_text("menu_l_lootscreen")
	local loot_text = self._foreground_layer_safe:text({
		name = "loot_text",
		text = lootscreen_string,
		align = "center",
		vertical = "top",
		font_size = large_font_size,
		font = large_font,
		color = tweak_data.screen_colors.text
	})
	self:make_fine_text(loot_text)
	local bg_text = self._background_layer_full:text({
		text = loot_text:text(),
		h = 90,
		align = "left",
		vertical = "top",
		font_size = massive_font_size,
		font = massive_font,
		color = tweak_data.screen_colors.button_stage_3,
		alpha = 0.4
	})
	self:make_fine_text(bg_text)
	local x, y = managers.gui_data:safe_to_full_16_9(loot_text:world_x(), loot_text:world_center_y())
	bg_text:set_world_left(loot_text:world_x())
	bg_text:set_world_center_y(loot_text:world_center_y())
	bg_text:move(-13, 9)
	local icon_path, texture_rect = tweak_data.hud_icons:get_icon_data("downcard_overkill_deck")
	self._downcard_icon_path = icon_path
	self._downcard_texture_rect = texture_rect
	self._hud_panel = self._foreground_layer_safe:panel()
	self._hud_panel:set_y(25)
	self._hud_panel:set_h(self._hud_panel:h() - 25 - 150)
	self._peer_data = {}
	self._peers_panel = self._hud_panel:panel({})
	for i = 1, 4 do
		self:create_peer(self._peers_panel, i)
	end
	self._num_visible = 1
	self:set_num_visible(self:get_local_peer_id())
	self._lootdrops = self._lootdrops or {}
	if saved_lootdrop then
		for _, lootdrop in ipairs(saved_lootdrop) do
			self:feed_lootdrop(lootdrop)
		end
	end
	if saved_selected then
		for peer_id, selected in pairs(saved_selected) do
			self:set_selected(peer_id, selected)
		end
	end
	if saved_chosen then
		for peer_id, card_id in pairs(saved_chosen) do
			self:begin_choose_card(peer_id, card_id)
		end
	end
	local local_peer_id = self:get_local_peer_id()
	local panel = self._peers_panel:child("peer" .. tostring(local_peer_id))
	local peer_info_panel = panel:child("peer_info")
	local peer_name = peer_info_panel:child("peer_name")
	peer_name:set_text(tostring(managers.network.account:username() or managers.blackmarket:get_preferred_character_real_name()) .. " (" .. managers.experience:current_level() .. ")")
	self:make_fine_text(peer_name)
	peer_name:set_right(peer_info_panel:w())
	panel:set_alpha(1)
	peer_info_panel:show()
	panel:child("card_info"):hide()
end
function HUDLootScreen:create_peer(peers_panel, peer_id)
	local massive_font = tweak_data.menu.pd2_massive_font
	local large_font = tweak_data.menu.pd2_large_font
	local medium_font = tweak_data.menu.pd2_medium_font
	local small_font = tweak_data.menu.pd2_small_font
	local massive_font_size = tweak_data.menu.pd2_massive_font_size
	local large_font_size = tweak_data.menu.pd2_large_font_size
	local medium_font_size = tweak_data.menu.pd2_medium_font_size
	local small_font_size = tweak_data.menu.pd2_small_font_size
	local color = tweak_data.chat_colors[peer_id]
	local is_local_peer = peer_id == self:get_local_peer_id()
	self._peer_data[peer_id] = {}
	self._peer_data[peer_id].selected = 2
	self._peer_data[peer_id].wait_t = false
	self._peer_data[peer_id].ready = false
	self._peer_data[peer_id].active = false
	local panel = peers_panel:panel({
		name = "peer" .. tostring(peer_id),
		x = 0,
		y = (peer_id - 1) * 110,
		w = peers_panel:w(),
		h = 110
	})
	local peer_info_panel = panel:panel({name = "peer_info", w = 255})
	local peer_name = peer_info_panel:text({
		name = "peer_name",
		font = medium_font,
		font_size = medium_font_size - 1,
		text = " ",
		h = medium_font_size,
		w = 1,
		color = color,
		blend_mode = "add"
	})
	self:make_fine_text(peer_name)
	peer_name:set_right(peer_info_panel:w())
	peer_name:set_center_y(peer_info_panel:h() * 0.5)
	local max_quality = peer_info_panel:text({
		name = "max_quality",
		font = small_font,
		font_size = small_font_size - 1,
		text = " ",
		h = medium_font_size,
		w = 1,
		color = tweak_data.screen_colors.text,
		blend_mode = "add",
		visible = false
	})
	self:make_fine_text(max_quality)
	max_quality:set_right(peer_info_panel:w())
	max_quality:set_top(peer_name:bottom())
	local card_info_panel = panel:panel({name = "card_info", w = 300})
	card_info_panel:set_right(panel:w())
	local main_text = card_info_panel:text({
		name = "main_text",
		font = medium_font,
		font_size = medium_font_size,
		text = managers.localization:to_upper_text(is_local_peer and "menu_l_choose_card_local" or "menu_l_choose_card_peer"),
		blend_mode = "add",
		wrap = true,
		word_wrap = true
	})
	local quality_text = card_info_panel:text({
		name = "quality_text",
		font = small_font,
		font_size = small_font_size,
		text = " ",
		blend_mode = "add",
		visible = false
	})
	local global_value_text = card_info_panel:text({
		name = "global_value_text",
		font = small_font,
		font_size = small_font_size,
		text = managers.localization:to_upper_text("menu_l_infamous"),
		color = tweak_data.lootdrop.global_values.infamous.color,
		blend_mode = "add"
	})
	global_value_text:hide()
	local _, _, _, hh = main_text:text_rect()
	main_text:set_h(hh + 2)
	self:make_fine_text(quality_text)
	self:make_fine_text(global_value_text)
	main_text:set_y(0)
	quality_text:set_y(main_text:bottom())
	global_value_text:set_y(main_text:bottom())
	card_info_panel:set_h(main_text:bottom())
	card_info_panel:set_center_y(panel:h() * 0.5)
	local card_nums = {
		"joker",
		"two",
		"three",
		"four",
		"five",
		"six",
		"seven",
		"eight",
		"nine",
		"ace"
	}
	local total_cards_w = panel:w() - peer_info_panel:w() - card_info_panel:w() - 10
	local card_w = math.round((total_cards_w - 10) / 3)
	for i = 1, 3 do
		local card_panel = panel:panel({
			name = "card" .. i,
			x = peer_info_panel:right() + (i - 1) * card_w + 10,
			y = 10,
			w = card_w - 2.5,
			h = panel:h() - 20,
			halign = "scale",
			valign = "scale"
		})
		local downcard = card_panel:bitmap({
			name = "downcard",
			texture = self._downcard_icon_path,
			texture_rect = self._downcard_texture_rect,
			w = math.round(0.7111111 * card_panel:h()),
			h = card_panel:h(),
			blend_mode = "add",
			rotation = math.random(4) - 2,
			layer = 1,
			halign = "scale",
			valign = "scale"
		})
		if downcard:rotation() == 0 then
			downcard:set_rotation(1)
		end
		if not is_local_peer then
			downcard:set_size(math.round(0.7111111 * card_panel:h() * 0.75), math.round(card_panel:h() * 0.75))
		end
		downcard:set_center(card_panel:w() * 0.5, card_panel:h() * 0.5)
		local bg = card_panel:bitmap({
			name = "bg",
			texture = self._downcard_icon_path,
			texture_rect = self._downcard_texture_rect,
			color = tweak_data.screen_colors.button_stage_3,
			halign = "scale",
			valign = "scale"
		})
		bg:set_rotation(downcard:rotation())
		bg:set_shape(downcard:shape())
		local inside_card_check = panel:panel({
			name = "inside_check_card" .. tostring(i),
			w = 100,
			h = 100
		})
		inside_card_check:set_center(card_panel:center())
		card_panel:hide()
	end
	local box = BoxGuiObject:new(panel:panel({
		x = peer_info_panel:right() + 5,
		y = 5,
		w = total_cards_w,
		h = panel:h() - 10
	}), {
		sides = {
			1,
			1,
			1,
			1
		}
	})
	if not is_local_peer then
		box:set_color(tweak_data.screen_colors.item_stage_2)
	end
	card_info_panel:hide()
	peer_info_panel:hide()
	panel:set_alpha(0)
end
function HUDLootScreen:set_num_visible(peers_num)
	self._num_visible = math.max(self._num_visible, peers_num)
	for i = 1, 4 do
		self._peers_panel:child("peer" .. i):set_visible(i <= self._num_visible)
	end
	self._peers_panel:set_h(self._num_visible * 110)
	self._peers_panel:set_center_y(self._hud_panel:h() * 0.5)
	if managers.menu:is_console() and self._num_visible >= 4 then
		self._peers_panel:move(0, 30)
	end
end
function HUDLootScreen:make_fine_text(text)
	local x, y, w, h = text:text_rect()
	text:set_size(w, h)
	text:set_position(math.round(text:x()), math.round(text:y()))
end
function HUDLootScreen:create_selected_panel(peer_id)
	local panel = self._peers_panel:child("peer" .. peer_id)
	local selected_panel = panel:panel({
		name = "selected_panel",
		w = 100,
		h = 100,
		layer = -1
	})
	local glow_circle = selected_panel:bitmap({
		texture = "guis/textures/pd2/crimenet_marker_glow",
		w = 200,
		h = 200,
		blend_mode = "add",
		color = tweak_data.screen_colors.button_stage_3,
		alpha = 0.4,
		rotation = 360
	})
	local glow_stretch = selected_panel:bitmap({
		texture = "guis/textures/pd2/crimenet_marker_glow",
		w = 500,
		h = 200,
		blend_mode = "add",
		color = tweak_data.screen_colors.button_stage_3,
		alpha = 0.4,
		rotation = 360
	})
	glow_circle:set_center(selected_panel:w() * 0.5, selected_panel:h() * 0.5)
	glow_stretch:set_center(selected_panel:w() * 0.5, selected_panel:h() * 0.5)
	local anim_func = function(o)
		while true do
			over(1, function(p)
				o:set_alpha(math.sin(p * 180 % 180) * 0.2 + 0.6)
			end)
		end
	end
	selected_panel:animate(anim_func)
	return selected_panel
end
function HUDLootScreen:set_selected(peer_id, selected)
	local panel = self._peers_panel:child("peer" .. peer_id)
	local selected_panel = panel:child("selected_panel") or self:create_selected_panel(peer_id)
	local card_panel = panel:child("card" .. selected)
	selected_panel:set_center(card_panel:center())
	self._peer_data[peer_id].selected = selected
	local is_local_peer = peer_id == self:get_local_peer_id()
	local aspect = 0.7111111
	for i = 1, 3 do
		local card_panel = panel:child("card" .. i)
		local downcard = card_panel:child("downcard")
		local bg = card_panel:child("bg")
		local cx, cy = downcard:center()
		local size = card_panel:h() * (i == selected and 1.15 or 0.9) * (is_local_peer and 1 or 0.75)
		bg:set_color(tweak_data.screen_colors[i == selected and "button_stage_2" or "button_stage_3"])
		downcard:set_size(math.round(aspect * size), math.round(size))
		downcard:set_center(cx, cy)
		downcard:set_alpha(is_local_peer and 1 or 0.58)
		bg:set_alpha(1)
		bg:set_shape(downcard:shape())
	end
end
function HUDLootScreen:add_callback(key, clbk)
	self._callback_handler[key] = clbk
end
function HUDLootScreen:clear_other_peers(peer_id)
	peer_id = peer_id or self:get_local_peer_id()
	for i = 1, 4 do
		if i ~= peer_id then
			self:remove_peer(i)
		end
	end
end
function HUDLootScreen:check_all_ready()
	local ready = true
	for i = 1, 4 do
		if self._peer_data[i].active and ready then
			ready = self._peer_data[i].ready
		end
	end
	return ready
end
function HUDLootScreen:remove_peer(peer_id, reason)
	Application:debug("HUDLootScreen:remove_peer( peer_id, reason )", peer_id, reason)
	local panel = self._peers_panel:child("peer" .. tostring(peer_id))
	panel:stop()
	panel:child("card_info"):hide()
	panel:child("peer_info"):hide()
	panel:child("card1"):stop()
	panel:child("card2"):stop()
	panel:child("card3"):stop()
	panel:child("card1"):hide()
	panel:child("card2"):hide()
	panel:child("card3"):hide()
	if panel:child("item") then
		panel:child("item"):stop()
		panel:child("item"):hide()
	end
	if panel:child("selected_panel") then
		panel:child("selected_panel"):hide()
	end
	self._peer_data[peer_id] = {}
	self._peer_data[peer_id].active = false
end
function HUDLootScreen:hide()
	if self._active then
		return
	end
	self._backdrop:hide()
	if self._video then
		managers.video:remove_video(self._video)
		self._video:parent():remove(self._video)
		self._video = nil
	end
	if self._sound_listener then
		self._sound_listener:delete()
		self._sound_listener = nil
	end
	if self._sound_source then
		self._sound_source:stop()
		self._sound_source:delete()
		self._sound_source = nil
	end
end
function HUDLootScreen:show()
	if not self._video and SystemInfo:platform() ~= Idstring("X360") then
		local variant = math.random(8)
		self._video = self._baselayer_two:video({
			video = "movies/lootdrop" .. tostring(variant),
			loop = false,
			speed = 1,
			blend_mode = "add",
			alpha = 0.2
		})
		managers.video:add_video(self._video)
	end
	self._backdrop:show()
	self._active = true
	if not self._sound_listener then
		self._sound_listener = SoundDevice:create_listener("lobby_menu")
		self._sound_listener:set_position(Vector3(0, -50000, 0))
		self._sound_listener:activate(true)
	end
	if not self._sound_source then
		self._sound_source = SoundDevice:create_source("HUDLootScreen")
		self._sound_source:post_event("music_loot_drop")
	end
	local fade_rect = self._foreground_layer_full:rect({
		layer = 10000,
		color = Color.black
	})
	local function fade_out_anim(o)
		over(0.5, function(p)
			o:set_alpha(1 - p)
		end)
		fade_rect:parent():remove(fade_rect)
	end
	fade_rect:animate(fade_out_anim)
	managers.menu_component:lootdrop_is_now_active()
end
function HUDLootScreen:is_active()
	return self._active
end
function HUDLootScreen:update_layout()
	self._backdrop:_set_black_borders()
end
function HUDLootScreen:feed_lootdrop(lootdrop_data)
	Application:debug(inspect(lootdrop_data))
	if not self:is_active() then
		self:show()
	end
	local peer = lootdrop_data[1]
	local peer_id = peer and peer:id() or 1
	local is_local_peer = self:get_local_peer_id() == peer_id
	if is_local_peer then
	else
		local peer_name_string = tostring(managers.network.account:username() or managers.blackmarket:get_preferred_character_real_name()) or peer and peer:name() or ""
	end
	local player_level = is_local_peer and managers.experience:current_level() or peer and peer:level() or 0
	local global_value = lootdrop_data[2]
	local item_category = lootdrop_data[3]
	local item_id = lootdrop_data[4]
	local max_pc = lootdrop_data[5]
	local item_pc = lootdrop_data[6]
	local left_pc = lootdrop_data[7]
	local right_pc = lootdrop_data[8]
	self._peer_data[peer_id].lootdrops = lootdrop_data
	self._peer_data[peer_id].active = true
	local panel = self._peers_panel:child("peer" .. tostring(peer_id))
	local peer_info_panel = panel:child("peer_info")
	local peer_name = peer_info_panel:child("peer_name")
	local max_quality = peer_info_panel:child("max_quality")
	peer_name:set_text(peer_name_string .. " (" .. player_level .. ")")
	max_quality:set_text(managers.localization:to_upper_text("menu_l_max_quality", {quality = max_pc}))
	self:make_fine_text(peer_name)
	self:make_fine_text(max_quality)
	peer_name:set_right(peer_info_panel:w())
	max_quality:set_right(peer_info_panel:w())
	peer_info_panel:show()
	panel:child("card_info"):show()
	for i = 1, 3 do
		panel:child("card" .. i):show()
	end
	local anim_fadein = function(o)
		over(1, function(p)
			o:set_alpha(p)
		end)
	end
	panel:animate(anim_fadein)
	local item_panel = panel:panel({
		name = "item",
		w = panel:h(),
		h = panel:h(),
		layer = 2
	})
	item_panel:hide()
	local category = item_category
	if category == "weapon_mods" then
		category = "mods"
	end
	if category == "colors" then
		local colors = tweak_data.blackmarket.colors[item_id].colors
		local bg = item_panel:bitmap({
			texture = "guis/textures/pd2/blackmarket/icons/colors/color_bg",
			w = panel:h(),
			h = panel:h(),
			layer = 1
		})
		local c1 = item_panel:bitmap({
			texture = "guis/textures/pd2/blackmarket/icons/colors/color_01",
			w = panel:h(),
			h = panel:h(),
			layer = 0
		})
		local c2 = item_panel:bitmap({
			texture = "guis/textures/pd2/blackmarket/icons/colors/color_02",
			w = panel:h(),
			h = panel:h(),
			layer = 0
		})
		c1:set_color(colors[1])
		c2:set_color(colors[2])
	else
		local texture_loaded_clbk = callback(self, self, "texture_loaded_clbk", {
			peer_id,
			category == "textures" and true or false
		})
		local texture_path
		if category == "textures" then
			texture_path = tweak_data.blackmarket.textures[item_id].texture
			if not texture_path then
				Application:error("Pattern missing", "PEER", peer_id)
				return
			end
		elseif category == "cash" then
			texture_path = "guis/textures/pd2/blackmarket/cash_drop"
		else
			texture_path = "guis/textures/pd2/blackmarket/icons/" .. tostring(category) .. "/" .. tostring(item_id)
		end
		Application:debug("Requesting Texture", texture_path, "PEER", peer_id)
		if DB:has(Idstring("texture"), texture_path) then
			TextureCache:request(texture_path, "NORMAL", texture_loaded_clbk)
		else
			Application:error("[HUDLootScreen]", "Texture not in DB", texture_path, peer_id)
			item_panel:rect({
				color = Color.red
			})
		end
	end
	self:set_num_visible(math.max(self:get_local_peer_id(), peer_id))
end
function HUDLootScreen:texture_loaded_clbk(params, texture_idstring)
	local peer_id = params[1]
	local is_pattern = params[2]
	local panel = self._peers_panel:child("peer" .. tostring(peer_id)):child("item")
	local item = panel:bitmap({texture = texture_idstring, blend_mode = "add"})
	TextureCache:unretrieve(texture_idstring)
	if is_pattern then
		item:set_render_template(Idstring("VertexColorTexturedPatterns"))
		item:set_blend_mode("normal")
	end
	local texture_width = item:texture_width()
	local texture_height = item:texture_height()
	local panel_width = 100
	local panel_height = 100
	if texture_width == 0 or texture_height == 0 or panel_width == 0 or panel_height == 0 then
		Application:error("HUDLootScreen:texture_loaded_clbk():", texture_idstring)
		Application:debug("HUDLootScreen:", "texture_width " .. texture_width, "texture_height " .. texture_height, "panel_width " .. panel_width, "panel_height " .. panel_height)
		panel:remove(item)
		local rect = panel:rect({
			w = 100,
			h = 100,
			color = Color.red,
			blend_mode = "add",
			rotation = 360
		})
		rect:set_center(panel:w() * 0.5, panel:h() * 0.5)
		return
	end
	local s = math.min(texture_width, texture_height)
	local dw = texture_width / s
	local dh = texture_height / s
	Application:debug("Got texture: ", texture_idstring, peer_id)
	item:set_size(math.round(dw * panel_width), math.round(dh * panel_height))
	item:set_rotation(360)
	item:set_center(panel:w() * 0.5, panel:h() * 0.5)
	if self._need_item and self._need_item[peer_id] then
		self._need_item[peer_id] = false
		self:show_item(peer_id)
	end
end
function HUDLootScreen:begin_choose_card(peer_id, card_id)
	print("YOU CHOOSED " .. card_id .. "MR. " .. peer_id)
	local panel = self._peers_panel:child("peer" .. tostring(peer_id))
	panel:stop()
	panel:set_alpha(1)
	self._peer_data[peer_id].wait_t = 5
	local card_info_panel = panel:child("card_info")
	local main_text = card_info_panel:child("main_text")
	main_text:set_text(managers.localization:to_upper_text("menu_l_choose_card_chosen", {time = 5}))
	local _, _, _, hh = main_text:text_rect()
	main_text:set_h(hh + 2)
	local lootdrop_data = self._peer_data[peer_id].lootdrops
	local item_pc = lootdrop_data[6]
	local left_pc = lootdrop_data[7]
	local right_pc = lootdrop_data[8]
	local cards = {}
	local card_one = card_id
	cards[card_one] = item_pc
	local card_two = #cards + 1
	cards[card_two] = left_pc
	local card_three = #cards + 1
	cards[card_three] = right_pc
	if item_pc == 0 then
		self._peer_data[peer_id].joker = true
	end
	local card_nums = {
		"one",
		"two",
		"three",
		"four",
		"five",
		"six",
		"seven",
		"eight",
		"nine",
		"ace"
	}
	for i, pc in ipairs(cards) do
		local card_panel = panel:child("card" .. i)
		local downcard = card_panel:child("downcard")
		local joker = pc == 0
		if not joker or not "joker_of_spade" then
		end
		local texture, rect, coords = tweak_data.hud_icons:get_icon_data(card_nums[pc] .. "_of_spade")
		local upcard = card_panel:bitmap({
			name = "upcard",
			texture = texture,
			w = math.round(0.7111111 * card_panel:h()),
			h = card_panel:h(),
			blend_mode = "add",
			layer = 1,
			halign = "scale",
			valign = "scale"
		})
		upcard:set_rotation(downcard:rotation())
		upcard:set_shape(downcard:shape())
		if joker then
			upcard:set_color(Color(1, 0.8, 0.8))
		end
		if coords then
			local tl = Vector3(coords[1][1], coords[1][2], 0)
			local tr = Vector3(coords[2][1], coords[2][2], 0)
			local bl = Vector3(coords[3][1], coords[3][2], 0)
			local br = Vector3(coords[4][1], coords[4][2], 0)
			upcard:set_texture_coordinates(tl, tr, bl, br)
		else
			upcard:set_texture_rect(unpack(rect))
		end
		upcard:hide()
	end
	panel:child("card" .. card_two):animate(callback(self, self, "flipcard"), 5)
	panel:child("card" .. card_three):animate(callback(self, self, "flipcard"), 5)
end
function HUDLootScreen:debug_flip()
	local card = self._peers_panel:child("peer1"):child("card1")
	card:animate(callback(self, self, "flipcard"), 1.5)
end
function HUDLootScreen:flipcard(card_panel, timer, done_clbk, peer_id)
	local downcard = card_panel:child("downcard")
	local upcard = card_panel:child("upcard")
	local bg = card_panel:child("bg")
	downcard:set_valign("scale")
	downcard:set_halign("scale")
	upcard:set_valign("scale")
	upcard:set_halign("scale")
	bg:set_valign("scale")
	bg:set_halign("scale")
	local start_rot = downcard:rotation()
	local start_w = downcard:w()
	local cx, cy = downcard:center()
	card_panel:set_alpha(1)
	downcard:show()
	upcard:hide()
	local start_rotation = downcard:rotation()
	local end_rotation = start_rotation * -1
	local diff = end_rotation - start_rotation
	bg:set_rotation(downcard:rotation())
	bg:set_shape(downcard:shape())
	wait(0.5)
	managers.menu_component:post_event("loot_flip_card")
	over(0.25, function(p)
		downcard:set_rotation(start_rotation + math.sin(p * 45) * diff)
		if downcard:rotation() == 0 then
			downcard:set_rotation(360)
		end
		downcard:set_w(start_w * math.cos(p * 90))
		downcard:set_center(cx, cy)
		bg:set_rotation(downcard:rotation())
		bg:set_shape(downcard:shape())
	end)
	upcard:set_shape(downcard:shape())
	upcard:set_rotation(downcard:rotation())
	start_rotation = upcard:rotation()
	diff = end_rotation - start_rotation
	bg:set_color(Color.black)
	bg:set_rotation(upcard:rotation())
	bg:set_shape(upcard:shape())
	downcard:hide()
	upcard:show()
	over(0.25, function(p)
		upcard:set_rotation(start_rotation + math.sin(p * 45 + 45) * diff)
		if upcard:rotation() == 0 then
			upcard:set_rotation(360)
		end
		upcard:set_w(start_w * math.sin(p * 90))
		upcard:set_center(cx, cy)
		bg:set_rotation(upcard:rotation())
		bg:set_shape(upcard:shape())
	end)
	local extra_time = 0
	if done_clbk then
		local lootdrop_data = self._peer_data[peer_id].lootdrops
		local max_pc = lootdrop_data[5]
		local item_pc = lootdrop_data[6]
		if max_pc == 0 then
		elseif max_pc > item_pc then
			extra_time = -0.2
		elseif item_pc == max_pc then
			extra_time = 0.2
		elseif max_pc < item_pc then
			extra_time = 1.1
		end
	end
	wait(timer - 1.5 + extra_time)
	if not done_clbk then
		managers.menu_component:post_event("loot_fold_cards")
	end
	over(0.25, function(p)
		card_panel:set_alpha(math.cos(p * 45))
	end)
	if done_clbk then
		done_clbk(peer_id)
	end
	local cx, cy = card_panel:center()
	local w, h = card_panel:size()
	over(0.25, function(p)
		card_panel:set_alpha(math.cos(p * 45 + 45))
		card_panel:set_size(w * math.cos(p * 90), h * math.cos(p * 90))
		card_panel:set_center(cx, cy)
	end)
end
function HUDLootScreen:show_item(peer_id)
	if not self._peer_data[peer_id].active then
		return
	end
	local panel = self._peers_panel:child("peer" .. peer_id)
	if panel:child("item") then
		panel:child("item"):set_center(panel:child("selected_panel"):center())
		panel:child("item"):show()
		for _, child in ipairs(panel:child("item"):children()) do
			child:set_center(panel:child("item"):w() * 0.5, panel:child("item"):h() * 0.5)
		end
		local anim_fadein = function(o)
			over(1, function(p)
				o:set_alpha(p)
			end)
		end
		panel:child("item"):animate(anim_fadein)
		local card_info_panel = panel:child("card_info")
		local main_text = card_info_panel:child("main_text")
		local quality_text = card_info_panel:child("quality_text")
		local global_value_text = card_info_panel:child("global_value_text")
		local lootdrop_data = self._peer_data[peer_id].lootdrops
		local global_value = lootdrop_data[2]
		local item_category = lootdrop_data[3]
		local item_id = lootdrop_data[4]
		local item_pc = lootdrop_data[6]
		local loot_tweak = tweak_data.blackmarket[item_category][item_id]
		local item_text = managers.localization:text(loot_tweak.name_id)
		if item_category == "cash" then
			local value_id = tweak_data.blackmarket[item_category][item_id].value_id
			local money = tweak_data.money_manager.loot_drop_cash[value_id] or 100
			item_text = managers.experience:cash_string(money)
		end
		main_text:set_text(managers.localization:to_upper_text("menu_l_you_got", {
			category = managers.localization:text("bm_menu_" .. item_category),
			item = item_text
		}))
		quality_text:set_text(managers.localization:to_upper_text("menu_l_quality", {
			quality = item_pc == 0 and "?" or item_pc
		}))
		global_value_text:set_visible(loot_tweak.infamous)
		if item_category == "weapon_mods" then
			local list_of_weapons = managers.weapon_factory:get_weapons_uses_part(item_id) or {}
			if table.size(list_of_weapons) == 1 then
				main_text:set_text(main_text:text() .. " (" .. managers.weapon_factory:get_weapon_name_by_factory_id(list_of_weapons[1]) .. ")")
			end
		end
		local _, _, _, hh = main_text:text_rect()
		main_text:set_h(hh + 2)
		self:make_fine_text(quality_text)
		main_text:set_y(0)
		quality_text:set_y(main_text:bottom())
		global_value_text:set_y(quality_text:bottom())
		card_info_panel:set_h(global_value_text:visible() and global_value_text:bottom() or quality_text:bottom())
		card_info_panel:set_center_y(panel:h() * 0.5)
		if self:get_local_peer_id() == peer_id then
			local player_pc = managers.experience:level_to_stars()
			if item_pc < player_pc then
				managers.menu_component:post_event("loot_gain_low")
			elseif item_pc == player_pc then
				managers.menu_component:post_event("loot_gain_med")
			elseif item_pc > player_pc then
				managers.menu_component:post_event("loot_gain_high")
			end
		end
		self._peer_data[peer_id].ready = true
		local clbk = self._callback_handler.on_peer_ready
		if clbk then
			clbk()
		end
	else
		self._need_item = self._need_item or {}
		self._need_item[peer_id] = true
	end
end
function HUDLootScreen:update(t, dt)
	for peer_id = 1, 4 do
		if self._peer_data[peer_id].wait_t then
			self._peer_data[peer_id].wait_t = math.max(self._peer_data[peer_id].wait_t - dt, 0)
			local panel = self._peers_panel:child("peer" .. tostring(peer_id))
			local card_info_panel = panel:child("card_info")
			local main_text = card_info_panel:child("main_text")
			main_text:set_text(managers.localization:to_upper_text("menu_l_choose_card_chosen", {
				time = math.ceil(self._peer_data[peer_id].wait_t)
			}))
			local _, _, _, hh = main_text:text_rect()
			main_text:set_h(hh + 2)
			if self._peer_data[peer_id].wait_t == 0 then
				main_text:set_text(managers.localization:to_upper_text("menu_l_choose_card_chosen_suspense"))
				local joker = self._peer_data[peer_id].joker
				panel:child("card" .. self._peer_data[peer_id].selected):animate(callback(self, self, "flipcard"), joker and 7 or 2.5, callback(self, self, "show_item"), peer_id)
				self._peer_data[peer_id].wait_t = false
			end
		end
	end
end
function HUDLootScreen:fetch_local_lootdata()
	return self._peer_data[self:get_local_peer_id()].lootdrops
end
function HUDLootScreen:create_stars_giving_animation()
	local lootdrops = self:fetch_local_lootdata()
	local human_players = managers.network:game() and managers.network:game():amount_of_alive_players() or 1
	local all_humans = human_players == 4
	if not lootdrops or not lootdrops[5] then
		return
	end
	local max_pc = lootdrops[5]
	local job_stars = managers.job:has_active_job() and managers.job:current_job_and_difficulty_stars() or 1
	local difficulty_stars = managers.job:has_active_job() and managers.job:current_difficulty_stars() or 0
	local player_stars = managers.experience:level_to_stars()
	local bonus_stars = all_humans and 1 or 0
	local level_stars = max_pc > player_stars and tweak_data.lootdrop.level_limit or 0
	local max_number_of_stars = job_stars
	if self._stars_panel then
		self._stars_panel:stop()
		self._stars_panel:parent():remove(self._stars_panel)
		self._stars_panel = nil
	end
	self._stars_panel = self._foreground_layer_safe:panel()
	self._stars_panel:set_left(self._foreground_layer_safe:child("loot_text"):right() + 10)
	local star_reason_text = self._stars_panel:text({
		font = tweak_data.menu.pd2_medium_font,
		font_size = tweak_data.menu.pd2_medium_font_size,
		text = ""
	})
	star_reason_text:set_left(max_number_of_stars * 35)
	star_reason_text:set_h(tweak_data.menu.pd2_medium_font_size)
	star_reason_text:set_world_center_y(math.round(self._foreground_layer_safe:child("loot_text"):world_center_y()) + 2)
	local function animation_func(o)
		local texture, rect = tweak_data.hud_icons:get_icon_data("risk_pd")
		local latest_star = 0
		wait(1.35)
		for i = 1, max_number_of_stars do
			wait(0.1)
			do
				local star = self._stars_panel:bitmap({
					name = "star_" .. tostring(i),
					texture = texture,
					texture_rect = rect,
					w = 32,
					h = 32,
					color = i > max_number_of_stars - difficulty_stars and tweak_data.screen_colors.risk or tweak_data.screen_colors.text,
					blend_mode = "add"
				})
				local star_color = star:color()
				star:set_alpha(0)
				star:set_x((i - 1) * 35)
				star:set_world_center_y(math.round(self._foreground_layer_safe:child("loot_text"):world_center_y()))
				managers.menu_component:post_event("Play_star_hit")
				over(0.45, function(p)
					star:set_alpha(math.min(p * 10, 1))
					star:set_color(math.lerp(star_color, star_color, p) - math.clamp(math.sin(p * 180), 0, 1) * Color(1, 1, 1))
					star:set_color(star:color():with_alpha(1))
				end)
				latest_star = i
			end
		end
		over(0.5, function(p)
			star_reason_text:set_alpha(1 - p)
		end)
	end
	self._stars_panel:animate(animation_func)
end
function HUDLootScreen:get_local_peer_id()
	return Global.game_settings.single_player and 1 or managers.network:session() and managers.network:session():local_peer():id() or 1
end
function HUDLootScreen:check_inside_local_peer(x, y)
	local peer_id = self:get_local_peer_id()
	local panel = self._peers_panel:child("peer" .. tostring(peer_id))
	for i = 1, 3 do
		local inside_check_card = panel:child("inside_check_card" .. tostring(i))
		if inside_check_card:inside(x, y) then
			return i
		end
	end
end
function HUDLootScreen:reload()
	self._backdrop:close()
	self._backdrop = nil
	HUDLootScreen.init(self, self._hud, self._workspace)
end
