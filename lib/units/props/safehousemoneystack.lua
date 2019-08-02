SafehouseMoneyStack = SafehouseMoneyStack or class(UnitBase)
SafehouseMoneyStack.MAX_SUM = 10000000
SafehouseMoneyStack.STEPS = 32
function SafehouseMoneyStack:init(unit)
	UnitBase.init(self, unit, false)
	self._unit = unit
	self._sequences = {}
	for i = 1, SafehouseMoneyStack.STEPS do
		local post_fix = (i < 10 and "0" or "") .. i
		table.insert(self._sequences, "var_money_grow_" .. post_fix)
	end
	local money = managers.money:total()
	local where = math.min(money / SafehouseMoneyStack.MAX_SUM, 1)
	local sequence_index = math.ceil(where * #self._sequences)
	local sequence = sequence_index == 0 and "var_money_grow_00" or self._sequences[math.clamp(sequence_index, 1, #self._sequences)]
	self._unit:damage():run_sequence_simple(sequence)
end
function SafehouseMoneyStack:destroy()
end
