local metadata = {
"## Interface:FS15 1.1.0.0 RC12",
"## Title: WaterMod",
"## Notes: Map WaterMod give animals Water",
"## Author: Marhu",
"## Version: 3.1.5",
"## Date: 10.11.2014",
"## Web: http://marhu.net"
}


WaterMod = {};
WaterMod.Triggers = {}
WaterMod.Animals = {}
WaterMod.Needs = { ["cow"]={[Fillable.FILLTYPE_WATER]=60},
				   ["sheep"]={[Fillable.FILLTYPE_WATER]=10},
				   ["chicken"]={[Fillable.FILLTYPE_WATER]=1,[Fillable.FILLTYPE_WHEAT]=0.5}}

if AnimalHusbandry.load ~= nil then
	local orgload = AnimalHusbandry.load
	AnimalHusbandry.load = function(a, b, c, d, e, f)
		local ra = orgload(a, b, c, d, e, f)
		
		for i = 1 ,table.getn(a.tipTriggers) do
			if WaterMod.Animals[a.typeName] == nil then  WaterMod.Animals[a.typeName] = {} end;
			
			for FillType,v in pairs(a.tipTriggers[i].acceptedFillTypes) do
				
				if WaterMod.Needs[a.typeName][FillType] then
					if a.tipTriggersFillLevels then
						if a.tipTriggersFillLevels[FillType] == nil then a.tipTriggersFillLevels[FillType] = {} end;
						local haveTrigger = false
						
						for j = 1 ,table.getn(a.tipTriggersFillLevels[FillType]) do
							if a.tipTriggersFillLevels[FillType][j].tipTrigger == a.tipTriggers[i] then
								haveTrigger = true
							end
						end
						if haveTrigger == false then
							table.insert(a.tipTriggersFillLevels[FillType],{tipTriggerIndex = i,tipTrigger = a.tipTriggers[i],fillLevel = 0});
						end;
						WaterMod.Animals[a.typeName][FillType] = true
					else
						print("WaterMod Needs Patch 1.4")
					end;
				end;
				
			end;
		end;
		
		return ra
	end;
end;

local WaterMod_mt = Class(WaterMod, Object);
InitObjectClass(WaterMod, "WaterMod");

