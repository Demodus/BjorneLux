-- für Guelle-Mist-Mod von TMT
FruitUtil.registerFruitType("manureSolid", "manureSolid", false, false, true, 1, 100, 2, 1, 1, nil);
FruitUtil.registerFruitType("manureLiquid", "manureLiquid", false, false, true, 1, 100, 2, 1, 1, nil);
FruitUtil.registerFruitType("kalkSolid", "kalkSolid", false, false, true, 1, 100, 2, 1, 1, nil);
FruitUtil.registerFruitTypeWindrow(FruitUtil.FRUITTYPE_MANURESOLID, "manureSolid_windrow", g_i18n:getText("manure"), 0, 3, false, nil );
FruitUtil.registerFruitTypeWindrow(FruitUtil.FRUITTYPE_MANURELIQUID, "manureLiquid_windrow", g_i18n:getText("liquidManure"), 0, 3, false, nil );
FruitUtil.registerFruitTypeWindrow(FruitUtil.FRUITTYPE_KALKSOLID, "kalkSolid_windrow", g_i18n:getText("kalkSolid"), 0, 3, false, nil);
Sprayer.registerSprayType("kalk", g_i18n:getText("kalkSolid"), 0.3, 10, true, nil);


