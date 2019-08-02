core:import("CoreMissionScriptElement")
ElementInventoryDummy = ElementInventoryDummy or class(CoreMissionScriptElement.MissionScriptElement)
function ElementInventoryDummy:init(...)
	ElementInventoryDummy.super.init(self, ...)
end
function ElementInventoryDummy:client_on_executed(...)
end
function ElementInventoryDummy:on_executed(instigator)
	if not self._values.enabled then
		return
	end
	if self._values.category ~= "none" then
		if self._values.category == "primaries" or self._values.category == "secondaries" then
			self:_spawn_weapon(self._values.category, self._values.slot, self._values.position, self._values.rotation)
		elseif self._values.category == "masks" then
			self:_spawn_mask(self._values.category, self._values.slot, self._values.position, self._values.rotation)
		end
	end
	ElementInventoryDummy.super.on_executed(self, instigator)
end
function ElementInventoryDummy:_spawn_weapon(category, slot, position, rotation)
	local category = managers.blackmarket:get_crafted_category(category)
	if not category then
		return
	end
	local slot_data = category[slot]
	if not slot_data then
		return
	end
	local unit_name = tweak_data.weapon.factory[slot_data.factory_id].unit
	managers.dyn_resource:load(Idstring("unit"), Idstring(unit_name), DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	self._weapon_unit = World:spawn_unit(Idstring(unit_name), position, rotation)
	self._parts, self._blueprint = managers.weapon_factory:assemble_from_blueprint(slot_data.factory_id, self._weapon_unit, slot_data.blueprint, true, callback(self, self, "_assemble_completed"))
	self._weapon_unit:set_moving(true)
end
function ElementInventoryDummy:_assemble_completed(parts, blueprint)
	self._parts = parts
	self._blueprint = blueprint
	self._weapon_unit:set_moving(true)
end
function ElementInventoryDummy:_spawn_mask(category, slot, position, rotation)
	local category = managers.blackmarket:get_crafted_category(category)
	if not category then
		return
	end
	local slot_data = category[slot]
	if not slot_data then
		return
	end
	local mask_unit_name = managers.blackmarket:mask_unit_name_by_mask_id(slot_data.mask_id)
	managers.dyn_resource:load(Idstring("unit"), Idstring(mask_unit_name), DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	self._mask_unit = World:spawn_unit(Idstring(mask_unit_name), position, rotation)
	local backside = World:spawn_unit(Idstring("units/payday2/masks/msk_backside/msk_backside"), position, rotation, position, rotation)
	self._mask_unit:link(self._mask_unit:orientation_object():name(), backside, backside:orientation_object():name())
	self._mask_unit:base():apply_blueprint(slot_data.blueprint)
	self._mask_unit:set_moving(true)
end
function ElementInventoryDummy:pre_destroy()
	ElementInventoryDummy.super.pre_destroy(self)
	if alive(self._weapon_unit) then
		managers.weapon_factory:disassemble(self._parts)
		local name = self._weapon_unit:name()
		self._weapon_unit:base():set_slot(self._weapon_unit, 0)
		World:delete_unit(self._weapon_unit)
		managers.dyn_resource:unload(Idstring("unit"), name, DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	end
	if alive(self._mask_unit) then
		for _, linked_unit in ipairs(self._mask_unit:children()) do
			linked_unit:unlink()
			World:delete_unit(linked_unit)
		end
		local name = self._mask_unit:name()
		World:delete_unit(self._mask_unit)
		managers.dyn_resource:unload(Idstring("unit"), name, DynamicResourceManager.DYN_RESOURCES_PACKAGE, false)
	end
end
