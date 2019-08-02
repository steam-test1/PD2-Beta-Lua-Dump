CrimeNetFiltersGui = CrimeNetFiltersGui or class()
function CrimeNetFiltersGui:init(ws, fullscreen_ws, node)
	self._ws = ws
	self._fullscreen_ws = fullscreen_ws
	self._panel = self._ws:panel():panel({layer = 51})
	self._fullscreen_panel = self._fullscreen_ws:panel():panel({layer = 50})
	self._node = node
	local blur = self._fullscreen_panel:bitmap({
		texture = "guis/textures/test_blur_df",
		w = self._fullscreen_ws:panel():w(),
		h = self._fullscreen_ws:panel():h(),
		render_template = "VertexColorTexturedBlur3D"
	})
	local func = function(o)
		local start_blur = 0
		over(0.6, function(p)
			o:set_alpha(math.lerp(start_blur, 1, p))
		end)
	end
	blur:animate(func)
	managers.menu:active_menu().input:deactivate_controller_mouse()
end
function CrimeNetFiltersGui:close()
	if not managers.menu:is_pc_controller() then
		managers.menu:active_menu().input:activate_controller_mouse()
	end
	self._ws:panel():remove(self._panel)
	self._fullscreen_ws:panel():remove(self._fullscreen_panel)
end
