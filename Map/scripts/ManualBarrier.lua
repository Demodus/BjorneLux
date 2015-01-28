--
-- Manual Barrier (automatic included)
-- by Blacky_BPG
-- only for FS15
--
-- Version 5.15.5 | 29.11.2014 - fixed error when a trailer leaves the trigger before the vehicle (reverse drive for example)
-- Version 5.15.4 | 08.11.2014
--
-- No script change without my permission
-- 

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--   ATTENTION      ATTENTION      ATTENTION      ATTENTION      ATTENTION   --
-- ========================================================================= --
--   The UserAttribute   manualBarrierId   must be unique for each object    --
--   that must work with this script, thats realy important, otherwise       --
--   you can open only the last assigned objects with the same               --
--   manualBarrierId .                                                       --
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


ManualBarrier = {};
ManualBarrier.statusString = nil;
ManualBarrier_mt = Class(ManualBarrier, Object);
InitObjectClass(ManualBarrier, "ManualBarrier");

function ManualBarrier.onCreate(id)
	local object = ManualBarrier:new(g_server ~= nil, g_client ~= nil);
	if object:load(id) then
		g_currentMission:addOnCreateLoadedObject(object);
		object:register(true);
	else
		object:delete();
	end;
end;

function ManualBarrier:new(isServer, isClient, customMt)
	local mt = customMt;
	if mt == nil then
		mt = ManualBarrier_mt;
	end;

	local self = Object:new(isServer, isClient, mt);
	self.ManualBarrierDirtyFlag = self:getNextDirtyFlag();
	self.openState = 0;
	return self;
end;

function ManualBarrier:delete()
	if self.triggerId ~= nil then
		removeTrigger(self.triggerId);
	end;
	if self.nodeId ~= 0 then
		g_currentMission:removeNodeObject(self.nodeId);
	end;
	ManualBarrier:superClass().delete(self);
end;

function ManualBarrier:readStream(streamId, connection)
	ManualBarrier:superClass().readStream(self, streamId, connection);
	if connection:getIsServer() then
		local openState = streamReadInt8(streamId);
		self:setOpenState(openState);
	end;
end;

function ManualBarrier:writeStream(streamId, connection)
	ManualBarrier:superClass().writeStream(self, streamId, connection);
	if not connection:getIsServer() then
		streamWriteInt8(streamId, self.openState);
	end;
end;

function ManualBarrier:readUpdateStream(streamId, timestamp, connection)
	ManualBarrier:superClass().readUpdateStream(self, streamId, timestamp, connection)
	if connection:getIsServer() then
		local openState = streamReadInt8(streamId);
		self:setOpenState(openState);
	end;
end;

function ManualBarrier:writeUpdateStream(streamId, connection, dirtyMask)
	ManualBarrier:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
	if not connection:getIsServer() then
		streamWriteInt8(streamId, self.openState);
	end;
end;

