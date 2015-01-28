DigitalAmountMover = {};
local DigitalAmountMover_mt = Class(DigitalAmountMover);

function DigitalAmountMover.onCreate(id)
	g_currentMission:addUpdateable(DigitalAmountMover:new(id));
end;

function DigitalAmountMover:new(id, customMt)
	local instance = {};
      if customMt ~= nil then
          setmetatable(instance, customMt);
      else
          setmetatable(instance, DigitalAmountMover_mt);
      end;

	instance.id = id;
	local idx = getUserAttribute(id, "triggerId");
	if idx ~= nil then
		instance.triggerId = idx;
		addTrigger(idx, "triggerCallback", instance);
	else
		print("  ERROR: Cannot add this Digital Trigger");
		return nil;
	end;
	local fillType = getUserAttribute(id, "fillType");
	if fillType ~= nil then
		instance.fillType = Fillable.fillTypeNameToInt[fillType];
	end;
	if instance.fillType == nil then
		instance.fillType = Fillable.FILLTYPE_LIQUIDMANURE;
	end;
	local tmp = getUserAttribute(instance.id, "digit1");
	if tmp ~= nil then
		instance.digits = {};
		instance.digits[1] = Utils.indexToObject(instance.id, getUserAttribute(instance.id, "digit1"));
		instance.digits[2] = Utils.indexToObject(instance.id, getUserAttribute(instance.id, "digit2"));
		instance.digits[3] = Utils.indexToObject(instance.id, getUserAttribute(instance.id, "digit3"));
		instance.digits[4] = Utils.indexToObject(instance.id, getUserAttribute(instance.id, "digit4"));
		instance.digits[5] = Utils.indexToObject(instance.id, getUserAttribute(instance.id, "digit5"));
		instance.digits[6] = Utils.indexToObject(instance.id, getUserAttribute(instance.id, "digit6"));
		instance.digits[7] = Utils.indexToObject(instance.id, getUserAttribute(instance.id, "digit7"));

		instance.digitPosition = {};
		instance.digitPosition["0"] = -1.000;
		instance.digitPosition["1"] = -0.105;
		instance.digitPosition["2"] = -0.208;
		instance.digitPosition["3"] = -0.306;
		instance.digitPosition["4"] = -0.410;
		instance.digitPosition["5"] = -0.517;
		instance.digitPosition["6"] = -0.613;
		instance.digitPosition["7"] = -0.719;
		instance.digitPosition["8"] = -0.817;
		instance.digitPosition["9"] = -0.926;
	end;

	instance.oldAmount = 0;
	instance.isEnabled = true;
	return instance;
end;

function DigitalAmountMover:delete()
	removeTrigger(self.triggerId);
end;

function DigitalAmountMover:update(dt)
	local amount = 0;
	if self.fillType == (Fillable.FILLTYPE_WHEAT_WINDROW or Fillable.FILLTYPE_BARLEY_WINDROW) then
		amount = amount + g_currentMission:getSiloAmount(Fillable.FILLTYPE_WHEAT_WINDROW);
		amount = amount + g_currentMission:getSiloAmount(Fillable.FILLTYPE_BARLEY_WINDROW);
		amount = amount + g_currentMission:getSiloAmount(Fillable.FILLTYPE_RYE_WINDROW);
		amount = amount + g_currentMission:getSiloAmount(Fillable.FILLTYPE_DINKEL_WINDROW);
		amount = amount + g_currentMission:getSiloAmount(Fillable.FILLTYPE_OAT_WINDROW);
	elseif self.fillType == (Fillable.FILLTYPE_GRASS_WINDROW or Fillable.FILLTYPE_DRYGRASS_WINDROW) then
		amount = amount + g_currentMission:getSiloAmount(Fillable.FILLTYPE_GRASS_WINDROW);
		amount = amount + g_currentMission:getSiloAmount(Fillable.FILLTYPE_DRYGRASS_WINDROW);
	else
		amount = amount + g_currentMission:getSiloAmount(self.fillType);
	end;
	if self.oldAmount ~= amount then
		self.oldAmount = amount;
		if amount < 0.5 then
			amount = 0;
		end;
		self:setDigitNumbers(amount);
	end;
end;

function DigitalAmountMover:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
end;

