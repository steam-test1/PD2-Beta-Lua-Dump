HUDHint = HUDHint or class()
function HUDHint:init(hud)
	self._hud_panel = hud.panel
	if self._hud_panel:child("hint_panel") then
		self._hud_panel:remove(self._hud_panel:child("hint_panel"))
	end
	self._hint_panel = self._hud_panel:panel({
		visible = false,
		name = "hint_panel",
		h = 30,
		y = 0,
		valign = {0.3125, 0},
		layer = 3
	})
	local y = self._hud_panel:h() / 3.2
	self._hint_panel:set_center_y(y)
	local marker = self._hint_panel:rect({
		name = "marker",
		visible = true,
		color = Color.white:with_alpha(0.75),
		layer = 2,
		h = 30,
		w = 12
	})
	marker:set_center_y(self._hint_panel:h() / 2)
	local clip_panel = self._hint_panel:panel({name = "clip_panel"})
	clip_panel:rect({
		name = "bg",
		visible = true,
		color = Color.black:with_alpha(0.25)
	})
	clip_panel:text({
		name = "hint_text",
		text = "",
		font_size = 28,
		font = tweak_data.hud.medium_font_noshadow,
		color = Color.white,
		align = "center",
		vertical = "center",
		layer = 1,
		wrap = false,
		word_wrap = false
	})
end
function HUDHint:show(params)
	local text = params.text
	local clip_panel = self._hint_panel:child("clip_panel")
	clip_panel:child("hint_text"):set_text(utf8.to_upper(""))
	self._stop = false
	self._hint_panel:stop()
	self._hint_panel:animate(callback(self, self, "_animate_show"), callback(self, self, "show_done"), params.time or 3, utf8.to_upper(text))
end
function HUDHint:stop()
	self._stop = true
end
function HUDHint:_animate_show(hint_panel, done_cb, seconds, text)
	local clip_panel = hint_panel:child("clip_panel")
	local hint_text = clip_panel:child("hint_text")
	hint_panel:set_visible(true)
	hint_panel:set_alpha(1)
	hint_text:set_text(text)
	local offset = 32
	local _, _, w, h = hint_text:text_rect()
	hint_text:set_w(w + offset)
	clip_panel:set_w(w + offset)
	clip_panel:set_center_x(clip_panel:parent():w() / 2)
	clip_panel:set_w(0)
	local target_w = w + offset
	local w = 0
	local marker = hint_panel:child("marker")
	marker:set_visible(true)
	local t = seconds
	local forever = t == -1
	local st = 1
	local cs = 0
	local speed = 600
	local presenting = true
	while presenting do
		local dt = coroutine.yield()
		w = math.clamp(w + dt * speed, 0, target_w)
		presenting = w ~= target_w
		clip_panel:set_w(w)
		hint_text:set_text("")
		hint_text:set_text(text)
		marker:set_alpha((1 + math.sin(Application:time() * 800)) / 2)
		marker:set_right(clip_panel:right())
	end
	while (t > 0 or forever) and not self._stop do
		local dt = coroutine.yield()
		t = t - dt
		marker:set_alpha((1 + math.sin(Application:time() * 800)) / 2)
		marker:set_right(clip_panel:right())
	end
	self._stop = false
	local removing = true
	while removing do
		local dt = coroutine.yield()
		w = math.clamp(w - dt * speed * 2, 0, target_w)
		clip_panel:set_w(w)
		removing = w ~= 0
		marker:set_alpha((1 + math.sin(Application:time() * 800)) / 2)
		marker:set_right(clip_panel:right())
	end
	hint_panel:set_visible(false)
	done_cb()
end
function HUDHint:show_done()
end
