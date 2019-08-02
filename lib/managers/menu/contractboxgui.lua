ContractBoxGui = ContractBoxGui or class()
function ContractBoxGui:init(ws, fullscreen_ws)
	self._ws = ws
	self._fullscreen_ws = fullscreen_ws
	self._panel = self._ws:panel():panel()
	self._fullscreen_panel = self._fullscreen_ws:panel():panel()
	local crewpage_text = self._panel:text({
		name = "crewpage_text",
		text = managers.localization:to_upper_text("menu_crewpage"),
		align = "left",
		vertical = "top",
		font_size = tweak_data.menu.pd2_large_font_size,
		font = tweak_data.menu.pd2_large_font,
		color = tweak_data.screen_colors.text
	})
	local _, _, w, h = crewpage_text:text_rect()
	crewpage_text:set_size(w, h)
	local wfs_text
	if not Network:is_server() then
		wfs_text = self._panel:text({
			name = "wfs",
			text = managers.localization:to_upper_text("victory_client_waiting_for_server"),
			align = "right",
			vertical = "bottom",
			font_size = tweak_data.menu.pd2_medium_font_size,
			font = tweak_data.menu.pd2_medium_font,
			color = tweak_data.screen_colors.text
		})
		local _, _, w, h = wfs_text:text_rect()
		wfs_text:set_size(w, h)
		wfs_text:set_rightbottom(self._panel:w(), self._panel:h())
	elseif not managers.job:has_active_job() then
		wfs_text = self._panel:text({
			name = "wfs",
			text = managers.localization:to_upper_text("menu_choose_new_contract"),
			align = "right",
			vertical = "bottom",
			font_size = tweak_data.menu.pd2_medium_font_size,
			font = tweak_data.menu.pd2_medium_font,
			color = tweak_data.screen_colors.text
		})
		local _, _, w, h = wfs_text:text_rect()
		wfs_text:set_size(w, h)
		wfs_text:set_rightbottom(self._panel:w(), self._panel:h())
	end
	if not managers.menu:is_pc_controller() and wfs_text then
		wfs_text:set_rightbottom(self._panel:w() - 40, self._panel:h() - 150)
	end
	if MenuBackdropGUI then
		if crewpage_text then
			local bg_text = self._fullscreen_panel:text({
				name = "crewpage_text",
				text = managers.localization:to_upper_text("menu_crewpage"),
				h = 90,
				align = "left",
				vertical = "top",
				font_size = tweak_data.menu.pd2_massive_font_size,
				font = tweak_data.menu.pd2_massive_font,
				color = tweak_data.screen_colors.button_stage_3,
				alpha = 0.4,
				layer = 1
			})
			local x, y = managers.gui_data:safe_to_full_16_9(crewpage_text:world_x(), crewpage_text:world_center_y())
			bg_text:set_world_left(x)
			bg_text:set_world_center_y(y)
			bg_text:move(-13, 9)
			MenuBackdropGUI.animate_bg_text(self, bg_text)
		end
		if managers.menu:is_pc_controller() and wfs_text then
			local bg_text = self._fullscreen_panel:text({
				text = wfs_text:text(),
				h = 90,
				align = "right",
				vertical = "bottom",
				font_size = tweak_data.menu.pd2_massive_font_size,
				font = tweak_data.menu.pd2_massive_font,
				color = tweak_data.screen_colors.button_stage_3,
				alpha = 0.4,
				layer = 1
			})
			local x, y = managers.gui_data:safe_to_full_16_9(wfs_text:world_right(), wfs_text:world_center_y())
			bg_text:set_world_right(x)
			bg_text:set_world_center_y(y)
			bg_text:move(13, -9)
			MenuBackdropGUI.animate_bg_text(self, bg_text)
		end
	end
	self:create_contract_box()
