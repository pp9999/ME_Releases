---- Beehive run Script -----

---- Just a simple script, for early farming ----

----(1st script, so any suggestions are welcome!!) ----

---- Requirements: Ardy teleport bound to "p" (replaceable) and woad leaves (or anything to feed the hives) ----

local API = require("api")
local MAX_IDLE_TIME_MINUTES = 5
local afk = os.time()
API.SetDrawTrackedSkills(true)
math.randomseed(os.time())

local AREA = {
    ARDOUGNE_LODESTONE = { x = 2634, y = 3348, z = 0 }
}

local BEEHIVES = {
    112273, -- beehive1
    112271, -- beehive2
    112272, -- beehive3
    112269, -- beehive4
    112275, -- beehive5
    112270, -- beehive6
    112274  -- beehive7
}

local function isAtLocation(location, distance)
    local distance = distance or 20
    return API.PInArea(location.x, distance, location.y, distance, location.z)
end

local function teleport()
    print("Starting teleport to Ardougne Lodestone...")
    API.KeyboardPress('p', 200, 600)
    API.RandomSleep2(7000, 1000)

    local startTime = os.time()
    while not isAtLocation(AREA.ARDOUGNE_LODESTONE, 5) do
        if os.difftime(os.time(), startTime) > 20 then
            print("Teleport failed! Trying again...")
            return teleport()
        end
        API.RandomSleep2(2000, 500)
    end
    print("Teleport completed!")
end

local function GotoBeeHive()
    if isAtLocation(AREA.ARDOUGNE_LODESTONE, 20) then
        print("Walking to the beehives...")
        API.DoAction_Tile(WPOINT.new(2683 + math.random(-1, 1), 3347 + math.random(-1, 1), 0))
        API.RandomSleep2(20000, 1000)
    else
        print("We are not in the correct area yet!")
    end
end

local function ColectFromBeehive(beehive)
    print("Collecting honey from beehive ID:", beehive)

    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route1, { beehive }, 50)
    API.RandomSleep2(17500, 500)

    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { beehive }, 50)
    API.RandomSleep2(1000, 300)
    API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1370, 30, -1, API.OFF_ACT_GeneralInterface_Choose_option)
    API.RandomSleep2(17500, 500)
end

local function ColectHoney()
    for _, beehive in ipairs(BEEHIVES) do
        ColectFromBeehive(beehive)
    end
    print("Honey collection completed!")
end

API.Write_LoopyLoop(true)
while (API.Read_LoopyLoop()) do
    
    if isAtLocation(AREA.ARDOUGNE_LODESTONE, 20) then 
        print("Already near Ardougne Lodestone, skipping teleport.")
    else
        teleport()
    end
    GotoBeeHive()
    ColectHoney()
    API.Write_LoopyLoop(false)
    print("Script completed successfully.")
end