function ManualBarrier:load(nodeId)
	self.nodeId = nodeId;

	local manualBarrierId = getUserAttribute(nodeId, "manualBarrierId");
	self.manualBarrierId = 1;
	if manualBarrierId ~= nil then
		self.manualBarrierId = manualBarrierId;
	else
		return false;
	end;
	self.triggerId = nil;
	local triggerId = getUserAttribute(nodeId, "triggerIndex");
	if triggerId ~= nil then
		self.triggerId = Utils.indexToObject(nodeId,triggerId);
	end;

	self.saveName = "MB_";

	self.typeBarrier = Utils.getNoNil(getUserAttribute(nodeId, "typeBarrier"), false);
	self.typeGate = Utils.getNoNil(getUserAttribute(nodeId, "typeGate"), false);
	self.typeAnimated = Utils.getNoNil(getUserAttribute(nodeId, "typeAnimated"), false);
	self.typeLight = Utils.getNoNil(getUserAttribute(nodeId, "typeLight"), false);
	self.flickerMode = Utils.getNoNil(getUserAttribute(nodeId, "flickerMode"), false);
	self.lightOnMove = Utils.getNoNil(getUserAttribute(nodeId, "lightOnMove"), false);
	self.flickerCounter = 0;

	self.stringOpen = Utils.getNoNil(getUserAttribute(nodeId, "string_Open"), "string_OPEN");
	self.stringClose = Utils.getNoNil(getUserAttribute(nodeId, "string_Close"), "string_CLOSE");
	self.stringName = Utils.getNoNil(getUserAttribute(nodeId, "string_Name"), "string_DEFAULT");
	self.stringOption = self.stringOpen;

	self.automaticMode = Utils.getNoNil(getUserAttribute(nodeId, "automaticMode"), false);
	self.halfAutomatic = false;
	self.automaticOpen = Utils.getNoNil(getUserAttribute(nodeId, "automaticOpen"), 7);
	self.automaticClose = Utils.getNoNil(getUserAttribute(nodeId, "automaticClose"), 18);
	self.automaticStrict = Utils.getNoNil(getUserAttribute(nodeId, "automaticStrict"), false);

	self.manualOpen = Utils.getNoNil(getUserAttribute(nodeId, "manualOpen"), false);
	self.openState = 1;
	if self.manualOpen then
		self.openState = 0;
		if self.automaticMode then
			self.halfAutomatic = true;
			self.automaticMode = false;
		end;
		setCollisionMask(self.triggerId,99614720);
	else
		setCollisionMask(self.triggerId,98566144);
	end;

	self.playerInTrigger = false;

	self.Barriers = {};
	self.audio = nil;
	self.light = nil;
	self.speedScale = Utils.getNoNil(getUserAttribute(nodeId, "speedScale"),60) / 20;
	self.animCharSet = 0;
	self.trackTime = 0;
	self.lastTrackTime = 0;
	local audio = getUserAttribute(nodeId, "audioIndex");
	if audio ~= nil then
		self.audio = Utils.indexToObject(nodeId, audio);
	end;
	if self.typeLight then
		local lightIndex = getUserAttribute(nodeId, "lightIndex");
		if lightIndex ~= nil then
			local lightNode = Utils.indexToObject(nodeId, lightIndex);
			if lightNode ~= nil then
				self.light = lightNode;
			else
				self.typeLight = false;
			end;
		else
			self.typeLight = false;
		end;
	end;
	if self.typeBarrier or self.typeGate then
		local num = getNumOfChildren(self.triggerId);
		for i=0, num-1 do
			local childLevel1 = getChildAt(self.triggerId, i);
			if childLevel1 ~= 0 and getNumOfChildren(self.triggerId) >= 1 then
				local BarriersId = getChildAt(childLevel1, 0);
				if BarriersId ~= 0 then
					table.insert(self.Barriers, BarriersId);
				end;
			end;
		end;
	end;
	if self.typeAnimated then
		local animIndex = getUserAttribute(nodeId, "animatorIndex");
		local rootNode = nil;
		if animIndex ~= nil then
			rootNode = Utils.indexToObject(nodeId, animIndex);
		else
			self.typeAnimated = false;
		end;
		if rootNode ~= nil then
			self.animCharSet = getAnimCharacterSet(rootNode);
			if self.animCharSet ~= 0 then
				local clipSource = getUserAttribute(nodeId, "animationClip");
				if clipSource ~= nil then
					self.clip = getAnimClipIndex(self.animCharSet, clipSource);
					if self.clip ~= nil and self.clip >= 0 then
						assignAnimTrackClip(self.animCharSet, 0, self.clip);
						setAnimTrackLoopState(self.animCharSet, 0, false);
						setAnimTrackSpeedScale(self.animCharSet, 0, self.speedScale);
						self.animDuration = getAnimClipDuration(self.animCharSet, self.clip);
					else
						self.typeAnimated = false;
					end;
				else
					self.typeAnimated = false;
				end;
			else
				self.typeAnimated = false;
			end;
		else
			self.typeAnimated = false;
		end;
	end;

	if not self.typeBarrier and not self.typeGate and not self.typeAnimated and not self.typeLight then
		print(" Error: Manual barrier with ID "..tostring(self.manualBarrierId).." cant be loaded, no type specified");
		return false;
	end;
	if self.typeBarrier then
		self.saveName = self.saveName .."Barrier_";
	end;
	if self.typeGate then
		self.saveName = self.saveName .."Gate_";
	end;
	if self.typeAnimated then
		self.saveName = self.saveName .."Animated_";
	end;
	if self.typeLight then
		self.saveName = self.saveName .."Light_";
	end;
	self.saveName = self.saveName ..tostring(self.manualBarrierId);

	if self.triggerId ~= nil then
		addTrigger(self.triggerId, "triggerCallback", self);
	end;

	self.isEnabled = true;
	self.count = 0;

	self.angleX = 0;
	self.angleY = 0;
	self.angleZ = 0;
	self.maxXAngle = Utils.getNoNil(getUserAttribute(nodeId, "maxXAngle"), 0.0);
	self.minXAngle = Utils.getNoNil(getUserAttribute(nodeId, "minXAngle"), 0.0);
	self.maxYAngle = Utils.getNoNil(getUserAttribute(nodeId, "maxYAngle"), 0.0);
	self.minYAngle = Utils.getNoNil(getUserAttribute(nodeId, "minYAngle"), 0.0);
	self.maxZAngle = Utils.getNoNil(getUserAttribute(nodeId, "maxZAngle"), 0.0);
	self.minZAngle = Utils.getNoNil(getUserAttribute(nodeId, "minZAngle"), 0.0);

	self.transX = 0;
	self.transY = 0;
	self.transZ = 0;
	self.maxX = Utils.getNoNil(getUserAttribute(nodeId, "maxX"), 0.0);
	self.minX = Utils.getNoNil(getUserAttribute(nodeId, "minX"), 0.0);
	self.maxY = Utils.getNoNil(getUserAttribute(nodeId, "maxY"), 0.0);
	self.minY = Utils.getNoNil(getUserAttribute(nodeId, "minY"), 0.0);
	self.maxZ = Utils.getNoNil(getUserAttribute(nodeId, "maxZ"), 0.0);
	self.minZ = Utils.getNoNil(getUserAttribute(nodeId, "minZ"), 0.0);

	if self.audio ~= nil then
		setVisibility(self.audio, false);
	end;

	if self.light ~= nil then
		setVisibility(self.light, false);
	end;

	self.setOpenState = ManualBarrier.setOpenState;

	g_currentMission:addNodeObject(self.nodeId, self);

	self.triggerIsAdded = false;

	return true;
