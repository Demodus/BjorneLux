--
-- Manual Barrier Manager
-- (functions for load and save manual opened barrier and gates)
-- by Blacky_BPG
-- only for FS15
--
-- Version 5.15.4 | 08.11.2014
--
-- No script change without my permission
-- 

ManualBarrierManager = {};
ManualBarrierManager.savegamePath = getUserProfileAppPath() .. "savegame" .. g_careerScreen.selectedIndex;
ManualBarrierManager.savegameFilename = ManualBarrierManager.savegamePath .. "/ManualBarrier.xml";
ManualBarrierManager.isSaved = false;
ManualBarrierManager.saveTimer = 200;

steerable_save = Steerable.getSaveAttributesAndNodes;
Steerable.getSaveAttributesAndNodes = function(self, nodeIdent)
	if ManualBarrierManager ~= nil then
		if not ManualBarrierManager.isSaved then
			ManualBarrierManager:saveOpenStates();
			ManualBarrierManager.isSaved = true;
		end;
	end;
	steerable_save(self,nodeIdent);
end;

----------------------------------------------------------------------------------------

function ManualBarrierManager:loadMap(name)
	if g_currentMission ~= nil then
		if g_currentMission.barrierTriggers == nil then
			g_currentMission.barrierTriggers = {};
		end;
	end;
	self.triggersLoaded = false;
	self.oldNumTriggers = 0;

	print("--- loading ManualBarrier mod V5.15.4 (by Blacky_BPG)---")

	-- load default Text
	g_i18n.globalI18N.texts["string_OPEN"] = g_i18n:getText("string_OPEN");
	g_i18n.globalI18N.texts["string_CLOSE"] = g_i18n:getText("string_CLOSE");
	g_i18n.globalI18N.texts["string_ON"] = g_i18n:getText("string_ON");
	g_i18n.globalI18N.texts["string_OFF"] = g_i18n:getText("string_OFF");
	g_i18n.globalI18N.texts["string_BARRIER"] = g_i18n:getText("string_BARRIER");
	g_i18n.globalI18N.texts["string_GATE"] = g_i18n:getText("string_GATE");
	g_i18n.globalI18N.texts["string_LIGHT"] = g_i18n:getText("string_LIGHT");
	g_i18n.globalI18N.texts["string_DEFAULT"] = g_i18n:getText("string_DEFAULT");
	g_i18n.globalI18N.texts["OPEN_GATE"] = g_i18n:getText("OPEN_GATE");
end;

function ManualBarrierManager:deleteMap()
end;

function ManualBarrierManager:update(dt)
	if not self.triggersLoaded then
		if g_currentMission.barrierTriggers ~= nil and table.getn(g_currentMission.barrierTriggers) > 0 then
			if table.getn(g_currentMission.barrierTriggers) > self.oldNumTriggers then
				self.oldNumTriggers = table.getn(g_currentMission.barrierTriggers);
				self:loadOpenStates();
			end;
		end;
	end;
	if self.isSaved then
		self.saveTimer = self.saveTimer - 1;
		if self.saveTimer <= 0 then
			self.isSaved = false;
			self.saveTimer = 200;
		end;
	end;
end;

function ManualBarrierManager:saveOpenStates()
	if self.savegamePath ~= nil and ((g_server and g_currentMission.missionDynamicInfo.isMultiplayer) or (not g_currentMission.missionDynamicInfo.isMultiplayer)) then
		local xmlFile = createXMLFile("ManualBarrier", self.savegameFilename, "ManualBarrier");
		if xmlFile ~= nil then
			for _,barrierTrigger in pairs(g_currentMission.barrierTriggers) do
				if barrierTrigger.saveName ~= nil then
					local name = "ManualBarrier."..barrierTrigger.saveName;
					setXMLBool(xmlFile, name.."#manualOpen",barrierTrigger.manualOpen);
					setXMLInt(xmlFile, name.."#openState",barrierTrigger.openState);
				end;
			end;
		end;
		saveXMLFile(xmlFile);
		delete(xmlFile);
	end;
end;

function ManualBarrierManager:loadOpenStates()
	if self.savegamePath ~= nil and fileExists(self.savegameFilename) then
		local xmlFile = loadXMLFile("ManualBarrier", self.savegameFilename);
		if xmlFile ~= nil and g_currentMission.barrierTriggers ~= nil then
			for triggerId ,barrierTrigger in pairs(g_currentMission.barrierTriggers) do
				if barrierTrigger.saveName ~= nil then
					local name = "ManualBarrier."..barrierTrigger.saveName;
					local sN = getXMLBool(xmlFile, name.."#manualOpen");
					local oS = Utils.getNoNil(getXMLInt(xmlFile, name.."#openState"),1);
					if sN ~= nil and sN == true then
						barrierTrigger:setOpenState(oS);
					end;
				end;
			end;
			delete(xmlFile);
		end;
	end;
	self.triggersLoaded = true;
end;

function ManualBarrierManager:mouseEvent(posX, posY, isDown, isUp, button)
end;
function ManualBarrierManager:keyEvent(unicode, sym, modifier, isDown)
end;
function ManualBarrierManager:draw()
end;

addModEventListener(ManualBarrierManager);