function WaterMod.onCreate(id)

	local object = WaterMod:new(g_server ~= nil, g_client ~= nil)
	object.id = id
	object:load(id)
	--g_currentMission:addUpdateable(object);
	g_currentMission:addOnCreateLoadedObject(object);
    object:register(true);
	WaterMod.Triggers[id] = object	
	
	if not WaterMod.HookAnimalHusbandry then
		WaterMod.HookAnimalHusbandry = true
	
		if AnimalHusbandry.getHasSpaceForTipping ~= nil then
			local orggetHasSpaceForTipping = AnimalHusbandry.getHasSpaceForTipping
			AnimalHusbandry.getHasSpaceForTipping = function(a, b, c, d, e, f)
				local ra, rb, rc, rd = orggetHasSpaceForTipping(a, b, c, d, e, f)
				if WaterMod.Animals[a.typeName] and WaterMod.Animals[a.typeName][b] then
					ra = false
					local FillLevel = 0
					for i = 1 ,table.getn(a.tipTriggersFillLevels[b]) do
						FillLevel = FillLevel + a.tipTriggersFillLevels[b][i].fillLevel
					end;
					if a.totalNumAnimals * ((WaterMod.Needs[a.typeName][b] or 0)*6) >= FillLevel then
						ra = true
					end;
				end;
				return ra
			end;
		end;	

		if AnimalHusbandry.updateTrailerTipping ~= nil then
			local orgupdateTrailerTipping = AnimalHusbandry.updateTrailerTipping
			AnimalHusbandry.updateTrailerTipping = function(a, b, c, d, e, f)
				local ra, rb, rc, rd = orgupdateTrailerTipping(a, b, c, d, e, f)
				if WaterMod.Triggers[e.rootNode] and not a.useCowFeeding then
					for i = 1 ,table.getn(e.animalHusbandry.tipTriggersFillLevels[d]) do
						local trigger = e.animalHusbandry.tipTriggersFillLevels[d][i]
						if trigger.tipTrigger == e then
							trigger.fillLevel = trigger.fillLevel - c
						end;
					end;
				end;
				return ra
			end;
		end;
			
		if AnimalHusbandry.minuteChanged ~= nil then
			local orgminuteChanged = AnimalHusbandry.minuteChanged
			AnimalHusbandry.minuteChanged = function(a, b, c, d, e, f)
				if a.typeName == "chicken" and a.updateMinutes == a.updateMinutesInterval then
					for FillType,Triggers in pairs(a.tipTriggersFillLevels) do
						if WaterMod.Needs[a.typeName][FillType] then
							local bedarf = a.totalNumAnimals * ((WaterMod.Needs[a.typeName][FillType] or 0)/1440*a.updateMinutesInterval) -- eine Kuh 60 l/tag
							if bedarf > 0 then
								for i = 1 ,table.getn(Triggers) do
									local index = Triggers[i].tipTriggerIndex
									if WaterMod.Triggers[a.tipTriggers[index].rootNode] then
										local delta = math.min(Triggers[i].fillLevel,  bedarf)
										bedarf = math.max(0, bedarf - delta)
									end
								end;
								if bedarf == 0 then --nur wenn bedarf gedeckt
									a.numPickupObjectsToSpawn = a.numPickupObjectsToSpawn + ((a.totalNumAnimals - 1) * (0.069445/2000) * a.updateMinutesInterval) --(a.totalNumAnimals - 1) = abzug Hahn
								end;
							end;
						end;
					end;
				end;
				
				local ra, rb, rc, rd = orgminuteChanged(a, b, c, d, e, f)
				
				if a.updateMinutes == 0 then
					for FillType,Triggers in pairs(a.tipTriggersFillLevels) do
						if WaterMod.Needs[a.typeName][FillType] then
							local bedarf = a.totalNumAnimals * ((WaterMod.Needs[a.typeName][FillType] or 0)/1440*a.updateMinutesInterval) -- eine Kuh 60 l/tag
							if bedarf > 0 then
								for i = 1 ,table.getn(Triggers) do
									local index = Triggers[i].tipTriggerIndex
									if WaterMod.Triggers[a.tipTriggers[index].rootNode] then
										local delta = math.min(Triggers[i].fillLevel,  bedarf)
										Triggers[i].fillLevel = math.max(0, Triggers[i].fillLevel - delta)
										bedarf = math.max(0, bedarf - delta)
									end;
								end;
								if bedarf == 0 then --nur wenn bedarf gedeckt
									if a.typeName == "cow" then
										a.productivity = a.productivity + .1
										a.fillLevelMilk = a.fillLevelMilk + (a.totalNumAnimals * 0.04956 * a.updateMinutesInterval)
									elseif a.typeName == "sheep" then
										a.productivity = a.productivity + .1
										if a.currentPallet then 
											local newFillLvl = a.currentPallet.fillLevel + (a.totalNumAnimals * 0.001667 * a.updateMinutesInterval)
											a.currentPallet:setFillLevel(newFillLvl)
										end;
									elseif a.typeName == "chicken" then
										a.productivity = a.productivity + .05
									end;
								end;
							end;
						end;
					end;
				end;
			end;
			
		end;

		if AnimalHusbandry.writeStream ~= nil then
			local orgwriteStream = AnimalHusbandry.writeStream
			AnimalHusbandry.writeStream = function(a, b, c, d, e, f)
				orgwriteStream(a, b, c, d, e, f)
				for FillType,Triggers in pairs(a.tipTriggersFillLevels) do
					if WaterMod.Needs[a.typeName][FillType] then
						for i = 1 ,table.getn(Triggers) do
							streamWriteFloat32(b,Triggers[i].fillLevel)
						end;
					end;
				end;
				if a.typeName == "chicken" then
					streamWriteFloat32(b,a.productivity)
				end;
			end;
		end;
			
		if AnimalHusbandry.readStream ~= nil then
			local orgreadStream = AnimalHusbandry.readStream
			AnimalHusbandry.readStream = function(a, b, c, d, e, f)
				orgreadStream(a, b, c, d, e, f)
				for FillType,Triggers in pairs(a.tipTriggersFillLevels) do
					if WaterMod.Needs[a.typeName][FillType] then
						for i = 1 ,table.getn(Triggers) do
							Triggers[i].fillLevel = streamReadFloat32(b)
						end;
					end;
				end;
				if a.typeName == "chicken" then
					a.productivity = streamReadFloat32(b)
				end;
			end;
		end;

		if AnimalHusbandry.writeUpdateStream ~= nil then
			local orgwriteUpdateStream = AnimalHusbandry.writeUpdateStream
			AnimalHusbandry.writeUpdateStream = function(a, b, c, d, e, f)
				orgwriteUpdateStream(a, b, c, d, e, f)
				for FillType,Triggers in pairs(a.tipTriggersFillLevels) do
					if WaterMod.Needs[a.typeName][FillType] then
						for i = 1 ,table.getn(Triggers) do
							streamWriteFloat32(b,Triggers[i].fillLevel)
						end;
					end;
				end;
				if a.typeName == "chicken" then
					streamWriteFloat32(b,a.productivity)
				end;
			end;
		end;
			
		if AnimalHusbandry.readUpdateStream ~= nil then
			local orgreadUpdateStream = AnimalHusbandry.readUpdateStream
			AnimalHusbandry.readUpdateStream = function(a, b, c, d, e, f)
				orgreadUpdateStream(a, b, c, d, e, f)
				for FillType,Triggers in pairs(a.tipTriggersFillLevels) do
					if WaterMod.Needs[a.typeName][FillType] then
						for i = 1 ,table.getn(Triggers) do
							Triggers[i].fillLevel = streamReadFloat32(b)
						end;
					end;
				end;
				if a.typeName == "chicken" then
					a.productivity = streamReadFloat32(b)
				end;
			end;
		end;
	end;
	
	--print("WaterMod.onCreate ",id)
