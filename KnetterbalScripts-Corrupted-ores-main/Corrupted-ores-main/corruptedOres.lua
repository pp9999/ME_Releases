local API = require("API")

local MAX_IDLE_TIME_MINUTES = 5

API.SetDrawTrackedSkills(true)

local ore = 32262
local hasMats = nil
local selectedSmelt = false


local function isInterfaceOpen()
    return API.Compare2874Status(85)
end

local function isBusy()
    return API.CheckAnim(20) or API.isProcessing()
end

local function canCraft()
    if Inventory:Contains(ore) then
        hasMats = true
    else
        hasMats = false
        API.Write_LoopyLoop(false)
    end
end


local function selectCorrupt()
    if not selectedSmelt then 
        API.DoAction_Interface(0xffffffff,0x7e06,1,37,125,19,API.OFF_ACT_GeneralInterface_route)
       API.Sleep_tick(2)
        selectedSmelt = true
    end
end

local function startSmelting()
    if isInterfaceOpen() then
        selectCorrupt()
        API.KeyboardPress2(0x20, 100, 50)
        API.Sleep_tick(1)
    end
    if hasMats and not isBusy() then
        Interact:Object("Furnace", "Smelt")
        API.Sleep_tick(1)
        
    end
end

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)
    canCraft()
    startSmelting()
end

