local metadata = {
"## Interface: FS15 1.1.0.0 RC12",
"## Title: SchweineZucht",
"## Notes: Map SchweineZucht",
"## Author: Marhu",
"## Version: 3.2.7",
"## Date: 01.12.2014",
"## Web: http://marhu.net"
}

local FutterTypes = {[Fillable.FILLTYPE_FORAGE] = 4,
					 [Fillable.FILLTYPE_WATER] = 5,
					 [Fillable.FILLTYPE_BARLEY_WINDROW] = 6,
					 [Fillable.FILLTYPE_WHEAT_WINDROW] = 6};

local FutterTypFac = {[1]=0.98,[2]=1,[3]=0.95,[4]=1.05,[5]=0.9,[6]=0.9};

local FutterTypProd = {[1]=0.2,[2]=0.2,[3]=0.2,[4]=0.8,[5]=0.1,[6]=0.1};

local FutterIntName = {[1] = g_i18n:getText("grain_fruits"),
					   [2] = g_i18n:getText("earth_fruits"),
					   [3] = g_i18n:getText("Silo_fruits"),
					   [4] = Fillable.fillTypeIndexToDesc[Fillable.FILLTYPE_FORAGE].nameI18N,
					   [5] = Fillable.fillTypeIndexToDesc[Fillable.FILLTYPE_WATER].nameI18N,
					   [6] = Fillable.fillTypeIndexToDesc[Fillable.FILLTYPE_WHEAT_WINDROW].nameI18N};


g_SchweineDaten = {};
					   
SchweineZucht = {};

SchweineZucht.ModDir = g_currentModDirectory

local SchweineZucht_mt = Class(SchweineZucht, Object);
InitObjectClass(SchweineZucht, "SchweineZucht");

function SchweineZucht.onCreate(id)
	local object = SchweineZucht:new(g_server ~= nil, g_client ~= nil)
	if object:load(id) then
        g_currentMission:addOnCreateLoadedObject(object);
        object:register(true);
    else
        object:delete();
    end;

end;

function SchweineZucht:new(isServer, isClient, customMt)

	local mt = customMt;
    if mt == nil then
          mt = SchweineZucht_mt;
    end;

	local self = Object:new(isServer, isClient, mt);

	self.SchweineZuchtDirtyFlag = self:getNextDirtyFlag();

	return self;
end;

