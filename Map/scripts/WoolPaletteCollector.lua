local metadata = {
"## Interface: FS15 1.1.0.0 RC12",
"## Title: WoolPaletteCollector",
"## Notes: Sammelt Wollpaletten vom Spawn point",
"## Author: Marhu",
"## Version: 2.2.1b",
"## Date: 05.12.2014",
"## Web: http://marhu.net"
}
 
WoolPaletteCollector = {};
local WoolPaletteCollector_mt = Class(WoolPaletteCollector, Object);
InitObjectClass(WoolPaletteCollector, "WoolPaletteCollector");

local TITLE = "WoolPaletteCollector";

WoolPaletteCollector.db = {
		name = "WoolPaletteCollector",
		debug = false,
		transTime = 5000
	};
	
WoolPaletteCollector.optionen = {
		name = "WoolPaletteCollector",
		desc = "WoolPaletteCollector",
		type = 'group',
		args = {
			debuging = {
				name = "Debug",
				desc = "Print Debug info in Log",
				type = 'toggle',
				get = function() return WoolPaletteCollector.db.debug end,
				set = function(info, newValue)
					WoolPaletteCollector.db.debug = newValue
				end
			},
			trans = {
				name = "transTime",
				desc = "time of transport",
				type = 'range',
				min = 1000,
				max = 20000,
				step = 100,
				ispercent = true,
				get = function() return WoolPaletteCollector.db.transTime end,
				set = function(info, newValue)
					WoolPaletteCollector.db.transTime = newValue
				end
			}
		}
	};	
	
local function Debug(...)
	if WoolPaletteCollector.db.debug then
		local text = ""
		for i = 1, select("#", ...) do
			if type(select(i, ...)) == "boolean" then
				text = text..(select(i, ...) and "true" or "false").." "
			else
				text = text..(select(i, ...) or "nil").." "
			end
		end
		print(TITLE..": "..text)
	end
end	

function WoolPaletteCollector.onCreate(id)
	local object = WoolPaletteCollector:new(g_server ~= nil, g_client ~= nil)
	if object:load(id) then
        g_currentMission:addOnCreateLoadedObject(object);
        object:register(true);
		--- Log Info ---
		local function autor() for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],"## Author: ");if n then return (string.sub (metadata[i], n+1)); end;end;end;
		local function name() for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],"## Title: ");if n then return (string.sub (metadata[i], n+1)); end;end;end;
		local function version() for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],"## Version: ");if n then return (string.sub (metadata[i], n+1)); end;end;end;
		local function support() for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],"## Web: ");if n then return (string.sub (metadata[i], n+1)); end;end;end;
		print(string.format("Script %s v%s by %s created id %d! Support on %s",(name()),(version()),(autor()),id,(support())));
    else
        object:delete();
    end;
end;

function WoolPaletteCollector:new(isServer, isClient, customMt)
  
	local mt = customMt;
    if mt == nil then
        mt = WoolPaletteCollector_mt;
    end;

	local self = Object:new(isServer, isClient, mt);

	self.nodeID = 0;
	self.RollenMinY = -0.03;
	self.RollenMaxY = 0;
				
	self.WoolPaletteCollectorDirtyFlag = self:getNextDirtyFlag();


	return self;
 
end;

function WoolPaletteCollector:load(id) 
  
	if g_currentMission.DatenBank then
		g_currentMission.DatenBank.Add(self,self.db);
	end
	
	self.nodeID = id;
			
	local MainPlateIndex = getUserAttribute(id, "MainPlateIndex");
	if MainPlateIndex ~= nil then         
		local MainPlate = Utils.indexToObject(id, MainPlateIndex);
		if MainPlate ~= nil then
			self.Points = {};
			local numChildren = getNumOfChildren(MainPlate);
			for i = 1, numChildren do
				self.Points[i] = {};
				self.Points[i].node = getChildAt(getChildAt(MainPlate,i-1),0);
				self.Points[i].node2 = getChildAt(getChildAt(MainPlate,i-1),1);
				self.Points[i].set = false;
			end;
			self.Points[0] = {};
			self.Points[0].node2 = Utils.indexToObject(id, getUserAttribute(id, "RollenSpawner"));
			self.Points[0].set = false;
			self.width = getUserAttribute(MainPlate, "width");
			local minY, maxY = Utils.getVectorFromString(getUserAttribute(id, "RollenMinMax"));
			if minY ~= nil and maxY ~= nil then
				self.RollenMinY = minY;
				self.RollenMaxY = maxY;
			end;
		else
			return false;
		end;
	else
		return false;
	end;
		
	if self.isServer then	
		local TriggerIndex = getUserAttribute(id, "TriggerIndex");
		if TriggerIndex ~= nil then         
			local Trigger = Utils.indexToObject(id, TriggerIndex);
			if Trigger ~= nil then
				self.trigger = Trigger;
				addTrigger(self.trigger, "TriggerCallback", self);
			end;
		end;
		self.fremdObject = 0;
		self.PalletObjects = {};
	end;
	
	local LampIndex = getUserAttribute(id, "LampIndex");
	if LampIndex ~= nil then         
		local Lamp = Utils.indexToObject(id, LampIndex);
		if Lamp ~= nil then
			self.Lamp = {};
			local numChildren = getNumOfChildren(Lamp);
			for i = 1, numChildren do
				self.Lamp[i] = {};
				self.Lamp[i].node = getChildAt(Lamp,i-1);
				self.Lamp[i].t = 0;
				self.Lamp[i].s = 0; 
			end;
		end;
	end;
	
	return true;
