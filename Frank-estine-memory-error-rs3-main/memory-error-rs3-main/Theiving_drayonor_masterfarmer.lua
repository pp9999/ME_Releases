--[[
# Script Name:  <Theiving_drayonor_masterfarmer.lua>
# Description:  {tHEIVING dRAYNOR}>
# Version:      <2>
# Datum:        <2025.02.11>
# Author:       <Frank-key>

------------------------------------------------------------
-- Module Imports and Global Variables
------------------------------------------------------------
local API = require("api")
local ID = {
    STUNNED_ANIMATION = 424,
    NPCS = {2234}  -- Pickpocket target NPC ID
}
local localPlayer = API.GetLocalPlayerName()

------------------------------------------------------------
-- Function: attemptPickpocket
-- Description: Performs the pickpocket action on the target NPC.
------------------------------------------------------------
local function attemptPickpocket()
    -- Use the NPC ID from our table (2234)
    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route2, {ID.NPCS[1]}, 50)
    API.RandomSleep2(1000, 500, 1000)
end

------------------------------------------------------------
-- Function: checkHP
-- Description: Checks the player's HP percentage; if below 50%, 
--              repeatedly uses a healing action until HP reaches 100% 
--              or the script stops.
------------------------------------------------------------
local function checkHP()
    local hppercent = (API.GetHP_() / API.GetHPMax_()) * 100
    if hppercent < 50 then
        repeat
            print("HP Percent: " .. hppercent)
            -- Use a healing action on one of the provided object IDs
            API.DoAction_Object1(0x5, API.OFF_ACT_GeneralObject_route1, {2012, 2015, 2019}, 50)
            API.WaitUntilMovingandAnimEnds(5, 5)
            API.RandomSleep2(1000, 500, 1000)
            if API.BankOpen2() then
                API.BankAllItems()
            end
            hppercent = (API.GetHP_() / API.GetHPMax_()) * 100
        until hppercent == 100 or not API.Read_LoopyLoop()
    end
end

------------------------------------------------------------
-- Main Loop
-- Description: Repeatedly attempts pickpocketing and checks HP.
------------------------------------------------------------
while API.Read_LoopyLoop() do
    attemptPickpocket()
    checkHP()
    API.WaitUntilMovingandAnimEnds(2, 2)
end