function SchweineZucht:load(nodeId)

	self.nodeId = nodeId;

	self.updateMs = 0;
	self.updateMin = 0;
	self.updateIntervall = 20;
	self.tipTriggers = {}
	self.FillTypeLvl = {}
	self.WaterTrailers = {}
	self.FutterFillevel = 0;
	self.WaterFillevel = 0;
	self.FutterTypLvl = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0};
	self.StrawLvl = 0;
	self.Produktivi = 0;
	self.nextSchwein = 0;
	self.numSchweine = 0;
	self.manure = 0;
	self.liquitmanure = 0;
	self.tipTriggersFillLevels = {{}}
	
	self.FutterKgTag = Utils.getNoNil(getUserAttribute(nodeId, "FutterKgTag"),10); -- pro Pig von jeder sorte
	self.PigProMin = Utils.getNoNil(getUserAttribute(nodeId, "PigProDay"),0.2)/1440; -- ~1 in 5 Tagen pro Ferkel
	self.ManureProMin = Utils.getNoNil(getUserAttribute(nodeId, "ManureProMin"),.05);
	self.numPig = Utils.getNoNil(getUserAttribute(nodeId, "numPig"),0);
	self.StationNr = getUserAttribute(nodeId, "StationNr");
	
	local animal = getUserAttribute(nodeId, "Animal");
	local desc = Fillable.fillTypeNameToDesc[animal];
	if desc == nil then
		print(string.format("ERROR: (SchweineZucht) %s invalid Animal Type %s",(tostring(self.StationNr) or "nil"),(animal or "nil")))
		return false;
	end
	self.animal = animal;
	
	local PigFillTriggerIndex = getUserAttribute(nodeId, "PigFillTriggerIndex");
	if PigFillTriggerIndex ~= nil then
		local PigFillTrigger = Utils.indexToObject(nodeId, PigFillTriggerIndex);
		if PigFillTrigger ~= nil then
			local trigger = SiloTrigger:new(g_server ~= nil, g_client ~= nil);
			local index = g_currentMission:addOnCreateLoadedObject(trigger);
			trigger:load(PigFillTrigger);
			trigger:register(true);
			trigger.fillType = desc.index
			self.PigFillTrigger = trigger
			function self.PigFillTrigger:update(dt) end;
		end;
	end;

	local TipTriggerIndex = getUserAttribute(nodeId, "TipTriggerIndex");
	if TipTriggerIndex then
		local tipTriggersId = Utils.indexToObject(self.nodeId, TipTriggerIndex);
		if tipTriggersId then
			local FutterNameString = getUserAttribute(tipTriggersId, "FruitTyp")
			local FutterTypString = getUserAttribute(tipTriggersId, "FutterTyp")
			if FutterNameString and FutterTypString then
				local FutterName = Utils.splitString(" ",FutterNameString);
				local FutterTyp = Utils.splitString(" ",FutterTypString);
				for k,v in pairs(FutterName) do
					local desc = Fillable.fillTypeNameToDesc[v];
					if desc ~= nil then
						FutterTypes[desc.index] = (tonumber(FutterTyp[k]) or 3);
					end;
				end;
			else
				print("ERROR: (SchweineZucht) missing FutterNameString or FutterTypString in "..getName(tipTriggersId));
			end
			local numChildren = getNumOfChildren(tipTriggersId);
			local need = self.numPig * self.FutterKgTag * 6
			for i=1,numChildren do
                local straw = false
				local acceptedFillTypes = {}
				local childId = getChildAt(tipTriggersId, i-1);
				local fillTypes = getUserAttribute(childId, "fillTypes");
				if fillTypes == nil then
					fillTypes = getUserAttribute(childId, "fruitTypes");
				end
				local maxfillLvl = 0
				if fillTypes ~= nil then
					local types = Utils.splitString(" ", fillTypes);
					for k,v in pairs(types) do
						local desc = Fillable.fillTypeNameToDesc[v];
						if desc ~= nil then
							if FutterTypes[desc.index] == nil then
								FutterTypes[desc.index] = 3;
							end
							maxfillLvl = math.max(need * FutterTypFac[FutterTypes[desc.index]],maxfillLvl);
							acceptedFillTypes[desc.index] = true;
						else
							print("Error: (SchweineZucht) invalid fillType "..v.." in "..getName(childId));
						end;
					end;
				end;
				local tipTrigger = FeedingTroughTipTrigger:new(g_server ~= nil, g_client ~= nil);
				tipTrigger.priceMultipliers = {};
				tipTrigger.acceptedFillTypes = acceptedFillTypes;
				tipTrigger:load(childId,self);
				g_currentMission:addOnCreateLoadedObject(tipTrigger);
				tipTrigger:register(true);
				if maxfillLvl > 0 and tipTrigger.fillPlane ~= nil then
					tipTrigger.moveScale = (tipTrigger.moveMaxY-tipTrigger.moveMinY) / maxfillLvl;
				end;
				if acceptedFillTypes[Fillable.FILLTYPE_WATER] then
					removeTrigger(tipTrigger.triggerId)
					addTrigger(tipTrigger.triggerId, "onWaterTankTrigger", self);
					if not self.WaterTrailerActivatable then
						self.WaterTrailerActivatable = SMAWaterTrailerActivatable:new(self);
					end;
				end
				table.insert(self.tipTriggers, tipTrigger);
			end;
		end;
	end;

	local liquidManureSiloIndex = getUserAttribute(nodeId, "liquidManureSiloIndex");
    if liquidManureSiloIndex ~= nil then
        local liquidManureSiloId = Utils.indexToObject(nodeId, liquidManureSiloIndex);
        if liquidManureSiloId ~= nil then
            self.liquidManureSiloTrigger = LiquidManureFillTrigger:new();
            if not self.liquidManureSiloTrigger:load(liquidManureSiloId, self) then
                self.liquidManureSiloTrigger:delete();
                self.liquidManureSiloTrigger = nil;
           end
        end;
    end;

	local manureHeapIndex = getUserAttribute(nodeId, "manureHeapIndex");
	if manureHeapIndex ~= nil then
		local manureHeap = Utils.indexToObject(nodeId, manureHeapIndex);
		if manureHeap ~= nil then
			self.manureHeap = {}
			self.manureHeap.FillLvl = 0;
			local capacityStr = getUserAttribute(manureHeap, "capacity");
			if capacityStr ~= nil then
				self.manureHeap.capacity = Utils.getNoNil(tonumber(capacityStr), 100000);
			end;

			local minY, maxY = Utils.getVectorFromString(getUserAttribute(manureHeap, "moveMinMaxY"));
			if minY ~= nil and maxY ~= nil then
				self.manureHeap.moveMinY = minY;
				self.manureHeap.moveMaxY = maxY;
				self.manureHeap.movingId = Utils.indexToObject(manureHeap, getUserAttribute(manureHeap, "movingIndex"));
			end;

			if g_currentMission:getIsServer() then
				local ShovelTrigger =  Utils.indexToObject(manureHeap, getUserAttribute(manureHeap, "triggerIndex"));
				if ShovelTrigger then
					local trigger = ShovelFillTrigger:new();
					if trigger:load(ShovelTrigger, "manure") then
						g_currentMission:addUpdateable(trigger);
						self.manureHeap.ShovelTrigger = trigger
						self.manureHeap.ShovelTrigger.fillShovel = function(SFT, shovel, dt) self:manureHeapfillShovel(SFT, shovel, dt); end;
					else
						trigger:delete();
					end;
				end;
			end;
			self:manureHeapSetFillLevel(0)
		end;
	end;

	local DoorsIndex = getUserAttribute(nodeId, "DoorsIndex");
	if DoorsIndex ~= nil then
		local Doors = Utils.indexToObject(nodeId, DoorsIndex);
		if Doors then
			self.Doors = {}
			local numChildren = getNumOfChildren(Doors);
			for i=1,numChildren do
				local Child = getChildAt(Doors, i-1)
				self.Doors[i] = {}
				self.Doors[i].minTrans = Utils.getNoNil(getUserAttribute(Child, "MinTrans"),0);
				self.Doors[i].maxTrans = Utils.getNoNil(getUserAttribute(Child, "MaxTrans"),2);
				self.Doors[i].Trans = self.Doors[i].minTrans;
				local doorIndex = getUserAttribute(Child, "DoorIndex");
				if doorIndex then
					local door = Utils.indexToObject(Child, doorIndex);
					local numDoors = getNumOfChildren(door);
					self.Doors[i].door = {}
					for j=1,numDoors do
						self.Doors[i].door[j] = getChildAt(door, j-1);
					end;
				end;
				local triggerIndex = getUserAttribute(Child, "triggerIndex");
				if triggerIndex then
					local trigger = Utils.indexToObject(Child,triggerIndex);
					self.Doors[i].triggerId = trigger;
					self.Doors[i].entred = 0;
					addTrigger(trigger, "doorTriggerCallback", self);
				end;
			end;
		end;
	end;

	local PigPosIndex = getUserAttribute(nodeId, "PigPosIndex");
	local PigsIndex = getUserAttribute(nodeId, "PigsIndex");
	if PigPosIndex ~= nil and PigsIndex ~= nil then
		local positions = Utils.indexToObject(nodeId, PigPosIndex);
		local Pigs = Utils.indexToObject(nodeId, PigsIndex);
		if Pigs ~= nil and positions ~= nil then
			link(getRootNode(),Pigs); 
			self.AniPig = {}
			local numPos = getNumOfChildren(positions);
			local numPigs = getNumOfChildren(Pigs);
			for i = 1, numPos do
				self.AniPig[i] = {}
				local posnode = getChildAt(positions, i-1);
				local pos = {getWorldTranslation(posnode)}
				local rot = {getRotation(posnode)}
				rot[2] = math.rad(math.random(0, 359))
				self.AniPig[i].pig = clone(getChildAt(Pigs,(i % numPigs)), true)
				setTranslation(getChildAt(self.AniPig[i].pig,1),unpack(pos))
				setRotation(getChildAt(self.AniPig[i].pig,1),unpack(rot))
				self.AniPig[i].Animi = getAnimCharacterSet(getChildAt(self.AniPig[i].pig,0));
				self.AniPig[i].Clip = getAnimClipIndex(self.AniPig[i].Animi,"clip1Source")
				assignAnimTrackClip(self.AniPig[i].Animi, 0, self.AniPig[i].Clip);
				setAnimTrackLoopState(self.AniPig[i].Animi, 0, false);
				setAnimTrackSpeedScale(self.AniPig[i].Animi, 0, 1);

				self.AniPig[i].RNDTime = Utils.getNoNil(getUserAttribute(self.AniPig[i].pig, "RNDTime"), 0); -- in s
				self.AniPig[i].time = math.random(0, self.AniPig[i].RNDTime)
				
			end
		end
	end
	
	local NumAnzeigeIndex = getUserAttribute(nodeId, "NrIndex");
	if NumAnzeigeIndex ~= nil then
		local NumAnzeige = Utils.indexToObject(nodeId, NumAnzeigeIndex);
		if NumAnzeige ~= nil then
			for i = 1, getNumOfChildren(NumAnzeige) do
				local Schild = getChildAt(NumAnzeige, i-1);
				local num = tonumber(self.StationNr);
				for j = getNumOfChildren(Schild), 1, -1 do
					local offset = (num % 10)
					setShaderParameter(getChildAt(Schild, j-1), "number", offset,0 , 0, 0, false);			
					num = math.floor(num / 10);
				end;
			end;
		end;
	end;
	local PigCountIndex = getUserAttribute(nodeId, "PigCountIndex");
	if PigCountIndex ~= nil then
		self.PigCount = Utils.indexToObject(nodeId, PigCountIndex);
	end
	
	self.isEnabled = true

	g_currentMission:addNodeObject(self.nodeId, self);
	g_currentMission:addOnCreateLoadedObjectToSave(self);

	if g_currentMission.husbandries[animal] == nil then
		g_currentMission.husbandries[animal] = self
		 
		local a = "Schwein" 	--Name
		local b = {""} 			--functions,{functionKey,functionName}
		local c = {fillTypes={}}--specs,{fillTypes}
		local d = ""  			--imageActive
		local e = "" 			--imageBrand
		local f = 50 			--Price
		local g = 1				--dailyUpkeep
		local h = {0,0,0}		--incomePerHour
		local i = "pig" 		--xmlFilename
		local j = "pig" 		--species
		local k = false 		--isDyeable
		local l = nil			--color
		local m = 0				--rotation
		local n = ""	 	   	--brand
		local o = "animals" 	--category
		local p = 1         	--shop
		local q = false      	--isMod
		local r = nil       	--customEnvironment
		local s = 0  			--achievementsNeeded
		local t = 0         	--sharedVramUsage
		local u = 0	 			--perInstanceVramUsage
		local xmlFilePath = getUserAttribute(nodeId, "xmlFile");
		if fileExists(SchweineZucht.ModDir..xmlFilePath) then
			local File = loadXMLFile("AnimalHusbandry", SchweineZucht.ModDir..xmlFilePath)
			local baseProf = "Husbandry."
			local LProf = baseProf.."en"
			if hasXMLProperty(File, baseProf..g_languageShort) then
				LProf = baseProf..g_languageShort
			end
			a = getXMLString(File, LProf..".name");
			b = {getXMLString(File, LProf..".description")};
			d = SchweineZucht.ModDir..getXMLString(File, baseProf.."imageActive");
			f = getXMLFloat(File, baseProf.."price");
			g = getXMLFloat(File, baseProf.."dailyUpkeep");
			i = animal;--SchweineZucht.ModDir..xmlFilePath;
			j = animal;
		else
			print(string.format("ERROR: (SchweineZucht) %s invalid AnimalHusbandry.xml %s",(tostring(self.StationNr) or "nil"),(SchweineZucht.ModDir..xmlFilePath or "nil")))
			return false;
		end
		StoreItemsUtil.addStoreItem(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u)
	end
	
	if not g_SchweineDaten[animal] then g_SchweineDaten[animal] = {} end;
	table.insert(g_SchweineDaten[animal],self)
	
	if self.isClient then
		local textTable = {}
		table.insert(textTable,g_i18n:getText(self.animal.."_amount"))
		table.insert(textTable,"")
		table.insert(textTable,g_i18n:getText("buy_amount"))
		table.insert(textTable,"")
		table.insert(textTable,g_i18n:getText("Productivity"))
		table.insert(textTable,"")
		table.insert(textTable,string.format("%s",FutterIntName[4].." [l]"))
		table.insert(textTable,"")
		for i = 1, table.getn(self.FutterTypLvl) do
			if i ~= 4 then
				table.insert(textTable,string.format("%s",FutterIntName[i].." [l]"))
				table.insert(textTable,"")
			end
		end
		if self.manureHeap then
			local desc = Fillable.fillTypeIndexToDesc[Fillable.FILLTYPE_MANURE].nameI18N
			table.insert(textTable,string.format("%s",desc.." [l]"))
			table.insert(textTable,"")
		end
		if self.liquidManureSiloTrigger then
			local desc = Fillable.fillTypeIndexToDesc[Fillable.FILLTYPE_LIQUIDMANURE].nameI18N
			table.insert(textTable,string.format("%s",desc.." [l]"))
			table.insert(textTable,"")
		end
	
		local g = getfenv(0)
		local freeStatistikPlace = false;
		if not g.PigStatistiks then g.PigStatistiks={} end;
		for i=1,table.getn(g.PigStatistiks) do
			if not g.PigStatistiks[i].element.elements[2] then
				freeStatistikPlace = g.PigStatistiks[i].element.elements;
			end
		end
			
		local elements = {}
		elements[1] = GuiElement:new(self) --base
		elements[2] = g.g_gui.guis.StatisticView.target.pages[1].element.elements[2]:clone(elements[1]) --bgColorWhite90
		local xOffset = elements[2].absPosition[1]-(1 - elements[2].absPosition[1]- elements[2].size[1])
		local ClonElements = g.g_gui.guis.StatisticView.target.pages[1].element.elements[2].elements 
		elements[3] = ClonElements[1]:clone(elements[1])--bgColorBlack
		elements[4] = ClonElements[1].elements[1]:clone(elements[1])--statisticTitles
		elements[4].text = string.format("%s %d",g_i18n:getText(self.animal),self.StationNr)
		for i=2,7 do --bgColorBlack2
			table.insert(elements,ClonElements[i]:clone(elements[1]))
			elements[table.getn(elements)].elements = {}
		end
		local j = 1
		for i=9,9+table.getn(textTable) do --financesTitle
			table.insert(elements,ClonElements[i]:clone(elements[1]))
			elements[table.getn(elements)].text = textTable[j]
			elements[table.getn(elements)].textBold = false
			j=j+1
		end
		for i=1,table.getn(elements[1].elements) do
			elements[1].elements[i].elements = {}
			if freeStatistikPlace == false then	
				elements[1].elements[i].absPosition[1] = elements[1].elements[i].absPosition[1] + 0.05 - xOffset;
			else
				elements[1].elements[i].absPosition[1] = elements[1].elements[i].absPosition[1] - 0.05;
			end
		end
		self.elements = elements[1]
		
		if freeStatistikPlace == false then	
			local SiteBase = GuiElement:new()
			SiteBase.SchweineZucht = true
			table.insert(SiteBase.elements,elements[1])
			table.insert(g.PigStatistiks,g.g_gui.guis.StatisticView.target.addPage(g.g_gui.guis.StatisticView.target, StatisticView.PAGE_NEXT_ID, SiteBase, string.format("%s: %d",g_i18n:getText("MASeite"), table.getn(g.PigStatistiks)+1)))
		else
			table.insert(freeStatistikPlace,elements[1])
		end
		
		SchweineZucht:HookStatisticView()
	end;
	
	return true;