end;
  
function WoolPaletteCollector:delete()
	if self.trigger then
		removeTrigger(self.trigger);
		self.trigger = nil;
	end;
end;

function WoolPaletteCollector:writeStream(streamId, connection)
	
	for i = 1, table.getn(self.Lamp) do
		local t = math.floor(self.Lamp[i].t);
		streamWriteInt8(streamId, self.Lamp[i].s);
		streamWriteInt16(streamId, t);
	end;
	for i = 0, table.getn(self.Points) do
		streamWriteBool(streamId, self.Points[i].set);
	end;
end; 

function WoolPaletteCollector:readStream(streamId, connection)
	
	for i = 1, table.getn(self.Lamp) do
		local s = streamReadInt8(streamId);
		local t = streamReadInt16(streamId);
		self:updateLamp(i, s, t);
	end;
	for i = 0, table.getn(self.Points) do
		local set = streamReadBool(streamId);
		if self.Points[i].set ~= set then
			self.Points[i].set = set;
			local trans = self.RollenMinY;
			if set then trans = self.RollenMaxY end;
			setTranslation(self.Points[i].node2, 0,trans,0);
		end;
	end;
end;

function WoolPaletteCollector:writeUpdateStream(streamId, connection, dirtyMask)
	
	if not connection:getIsServer() then
        for i = 1, table.getn(self.Lamp) do
			local t = math.floor(self.Lamp[i].t or 0);
			streamWriteInt8(streamId, self.Lamp[i].s);
			streamWriteInt16(streamId, t);
		end;
		for i = 0, table.getn(self.Points) do
			streamWriteBool(streamId, self.Points[i].set);
		end;
    end;
	
end;
 
function WoolPaletteCollector:readUpdateStream(streamId, timestamp, connection)
	
	if connection:getIsServer() then
        for i = 1, table.getn(self.Lamp) do
			local s = streamReadInt8(streamId);
			local t = streamReadInt16(streamId);
			self:updateLamp(i, s, t);
		end;
		for i = 0, table.getn(self.Points) do
			local set = streamReadBool(streamId);
			if self.Points[i].set ~= set then
				self.Points[i].set = set;
				local trans = self.RollenMinY;
				if set then trans = self.RollenMaxY end;
				setTranslation(self.Points[i].node2, 0,trans,0);
			end;
		end;
	end;
	
end;

