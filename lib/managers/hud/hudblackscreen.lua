HUDBlackScreen = HUDBlackScreen or class()
function HUDBlackScreen:init(hud)
	self._hud_panel = hud.panel
	if self._hud_panel:child("blackscreen_panel") then
		self._hud_panel:remove(self._hud_panel:child("blackscreen_panel"))
	end
	self._blackscreen_panel = self._hud_panel:panel({
		visible = true,
		name = "blackscreen_panel",
		y = 0,
		valign = "grow",
		halign = "grow",
		layer = 0
	})
	local mid_text = self._blackscreen_panel:text({
		name = "mid_text",
		visible = true,
		text = "000",
		layer = 1,
		color = Color.white,
		y = 0,
		valign = {0.4, 0},
		align = "center",
		vertical = "center",
		font_size = tweak_data.hud.default_font_size,
		font = tweak_data.hud.medium_font,
		w = self._blackscreen_panel:w()
	})
	local _, _, _, h = mid_text:text_rect()
	mid_text:set_h(h)
	mid_text:set_center_x(self._blackscreen_panel:center_x())
	mid_text:set_center_y(self._blackscreen_panel:h() / 2.5)
	local is_server = Network:is_server()
	local text = utf8.to_upper(managers.localization:text("hud_skip_blackscreen", {
		BTN_ACCEPT = managers.localization:btn_macro("continue")
	}))
	local skip_text = self._blackscreen_panel:text({
		name = "skip_text",
		visible = is_server,
		text = text,
		layer = 1,
		color = Color.white,
		y = 0,
		align = "right",
		vertical = "bottom",
		font_size = nil,
		font = tweak_data.hud.medium_font_noshadow
	})
	self._circle_radius = 16
	self._sides = 64
	skip_text:set_x(skip_text:x() - self._circle_radius * 3)
	skip_text:set_y(skip_text:y() - self._circle_radius)
	self._skip_circle = CircleBitmapGuiObject:new(self._blackscreen_panel, {
		image = "guis/textures/pd2/hud_progress_32px",
		radius = self._circle_radius,
		sides = self._sides,
		current = self._sides,
		total = self._sides,
		blend_mode = "normal",
		color = Color.white,
		layer = 2
	})
	self._skip_circle:set_position(self._blackscreen_panel:w() - self._circle_radius * 3, self._blackscreen_panel:h() - self._circle_radius * 3)
end
function HUDBlackScreen:set_skip_circle(current, total)
	self._skip_circle:set_current(current / total)
end
function HUDBlackScreen:skip_circle_done()
	self._blackscreen_panel:child("skip_text"):set_visible(false)
	local bitmap = self._blackscreen_panel:bitmap({
		texture = "guis/textures/pd2/hud_progress_32px",
		w = self._circle_radius * 2,
		h = self._circle_radius * 2,
		blend_mode = "add",
		align = "center",
		valign = "center",
		layer = 2
	})
	bitmap:set_position(self._skip_circle:position())
	local circle = CircleBitmapGuiObject:new(self._blackscreen_panel, {
		image = "guis/textures/pd2/hud_progress_32px",
		radius = self._circle_radius,
		sides = 64,
		current = 64,
		total = 64,
		color = Color.white:with_alpha(1),
		blend_mode = "normal",
		layer = 3
	})
	circle:set_position(self._skip_circle:position())
	bitmap:animate(callback(self, HUDInteraction, "_animate_interaction_complete"), circle)
end
function HUDBlackScreen:set_job_data()
	do return end
	if not managers.job:has_active_job() then
		return
	end
	local contact_data = managers.job:current_contact_data()
	local job_data = managers.job:current_job_data()
	if self._blackscreen_panel:child("job_panel") then
		self._blackscreen_panel:remove(self._blackscreen_panel:child("job_panel"))
	end
	local job_panel = self._blackscreen_panel:panel({
		visible = true,
		name = "job_panel",
		y = 0,
		valign = "grow",
		halign = "grow",
		layer = 0
	})
	job_panel:hide()
	job_panel:text({
		name = "title",
		text = managers.localization:text(job_data.name_id),
		layer = 1,
		align = "center",
		vertical = "top",
		font_size = tweak_data.hud.default_font_size,
		font = tweak_data.hud.medium_font,
		w = job_panel:w(),
		h = 32
	})
	local contact_name = job_panel:text({
		name = "contact_name",
		text = managers.localization:text(contact_data.name_id),
		layer = 1,
		align = "left",
		vertical = "top",
		font_size = tweak_data.hud.default_font_size,
		font = tweak_data.hud.medium_font,
		w = job_panel:w(),
		h = 32,
		y = 50
	})
	local portrait = job_panel:bitmap({
		name = "portrait",
		texture = contact_data.image,
		y = contact_name:bottom()
	})
	job_panel:text({
		name = "payout",
		text = "Payout: $1.000.000",
		layer = 1,
		align = "left",
		vertical = "top",
		font_size = tweak_data.hud.default_font_size,
		font = tweak_data.hud.medium_font,
		w = job_panel:w(),
		h = 32,
		y = portrait:bottom() + 32
	})
	self:_create_stages()
	local level_data = managers.job:current_level_data()
	local objective_title = job_panel:text({
		name = "objective_title",
		text = managers.localization:text("hud_objectives"),
		layer = 1,
		align = "left",
		vertical = "top",
		font_size = tweak_data.hud.default_font_size,
		font = tweak_data.hud.medium_font,
		w = job_panel:w(),
		h = 32,
		y = job_panel:h() / 2
	})
	local objective_text = job_panel:text({
		name = "objective_text",
		text = managers.localization:text(level_data.briefing_id),
		layer = 1,
		align = "left",
		vertical = "top",
		font_size = tweak_data.hud.small_font_size,
		font = tweak_data.hud.small_font,
		w = job_panel:w(),
		h = 32,
		y = job_panel:h() / 2 + 50,
		wrap = true,
		word_wrap = true
	})
