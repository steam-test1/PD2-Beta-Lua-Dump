WalletGuiObject = WalletGuiObject or class()
function WalletGuiObject:init(panel)
	WalletGuiObject.set_wallet(panel)
end
function WalletGuiObject.set_wallet(panel, layer)
	WalletGuiObject.remove_wallet()
	Global.wallet_panel = panel:panel({
		name = "WalletGuiObject",
		layer = layer or 0
	})
	local money_icon = Global.wallet_panel:bitmap({
		name = "wallet_money_icon",
		texture = "guis/textures/pd2/shared_wallet_symbol"
	})
	local level_icon = Global.wallet_panel:bitmap({
		name = "wallet_level_icon",
		texture = "guis/textures/pd2/shared_level_symbol"
	})
	local skillpoint_icon = Global.wallet_panel:bitmap({
		name = "wallet_skillpoint_icon",
		texture = "guis/textures/pd2/shared_skillpoint_symbol"
	})
	local money_text = Global.wallet_panel:text({
		name = "wallet_money_text",
		text = managers.money:total_string_no_currency(),
		font_size = tweak_data.menu.pd2_small_font_size,
		font = tweak_data.menu.pd2_small_font,
		color = tweak_data.screen_colors.text,
		vertical = "center"
	})
	local level_text = Global.wallet_panel:text({
		name = "wallet_level_text",
		text = tostring(managers.experience:current_level()),
		font_size = tweak_data.menu.pd2_small_font_size,
		font = tweak_data.menu.pd2_small_font,
		color = tweak_data.screen_colors.text,
		vertical = "center"
	})
	local skillpoint_text = Global.wallet_panel:text({
		name = "wallet_skillpoint_text",
		text = managers.skilltree:points() > 1 and tostring(managers.skilltree:points()) or "",
		font_size = tweak_data.menu.pd2_small_font_size,
		font = tweak_data.menu.pd2_small_font,
		color = tweak_data.screen_colors.text,
		vertical = "center"
	})
	local mw, mh = WalletGuiObject.make_fine_text(money_text)
	local lw, lh = WalletGuiObject.make_fine_text(level_text)
	local sw, sh = WalletGuiObject.make_fine_text(skillpoint_text)
	money_icon:set_leftbottom(2, Global.wallet_panel:h() - 2)
	level_icon:set_leftbottom(2, money_icon:top() - 2)
	skillpoint_icon:set_leftbottom(2, level_icon:top() - 2)
	WalletGuiObject.make_fine_text(money_text)
	money_text:set_left(money_icon:right() + 2)
	money_text:set_center_y(money_icon:center_y())
	WalletGuiObject.make_fine_text(level_text)
	level_text:set_left(level_icon:right() + 2)
	level_text:set_center_y(level_icon:center_y())
	WalletGuiObject.make_fine_text(skillpoint_text)
	skillpoint_text:set_left(skillpoint_icon:right() + 2)
	skillpoint_text:set_center_y(skillpoint_icon:center_y())
	local max_w = math.max(mw, lw, sw)
	local bg_blur = Global.wallet_panel:bitmap({
		name = "bg_blur",
		texture = "guis/textures/test_blur_df",
		w = 0,
		h = 0,
		render_template = "VertexColorTexturedBlur3D",
		layer = -1
	})
	bg_blur:set_leftbottom(money_icon:leftbottom())
	bg_blur:set_w(max_w + money_icon:w() + 2)
	bg_blur:set_h(Global.wallet_panel:h() - skillpoint_icon:top())
	WalletGuiObject.set_object_visible("wallet_skillpoint_icon", false)
	WalletGuiObject.set_object_visible("wallet_skillpoint_text", false)
end
function WalletGuiObject.refresh()
	if Global.wallet_panel then
		Global.wallet_panel:child("wallet_money_text"):set_text(managers.money:total_string_no_currency())
		Global.wallet_panel:child("wallet_level_text"):set_text(tostring(managers.experience:current_level()))
		Global.wallet_panel:child("wallet_skillpoint_text"):set_text(managers.skilltree:points() > 1 and tostring(managers.skilltree:points()) or "")
		WalletGuiObject.make_fine_text(Global.wallet_panel:child("wallet_money_text"))
		WalletGuiObject.make_fine_text(Global.wallet_panel:child("wallet_level_text"))
		WalletGuiObject.make_fine_text(Global.wallet_panel:child("wallet_skillpoint_text"))
	end
end
function WalletGuiObject.make_fine_text(text)
	local x, y, w, h = text:text_rect()
	text:set_size(w, h)
	text:set_position(math.round(text:x()), math.round(text:y()))
	return w, h
end
function WalletGuiObject.set_layer(layer)
	if not alive(Global.wallet_panel) then
		return
	end
	Global.wallet_panel:set_layer(layer)
end
function WalletGuiObject.move_wallet(mx, my)
	if not alive(Global.wallet_panel) then
		return
	end
	Global.wallet_panel:move(mx, my)
end
function WalletGuiObject.set_object_visible(object, visible)
	if not alive(Global.wallet_panel) then
		return
	end
	Global.wallet_panel:child(object):set_visible(visible)
	local bg_blur = Global.wallet_panel:child("bg_blur")
	if Global.wallet_panel:child("wallet_skillpoint_icon"):visible() then
		bg_blur:set_h(Global.wallet_panel:h() - Global.wallet_panel:child("wallet_skillpoint_icon"):top())
	elseif Global.wallet_panel:child("wallet_level_icon"):visible() then
		bg_blur:set_h(Global.wallet_panel:h() - Global.wallet_panel:child("wallet_level_icon"):top())
	elseif Global.wallet_panel:child("wallet_money_icon"):visible() then
		bg_blur:set_h(Global.wallet_panel:h() - Global.wallet_panel:child("wallet_money_icon"):top())
	else
		bg_blur:set_h(0)
	end
	bg_blur:set_leftbottom(Global.wallet_panel:child("wallet_money_icon"):leftbottom())
end
function WalletGuiObject.remove_wallet()
	if not alive(Global.wallet_panel) or not alive(Global.wallet_panel:parent()) then
		Global.wallet_panel = nil
		return
	end
	Global.wallet_panel:parent():remove(Global.wallet_panel)
	Global.wallet_panel = nil
end
function WalletGuiObject.close_wallet(panel)
	if not alive(Global.wallet_panel) or not alive(Global.wallet_panel:parent()) then
		Global.wallet_panel = nil
		return
	end
	if panel ~= Global.wallet_panel:parent() then
		return
	end
	panel:remove(Global.wallet_panel)
	Global.wallet_panel = nil
end
