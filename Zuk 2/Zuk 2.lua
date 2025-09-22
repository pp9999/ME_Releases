local API = require("api")
local UTILS = require("utils")

-- Cooldown table to store the last trigger time for each condition
local cooldowns = {
    Quake = 0,
    Empower = 0,
    GeothermalBurn = 0,
    Sear = 0,
    PrayerPotion = 0,
    EatFood = 0
}

-- Cooldown durations in milliseconds
local cooldownDurations = {
    Quake = 2000, -- 2 seconds
    Empower = 2000, -- 2 seconds
    GeothermalBurn = 2000, -- 2 seconds
    Sear = 5000, -- 5 seconds
    PrayerPotion = 2000, -- 2 seconds
    EatFood = 1800 -- 2 seconds
}

-- Main loop
while API.Read_LoopyLoop() do
    local currentTime = os.clock() * 1000 -- Current time in milliseconds

    zuk = API.FindNPCbyName("TzKal-Zuk", 50)

    if zuk.Anim == 34496 and (currentTime - cooldowns.Quake) >= cooldownDurations.Quake then
        print("Quake")
        UTILS.rangeSleep(200, 0, 200)
        UTILS.surge()
        UTILS.countTicks(1)
        cooldowns.Quake = currentTime
    elseif zuk.Anim == 34499 and (currentTime - cooldowns.Empower) >= cooldownDurations.Empower then
        print("Empower")
        API.DoAction_Ability('Resonance', 1, API.OFF_ACT_GeneralInterface_route)
        UTILS.countTicks(1)
        cooldowns.Empower = currentTime
    elseif API.DeBuffbar_GetIDstatus(30096, false).id == 30096 and API.GetABs_name1("Freedom").cooldown_timer == 0 and (currentTime - cooldowns.GeothermalBurn) >= cooldownDurations.GeothermalBurn then
        print("Geothermal Burn")
        API.DoAction_Ability("Freedom", 1, API.OFF_ACT_GeneralInterface_route)
        cooldowns.GeothermalBurn = currentTime
    elseif API.DeBuffbar_GetIDstatus(30721, false).id == 30721 and (currentTime - cooldowns.Sear) >= cooldownDurations.Sear then
        print("Sear")
        local tile = API.PlayerCoord()
        UTILS.surge()
        UTILS.rangeSleep(200, 0, 100)
        API.DoAction_Tile(WPOINT.new(tile.x, tile.y, tile.z))
        UTILS.countTicks(1)
        API.DoAction_Ability('Super restore potion', 1, API.OFF_ACT_GeneralInterface_route)
        cooldowns.Sear = currentTime
    elseif API.GetPrayPrecent() <= 50 and (currentTime - cooldowns.PrayerPotion) >= cooldownDurations.PrayerPotion then
        print('Using Prayer Potion')
        API.DoAction_Ability("Super prayer renewal potion", 1, API.OFF_ACT_GeneralInterface_route)
        cooldowns.PrayerPotion = currentTime
    elseif API.GetHPrecent() <= 60 and (currentTime - cooldowns.EatFood) >= cooldownDurations.EatFood then
        print("Eat food")
        API.DoAction_Ability("Blue blubber jellyfish", 1, API.OFF_ACT_GeneralInterface_route)
        API.DoAction_Ability("Sailfish", 1, API.OFF_ACT_GeneralInterface_route)
        API.DoAction_Ability("Saradomin brew", 1, API.OFF_ACT_GeneralInterface_route)
        cooldowns.EatFood = currentTime
    end
end