end;

function WaterMod:new(isServer, isClient, customMt)
  
	local mt = customMt;
    if mt == nil then
        mt = WaterMod_mt;
    end;
  
	local self = Object:new(isServer, isClient, mt);
	
	return self;
end;
 
function WaterMod:load(nodeId)
	local WaterTrailerTriggerIndex = getUserAttribute(nodeId, "waterTriggerIndex");
	if WaterTrailerTriggerIndex then
		local WaterTrailerTrigger = Utils.indexToObject(nodeId, WaterTrailerTriggerIndex);
		if WaterTrailerTrigger then
			self.WaterTrailers = {};
			self.WaterTrailerTrigger = WaterTrailerTrigger;
			addTrigger(self.WaterTrailerTrigger, "onWaterTrailerTrigger", self);
			self.WaterTrailerActivatable = WaterModActivatable:new(self);
		end;
	end;
	return true;
end;

function WaterMod:delete()
	if self.WaterTrailerTrigger then
		removeTrigger(self.WaterTrailerTrigger);
		self.WaterTrailerTrigger = nil;
	end;
	WaterMod.Triggers = {}
end;
  
function WaterMod:update(dt)

	if not self.TipTrigger then
		for typ,husbandries in pairs(g_currentMission.husbandries) do
			for i = 1, table.getn(husbandries.tipTriggers) do
				if husbandries.tipTriggers[i].rootNode == self.id then
					self.TipTrigger = husbandries.tipTriggers[i];
					local org_delete = self.TipTrigger.delete;
					self.TipTrigger.delete = function(trigger) self:delete(trigger); org_delete(trigger); end;
					if self.TipTrigger.getAllowShovelFillType then
						local org_getAllowShovelFillType = self.TipTrigger.getAllowShovelFillType
						self.TipTrigger.getAllowShovelFillType = function(a, b)
							local ra = org_getAllowShovelFillType(a, b)
							if ra == false and a.acceptedFillTypes[b] then
								local trailer = {currentFillType = b}
								text = a:getNoAllowedText(trailer)
								 if text ~= nil and text ~= "" then
									g_currentMission:addWarning(text, 0.018, 0.033);
								end;
							end;
							return ra
						end;
					end;
					break;
				end;
			end;
			if self.TipTrigger then
				break;
			end;
		end;
	end;

	if not WaterMod.HookPDA then

		WaterMod.HookPDA = true
		local org_StatisticView_getAnimalData = StatisticView.getAnimalData
		StatisticView.getAnimalData = function(...)
			local r = org_StatisticView_getAnimalData(...)
			local addLine = 0
			for i = 1,table.getn(r) do
				if r[i].name == "chicken" then
					if WaterMod.Animals[r[i].name] ~= nil then
						local desc = g_i18n:getText("Productivity")
						local p = g_currentMission.husbandries[r[i].name].productivity * 100
						table.insert(r[i].attributes,2,{name=desc,value=math.floor(p).."%"})	
						addLine = addLine + 1
					end;
				end;
				for FillType,Triggers in pairs(g_currentMission.husbandries[r[i].name].tipTriggersFillLevels) do
					local FillLevel
					for j = 1 ,table.getn(Triggers) do
						local index = Triggers[j].tipTriggerIndex
						if WaterMod.Triggers[g_currentMission.husbandries[r[i].name].tipTriggers[index].rootNode] then
							FillLevel = (FillLevel or 0) + Triggers[j].fillLevel
						end;
					end;
					if FillLevel ~= nil then
						local desc = Fillable.fillTypeIndexToDesc[FillType].nameI18N
						if r[i].name == "cow" then
							table.insert(r[i].attributes,8,{name=desc.." [l]",value=math.floor(FillLevel)})
						elseif r[i].name == "chicken" then
							table.insert(r[i].attributes,3,{name=desc.." [l]",value=math.floor(FillLevel)})
							addLine = addLine + 1
						else
							table.insert(r[i].attributes,4,{name=desc.." [l]",value=math.floor(FillLevel)})
							addLine = addLine + 1
						end
					end;
				end;
			end
			if addLine >= 4 then
				select(1,...).animalTemplate.elements[4].size[2] = 0.034;
			end
			return r
		end
	end	
  
