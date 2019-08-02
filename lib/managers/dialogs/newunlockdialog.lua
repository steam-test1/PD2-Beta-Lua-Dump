core:module("SystemMenuManager")
require("lib/managers/dialogs/GenericDialog")
NewUnlockDialog = NewUnlockDialog or class(GenericDialog)
function NewUnlockDialog:init(manager, data)
	NewUnlockDialog.super.init(self, manager, data, false)
	self._sound_event = data.sound_event
end
function NewUnlockDialog:fade_in()
	NewUnlockDialog.super.fade_in(self)
	self._start_sound_t = TimerManager:main():time() + 0.2
end
function NewUnlockDialog:update(t, dt)
	NewUnlockDialog.super.update(self, t, dt)
	if self._start_sound_t and t > self._start_sound_t then
		managers.menu_component:post_event(self._sound_event)
		self._start_sound_t = nil
	end
end
