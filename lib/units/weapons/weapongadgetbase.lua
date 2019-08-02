WeaponGadgetBase = WeaponGadgetBase or class(UnitBase)
function WeaponGadgetBase:init(unit)
	WeaponGadgetBase.super.init(self, unit)
	self._on = false
end
function WeaponGadgetBase:set_npc()
end
function WeaponGadgetBase:set_state(on, sound_source)
	if self._on ~= on and sound_source then
		sound_source:post_event(on and self._on_event or self._off_event)
	end
	self._on = on
	self:_check_state()
end
function WeaponGadgetBase:set_on()
	self._on = true
	self:_check_state()
end
function WeaponGadgetBase:set_off()
	self._on = false
	self:_check_state()
end
function WeaponGadgetBase:toggle()
	self._on = not self._on
	self:_check_state()
end
function WeaponGadgetBase:is_on()
	return self._on
end
function WeaponGadgetBase:_check_state()
end
function WeaponGadgetBase:destroy(unit)
	WeaponGadgetBase.super.pre_destroy(self, unit)
end
