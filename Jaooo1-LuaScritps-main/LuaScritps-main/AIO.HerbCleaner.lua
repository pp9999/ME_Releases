--- Start at Fort Bank ---
--- Have Grimy herb on inv ---
--- Version 1.0 ---
local API = require("api")
local afk = os.time()
API.SetDrawTrackedSkills(true)
MAX_IDLE_TIME_MINUTES = 10
API.Write_fake_mouse_do(false)



local grimy_ids = {
    37975, -- GRIMY_BLOODWEED
    21626, -- GRIMY_FELLSTALK
    3049,  -- GRIMY_TOADFLAX
    2485,  -- GRIMY_LANTADYME
    3051,  -- GRIMY_SNAPDRAGON
    12174, -- GRIMY_SPIRIT_WEED
    14836, -- GRIMY_WERGALI
    199,   -- GRIMY_GUAM
    201,   -- GRIMY_MARRENTILL
    203,   -- GRIMY_TARROMIN
    205,   -- GRIMY_HARRALANDER
    207,   -- GRIMY_RANARR
    209,   -- GRIMY_IRIT
    211,   -- GRIMY_AVANTOE
    213,   -- GRIMY_KWUARM
    215,   -- GRIMY_CADANTINE
    217,   -- GRIMY_DWARF_WEED
    219    -- GRIMY_TORSTOL
   
}

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((5 * 60) * 0.6, (5 * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function hasGrimyHerbs()
    return Inventory:ContainsAny(grimy_ids)
end

local function cleanHerbs()
    for _, herb_id in ipairs(grimy_ids) do
        if Inventory:ContainsAny({herb_id}) then
            print("Has grimy Herbs!")
            API.DoAction_Inventory1(herb_id, 0, 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(1200, 300, 500)
            API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1370, 30, -1, API.OFF_ACT_GeneralInterface_Choose_option)
            API.RandomSleep2(1200, 300, 500)
            break
        end
    end
end

local function bankHerbs()
    API.DoAction_Object1(0x33,API.OFF_ACT_GeneralObject_route3,{ 125115 },50)
    API.RandomSleep2(1200, 300, 500)
end




API.Write_LoopyLoop(true)
while (API.Read_LoopyLoop()) do
    API.DoRandomEvents()
    idleCheck()
    if API.isProcessing() then
        API.RandomSleep2(200, 50, 150)
    elseif not hasGrimyHerbs() then
        print("No Herbs found (Banking!)")
        bankHerbs()
            if not hasGrimyHerbs() then 
                print("Out of Herbs (Exiting!)")
                break
            end
    else
        cleanHerbs()
    end
    API.RandomSleep2(500, 100, 300)
end