end;

function ManualBarrier:draw()
end;

function ManualBarrier:drawPlayer()
	if self.isClient then
		if self.canDrawOpen and self.mbName ~= nil and ManualBarrier.statusString ~= nil then
			g_currentMission:addHelpButtonText(g_i18n:getText(self.mbName).." "..g_i18n:getText(ManualBarrier.statusString), InputBinding.OPEN_GATE);
		end;
	end;
end;
function ManualBarrier:drawVehicle()
	if self.isClient then
		if self.canDrawOpen and self.mbName ~= nil and ManualBarrier.statusString ~= nil then
			g_currentMission:addHelpButtonText(g_i18n:getText(self.mbName).." "..g_i18n:getText(ManualBarrier.statusString), InputBinding.OPEN_GATE);
		end;
	end;
end;
Steerable.draw = Utils.appendedFunction(Steerable.draw, ManualBarrier.drawVehicle);
Player.draw = Utils.appendedFunction(Player.draw, ManualBarrier.drawPlayer);

function ManualBarrier:update(dt)
	if not self.triggerIsAdded then
		if g_currentMission.barrierTriggers == nil then
			g_currentMission.barrierTriggers = {};
		end;
		g_currentMission.barrierTriggers[self.manualBarrierId] = self;
		self.triggerIsAdded = true;
	end;

	local ctime = math.floor(g_currentMission.environment.dayTime / 3600 / 10) / 100;

	if self.halfAutomatic and self.manualOpen then
		if (ctime < self.automaticOpen) or (ctime > self.automaticClose) then
			if not self.automaticStrict then
				if not self.playerInTrigger then
					if self.openState == 2 then
						self:setOpenState(0);
					end;
				end;
			else
				self.playerInTrigger = false;
				if self.openState == 2 then
					self:setOpenState(0);
				end;
			end;
		end;
	end;
	if self.automaticMode then
		if (ctime < self.automaticOpen) or (ctime > self.automaticClose) then
			self.count = 0;
		else
			self.count = 1;
		end;
	end;

	if self.manualOpen == true and self.isClient then
		if self.playerInTrigger == true then
			if InputBinding.hasEvent(InputBinding.OPEN_GATE) then
				if self.openState == 0 then
					self:setOpenState(2);
				else
					self:setOpenState(0);
				end;
			end;
		end;
	end;

	local isWorking = false;
	if self.typeBarrier then
		local oldZ = self.angleZ;
		if (self.count > 0 and not self.manualOpen) or self.openState > 1 then
			if self.maxXAngle < self.minYAngle then
				if self.angleX > self.maxXAngle then self.angleX = self.angleX - dt*(self.speedScale/50) end;
				if self.angleX < self.maxXAngle then self.angleX = self.maxXAngle end;
			else
				if self.angleX < self.maxXAngle then self.angleX = self.angleX + dt*(self.speedScale/50) end;
				if self.angleX > self.maxXAngle then self.angleX = self.maxXAngle end;
			end;
			if self.maxYAngle < self.minYAngle then
				if self.angleY > self.maxYAngle then self.angleY = self.angleY - dt*(self.speedScale/50) end;
				if self.angleY < self.maxYAngle then self.angleY = self.maxYAngle end;
			else
				if self.angleY < self.maxYAngle then self.angleY = self.angleY + dt*(self.speedScale/50) end;
				if self.angleY > self.maxYAngle then self.angleY = self.maxYAngle end;
			end;
			if self.maxZAngle < self.minZAngle then
				if self.angleZ > self.maxZAngle then self.angleZ = self.angleZ - dt*(self.speedScale/50) end;
				if self.angleZ < self.maxZAngle then self.angleZ = self.maxZAngle end;
			else
				if self.angleZ < self.maxZAngle then self.angleZ = self.angleZ + dt*(self.speedScale/50) end;
				if self.angleZ > self.maxZAngle then self.angleZ = self.maxZAngle end;
			end;
		else
			if self.maxXAngle < self.minXAngle then
				if self.angleX < self.minXAngle then self.angleX = self.angleX + dt*(self.speedScale/50) end;
				if self.angleX > self.minXAngle then self.angleX = self.minXAngle end;
			else
				if self.angleX > self.minXAngle then self.angleX = self.angleX - dt*(self.speedScale/50) end;
				if self.angleX < self.minXAngle then self.angleX = self.minXAngle end;
			end;
			if self.maxYAngle < self.minYAngle then
				if self.angleY < self.minYAngle then self.angleY = self.angleY + dt*(self.speedScale/50) end;
				if self.angleY > self.minYAngle then self.angleY = self.minYAngle end;
			else
				if self.angleY > self.minYAngle then self.angleY = self.angleY - dt*(self.speedScale/50) end;
				if self.angleY < self.minYAngle then self.angleY = self.minYAngle end;
			end;
			if self.maxZAngle < self.minZAngle then
				if self.angleZ < self.minZAngle then self.angleZ = self.angleZ + dt*(self.speedScale/50) end;
				if self.angleZ > self.minZAngle then self.angleZ = self.minZAngle end;
			else
				if self.angleZ > self.minZAngle then self.angleZ = self.angleZ - dt*(self.speedScale/50) end;
				if self.angleZ < self.minZAngle then self.angleZ = self.minZAngle end;
			end;
		end;
		if oldX ~= self.angleX or oldY ~= self.angleY or oldZ ~= self.angleZ then
			isWorking = true;
			for i=1, table.getn(self.Barriers) do
				setRotation(self.Barriers[i], Utils.degToRad(self.angleX), Utils.degToRad(self.angleY), Utils.degToRad(self.angleZ));
			end;
		end;
	end;
	if self.typeGate then
		self.transX,self.transY,self.transZ = getTranslation(self.Barriers[1]);
		local oldX = self.transX;
		local oldY = self.transY;
		local oldZ = self.transZ;
		if (self.count > 0 and not self.manualOpen) or self.openState > 1 then
			if self.maxX < self.minX then
				if self.transX > self.maxX then self.transX = self.transX - dt*(self.speedScale/1500) end;
				if self.transX < self.maxX then self.transX = self.maxX end;
			else
				if self.transX < self.maxX then self.transX = self.transX + dt*(self.speedScale/1500) end
				if self.transX > self.maxX then self.transX = self.maxX end;
			end;
			if self.maxY < self.minY then
				if self.transY > self.maxY then self.transY = self.transY - dt*(self.speedScale/1500) end;
				if self.transY < self.maxY then self.transY = self.maxY end;
			else
				if self.transY < self.maxY then self.transY = self.transY + dt*(self.speedScale/1500) end
				if self.transY > self.maxY then self.transY = self.maxY end;
			end;
			if self.maxZ < self.minZ then
				if self.transZ > self.maxZ then self.transZ = self.transZ - dt*(self.speedScale/1500) end;
				if self.transZ < self.maxZ then self.transZ = self.maxZ end;
			else
				if self.transZ < self.maxZ then self.transZ = self.transZ + dt*(self.speedScale/1500) end
				if self.transZ > self.maxZ then self.transZ = self.maxZ end;
			end;
		else
			if self.maxX < self.minX then
				if self.transX < self.minX then self.transX = self.transX + dt*(self.speedScale/1500) end;
				if self.transX > self.minX then self.transX = self.minX end;
			else
				if self.transX > self.minX then self.transX = self.transX - dt*(self.speedScale/1500) end;
				if self.transX < self.minX then self.transX = self.minX end;
			end;
			if self.maxY < self.minY then
				if self.transY < self.maxY then self.transY = self.transY + dt*(self.speedScale/1500) end;
				if self.transY > self.maxY then self.transY = self.maxY end;
			else
				if self.transY > self.maxY then self.transY = self.transY - dt*(self.speedScale/1500) end
				if self.transY < self.maxY then self.transY = self.maxY end;
			end;
			if self.maxZ < self.minZ then
				if self.transZ < self.maxZ then self.transZ = self.transZ + dt*(self.speedScale/1500) end;
				if self.transZ > self.maxZ then self.transZ = self.maxZ end;
			else
				if self.transZ > self.maxZ then self.transZ = self.transZ - dt*(self.speedScale/1500) end
				if self.transZ < self.maxZ then self.transZ = self.maxZ end;
			end;
		end;
		if oldX ~= self.transX or oldY ~= self.transY or oldZ ~= self.transZ then
			isWorking = true;
			for i=1, table.getn(self.Barriers) do
				setTranslation(self.Barriers[i], self.transX, self.transY, self.transZ);
			end;
		end;
	end;

	if self.typeAnimated then
		if self.trackTime < 1 then
			self.trackTime = 0;
		end;

		if self.trackTime > self.animDuration then
			self.trackTime = self.animDuration;
		end;

		if (self.count > 0 and not self.manualOpen) or self.openState > 1 then
			if self.trackTime < self.animDuration then
				self.trackTime = self.trackTime + 10 * self.speedScale;
			end;
		else
			if self.trackTime > 0 then
				self.trackTime = self.trackTime - 10 * self.speedScale;
			end;
		end;
		if self.lastTrackTime ~= self.trackTime then
			isWorking = true;
			enableAnimTrack(self.animCharSet, self.clip);
			setAnimTrackTime(self.animCharSet, self.clip, self.trackTime, true);
			disableAnimTrack(self.animCharSet, self.clip);
			self.lastTrackTime = self.trackTime;
		end;
	end;
	if self.typeLight then
		local willSet = false;
		if (self.count > 0 and not self.manualOpen) or self.openState > 1 then
			willSet = true;
		end;
		if willSet then
			if self.flickerMode then
				if self.flickerCounter == 0 or self.flickerCounter == 4 or self.flickerCounter == 8 or self.flickerCounter >= 13 then
					setVisibility(self.light, true);
				elseif self.flickerCounter == 2 or self.flickerCounter == 5 or self.flickerCounter == 11 then
					setVisibility(self.light, false);
				end;
				if self.flickerCounter < 14 then
					self.flickerCounter = self.flickerCounter + 1;
				end;
			else
				self.flickerCounter = 0;
				if not getVisibility(self.light) then
					setVisibility(self.light,true);
				end;
			end;
		else
			self.flickerCounter = 0;
			if getVisibility(self.light) then
				setVisibility(self.light,false);
			end;
		end;
	end;
	if isWorking then
		if self.typeLight and self.lightOnMove then
			if not getVisibility(self.light) then
				setVisibility(self.light,true);
			end;
		end;
		if self.audio ~= nil then
			if not getVisibility(self.audio) then
				setVisibility(self.audio, true);
			end;
		end;
	else
		if self.typeLight and self.lightOnMove then
			if getVisibility(self.light) then
				setVisibility(self.light,false);
			end;
		end;
		if self.audio ~= nil then
			if getVisibility(self.audio) then
				setVisibility(self.audio, false);
			end;
		end;
	end;
