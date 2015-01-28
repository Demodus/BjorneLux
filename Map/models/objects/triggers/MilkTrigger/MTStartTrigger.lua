local metadata = {
"## Interface: FS15 1.1.0.0 RC12",
"## Title: MTStartTrigger",
"## Notes: Placeable  MilkTruckStartTrigger",
"## Author: Marhu",
"## Version: 2.0.0",
"## Date: 07.11.2014",
}

MTStartTrigger = {};
MTStartTrigger_mt = Class(MTStartTrigger, Placeable);
InitObjectClass(MTStartTrigger, "MTStartTrigger");

function MTStartTrigger:new(isServer, isClient, customMt)
    local self = Placeable:new(isServer, isClient, MTStartTrigger_mt);
    registerObjectClassName(self, "MTStartTrigger");
	
	return self;
end;

function MTStartTrigger:delete()
  	if self.trigger ~= nil then
		removeTrigger(self.trigger.triggerId)
	end
	unregisterObjectClassName(self);
    MTStartTrigger:superClass().delete(self);
end;

function MTStartTrigger:deleteFinal()
    MTStartTrigger:superClass().deleteFinal(self);
end;

function MTStartTrigger:load(xmlFilename, x,y,z, rx,ry,rz, moveMode, initRandom)
    if not MTStartTrigger:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, moveMode, initRandom) then
        return false;
    end;

	if not moveMode then
		if g_currentMission:getIsServer() then
			self.trigger = MilktruckStartTrigger:new(self.nodeId)
			g_currentMission:addNonUpdateable(self.trigger)
		end
	end
  
	return true;
end;

function MTStartTrigger:update(dt)
end;

registerPlaceableType("MTStartTrigger", MTStartTrigger);