function WoolPaletteCollector:update(dt)
	
	
	if not self.menueaddet then
		self.menueaddet = true;
		if g_currentMission.ModMenue then
			g_currentMission.ModMenue:Add(self.optionen);
		end;
	end;
		
	if self.isServer and self.Points[0].node then	
		
		if not self.firstScan then
			self.firstScan = true;
			for index,item in pairs(g_currentMission.itemsToSave) do
				if item.item:isa(FillablePallet) then
					local bx, by, bz = getWorldTranslation(item.item.nodeId);
					for i = 1, table.getn(self.Points) do
						local x, y, z = getWorldTranslation(self.Points[i].node);
						local distance = Utils.vector3Length(x-bx, y-by, z-bz);
						if distance < 1 then
							self.Points[i].Pallet = item.item.nodeId;
							if self.PalletScan and self.PalletScan[item.item.nodeId] then
								self.fremdObject = math.max(0,self.fremdObject - self.PalletScan[item.item.nodeId]);
							end;
							break;
						end;
					end;
				end;
			end;
			self.PalletScan = nil;
			self:updateLamp(3, 1);
		end;
		
		if self.fremdObject <= 0 then	
			if self.Points[0].Pallet and not self.NextLine1 then
				for i = self.width - 1, 0, -1 do
					if self.Points[i].Pallet and (self.Points[i+1].Pallet == nil or self.Points[i+1].Move == true) then
						self.Points[i].Move = true;
						local sx,sy,sz = getWorldTranslation(self.Points[i].node);
						local ex,ey,ez = getWorldTranslation(self.Points[i+1].node);
						local trans = {getTranslation(self.Points[i].Pallet)};
						local newtrans = Utils.getMovedLimitedValues(trans, {ex,ey,ez}, {sx,sy,sz}, 3, self.db.transTime, dt, false);
     					removeFromPhysics(self.Points[i].Pallet)
						setTranslation(self.Points[i].Pallet, unpack(newtrans));
						addToPhysics(self.Points[i].Pallet)
		
						local distance = Utils.vector3Length(ex-newtrans[1], ey-newtrans[2], ez-newtrans[3]);
						if distance <= 0.01 and self.Points[i+1].Pallet == nil then
							self.Points[i+1].Pallet = self.Points[i].Pallet;
							if i == 0 then
								local sheep = g_currentMission.husbandries.sheep;
								sheep:palletSpawnerTriggerCallback(sheep.palletSpawnerTriggerId, self.Points[i].Pallet, false, true, nil);
								sheep.numObjectsInPalletSpawnerTrigger = 0;
							end
							self.Points[i].Pallet = nil;
							self.Points[i].Move = nil;
							
						else
							self.Points[i].enable = true;
							self.Points[i+1].enable = true;
						end;
					end;
				end;
				
				local firstFull = true;
				for i = 1, self.width do
					if self.Points[i].Pallet == nil then
						firstFull = false;
						break;
					end;
				end;
				
				if firstFull == true then -- palett on 1 - 3 next line
					self.NextLine1 = true;
				else
					self:updateLamp(1, 0);
					self:updateLamp(2, 1);
					self:updateLamp(3, 0);
				end;
			elseif self.NextLine1 then
				self.NextLine1 = nil;
				local FreePlace = false;
				local num = table.getn(self.Points) - self.width;
				for i = num, 1, -1 do
					if self.Points[i].Pallet and (self.Points[i+self.width].Pallet == nil or self.Points[i+self.width].Move == true)  then
						self.NextLine1 = true;
						self.Points[i].Move = true;
						local sx,sy,sz = getWorldTranslation(self.Points[i].node);
						local ex,ey,ez = getWorldTranslation(self.Points[i+self.width].node);
						local trans = {getTranslation(self.Points[i].Pallet)};
						local newtrans = Utils.getMovedLimitedValues(trans, {ex,ey,ez}, {sx,sy,sz}, 3, self.db.transTime, dt, false);
						removeFromPhysics(self.Points[i].Pallet)
						setTranslation(self.Points[i].Pallet, unpack(newtrans));
						addToPhysics(self.Points[i].Pallet)
						local distance = Utils.vector3Length(ex-newtrans[1], ey-newtrans[2], ez-newtrans[3]);
						if distance <= 0.01 and self.Points[i+self.width].Pallet == nil then
							self.Points[i+self.width].Pallet = self.Points[i].Pallet;
							self.Points[i].Pallet = nil;
							self.Points[i].Move = nil;
						else
							self.Points[i].enable = true;
							self.Points[i+self.width].enable = true;
						end;
						FreePlace = true;
					end;
				end;
				
				local firstEmpty = true;
				for i = 1, self.width do
					if self.Points[i].Pallet ~= nil then
						firstEmpty = false;
						break;
					end;
				end;
				if firstEmpty == true then
					self.NextLine1 = nil;
					Debug("firstEmpty");
				end
				
				if FreePlace == true then
					self:updateLamp(1, 0);
					self:updateLamp(2, 1);
					self:updateLamp(3, 0);
				else
					self:updateLamp(1, 3);
					self:updateLamp(2, 3, 500);
					self:updateLamp(3, 0);
					
					if not self.MSGsend and self.Points[0].Pallet then
						local free = false;
						for i = 1, table.getn(self.Points) do
							if self.Points[i].Pallet == nil then
								free = true;
								break;
							end;
						end;
						if free == false then
							self.MSGsend = true;
							if g_currentMission.LiveTicker then
								g_currentMission.LiveTicker:Add("WoolPalettCollector Full");
							end;
						end;
					end;
				end;
			else
				self:updateLamp(1, 0);
				self:updateLamp(2, 0);
				self:updateLamp(3, 1);
				self.MSGsend = nil;
			end;
		else
			self:updateLamp(1, 1);
			self:updateLamp(2, 0);
			self:updateLamp(3, 0);
		end;
			
		if g_currentMission.husbandries.sheep.currentPallet and self.Points[0].Pallet == nil then
			local lvl = g_currentMission.husbandries.sheep.currentPallet.fillLevel;
			local capa = g_currentMission.husbandries.sheep.currentPallet.capacity;
			if lvl == capa then
				self.Points[0].Pallet = g_currentMission.husbandries.sheep.currentPallet.nodeId;
			end;
		end;
	elseif self.Points[0].node == nil then
		if g_currentMission.husbandries.sheep then
			self.Points[0].node = g_currentMission.husbandries.sheep.palletSpawnerPlaceId;
		end;
	end;
	
	self:updateLamp(dt);
	