end;

function ManualBarrier:updateTick(dt)
end;

function ManualBarrier:setOpenState(state, noEventSend)
	if state ~= nil then
		if self.openState ~= state then
			self.openState = state;
			if state == 0 then
				self.stringOption = self.stringOpen;
			elseif state == 2 then
				self.stringOption = self.stringClose;
			end;
			if ManualBarrier.statusString ~= nil then
				ManualBarrier.statusString = self.stringOption;
			end;
			ManualBarrierEvent.sendEvent(self, self.manualBarrierId, state, noEventSend);
			if self.isServer or g_server ~= nil then
				self:raiseDirtyFlags(self.ManualBarrierDirtyFlag);
			end;
		end;
	end;
end;

function ManualBarrier:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if g_currentMission ~= nil then
		local pName = nil;
		if g_currentMission.player ~= nil then
			pName = g_currentMission.player.controllerName;
			if self.manualOpen == true then
				if g_currentMission.player.rootNode == otherId then
					if onEnter and self.isEnabled then
						self.playerInTrigger = true;
						g_currentMission.player.canDrawOpen = true;
						g_currentMission.player.mbName = self.stringName;
						ManualBarrier.statusString = self.stringOption;
						self.count = self.count + 1;
					elseif onLeave then
						self.playerInTrigger = false;
						self.count = self.count - 1;
						g_currentMission.player.canDrawOpen = false;
						g_currentMission.player.mbName = nil;
						ManualBarrier.statusString = nil;
						if self.count <= 0 then
							self.count = 0;
						end;
					end;
				end;
			end;
		end;

		local vehicle = g_currentMission.nodeToVehicle[otherId];
		if vehicle ~= nil then
			if onEnter and self.isEnabled then
				self.count = self.count + 1;
				vehicle.canDrawOpen = false;
				if vehicle.isControlled ~= nil and self.manualOpen and pName ~= nil and pName == vehicle.controllerName then
					self.playerInTrigger = true;
					vehicle.canDrawOpen = true;
					vehicle.mbName = self.stringName;
					ManualBarrier.statusString = self.stringOption;
				end;
			elseif onLeave then
				self.count = self.count - 1;
				vehicle.canDrawOpen = false;
				if vehicle.isControlled ~= nil and self.manualOpen and pName ~= nil and pName == vehicle.controllerName then
					vehicle.mbName = nil;
					ManualBarrier.statusString = nil;
					self.playerInTrigger = false;
				end;
				if self.count <= 0 then
					self.count = 0;
				end;
				if self.count <= 0 then
					self.count = 0;
				end;
			end;
		end;
	end;