end;

function SchweineZucht:getSaveAttributesAndNodes(nodeIdent)

	local manure = 0;
	local liquidManure = 0;
	if self.manureHeap then manure = self.manureHeap.FillLvl end;
	if self.liquidManureSiloTrigger then liquidManure = self.liquidManureSiloTrigger.fillLevel end;

	local attributes = ' manure="'..manure..'" liquidManure="'..liquidManure..'" Schweine="'..self.numSchweine..'" nextSchwein="'..self.nextSchwein..'" numPig="'..self.numPig..'"';

	local nodes = "";
	local FillTypesNum = 0;

	for i = 1, table.getn(self.FutterTypLvl) do
		if FillTypesNum>0 then
			nodes = nodes.."\n";
		end;
		nodes = nodes..nodeIdent..'<FillType Typ="'.. i..'" Lvl="'..self.FutterTypLvl[i]..'"/>';
		FillTypesNum = FillTypesNum+1;
	end;

    return attributes,nodes;
end

function SchweineZucht:loadFromAttributesAndNodes(xmlFile, Key)
	if self.manureHeap then
		self:manureHeapSetFillLevel(Utils.getNoNil(getXMLFloat(xmlFile, Key.."#manure"),0));
	end
	if self.liquidManureSiloTrigger then
		self.liquidManureSiloTrigger:setFillLevel(Utils.getNoNil(getXMLFloat(xmlFile, Key.."#liquidManure"),0));
	end
	local numSchweine = Utils.getNoNil(getXMLFloat(xmlFile, Key.."#Schweine"),0);
	self:setMastPigs(numSchweine)
	self.nextSchwein = Utils.getNoNil(getXMLFloat(xmlFile, Key.."#nextSchwein"),0);
	self.numPig = Utils.getNoNil(getXMLFloat(xmlFile, Key.."#numPig"),self.numPig);
	
	local i=0;
	while true do
		local fillTypeKey = Key..string.format(".FillType(%d)", i);
		if not hasXMLProperty(xmlFile, fillTypeKey) then
			break;
		end;
		local fillLevel = getXMLFloat(xmlFile, fillTypeKey.."#Lvl");
        local fillType = getXMLInt(xmlFile, fillTypeKey.."#Typ");
        if fillLevel ~= nil and fillType ~= nil then
			self.FutterTypLvl[fillType] = fillLevel
		end;
		i = i + 1;
	end;

	self:setPlanesMoveScale()

	return true;