end;

function WoolPaletteCollector:updateTick(dt)
	
	if self.isServer and self.Points[0].node ~= nil then
		if g_currentMission.husbandries.sheep.currentPallet then
			local parent = getParent(g_currentMission.husbandries.sheep.currentPallet.nodeId);
			if getName(parent) ~= "RootNode" then
				local sheep = g_currentMission.husbandries.sheep;
				sheep:palletSpawnerTriggerCallback(sheep.palletSpawnerTriggerId, sheep.currentPallet.nodeId, false, true, nil);
				sheep.numObjectsInPalletSpawnerTrigger = 0;
			end;
		end;
		for i=0,table.getn(self.Points) do
			if self.Points[i].Pallet then
				local parent = getParent(self.Points[i].Pallet);
				if getName(parent) ~= "RootNode" then
					self.Points[i].Pallet = nil;
					self.Points[i].Move = nil;
				end;
			end;
			if self.Points[i].enable == true then
				self.Points[i].enable = false;
				if not self.Points[i].set then
					self.Points[i].set = true;
					setTranslation(self.Points[i].node2, 0,self.RollenMaxY,0);
					self.SendEvent = true;
				end;
			elseif self.Points[i].enable == false and self.Points[i].set == true then
				self.Points[i].set = false;
				setTranslation(self.Points[i].node2, 0,self.RollenMinY,0);
				self.SendEvent = true;
			end;
		end;
		if self.SendEvent then
			self.SendEvent = false;
			self:raiseDirtyFlags(self.WoolPaletteCollectorDirtyFlag);
		end;
	end;
end;

function WoolPaletteCollector:updateLamp(i, s, t)
	if s ~= nil then
		if self.Lamp[i].s ~= s then
			if s == 0 then
				setVisibility(self.Lamp[i].node, false);
			elseif s == 1 then
				setVisibility(self.Lamp[i].node, true);
			elseif s == 3 then
				setVisibility(self.Lamp[i].node, true);
				self.Lamp[i].t = t or 0;
			end;
			self.Lamp[i].s = s;
			self.SendEvent = true;
		end;
	else
		for j = 1, table.getn(self.Lamp) do
			if self.Lamp[j].s == 3 then
				self.Lamp[j].t = self.Lamp[j].t + i;
				if self.Lamp[j].t >= 500 then
					self.Lamp[j].t = 0;
					setVisibility(self.Lamp[j].node,not getVisibility(self.Lamp[j].node));
				end;
			end;
		end;
	end;
end;

function WoolPaletteCollector:TriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	
	if otherId ~= 0 then
		local object = g_currentMission:getNodeObject(otherId);
		if object ~= nil then
			if object:isa(FillablePallet) then
				if (onEnter) then 
					local find;
					for i = 0 , table.getn(self.Points) do
						if self.Points[i].Pallet == otherId then
							find = true;
							break;
						end;
					end;
					if find ~= true then
						if not self.firstScan then
							if not self.PalletScan then self.PalletScan = {} end;
							self.PalletScan[otherId] = (self.PalletScan[otherId] or 0) + 1;
						end;
						self.fremdObject = self.fremdObject + 1;
					else
						self.PalletObjects[otherId] = math.min(4,(self.PalletObjects[otherId] or 0) + 1);
					end;
				elseif (onLeave) then
					local find;
					for i = 0 , table.getn(self.Points) do
						if self.Points[i].Pallet == otherId then
							find = true;
							self.Points[i].Pallet = nil;
							self.Points[i].Move = nil;
							if self.PalletObjects[otherId] then
								self.fremdObject = self.fremdObject + self.PalletObjects[otherId] - 1;
								self.PalletObjects[otherId] = nil;
							end;
						end;
					end;
					if find == nil then
						self.fremdObject = math.max(0,self.fremdObject - 1);
					end;
				end;
			else
				if (onEnter) then 
					self.fremdObject = self.fremdObject + 1;
				else
					self.fremdObject = math.max(0,self.fremdObject - 1);
				end;
			end;
		else
			if (onEnter) then 
				self.fremdObject = self.fremdObject + 1;
			else
				self.fremdObject = math.max(0,self.fremdObject - 1);
			end;
		end;
	end;
	
 end;

g_onCreateUtil.addOnCreateFunction("WoolPaletteCollector", WoolPaletteCollector.onCreate);
 