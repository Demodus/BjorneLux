-- by "Marhu" 
-- v 1.0
-- Date: 10.05.2013
--"Register Fill Types only for loaded Map"

RegFillTypes = {};
RegFillTypes.dir = g_currentModDirectory
RegFillTypes.t = {};

--[[Fillable.registerFillType "fill"
--  name						name			string
--  nameI18N					I18N			string --in modDesc.xml der Map eingeben <l10n>
--  pricePerLiter,				price			float
--  partOfEconomy				Eco				bool
--  hudOverlayFilename			hud				string
]]

local HudDir = "map/models/buildings/SchweineMast/"		--"map/Hud/"

table.insert(RegFillTypes.t, { name="pig", price=0.1, Eco=true, hud=HudDir.."pigHUD"});
--table.insert(RegFillTypes.t, { name="cow", price=0.5, Eco=true, hud=HudDir.."cowHUD"});
--table.insert(RegFillTypes.t, { name="sheep", price=0.05, Eco=true, hud=HudDir.."sheepHUD"});
--table.insert(RegFillTypes.t, { name="chicken", price=0.01, Eco=true, hud=HudDir.."chickenHUD"});
--table.insert(RegFillTypes.t, { name="flour", price=0.5, Eco=true, hud=HudDir.."flourHUD"});
--table.insert(RegFillTypes.t, { name="meat", price=0.5, Eco=true, hud=HudDir.."meatHUD"});
table.insert(RegFillTypes.t, { name="beef", price=0.1, Eco=true, hud=HudDir.."beefHUD"});

local org_FSBaseMission_loadMap = FSBaseMission.loadMap
FSBaseMission.loadMap = function(a, b, c, d, e)
	if a.baseDirectory == RegFillTypes.dir then
		RegFillTypes.MapName = a.missionInfo.map.title;
		local fill={}
		for i=1, table.getn(RegFillTypes.t) do
			local t = RegFillTypes.t[i];
			local HudFile = RegFillTypes.dir..t.hud..".dds";
			local I18N = t.I18N
			if I18N == nil then
				if g_i18n:hasText(t.name) then
					I18N = g_i18n:getText(t.name);
				else
					I18N = t.name;
				end;
			end;
			local FillType = Fillable.registerFillType(t.name,I18N,t.price,t.Eco,HudFile);
			if Fillable.fillTypeIndexToDesc[FillType] and Fillable.fillTypeIndexToDesc[FillType].nameI18N then
				FSBaseMission.addFillTypeOverlay(a,FillType,HudFile)
				--print("  Register fill type: ",Fillable.fillTypeIndexToDesc[FillType].nameI18N);
				table.insert(fill,Fillable.fillTypeIndexToDesc[FillType].nameI18N);
			else
				--print("  Register fill type: ",t.name," not nameI18N");
				table.insert(fill,t.name.." not nameI18N");
			end;
		end;

		local types = RegFillTypes.MapName..": Register Fill type: ";
		for k, v in pairs(fill) do
			types = types..v..", ";
		end;
		print(types)
	end;		
	ra,rb,rc,rd,re = org_FSBaseMission_loadMap(a, b, c, d, e)
	return ra,rb,rc,rd,re 
end





