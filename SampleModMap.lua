--
-- SampleModMap
--
-- @author  Stefan Geiger
-- @date  12/07/10
--
-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.

SampleModMap = {}

local SampleModMap_mt = Class(SampleModMap, Mission00);


function SampleModMap:new(baseDirectory, customMt)
    local mt = customMt;
    if mt == nil then
        mt = SampleModMap_mt;
    end;
    local self = SampleModMap:superClass():new(baseDirectory, mt);

    return self;
end;

function SampleModMap:delete()
    SampleModMap:superClass().delete(self);
end;

function SampleModMap:load()
    self:startLoadingTask();

    self.environment = Environment:new(Utils.getFilename("$data/sky/sky_day_night.i3d", self.baseDirectory), true, 8, true, true);

    self.helpIconsBase = nil;
    self.collectableGoldCoinsObject = nil;
    self.fieldDefinitionBase = nil;
    self.vehicleShopBase = nil;
	self.AnimationMapConfig = {"AnimationMap.xml", self.baseDirectory};

    self:loadMap(Utils.getFilename("map/map01.i3d", self.baseDirectory), true, self.loadCareerMap01Finished, self);
end;

function SampleModMap:loadCareerMap01Finished(node, arguments)
    if self.cancelLoading then
        return;
    end
    local startedRepeat = startFrameRepeatMode();
    trcScreenFlip();
    self:loadMapXMLFile(Utils.getFilename("SampleModMap.xml", self.baseDirectory));
    trcScreenFlip();
    self:loadTyreTrackSystem(Utils.getFilename("$data/vehicles/shared/tyreTrackMaterialHolder.i3d", self.baseDirectory));
    trcScreenFlip();
    self:loadI3D("$data/vehicles/particleAnimations/particle_materialHolder.i3d");
    trcScreenFlip();
    self:loadI3D("$data/vehicles/fillPlanes/fillPlane_materialHolder.i3d");
	trcScreenFlip();
    self.ingameMap:loadMap(Utils.getFilename("pda_map.png", self.baseDirectory), 2048, 2048);

	trcScreenFlip();
    g_statisticView:setMapViewsMap(Utils.getFilename("pda_map.png", self.baseDirectory), 2048, 2048);

	trcScreenFlip();
    -- ATMs
    self.ingameMap:createMapHotspot("Bank", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_bank.png", self.baseDirectory), 180, -790, nil, nil, false, false, false, 0, true);
    self.ingameMap:createMapHotspot("Bank", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_bank.png", self.baseDirectory), -192.5, -190, nil, nil, false, false, false, 0, true);

    -- shops
    self.ingameMap:createMapHotspot("Shop", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_shop.png", self.baseDirectory), -250, -175, nil, nil, false, false, false, 0, true);
    local gardenCenterHotspot = self.ingameMap:createMapHotspot("Shop", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_shop.png", self.baseDirectory), -572, 366, nil, nil, false, false, true, 0, true);
    gardenCenterHotspot.fullViewName = g_i18n:getText("gardenCenter");

    -- egg sellpoints
    self.ingameMap:createMapHotspot("Eggs", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_eggs.png", self.baseDirectory), 281.5, -704.5, nil, nil, false, false, false, 0, true);
    self.ingameMap:createMapHotspot("Eggs", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_eggs.png", self.baseDirectory), -741.5, -187, nil, nil, false, false, false, 0, true);
    
    -- farm silos
    self.ingameMap:createMapHotspot("TipPlace", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_tipPlace.png", self.baseDirectory), 161, -25, nil, nil, false, false, false, 0, true);
    
    -- bga
    self.ingameMap:createMapHotspot("TipPlace", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_tipPlace.png", self.baseDirectory), 10, 730, nil, nil, false, false, false, 0, true);
    
    -- grass heaps
    self.ingameMap:createMapHotspot("TipPlace", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_tipPlaceGreen.png", self.baseDirectory), -500, 500, nil, nil, false, false, false, 0, true);
    self.ingameMap:createMapHotspot("TipPlace", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_tipPlaceGreen.png", self.baseDirectory), -730.5, 140, nil, nil, false, false, false, 0, true);
    self.ingameMap:createMapHotspot("TipPlace", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_tipPlaceGreen.png", self.baseDirectory), -144.5, 264.5, nil, nil, false, false, false, 0, true);
    self.ingameMap:createMapHotspot("TipPlace", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_tipPlaceGreen.png", self.baseDirectory), -297, -595.5, nil, nil, false, false, false, 0, true);
    
    -- livestock
    self.ingameMap:createMapHotspot("Cows", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_cows.png", self.baseDirectory), 141, -75, nil, nil, false, false, false, 0, true);
    self.ingameMap:createMapHotspot("Sheep", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_sheep.png", self.baseDirectory), 236, 180, nil, nil, false, false, false, 0, true);
    self.ingameMap:createMapHotspot("Chickens", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_chickens.png", self.baseDirectory), 236.5, 118.5, nil, nil, false, false, false, 0, true);
    
    -- spinnery
    self.ingameMap:createMapHotspot("woolDeliveryHotspot", Utils.getFilename("$dataS2/menu/hud/hud_pda_spot_spinnery.png", self.baseDirectory), -63, 45, nil, nil, false, false, false, 0, true);

	trcScreenFlip();
    SampleModMap:superClass().load(self);

	trcScreenFlip();

    if startedRepeat then
        endFrameRepeatMode();
    end
    self:finishLoadingTask();
	if _G["AnimationMapTrigger"] == nil then print("  AnimationMapTrigger - Notice: The mod AnimationMapTrigger is missing from your mods folder, get your copy at http://vertexdezign.net/"); end;
end;

function SampleModMap:onStartMission()
    SampleModMap:superClass().onStartMission(self);
end;

function SampleModMap:mouseEvent(posX, posY, isDown, isUp, button)
    SampleModMap:superClass().mouseEvent(self, posX, posY, isDown, isUp, button);
end;

function SampleModMap:keyEvent(unicode, sym, modifier, isDown)
    SampleModMap:superClass().keyEvent(self, unicode, sym, modifier, isDown);
end;

function SampleModMap:update(dt)
    SampleModMap:superClass().update(self, dt);
end;

function SampleModMap:draw()
    SampleModMap:superClass().draw(self);
end;
