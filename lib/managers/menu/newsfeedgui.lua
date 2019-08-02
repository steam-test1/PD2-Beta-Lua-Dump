NewsFeedGui = NewsFeedGui or class(TextBoxGui)
function NewsFeedGui:init(ws)
	self._ws = ws
	self:_create_gui()
	self:make_news_request()
end
function NewsFeedGui:update(t, dt)
	if not self._titles then
		return
	end
	if self._news then
		if self._title_panel:right() < 0 then
			self._news.i = self._news.i + 1
			if self._news.i > #self._titles then
				self._news.i = 1
			end
			self._title_panel:child("title"):set_text(self._titles[self._news.i])
			local _, _, w, h = self._title_panel:child("title"):text_rect()
			self._title_panel:set_w(w + 10)
			self._title_panel:set_left(self._panel:w())
		else
			self._title_panel:set_right(self._title_panel:right() - dt * 80)
		end
	end
end
function NewsFeedGui:make_news_request()
	print("make_news_request()")
	Steam:http_request("http://www.overkillsoftware.com/?feed=rss", callback(self, self, "news_result"))
end
function NewsFeedGui:news_result(success, body)
	print("news_result()", success)
	if success then
		self._titles = self:_get_text_block(body, "<title>", "</title>")
		self._links = self:_get_text_block(body, "<link>", "</link>")
		self._news = {i = 0}
	end
end
function NewsFeedGui:_create_gui()
	local size = managers.gui_data:scaled_size()
	self._panel = self._ws:panel():panel({
		name = "main",
		w = size.width,
		h = 28
	})
	self._panel:bitmap({
		name = "bg_bitmap",
		texture = "guis/textures/textboxbg",
		layer = 0,
		color = Color.black,
		w = self._panel:w(),
		h = self._panel:h()
	})
	self._title_panel = self._panel:panel({
		name = "title_panel",
		layer = 1
	})
	self._title_panel:text({
		name = "title",
		text = "hej",
		font = tweak_data.menu.pd2_medium_font,
		font_size = tweak_data.menu.pd2_medium_font_size,
		align = "left",
		halign = "left",
		vertical = "center",
		hvertical = "center",
		color = Color(0.75, 0.75, 0.75)
	})
	self._title_panel:set_right(-10)
	self._panel:set_bottom(self._panel:parent():h() - 40)
end
function NewsFeedGui:_get_text_block(s, sp, ep)
	local result = {}
	local len = string.len(s)
	local i = 1
	while len > i do
		local s1, e1 = string.find(s, sp, i, true)
		if not e1 then
			break
		end
		local s2, e2 = string.find(s, ep, e1, true)
		table.insert(result, string.sub(s, e1 + 1, s2 - 1))
		i = e1
	end
	return result
end
function NewsFeedGui:mouse_moved(x, y)
	local inside = self._panel:inside(x, y)
	if not inside or not Color.white then
	end
	self._title_panel:child("title"):set_color((Color(0.75, 0.75, 0.75)))
	return false, inside and "link"
end
function NewsFeedGui:mouse_pressed(button, x, y)
	if not self._news then
		return
	end
	if button == Idstring("0") and self._panel:inside(x, y) then
		Steam:overlay_activate("url", self._links[self._news.i])
		return true
	end
end
function NewsFeedGui:close()
	if alive(self._panel) then
		self._ws:panel():remove(self._panel)
	end
end
