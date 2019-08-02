MissionDoorTweakData = MissionDoorTweakData or class()
function MissionDoorTweakData:init()
	self.default = {}
	self.default.devices = {}
	self.default.devices.drill = {
		{
			align = "a_drill_1",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 20
		},
		{
			align = "a_drill_2",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small")
		}
	}
	self.default.devices.c4 = {
		{
			align = "a_c4_1",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_c4_2",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_c4_3",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
	self.test = deep_clone(self.default)
	self.bank_door_test = {}
	self.bank_door_test.devices = {}
	self.bank_door_test.devices.drill = {
		{
			align = "a_drill_a",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 20
		}
	}
	self.crossing_armored_vehicle = {}
	self.crossing_armored_vehicle.devices = {}
	self.crossing_armored_vehicle.devices.drill = {
		{
			align = "a_drill_1",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 180
		}
	}
	self.reinforced_door = {}
	self.reinforced_door.devices = {}
	self.reinforced_door.devices.c4 = {
		{
			align = "a_shp_charge_1",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
	self.keycard_door = {}
	self.keycard_door.devices = {}
	self.keycard_door.devices.c4 = {
		{
			align = "a_shp_charge_1",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_shp_charge_2",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_shp_charge_3",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
	self.keycard_door.devices.drill = {
		{
			align = "a_drill",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 180
		}
	}
	self.keycard_door.devices.key = {
		{
			align = "a_keycard",
			unit = Idstring("units/payday2/equipment/gen_interactable_panel_keycard/gen_interactable_panel_keycard")
		}
	}
	self.keycard_door.devices.ecm = {
		{
			align = "a_ecm_hack",
			unit = Idstring("units/payday2/equipment/gen_interactable_door_keycard/gen_interactable_door_keycard_jammer")
		}
	}
	self.safe_small = {}
	self.safe_small.devices = {}
	self.safe_small.devices.drill = {
		{
			align = "a_drill",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 180
		}
	}
	self.safe_small.devices.c4 = {
		{
			align = "a_shp_charge",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
	self.safe_medium = {}
	self.safe_medium.devices = {}
	self.safe_medium.devices.drill = {
		{
			align = "a_drill",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 240
		}
	}
	self.safe_medium.devices.c4 = {
		{
			align = "a_shp_charge",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
	self.safe_large = {}
	self.safe_large.devices = {}
	self.safe_large.devices.drill = {
		{
			align = "a_drill",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 300
		}
	}
	self.safe_large.devices.c4 = {
		{
			align = "a_shp_charge",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
	self.safe_giga = {}
	self.safe_giga.devices = {}
	self.safe_giga.devices.drill = {
		{
			align = "a_drill",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 300
		}
	}
	self.safe_giga.devices.c4 = {
		{
			align = "a_shp_charge_1",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_shp_charge_2",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_shp_charge_3",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_shp_charge_4",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
	self.safe = {}
	self.safe.devices = {}
	self.safe.devices.drill = {
		{
			align = "a_drill",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 300
		}
	}
	self.safe.devices.c4 = {
		{
			align = "a_shp_charge_1",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_shp_charge_2",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_shp_charge_3",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		},
		{
			align = "a_shp_charge_4",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
	self.security_panel = {}
	self.security_panel.devices = {}
	self.security_panel.devices.ecm = {
		{
			align = "a_ecm_hack",
			unit = Idstring("units/payday2/equipment/gen_interactable_door_keycard/gen_interactable_door_keycard_jammer")
		}
	}
	self.vault_door = {}
	self.vault_door.devices = {}
	self.vault_door.devices.drill = {
		{
			align = "a_lance_1",
			unit = Idstring("units/payday2/equipment/gen_interactable_drill_large_thermic/gen_interactable_drill_large_thermic"),
			can_jam = true,
			timer = 360
		}
	}
	self.train_door = {}
	self.train_door.devices = {}
	self.train_door.devices.drill = {
		{
			align = "a_drill",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 60
		}
	}
	self.shape_and_drill = {}
	self.shape_and_drill.devices = {}
	self.shape_and_drill.devices.drill = {
		{
			align = "a_drill",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 180
		}
	}
	self.shape_and_drill.devices.c4 = {
		{
			align = "a_shp_charge",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
	self.truck = {}
	self.truck.devices = {}
	self.truck.devices.drill = {
		{
			align = "a_drill",
			unit = Idstring("units/payday2/equipment/item_door_drill_small/item_door_drill_small"),
			can_jam = true,
			timer = 120
		}
	}
	self.truck.devices.c4 = {
		{
			align = "a_shp_charge",
			unit = Idstring("units/payday2/equipment/gen_equipment_shape_charge/gen_equipment_shape_charge")
		}
	}
end
