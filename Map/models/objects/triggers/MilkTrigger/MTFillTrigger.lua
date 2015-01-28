local metadata = {
"## Interface: FS15 1.1.0.0 RC12",
"## Title: MTFillTrigger",
"## Notes: Placeable  MilkTruckFillTrigger",
"## Author: Marhu",
"## Version: 2.0.0",
"## Date: 07.11.2014",
}

MTFillTrigger = {};
MTFillTrigger_mt = Class(MTFillTrigger, Placeable);
InitObjectClass(MTFillTrigger, "MTFillTrigger");

function MTFillTrigger:new(isServer, isClient, customMt)
    local self = Placeable:new(isServer, isClient, MTFillTrigger_mt);
    registerObjectClassName(self, "MTFillTrigger");
	
	return self;
end;

function MTFillTrigger:delete()
	if self.trigger ~= nil then
		removeTrigger(self.trigger.triggerId)
	end
	unregisterObjectClassName(self);
    MTFillTrigger:superClass().delete(self);
end;

function MTFillTrigger:deleteFinal()
    MTFillTrigger:superClass().deleteFinal(self);
end;

function MTFillTrigger:load(xmlFilename, x,y,z, rx,ry,rz, moveMode, initRandom)
    if not MTFillTrigger:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, moveMode, initRandom) then
        return false;
    end;

	if not moveMode then
		if g_currentMission:getIsServer() then
			self.trigger = MilktruckFillTrigger:new(self.nodeId)
			g_currentMission:addNonUpdateable(self.trigger)
		end
	end
  	return true;
end;

function MTFillTrigger:update(dt)
end;

registerPlaceableType("MTFillTrigger", MTFillTrigger);