end

function SchweineZucht:readStream(streamId, connection)

	local numSchweine = streamReadFloat32(streamId);
	self:setMastPigs(numSchweine)
	for i = 1, table.getn(self.FutterTypLvl) do
		self.FutterTypLvl[i] = streamReadFloat32(streamId);
	end
	local manure = streamReadFloat32(streamId);
	local liquidManure = streamReadFloat32(streamId);
	if self.manureHeap then
		self:manureHeapSetFillLevel(manure);
	end
	if self.liquidManureSiloTrigger then
		self.liquidManureSiloTrigger:setFillLevel(liquidManure);
	end
	self.Produktivi = streamReadFloat32(streamId);
	self.numPig = streamReadInt32(streamId);
	self:setPlanesMoveScale()
end

function SchweineZucht:writeStream(streamId, connection)

	local manure = 0;
	local liquidManure = 0;
	if self.manureHeap then manure = self.manureHeap.FillLvl end;
	if self.liquidManureSiloTrigger then liquidManure = self.liquidManureSiloTrigger.fillLevel end;

	streamWriteFloat32(streamId, self.numSchweine);
	for i = 1, table.getn(self.FutterTypLvl) do
		streamWriteFloat32(streamId, self.FutterTypLvl[i]);
	end;
	streamWriteFloat32(streamId, manure);
	streamWriteFloat32(streamId, liquidManure);
	streamWriteFloat32(streamId, self.Produktivi);
	streamWriteInt32(streamId, self.numPig);
end

function SchweineZucht:readUpdateStream(streamId, timestamp, connection)

	if connection:getIsServer() then
		local numSchweine = streamReadFloat32(streamId);
		self:setMastPigs(numSchweine)
		for i = 1, table.getn(self.FutterTypLvl) do
			self.FutterTypLvl[i] = streamReadFloat32(streamId);
		end
		local manure = streamReadFloat32(streamId);
		local liquidManure = streamReadFloat32(streamId);
		if self.manureHeap then
			self:manureHeapSetFillLevel(manure);
		end
		if self.liquidManureSiloTrigger then
			self.liquidManureSiloTrigger:setFillLevel(liquidManure);
		end
		self.Produktivi = streamReadFloat32(streamId);
		self.numPig = streamReadInt32(streamId);
		self:setPlanesMoveScale()
	end

end;