end;

function WaterMod:updateTick(dt)
	if self.WaterTrailerTrigger then
		self.WaterTrailerInRange = nil
		for i = 1 , table.getn(self.WaterTrailers) do
			if self.WaterTrailers[i]:getFillLevel(Fillable.FILLTYPE_WATER) > 0 then
				self.WaterTrailerInRange = self.WaterTrailers[i];
				break;
			end;
		end;
		if self.WaterTrailerInRange then
			if not self.WaterTrailerActivatableAdded then
				g_currentMission:addActivatableObject(self.WaterTrailerActivatable);
				self.WaterTrailerActivatableAdded = true;
			end;
			if self.isWaterFilling and self.isServer then
				local delta = self.WaterTrailerInRange.fillLitersPerSecond*dt*0.001;
				delta = math.min(self.WaterTrailerInRange:getFillLevel(Fillable.FILLTYPE_WATER),delta);
				self.TipTrigger:updateTrailerTipping(self.WaterTrailerInRange, -delta, Fillable.FILLTYPE_WATER, self.TipTrigger);
				self.WaterTrailerInRange:setFillLevel(self.WaterTrailerInRange:getFillLevel(Fillable.FILLTYPE_WATER) - delta, Fillable.FILLTYPE_WATER, true);
			end;
		else
			self.isWaterFilling = false
			if self.WaterTrailerActivatableAdded then
				g_currentMission:removeActivatableObject(self.WaterTrailerActivatable);
				self.WaterTrailerActivatableAdded = false;
			end;
		end;
	end;
	
end;

function WaterMod:setIsWaterFilling(isFilling, noEventSend)
	
	WaterModIsWaterFillingEvent.sendEvent(self, isFilling, noEventSend);
	self.isWaterFilling = isFilling;
	
end;

function WaterMod:addWaterTrailer(waterTrailer)
	table.insert(self.WaterTrailers, waterTrailer);
end;
 
function WaterMod:removeWaterTrailer(waterTrailer)
	for i=1, table.getn(self.WaterTrailers) do
        if self.WaterTrailers[i] == waterTrailer then
            table.remove(self.WaterTrailers, i);
            break;
        end;
    end;
end;

function WaterMod:onWaterTrailerTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local waterTrailer = g_currentMission.objectToTrailer[otherShapeId];  
	if waterTrailer ~= nil and waterTrailer:allowFillType(Fillable.FILLTYPE_WATER, false) then
		if onEnter then
			self:addWaterTrailer(waterTrailer);
		else -- onLeave
			self:removeWaterTrailer(waterTrailer);
		end;
	end;
