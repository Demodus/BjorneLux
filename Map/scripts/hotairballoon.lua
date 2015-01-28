--
-- hotairballoon.lua
--
-- @Author: schwaki|112TEC
--

function onCreatehotairballoon(self,id)
	local instance = hotairballoon:new(g_server ~= nil, g_client ~= nil);
    local index = g_currentMission:addOnCreateLoadedObject(instance);
    instance:load(id);
    instance:register(true);
end;

hotairballoon = {}
local hotairballoon_mt = Class(hotairballoon, Object);

function hotairballoon:new(isServer, isClient)
    local self = Object:new(isServer, isClient, hotairballoon_mt);
    self.className = "hotairballoon";
    return self;
end;

function hotairballoon:load(id)  
    self.object = id;
    self.dtTime = 0;
end;

function hotairballoon:update(dt)
    self.dtTime = self.dtTime + dt;
    if self.dtTime > 6000 then
        self.dtTime = 0;
        setVisibility(self.object,not getVisibility(self.object));
	end;
end;

function hotairballoon:delete()
end;