function SchweineZucht:writeUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local manure = 0;
		local liquidManure = 0;
		if self.manureHeap then manure = self.manureHeap.FillLvl end;
		if self.liquidManureSiloTrigger then liquidManure = self.liquidManureSiloTrigger.fillLevel end;

		streamWriteFloat32(streamId, self.numSchweine);
		for i = 1, table.getn(self.FutterTypLvl) do
			streamWriteFloat32(streamId, self.FutterTypLvl[i]);
		end;
		streamWriteFloat32(streamId, manure);
		streamWriteFloat32(streamId, liquidManure);
		streamWriteFloat32(streamId, self.Produktivi);
		streamWriteInt32(streamId, self.numPig);
	end
end;

function SchweineZucht:delete()
	if self.Doors then
		for i=1, table.getn(self.Doors) do
			removeTrigger(self.Doors[i].triggerId);
		end
	end
	for k,t in pairs(g_SchweineDaten[self.animal]) do
		if t == self then
			table.remove(g_SchweineDaten[self.animal],k);
			break;
		end
	end
	g_currentMission:removeOnCreateLoadedObjectToSave(self);
	if self.liquidManureSiloTrigger ~= nil then
        self.liquidManureSiloTrigger:delete();
    end;
	if self.nodeId ~= 0 then
        g_currentMission:removeNodeObject(self.nodeId);
    end;
end;

function SchweineZucht:update(dt)
	
	if not SchweineZucht.HookStatisticView_getAnimalData then
		SchweineZucht.HookStatisticView_getAnimalData = true
		local org_StatisticView_getAnimalData = StatisticView.getAnimalData
		StatisticView.getAnimalData = function(...)
			local r = org_StatisticView_getAnimalData(...)
			for i = table.getn(r),1,-1 do
				if g_SchweineDaten[r[i].name] then
					table.remove(r,i)
				end;
			end;
			return r;
		end;
	end;
	
	if self.isClient then
        if self.liquidManureSiloTrigger ~= nil then
            self.liquidManureSiloTrigger:update(dt);
        end;
	end;
	
	if self.isServer then
		if self.PigFillTrigger then
			local trailer = self.PigFillTrigger.siloTrailer;
			if self.PigFillTrigger.fill >= 4 and trailer ~= nil and not self.PigFillTrigger.fillDone then
				-- if self.IsFilling then
					-- g_currentMission:addHelpButtonText(g_i18n:getText("StopFill"),InputBinding.PIGFILL_START);
				-- else
					-- g_currentMission:addHelpButtonText(g_i18n:getText("StartFill"),InputBinding.PIGFILL_START);
				-- end;
				-- if InputBinding.hasEvent(InputBinding.PIGFILL_START) then
					-- self.IsFilling = not self.IsFilling;
				-- end; 
				-- if self.IsFilling then
					trailer:resetFillLevelIfNeeded(self.PigFillTrigger.fillType);
					local fillLevel = trailer:getFillLevel(self.PigFillTrigger.fillType);
					local siloAmount = self.numSchweine;
					if siloAmount > 0 and trailer:allowFillType(self.PigFillTrigger.fillType, false) then
						trailer.LoadTime = (trailer.LoadTime or 0) + dt
						if trailer.LoadTime >= (trailer.CargoUnloadTime or 1000) then
							trailer.LoadTime = 0
							local deltaFillLevel = math.min(1, siloAmount);
							trailer:setFillLevel(fillLevel+deltaFillLevel, self.PigFillTrigger.fillType);
							local newFillLevel = trailer:getFillLevel(self.PigFillTrigger.fillType);

							if fillLevel ~= newFillLevel then
								self:setMastPigs(math.max(self.numSchweine-(newFillLevel-fillLevel), 0));
								self.PigFillTrigger:startFill();
								self.SendUpdate = true;
							else
								self.PigFillTrigger.fillDone = true; -- trailer is full
								self.PigFillTrigger:stopFill();
							end;
						end
					else
						self.PigFillTrigger.fillDone = true; -- silo is empty or trailer does not support fill type
						self.PigFillTrigger:stopFill();
					end;
				-- elseif self.PigFillTrigger.isFilling then
					-- self.PigFillTrigger.fillDone = true;
					-- self.PigFillTrigger:stopFill();
				-- end
			else
				if self.PigFillTrigger.isFilling then
					self.PigFillTrigger.fillDone = true;
					self.PigFillTrigger:stopFill();
				end;
				self.IsFilling = nil;
			end
		end;
	end;

end;