function DigitalAmountMover:setDigitNumbers(mass)
	local mass = mass;
	local massUnits = string.format("%d", mass);
	local digit1 = "0";
	local digit2 = "0";
	local digit3 = "0";
	local digit4 = "0";
	local digit5 = "0";
	local digit6 = "0";
	local digit7 = "0";
	if mass >= 1000000 then
		digit1 = string.sub(massUnits, 1, 1);
		digit2 = string.sub(massUnits, 2, 2);
		digit3 = string.sub(massUnits, 3, 3);
		digit4 = string.sub(massUnits, 4, 4);
		digit5 = string.sub(massUnits, 5, 5);
		digit6 = string.sub(massUnits, 6, 6);
		digit7 = string.sub(massUnits, 7, 7);
		setVisibility(self.digits[7],true);
		setVisibility(self.digits[6],true);
		setVisibility(self.digits[5],true);
		setVisibility(self.digits[4],true);
		setVisibility(self.digits[3],true);
		setVisibility(self.digits[2],true);
		setVisibility(self.digits[1],true);
	elseif mass >= 100000 then
		digit2 = string.sub(massUnits, 1, 1);
		digit3 = string.sub(massUnits, 2, 2);
		digit4 = string.sub(massUnits, 3, 3);
		digit5 = string.sub(massUnits, 4, 4);
		digit6 = string.sub(massUnits, 5, 5);
		digit7 = string.sub(massUnits, 6, 6);
		setVisibility(self.digits[7],true);
		setVisibility(self.digits[6],true);
		setVisibility(self.digits[5],true);
		setVisibility(self.digits[4],true);
		setVisibility(self.digits[3],true);
		setVisibility(self.digits[2],true);
		setVisibility(self.digits[1],false);
	elseif mass >= 10000 then
		digit3 = string.sub(massUnits, 1, 1);
		digit4 = string.sub(massUnits, 2, 2);
		digit5 = string.sub(massUnits, 3, 3);
		digit6 = string.sub(massUnits, 4, 4);
		digit7 = string.sub(massUnits, 5, 5);
		setVisibility(self.digits[7],true);
		setVisibility(self.digits[6],true);
		setVisibility(self.digits[5],true);
		setVisibility(self.digits[4],true);
		setVisibility(self.digits[3],true);
		setVisibility(self.digits[2],false);
		setVisibility(self.digits[1],false);
	elseif mass >= 1000 then
		digit4 = string.sub(massUnits, 1, 1);
		digit5 = string.sub(massUnits, 2, 2);
		digit6 = string.sub(massUnits, 3, 3);
		digit7 = string.sub(massUnits, 4, 4);
		setVisibility(self.digits[7],true);
		setVisibility(self.digits[6],true);
		setVisibility(self.digits[5],true);
		setVisibility(self.digits[4],true);
		setVisibility(self.digits[3],false);
		setVisibility(self.digits[2],false);
		setVisibility(self.digits[1],false);
	elseif mass >= 100 then
		digit5 = string.sub(massUnits, 1, 1);
		digit6 = string.sub(massUnits, 2, 2);
		digit7 = string.sub(massUnits, 3, 3);
		setVisibility(self.digits[7],true);
		setVisibility(self.digits[6],true);
		setVisibility(self.digits[5],true);
		setVisibility(self.digits[4],false);
		setVisibility(self.digits[3],false);
		setVisibility(self.digits[2],false);
		setVisibility(self.digits[1],false);
	elseif mass >= 10 then
		digit6 = string.sub(massUnits, 1, 1);
		digit7 = string.sub(massUnits, 2, 2);
		setVisibility(self.digits[7],true);
		setVisibility(self.digits[6],true);
		setVisibility(self.digits[5],false);
		setVisibility(self.digits[4],false);
		setVisibility(self.digits[3],false);
		setVisibility(self.digits[2],false);
		setVisibility(self.digits[1],false);
	elseif mass >= 0 then
		digit7 = string.sub(massUnits, 1, 1);
		setVisibility(self.digits[7],true);
		setVisibility(self.digits[6],false);
		setVisibility(self.digits[5],false);
		setVisibility(self.digits[4],false);
		setVisibility(self.digits[3],false);
		setVisibility(self.digits[2],false);
		setVisibility(self.digits[1],false);
	else
		setVisibility(self.digits[7],false);
		setVisibility(self.digits[6],false);
		setVisibility(self.digits[5],false);
		setVisibility(self.digits[4],false);
		setVisibility(self.digits[3],false);
		setVisibility(self.digits[2],false);
		setVisibility(self.digits[1],false);
	end;
	setShaderParameter(self.digits[7], "Position", self.digitPosition[digit7], 0, 0, 0, false);
	setShaderParameter(self.digits[6], "Position", self.digitPosition[digit6], 0, 0, 0, false);
	setShaderParameter(self.digits[5], "Position", self.digitPosition[digit5], 0, 0, 0, false);
	setShaderParameter(self.digits[4], "Position", self.digitPosition[digit4], 0, 0, 0, false);
	setShaderParameter(self.digits[3], "Position", self.digitPosition[digit3], 0, 0, 0, false);
	setShaderParameter(self.digits[2], "Position", self.digitPosition[digit2], 0, 0, 0, false);
	setShaderParameter(self.digits[1], "Position", self.digitPosition[digit1], 0, 0, 0, false);
end;

g_onCreateUtil.addOnCreateFunction("DigitalAmountMoverOnCreate", DigitalAmountMover.onCreate);