end
function HUDBlackScreen:_create_stages()
	local job_data = managers.job:current_job_data()
	local job_panel = self._blackscreen_panel:child("job_panel")
	local stages_panel = job_panel:panel({
		visible = true,
		name = "stages_panel",
		y = job_panel:child("contact_name"):bottom(),
		x = 320,
		h = 256
	})
	local types = {
		a = {
			256,
			0,
			64,
			64
		},
		b = {
			192,
			0,
			64,
			64
		},
		c = {
			128,
			0,
			64,
			64
		},
		d = {
			64,
			0,
			64,
			64
		},
		e = {
			0,
			0,
			64,
			64
		}
	}
	local level_rects = {
		{
			0,
			0,
			256,
			256
		},
		{
			768,
			0,
			256,
			256
		},
		{
			512,
			0,
			256,
			256
		},
		{
			256,
			0,
			256,
			256
		}
	}
	local x = 0
	for i, heist in ipairs(job_data.chain) do
		local is_current_stage = managers.job:current_stage() == i
		local is_completed = i < managers.job:current_stage()
		local panel = stages_panel:panel({
			visible = true,
			name = "panel",
			y = 0,
			x = x,
			w = is_current_stage and 256 or 80
		})
		if not is_completed and not is_current_stage then
			local image = panel:bitmap({
				texture = "guis/textures/pd2/icon_mission_overview_unknown",
				layer = 1,
				blend_mode = "normal"
			})
			image:set_center(panel:w() / 2, panel:h() / 2)
		else
			local image = panel:bitmap({
				texture = "guis/textures/pd2/icon_mission_overview",
				layer = 1,
				texture_rect = level_rects[i],
				blend_mode = "normal"
			})
			image:set_center(panel:w() / 2, panel:h() / 2)
		end
		local badge = panel:bitmap({
			texture = "guis/textures/pd2/gui_grade_badges",
			layer = 4,
			texture_rect = types[heist.type]
		})
		badge:set_right(panel:w() - 8)
		badge:set_bottom(panel:h() - 8)
		if (not is_completed or not {
			0,
			Color(120, 255, 120) / 255:with_alpha(0.25),
			1,
			Color(120, 255, 120) / 255:with_alpha(0)
		}) and (not is_current_stage or not {
			0,
			Color(230, 200, 150) / 255:with_alpha(0.5),
			1,
			Color(230, 200, 150) / 255:with_alpha(0)
		}) then
			local gradient_points = {
				0,
				Color.black:with_alpha(0),
				1,
				Color.black:with_alpha(0)
			}
		end
		panel:gradient({
			layer = 3,
			gradient_points = gradient_points,
			orientation = "vertical",
			h = panel:h() / 2
		})
		x = x + panel:w() + 10
		local level_data = tweak_data.levels[heist.level_id]
		if is_current_stage then
			local pad = 8
			panel:text({
				name = "stage_name",
				text = utf8.to_upper(managers.localization:text(level_data.name_id)),
				layer = 0,
				align = "left",
				vertical = "top",
				font_size = tweak_data.hud.small_font_size,
				font = tweak_data.hud.small_font,
				w = panel:w(),
				h = 24,
				x = pad,
				y = pad,
				layer = 4
			})
			panel:text({
				name = "type",
				text = utf8.to_upper(managers.localization:text(heist.type_id)),
				layer = 0,
				align = "left",
				vertical = "top",
				font_size = tweak_data.hud.small_font_size,
				font = tweak_data.hud.small_font,
				w = panel:w(),
				h = 24,
				x = pad,
				y = pad + 24,
				layer = 4
			})
		end
		stages_panel:set_w(panel:right())
	end
	stages_panel:set_center_x(math.round(job_panel:child("portrait"):w() + (job_panel:w() - job_panel:child("portrait"):w()) / 2))
end
function HUDBlackScreen:set_mid_text(text)
	local mid_text = self._blackscreen_panel:child("mid_text")
	mid_text:set_alpha(0)
	mid_text:set_text(utf8.to_upper(text))
end
function HUDBlackScreen:fade_in_mid_text()
	self._blackscreen_panel:child("mid_text"):animate(callback(self, self, "_animate_fade_in"))
end
function HUDBlackScreen:fade_out_mid_text()
	self._blackscreen_panel:child("mid_text"):animate(callback(self, self, "_animate_fade_out"))
end
function HUDBlackScreen:_animate_fade_in(mid_text)
	local job_panel = self._blackscreen_panel:child("job_panel")
	local t = 2
	local d = t
	while t > 0 do
		local dt = coroutine.yield()
		t = t - dt
		local a = (d - t) / d
		mid_text:set_alpha(a)
		if job_panel then
			job_panel:set_alpha(a)
		end
		self._blackscreen_panel:set_alpha(a)
	end
	mid_text:set_alpha(1)
	if job_panel then
		job_panel:set_alpha(1)
	end
	self._blackscreen_panel:set_alpha(1)
end
function HUDBlackScreen:_animate_fade_out(mid_text)
	local job_panel = self._blackscreen_panel:child("job_panel")
	local t = 1
	local d = t
	while t > 0 do
		local dt = coroutine.yield()
		t = t - dt
		local a = t / d
		mid_text:set_alpha(a)
		if job_panel then
			job_panel:set_alpha(a)
		end
		self._blackscreen_panel:set_alpha(a)
	end
	mid_text:set_alpha(0)
	if job_panel then
		job_panel:set_alpha(0)
	end
	self._blackscreen_panel:set_alpha(0)
end