end;

g_onCreateUtil.addOnCreateFunction("WaterMod", WaterMod.onCreate);

--- WaterModActivatable ---

WaterModActivatable = {}
local WaterModActivatable_mt = Class(WaterModActivatable);
 
function WaterModActivatable:new(Traenke)
    local self = {};
    setmetatable(self, WaterModActivatable_mt);
 
    self.Traenke = Traenke;
	self.activateText = "unknown";
	
    return self;
end;
 
function WaterModActivatable:getIsActivatable()
  	if self.Traenke.WaterTrailerInRange and self.Traenke.WaterTrailerInRange:getIsActiveForInput() then
		if self.Traenke.TipTrigger.animalHusbandry:getHasSpaceForTipping(Fillable.FILLTYPE_WATER) then
			self:updateActivateText();
			return true;
		else
			g_currentMission:addWarning(g_i18n:getText("limited_in_advance_feeding"), 0.018, 0.033);
            self.Traenke:setIsWaterFilling(false)
			return false;
		end
		
	end;
	
    return false;
end
 
function WaterModActivatable:onActivateObject()
	self.Traenke:setIsWaterFilling(not self.Traenke.isWaterFilling)
	
    self:updateActivateText();
    g_currentMission:addActivatableObject(self);
end;
 
function WaterModActivatable:drawActivate()
    --self.Overlay:render();
end;
 
function WaterModActivatable:updateActivateText()
	local wasseri18n = Fillable.fillTypeIndexToDesc[Fillable.FILLTYPE_WATER].nameI18N
	if self.Traenke.isWaterFilling then
		self.activateText = string.format(g_i18n:getText("stop_refill_OBJECT"), wasseri18n);
	else
		self.activateText = string.format(g_i18n:getText("refill_OBJECT"), wasseri18n);
	end;
	
end;

--- Event Set IsWaterFilling ---
 
WaterModIsWaterFillingEvent = {};
WaterModIsWaterFillingEvent_mt = Class(WaterModIsWaterFillingEvent, Event);

InitEventClass(WaterModIsWaterFillingEvent, "WaterModIsWaterFillingEvent");

function WaterModIsWaterFillingEvent:emptyNew()
    local self = Event:new(WaterModIsWaterFillingEvent_mt);
    return self;
end;
    
function WaterModIsWaterFillingEvent:new(object, SetIsFilling)
	local self = WaterModIsWaterFillingEvent:emptyNew()
	self.object = object;
	self.SetIsFilling = SetIsFilling;
	return self;
end;

function WaterModIsWaterFillingEvent:readStream(streamId, connection)
	local id = streamReadInt32(streamId);
	self.SetIsFilling = streamReadBool(streamId);
	self.object = networkGetObject(id);
	self:run(connection);
end;

function WaterModIsWaterFillingEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, networkGetObjectId(self.object));
	streamWriteBool(streamId, self.SetIsFilling);
end;

function WaterModIsWaterFillingEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object);
	end;
	if self.object ~= nil then
		self.object:setIsWaterFilling(self.SetIsFilling, true);
	end;
end;

function WaterModIsWaterFillingEvent.sendEvent(object, SetIsFilling, noEventSend)
	if SetIsFilling ~= object.isWaterFilling then
		if noEventSend == nil or noEventSend == false then
			if g_server ~= nil then
				g_server:broadcastEvent(WaterModIsWaterFillingEvent:new(object, SetIsFilling), nil, nil, object);
			else
				g_client:getServerConnection():sendEvent(WaterModIsWaterFillingEvent:new(object, SetIsFilling));
			end;
		end;
	end;
end;

--- Log Info ---
local function autor() for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],"## Author: ");if n then return (string.sub (metadata[i], n+1)); end;end;end;
local function name() for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],"## Title: ");if n then return (string.sub (metadata[i], n+1)); end;end;end;
local function version() for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],"## Version: ");if n then return (string.sub (metadata[i], n+1)); end;end;end;
local function support() for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],"## Web: ");if n then return (string.sub (metadata[i], n+1)); end;end;end;
print("Script "..(name()).." v"..(version()).." by "..(autor()).." loaded! Support on "..(support()));