function SchweineZucht:updateTick(dt)

	self.updateMs = self.updateMs + (dt * g_currentMission.missionStats.timeScale);
	if self.updateMs >= 60000 then
		self.updateMs = self.updateMs - 60000;
		self.updateMin = self.updateMin + 1;
		if self.updateMin >= self.updateIntervall then
			self.updateMin = self.updateMin - self.updateIntervall
			if self.isServer then
				local produktivi = 0
				local need = (self.numPig + (self.numSchweine/2)) * ((self.FutterKgTag/24/60) * self.updateIntervall)  -- Pro Schwein von jeder Sorte
				local mix = 1;
				if self.FutterTypLvl[FutterTypes[Fillable.FILLTYPE_FORAGE]] > 0 then
					mix = FutterTypes[Fillable.FILLTYPE_FORAGE];
				end;
				for i = mix, table.getn(self.FutterTypLvl) do
					self.FutterTypLvl[i] = math.max(self.FutterTypLvl[i] - (need * FutterTypFac[i]),0)
					if self.FutterTypLvl[i] > 0 then
						produktivi = produktivi + FutterTypProd[i]
					end
				end

				self.Produktivi = produktivi

				self.nextSchwein = self.nextSchwein + ((self.PigProMin * self.updateIntervall) * self.numPig * produktivi)
				while self.nextSchwein >= 1 do
					self.nextSchwein = self.nextSchwein - 1
					self:setMastPigs(self.numSchweine + 1)
				end;

				if self.liquidManureSiloTrigger ~= nil and self.Produktivi >= 0.1 then
					self.liquidManureSiloTrigger:setFillLevel(self.liquidManureSiloTrigger.fillLevel + ((self.numPig + (self.numSchweine/2)) * ((self.ManureProMin * self.updateIntervall) * 0.95)));
				end
				if self.manureHeap and self.FutterTypLvl[FutterTypes[Fillable.FILLTYPE_WHEAT_WINDROW]] > 0 then
					self:manureHeapSetFillLevel(self.manureHeap.FillLvl + ((self.numPig + (self.numSchweine/2)) * (self.ManureProMin * self.updateIntervall)));
				end;

				self.SendUpdate = true;
				self.updateFillPlane = true;

			end;
		end;
	end;

	self.WaterTrailerInRange = nil
	for i = 1 , table.getn(self.WaterTrailers) do
		if self.WaterTrailers[i]:getFillLevel(Fillable.FILLTYPE_WATER) > 0 then
			self.WaterTrailerInRange = self.WaterTrailers[i]
			break;
		end;
	end;
	if self.WaterTrailerInRange then
		if not self.WaterTrailerActivatableAdded then
			g_currentMission:addActivatableObject(self.WaterTrailerActivatable);
			self.WaterTrailerActivatableAdded = true;
		end;
		if self.isWaterTankFilling and self.isServer then
			local delta = self.WaterTrailerInRange.fillLitersPerSecond*dt*0.001;
			delta = math.min(self.WaterTrailerInRange:getFillLevel(Fillable.FILLTYPE_WATER),delta);
			for i = 1 ,table.getn(self.tipTriggers) do
				if self.tipTriggers[i].acceptedFillTypes[Fillable.FILLTYPE_WATER] then
					local oldLvl = self:getTipTriggerFillLevel(self.tipTriggers[i])
					self:updateTrailerTipping(self.WaterTrailerInRange, -delta, Fillable.FILLTYPE_WATER, self.tipTriggers[i]);
					delta = self:getTipTriggerFillLevel(self.tipTriggers[i]) - oldLvl;
					self.WaterTrailerInRange:setFillLevel(self.WaterTrailerInRange:getFillLevel(Fillable.FILLTYPE_WATER) - delta, Fillable.FILLTYPE_WATER, true);
					break;
				end;
			end;
		end;
	else
		self.isWaterTankFilling = false
		if self.WaterTrailerActivatableAdded then
			g_currentMission:removeActivatableObject(self.WaterTrailerActivatable);
			self.WaterTrailerActivatableAdded = false;
		end;
	end;

	if self.Doors then
		for i=1, table.getn(self.Doors) do
			local old = self.Doors[i].Trans;
			if (self.Doors[i].entred > 0) then
				if self.Doors[i].Trans < self.Doors[i].maxTrans then
					self.Doors[i].Trans = math.min(self.Doors[i].Trans + dt*0.003, self.Doors[i].maxTrans);
				end;
			elseif (self.Doors[i].entred <= 0) then
				if self.Doors[i].Trans > self.Doors[i].minTrans then
					self.Doors[i].Trans = math.max(self.Doors[i].Trans - dt*0.003, self.Doors[i].minTrans);
				end;
			end;

			if old ~= self.Doors[i].Trans then
				local dir = 1;
				for j=1, table.getn(self.Doors[i].door) do
					local x, y, z = getTranslation(self.Doors[i].door[j]);
					setTranslation(self.Doors[i].door[j], x, y, self.Doors[i].Trans * dir);
					dir = dir * -1
				end;
			end;
		end;
	end;
	
	if self.isClient then
        if self.AniPig then
			for i = 1, table.getn(self.AniPig) do
				local p = self.AniPig[i];
				if i <= self.numPig then
					if not getVisibility(p.pig) then setVisibility(p.pig,true) end;
					p.time = p.time - dt
					if p.time <= 0 then
						if not isAnimTrackEnabled(p.Animi, 0) then
							enableAnimTrack(p.Animi, 0);
						end
						if getAnimTrackTime(p.Animi, 0) > getAnimClipDuration(p.Animi, 0) then
							setAnimTrackTime(p.Animi, 0, 0, false);
							p.time = math.random(0, p.RNDTime)
						end;
					elseif isAnimTrackEnabled(p.Animi, 0) and getAnimTrackTime(p.Animi, 0) > getAnimClipDuration(p.Animi, 0) then
						disableAnimTrack(p.Animi, 0);
					end;
				elseif getVisibility(p.pig) then
					setVisibility(p.pig,false)
				end;
			end;
		end;
	end;
	
	if self.SendUpdate then
		self.SendUpdate = nil
		self:raiseDirtyFlags(self.SchweineZuchtDirtyFlag);
	end

	if self.updateFillPlane then
		self.updateFillPlane = nil;
		for i = 1 ,table.getn(self.tipTriggers) do
			if self.tipTriggers[i].updateFillPlane ~= nil then
				self.tipTriggers[i]:updateFillPlane();
			end;
		end;
	end;
end;

function SchweineZucht:getNumAnimals()
	local numPigs = 0
	for k,t in pairs(g_SchweineDaten[self.animal]) do
		numPigs = numPigs + t.numPig
	end
	return numPigs
end

function SchweineZucht:addAnimals(a,b)
	local minPig
	for k,t in pairs(g_SchweineDaten[self.animal]) do
		minPig = math.min(minPig or t.numPig, t.numPig)
	end
	for k,t in pairs(g_SchweineDaten[self.animal]) do
		if t.numPig <= minPig then
			t.numPig = t.numPig + a
			t:setPlanesMoveScale()
			break;
		end
	end
end

function SchweineZucht:removeAnimals(a)
	local maxPig = 0
	for k,t in pairs(g_SchweineDaten[self.animal]) do
		maxPig = math.max(maxPig, t.numPig)
	end
	for k,t in pairs(g_SchweineDaten[self.animal]) do
		if t.numPig >= maxPig then
			t.numPig = t.numPig - a
			t:setPlanesMoveScale()
			break;
		end
	end
end

function SchweineZucht:setMastPigs(v)
	self.numSchweine = v;
	if self.PigCount then
		local num = tonumber(self.numSchweine);
		for j = getNumOfChildren(self.PigCount), 1, -1 do
			local offset = (num % 10)
			setShaderParameter(getChildAt(self.PigCount, j-1), "number", offset,0 , 0, 0, false);			
			num = math.floor(num / 10);
		end;
	end;
end