end;

g_onCreateUtil.addOnCreateFunction("ManualBarrier", ManualBarrier.onCreate);



ManualBarrierEvent = {}
ManualBarrierEvent_mt = Class(ManualBarrierEvent, Event)
InitEventClass(ManualBarrierEvent, "ManualBarrierEvent")
function ManualBarrierEvent:emptyNew()
    local self = Event:new(ManualBarrierEvent_mt);
    return self;
end;
function ManualBarrierEvent:new(barrier,manualBarrierId,state)
    local self = ManualBarrierEvent:emptyNew()
    self.barrier = barrier;
    self.manualBarrierId = manualBarrierId;
    self.state = state;
    return self;
end;
function ManualBarrierEvent:readStream(streamId, connection)
    local Id = streamReadInt32(streamId);
    self.manualBarrierId = streamReadInt32(streamId);
    self.state = streamReadInt8(streamId);
    self.barrier = networkGetObject(id);
    self:run(connection);
end;
function ManualBarrierEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.barrier));
    streamWriteInt32(streamId, self.manualBarrierId);
    streamWriteInt8(streamId, self.state);
end;
function ManualBarrierEvent:run(connection)
	if g_currentMission.barrierTriggers ~= nil and g_currentMission.barrierTriggers[self.manualBarrierId] ~= nil then
		g_currentMission.barrierTriggers[self.manualBarrierId]:setOpenState(self.state,true)
	end;
	if self.barrier ~= nil then
		self.barrier:setOpenState(self.state,true)
	end;
	if not connection:getIsServer() then
		g_server:broadcastEvent(ManualBarrierEvent:new(self.barrier, self.manualBarrierId, self.state), nil, connection, self.barrier);
	end;
end;
function ManualBarrierEvent.sendEvent(barrier,manualBarrierId,state,noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(ManualBarrierEvent:new(barrier, manualBarrierId, state), nil, nil, barrier);
		else
			g_client:getServerConnection():sendEvent(ManualBarrierEvent:new(barrier, manualBarrierId, state));
		end;
	end;
end;