end
function ContractBoxGui:create_contract_box()
	if not managers.network:session() then
		return
	end
	if self._contract_panel and alive(self._contract_panel) then
		self._panel:remove(self._contract_panel)
	end
	if self._contract_text_header and alive(self._contract_text_header) then
		self._panel:remove(self._contract_text_header)
	end
	self._contract_panel = nil
	self._contract_text_header = nil
	local contact_data = managers.job:current_contact_data()
	local job_data = managers.job:current_job_data()
	self._contract_panel = self._panel:panel({
		name = "contract_box_panel",
		w = 350,
		h = 100,
		layer = 0
	})
	self._contract_panel:rect({
		color = Color(0.5, 0, 0, 0),
		layer = -1,
		halign = "grow",
		valign = "grow"
	})
	local font = tweak_data.menu.pd2_small_font
	local font_size = tweak_data.menu.pd2_small_font_size
	if contact_data then
		self._contract_text_header = self._panel:text({
			text = utf8.to_upper(managers.localization:text(contact_data.name_id) .. ": " .. managers.localization:text(job_data.name_id)),
			font_size = tweak_data.menu.pd2_medium_font_size,
			font = tweak_data.menu.pd2_medium_font,
			color = tweak_data.screen_colors.text,
			blend_mode = "add"
		})
		local length_text_header = self._contract_panel:text({
			text = managers.localization:to_upper_text("cn_menu_contract_length_header"),
			font_size = font_size,
			font = font,
			color = tweak_data.screen_colors.text
		})
		local paygrade_text_header = self._contract_panel:text({
			text = managers.localization:to_upper_text("cn_menu_contract_paygrade_header"),
			font_size = font_size,
			font = font,
			color = tweak_data.screen_colors.text
		})
		local exp_text_header = self._contract_panel:text({
			text = managers.localization:to_upper_text("menu_experience"),
			font_size = font_size,
			font = font,
			color = tweak_data.screen_colors.text
		})
		local payout_text_header = self._contract_panel:text({
			text = managers.localization:to_upper_text("cn_menu_contract_payout_header"),
			font_size = font_size,
			font = font,
			color = tweak_data.screen_colors.text
		})
		do
			local _, _, tw, th = self._contract_text_header:text_rect()
			self._contract_text_header:set_size(tw, th)
		end
		local w = 0
		do
			local _, _, tw, th = length_text_header:text_rect()
			w = math.max(w, tw)
			length_text_header:set_size(tw, th)
		end
		do
			local _, _, tw, th = paygrade_text_header:text_rect()
			w = math.max(w, tw)
			paygrade_text_header:set_size(tw, th)
		end
		do
			local _, _, tw, th = exp_text_header:text_rect()
			w = math.max(w, tw)
			exp_text_header:set_size(tw, th)
		end
		do
			local _, _, tw, th = payout_text_header:text_rect()
			w = math.max(w, tw)
			payout_text_header:set_size(tw, th)
		end
		w = w + 10
		length_text_header:set_right(w)
		paygrade_text_header:set_right(w)
		exp_text_header:set_right(w)
		payout_text_header:set_right(w)
		paygrade_text_header:set_top(10)
		length_text_header:set_top(paygrade_text_header:bottom())
		exp_text_header:set_top(length_text_header:bottom())
		payout_text_header:set_top(exp_text_header:bottom())
		local length_text = self._contract_panel:text({
			text = managers.localization:to_upper_text("cn_menu_contract_length", {
				stages = #job_data.chain
			}),
			align = "left",
			vertical = "top",
			font_size = font_size,
			font = font,
			color = tweak_data.screen_colors.text
		})
		length_text:set_position(length_text_header:right() + 5, length_text_header:top())
		local filled_star_rect = {
			0,
			32,
			32,
			32
		}
		local empty_star_rect = {
			32,
			32,
			32,
			32
		}
		local job_stars = managers.job:current_job_stars()
		local job_and_difficulty_stars = managers.job:current_job_and_difficulty_stars()
		local difficulty_stars = job_and_difficulty_stars - job_stars
		local risk_color = Color(255, 255, 204, 0) / 255
		local cy = paygrade_text_header:center_y()
		local sx = paygrade_text_header:right() + 5
		for i = 1, 10 do
			local x = sx + (i - 1) * 18
			local alpha = i > job_and_difficulty_stars and 0.25 or 1
			local color = (i > job_and_difficulty_stars or i <= job_stars) and Color.white or risk_color
			local star = self._contract_panel:bitmap({
				name = "star" .. tostring(i),
				texture = "guis/textures/pd2/mission_briefing/difficulty_icons",
				texture_rect = filled_star_rect,
				x = x,
				y = 0,
				w = 16,
				h = 16,
				alpha = alpha,
				color = color
			})
			star:set_center_y(math.round(cy))
		end
		local days_multiplier = 0
		local day_tweak = job_data.professional and tweak_data.experience_manager.pro_day_multiplier or tweak_data.experience_manager.day_multiplier
		for i = 1, #job_data.chain do
			days_multiplier = days_multiplier + (day_tweak[i] - 1)
		end
		days_multiplier = 1 + days_multiplier / #job_data.chain
		local xp_stage_stars = managers.experience:get_stage_xp_by_stars(job_stars)
		local xp_job_stars = managers.experience:get_job_xp_by_stars(job_stars)
		local xp_multiplier = managers.experience:get_contract_difficulty_multiplier(difficulty_stars)
		local job_experience = math.round(xp_job_stars * day_tweak[#job_data.chain] + xp_stage_stars + xp_stage_stars * (#job_data.chain - 1) * days_multiplier)
		local job_xp = self._contract_panel:text({
			font = font,
			font_size = font_size,
			text = tostring(job_experience),
			color = tweak_data.screen_colors.text
		})
		do
			local _, _, tw, th = job_xp:text_rect()
			job_xp:set_size(tw, th)
		end
		job_xp:set_position(math.round(exp_text_header:right() + 5), math.round(exp_text_header:top()))
		local risk_xp = self._contract_panel:text({
			font = font,
			font_size = font_size,
			text = " +" .. tostring(math.round(job_experience * xp_multiplier)),
			color = risk_color
		})
		do
			local _, _, tw, th = risk_xp:text_rect()
			risk_xp:set_size(tw, th)
		end
		risk_xp:set_position(math.round(job_xp:right()), job_xp:top())
		local money_stage_stars = managers.money:get_stage_payout_by_stars(job_stars)
		local money_job_stars = managers.money:get_job_payout_by_stars(job_stars)
		local money_multiplier = managers.money:get_contract_difficulty_multiplier(difficulty_stars)
		local job_money = self._contract_panel:text({
			font = font,
			font_size = font_size,
			text = managers.experience:cash_string(math.round(money_job_stars + money_stage_stars * #job_data.chain)),
			color = tweak_data.screen_colors.text
		})
		do
			local _, _, tw, th = job_money:text_rect()
			job_money:set_size(tw, th)
		end
		job_money:set_position(math.round(payout_text_header:right() + 5), math.round(payout_text_header:top()))
		local risk_money = self._contract_panel:text({
			font = font,
			font_size = font_size,
			text = " +" .. managers.experience:cash_string(math.round((money_job_stars + money_stage_stars * #job_data.chain) * money_multiplier)),
			color = risk_color
		})
		do
			local _, _, tw, th = risk_money:text_rect()
			risk_money:set_size(tw, th)
		end
		risk_money:set_position(math.round(job_money:right()), job_money:top())
		self._contract_panel:set_h(payout_text_header:bottom() + 10)
	elseif managers.menu:debug_menu_enabled() then
		local debug_start = self._contract_panel:text({
			text = "Use DEBUG START to start your level",
			font_size = font_size,
			font = font,
			color = tweak_data.screen_colors.text,
			x = 10,
			y = 10,
			wrap = true,
			word_wrap = true
		})
		debug_start:grow(-debug_start:x() - 10, debug_start:y() - 10)
	end
	self._contract_panel:set_rightbottom(self._panel:w() - 10, self._panel:h() - 50)
	if self._contract_text_header then
		self._contract_text_header:set_bottom(self._contract_panel:top())
		self._contract_text_header:set_left(self._contract_panel:left())
		local wfs_text = self._panel:child("wfs")
		if wfs_text and not managers.menu:is_pc_controller() then
			wfs_text:set_rightbottom(self._panel:w() - 20, self._contract_text_header:top())
		end
	end
	BoxGuiObject:new(self._contract_panel, {
		sides = {
			1,
			1,
			1,
			1
		}
	})
	for i = 1, 4 do
		local peer = managers.network:session():peer(i)
		if peer then
			local peer_pos = managers.menu_scene:character_screen_position(i)
			local peer_name = peer:name()
			if peer_pos then
				self:create_character_text(i, peer_pos.x, peer_pos.y, peer_name)
			end
		end
	end
	self._enabled = true
end
function ContractBoxGui:refresh()
	self:create_contract_box()
end
function ContractBoxGui:update(t, dt)
	for i = 1, 4 do
		self:update_character(i)
	end
end
function ContractBoxGui:create_character_text(peer_id, x, y, text)
	self._peers = self._peers or {}
	local color_id = peer_id
	local color = tweak_data.chat_colors[color_id]
	self._peers[peer_id] = self._peers[peer_id] or self._panel:text({
		name = tostring(peer_id),
		text = "",
		align = "center",
		vertical = "center",
		font_size = tweak_data.menu.pd2_medium_font_size,
		font = tweak_data.menu.pd2_medium_font,
		layer = 0,
		color = color,
		blend_mode = "add"
	})
	self._peers[peer_id]:set_text(text)
	self._peers[peer_id]:set_visible(self._enabled)
	local _, _, w, h = self._peers[peer_id]:text_rect()
	self._peers[peer_id]:set_size(w, h)
	self._peers[peer_id]:set_center(x, y)
end
function ContractBoxGui:update_character(peer_id)
	if not peer_id or not managers.network:session() then
		return
	end
	local x = 0
	local y = 0
	local text = ""
	local peer = managers.network:session():peer(peer_id)
	if peer then
		local local_peer = managers.network:session() and managers.network:session():local_peer()
		local peer_pos = managers.menu_scene:character_screen_position(peer_id)
		x = peer_pos.x
		y = peer_pos.y
		if peer ~= local_peer or not managers.experience:current_level() then
		end
		text = peer:name() .. " (" .. tostring((peer:level())) .. ")"
	end
	self:create_character_text(peer_id, x, y, text)
end
function ContractBoxGui:_create_text_box(ws, title, text, content_data, config)
end
function ContractBoxGui:_create_lower_static_panel(lower_static_panel)
end
function ContractBoxGui:mouse_pressed(button, x, y)
	if not self:can_take_input() then
		return
	end
	if button == Idstring("0") then
	end
end
function ContractBoxGui:mouse_moved(x, y)
	if not self:can_take_input() then
		return
	end
	return false, nil
end
function ContractBoxGui:can_take_input()
	return false
end
function ContractBoxGui:moved_scroll_bar()
end
function ContractBoxGui:mouse_wheel_down()
end
function ContractBoxGui:mouse_wheel_up()
end
function ContractBoxGui:check_minimize()
	return false
end
function ContractBoxGui:check_grab_scroll_bar()
	return false
end
function ContractBoxGui:release_scroll_bar()
	return false
end
function ContractBoxGui:set_enabled(enabled)
	self._enabled = enabled
	if enabled then
	else
	end
	if self._contract_panel then
		self._contract_panel:set_visible(enabled)
	end
	if self._contract_text_header then
		self._contract_text_header:set_visible(enabled)
	end
	if self._panel:child("wfs") then
		self._panel:child("wfs"):set_visible(enabled)
	end
end
function ContractBoxGui:set_size(x, y)
end
function ContractBoxGui:set_visible(visible)
end
function ContractBoxGui:close()
	self._ws:panel():remove(self._panel)
	self._fullscreen_ws:panel():remove(self._fullscreen_panel)
end