function SchweineZucht:setPlanesMoveScale()
	local need = math.max(self.numPig,10) * self.FutterKgTag * 6
	for i = 1 ,table.getn(self.tipTriggers) do
		if self.tipTriggers[i].updateFillPlane ~= nil then
			maxfillLvl = 0;
			for k,v in pairs(self.tipTriggers[i].acceptedFillTypes) do
				maxfillLvl = math.max(need * FutterTypFac[FutterTypes[k]],maxfillLvl);
			end
			self.tipTriggers[i].moveScale = (self.tipTriggers[i].moveMaxY-self.tipTriggers[i].moveMinY) / maxfillLvl;
			self.tipTriggers[i]:updateFillPlane();
		end;
	end;
end

function SchweineZucht:getHasSpaceForTipping(fillType)
	local need = math.max(self.numPig,10) * self.FutterKgTag * 6

	if FutterTypes[fillType] then
		if self.FutterTypLvl[FutterTypes[fillType]] >= need * FutterTypFac[FutterTypes[fillType]] then
			return false;
		end;
	end;
	return true;
end;

function SchweineZucht:updateTrailerTipping(trailer, fillDelta, fillType, trigger)

	if fillDelta < 0 then
		self.FutterTypLvl[FutterTypes[fillType]] = self.FutterTypLvl[FutterTypes[fillType]] - fillDelta;

		for i = 1 ,table.getn(self.tipTriggers) do
			if trigger.acceptedFillTypes[fillType] and self.tipTriggers[i].updateFillPlane ~= nil then
				self.tipTriggers[i]:updateFillPlane()
			end;
		end;
		self.SendUpdate = true
	end;
end;

function SchweineZucht:getTipTriggerFillTypes(trigger)
	local TriggerFillTypes = {}
	for fillType in pairs(trigger.acceptedFillTypes) do
		TriggerFillTypes[fillType] = self.FutterTypLvl[FutterTypes[fillType]]
	end
	return TriggerFillTypes
end

function SchweineZucht:getTipTriggerFillLevel(trigger)
	local maxFillLvl = 0;
	for fillType in pairs(trigger.acceptedFillTypes) do
		maxFillLvl = math.max(self.FutterTypLvl[FutterTypes[fillType]], maxFillLvl);
	end
	return maxFillLvl;
end

function SchweineZucht:manureHeapfillShovel(SFT, shovel, dt)
	local fillLevel = self.manureHeap.FillLvl;
	if fillLevel > 0 then
		local delta = shovel:fillShovelFromTrigger(SFT, fillLevel, Fillable.FILLTYPE_MANURE, dt);
		if delta > 0 then
			self:manureHeapSetFillLevel(fillLevel-delta, Fillable.FILLTYPE_MANURE);
			self.SendUpdate = true;
		end;
	end;
end;

function SchweineZucht:manureHeapSetFillLevel(fillLevel, fillType)

	if fillLevel > self.manureHeap.capacity  then
		fillLevel = self.manureHeap.capacity ;
	end;
	if fillLevel < 0 then
		fillLevel = 0;
	end;
	self.manureHeap.FillLvl = fillLevel;

	if self.manureHeap.movingId ~= nil then
		local x,y,z = getTranslation(self.manureHeap.movingId);
		local y =self.manureHeap.moveMinY + (self.manureHeap.moveMaxY - self.manureHeap.moveMinY)*self.manureHeap.FillLvl/self.manureHeap.capacity;
		setTranslation(self.manureHeap.movingId, x,y,z);
	end;

end;

function SchweineZucht:liquidManureFillLevelChanged(fillLevel, fillType, fillTrigger)
    if self.isServer then
        self.SendUpdate = true;
    end
end;

function SchweineZucht:setIsWaterTankFilling(isFilling, noEventSend)

	SMAsetIsWaterTankFillingEvent.sendEvent(self, isFilling, noEventSend);
	self.isWaterTankFilling = isFilling;

end;

function SchweineZucht:addWaterTrailer(waterTrailer, send, noEventSend)
	table.insert(self.WaterTrailers, waterTrailer);
end;

function SchweineZucht:removeWaterTrailer(waterTrailer, send, noEventSend)
	 for i=1, table.getn(self.WaterTrailers) do
        if self.WaterTrailers[i] == waterTrailer then
            table.remove(self.WaterTrailers, i);
            break;
        end;
    end;
end;

function SchweineZucht:onWaterTankTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local waterTrailer = g_currentMission.objectToTrailer[otherShapeId];
	if waterTrailer ~= nil and waterTrailer:allowFillType(Fillable.FILLTYPE_WATER, false) then
		if onEnter then
			self:addWaterTrailer(waterTrailer);
		else -- onLeave
			self:removeWaterTrailer(waterTrailer);
		end;
	end;
end;

function SchweineZucht:doorTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)

	for i=1, table.getn(self.Doors) do
		if self.Doors[i].triggerId == triggerId then
			if onEnter then
				self.Doors[i].entred = self.Doors[i].entred + 1
			else -- onLeave
				self.Doors[i].entred = math.max(self.Doors[i].entred - 1,0)
			end;
			break;
		end;
	end;

end;

function SchweineZucht:getDataAttributes()
 local data = {}
 return data
end

function SchweineZucht:UpdatePigStatistik()
	local textTable = {}
	table.insert(textTable,string.format("%d",self.numPig))
	table.insert(textTable,string.format("%d",self.numSchweine))
	table.insert(textTable,string.format("%d%%",math.ceil(self.Produktivi*100)))
	table.insert(textTable,string.format("%d",self.FutterTypLvl[4]))
	for i = 1, table.getn(self.FutterTypLvl) do
		if i ~= 4 then
			table.insert(textTable,string.format("%d",self.FutterTypLvl[i]))
		end
	end
	if self.manureHeap then
		table.insert(textTable,string.format("%d",self.manureHeap.FillLvl))
	end
	if self.liquidManureSiloTrigger then
		table.insert(textTable,string.format("%d",self.liquidManureSiloTrigger.fillLevel))
	end
	local j = 1
	for i=11,10+(table.getn(textTable)*2),2 do --financesTitle
		self.elements.elements[i].text = textTable[j]
		j=j+1
	end
end

local function DrawElements(element)
	if element.overlay and element.overlay.overlay then
		if element.overlay.uvs then
			setOverlayUVs(element.overlay.overlay,unpack(element.overlay.uvs));
		end
		if element.overlay.color then
			setOverlayColor(element.overlay.overlay,unpack(element.overlay.color));
		end
		renderOverlay(element.overlay.overlay,element.absPosition[1],element.absPosition[2],element.size[1],element.size[2])
	elseif element.text then
		setTextAlignment(element.alignment);
		setTextBold(element.textBold)
		setTextColor(unpack(element.textColor));
		renderText(element.absPosition[1],element.absPosition[2],element.textSize,element.text);
	end
end
		
function SchweineZucht:HookStatisticView()
	local g = getfenv(0)
	if not g.SchweineZuchtHook then
		g.SchweineZuchtHook = {}
		g.SchweineZuchtHook.StatisticViewDraw = StatisticView.draw
		StatisticView.draw = function(...)
			local r = {g.SchweineZuchtHook.StatisticViewDraw(...)}
			local SV = select(1,...)
			local page = SV:getCurrentPageId()
			if SV.pages[page].element.SchweineZucht then
				local Anlagen = SV.pages[page].element.elements;
				for i = 1,table.getn(Anlagen) do
					Anlagen[i].target:UpdatePigStatistik()
					for j=1,table.getn(Anlagen[i].elements) do
						DrawElements(Anlagen[i].elements[j])
					end
				end;
				setTextAlignment(RenderText.ALIGN_LEFT);
				setTextBold(false)
				setTextColor(1,1,1,1);
			end
			return unpack(r)
		end
		g.SchweineZuchtHook.StatisticViewUpdatePriceTable = StatisticView.updatePriceTable
		StatisticView.updatePriceTable = function(...)
			local fixFillTypes = {}
			for k,v in pairs (g_SchweineDaten) do
				local desc = Fillable.fillTypeNameToDesc[k] 
				if desc ~= nil then
					fixFillTypes[desc.index] = true;
				end
			end
			for k,v in pairs(g_currentMission.tipTriggers) do
				if v.acceptedFillTypes then
					for fillType in pairs (v.acceptedFillTypes) do
						if fixFillTypes[fillType] then
							if v.priceMultipliers and (v.SZ_pM == nil or v.SZ_pM[fillType] == nil) then
								if v.SZ_pM == nil then v.SZ_pM ={} end
								v.SZ_pM[fillType] = v.priceMultipliers[fillType]
								v.priceMultipliers[fillType] = v.priceMultipliers[fillType] / 1000
							end
						end
					end
				end
			end
			local r = {g.SchweineZuchtHook.StatisticViewUpdatePriceTable(...)}
			for k,v in pairs(g_currentMission.tipTriggers) do
				if v.SZ_pM then
					for fillType in pairs (v.SZ_pM) do
						v.priceMultipliers[fillType] = v.SZ_pM[fillType]
					end
					v.SZ_pM = nil;
				end
			end
			return unpack(r)
		end
	end;
end

g_onCreateUtil.addOnCreateFunction("SchweineZucht", SchweineZucht.onCreate);

SMAWaterTrailerActivatable = {}
local SMAWaterTrailerActivatable_mt = Class(SMAWaterTrailerActivatable);

function SMAWaterTrailerActivatable:new(SMA)
    local self = {};
    setmetatable(self, SMAWaterTrailerActivatable_mt);

    self.SMA = SMA;
	self.activateText = "unknown";

    return self;
end;

function SMAWaterTrailerActivatable:getIsActivatable()
  	if self.SMA.WaterTrailerInRange and self.SMA.WaterTrailerInRange:getIsActiveForInput() then
		if self.SMA:getHasSpaceForTipping(Fillable.FILLTYPE_WATER) then
			self:updateActivateText();
			return true;
		else
			g_currentMission:addWarning(g_i18n:getText("limited_in_advance_feeding"), 0.018, 0.033);
            self.SMA:setIsWaterTankFilling(false)
			return false;
		end

	end;

    return false;
end

function SMAWaterTrailerActivatable:onActivateObject()
	self.SMA:setIsWaterTankFilling(not self.SMA.isWaterTankFilling)

    self:updateActivateText();
    g_currentMission:addActivatableObject(self);
end;

function SMAWaterTrailerActivatable:drawActivate()
    --self.Overlay:render();
end;

function SMAWaterTrailerActivatable:updateActivateText()
	local wasseri18n = Fillable.fillTypeIndexToDesc[Fillable.FILLTYPE_WATER].nameI18N
	if self.SMA.isWaterTankFilling then
		self.activateText = string.format(g_i18n:getText("stop_refill_OBJECT"), wasseri18n);
	else
		self.activateText = string.format(g_i18n:getText("refill_OBJECT"), wasseri18n);
	end;

end;

 -- Event Set isWaterTankFilling --

SMAsetIsWaterTankFillingEvent = {};
SMAsetIsWaterTankFillingEvent_mt = Class(SMAsetIsWaterTankFillingEvent, Event);

InitEventClass(SMAsetIsWaterTankFillingEvent, "SMAsetIsWaterTankFillingEvent");

function SMAsetIsWaterTankFillingEvent:emptyNew()
    local self = Event:new(SMAsetIsWaterTankFillingEvent_mt);
    return self;
end;

function SMAsetIsWaterTankFillingEvent:new(object, SetIsFilling)
	local self = SMAsetIsWaterTankFillingEvent:emptyNew()
	self.object = object;
	self.SetIsFilling = SetIsFilling;
	return self;
end;

function SMAsetIsWaterTankFillingEvent:readStream(streamId, connection)
	local id = streamReadInt32(streamId);
	self.SetIsFilling = streamReadBool(streamId);
	self.object = networkGetObject(id);
	self:run(connection);
end;

function SMAsetIsWaterTankFillingEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, networkGetObjectId(self.object));
	streamWriteBool(streamId, self.SetIsFilling);
end;

function SMAsetIsWaterTankFillingEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object);
	end;
	if self.object ~= nil then
		self.object:setIsWaterTankFilling(self.SetIsFilling, true);
	end;
end;

function SMAsetIsWaterTankFillingEvent.sendEvent(silo, SetIsFilling, noEventSend)
	if SetIsFilling ~= silo.isWaterTankFilling then
		if noEventSend == nil or noEventSend == false then
			if g_server ~= nil then
				g_server:broadcastEvent(SMAsetIsWaterTankFillingEvent:new(silo, SetIsFilling), nil, nil, silo);
			else
				g_client:getServerConnection():sendEvent(SMAsetIsWaterTankFillingEvent:new(silo, SetIsFilling));
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