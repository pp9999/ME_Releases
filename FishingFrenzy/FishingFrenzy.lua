local API = require('api')

local MAX_IDLE_TIME_MINUTES = 10
local afk = os.time()
local lastXp = 0
local lastTimeGainedXp = os.time()

local function findSpot()
    local fish = API.GetAllObjArrayInteract_str({"Fish"}, 25, {1})
    return fish[1] or false
end

local fishingSpotId = 0;

local function fish()
    local spot = findSpot()
    if spot and spot.Id ~= fishingSpotId then
        if API.DoAction_NPC_str(0x3c, API.OFF_ACT_InteractNPC_route, { "Fish" }, 50)then
            fishingSpotId = spot.Id
            print("Fishing at:" .. fishingSpotId)
            API.RandomSleep2(600, 200, 100)
        end
    end
    if not API.CheckAnim(50) then
        fishingSpotId = 0
    end
end

local function checkGameState()
local gs = API.GetGameState2();
    if gs == 1 or gs == 2 then
        print("player not logged in");
        API.Write_LoopyLoop(false)
    end
end

local function xpCheckFailSafe(skill, time)
  local currentXp = API.GetSkillXP(skill)
  if currentXp > lastXp then
      lastXp = currentXp
      lastTimeGainedXp = os.time()
  end
  if (os.time() - lastTimeGainedXp) > time then
    print("No exp gained in the last ".. tostring(time) .. " seconds")
    --UTILS.sendNotification("No exp gained in the last ".. tostring(time) .. " seconds")
    return true
  end
  return false
end

local function logout()
    if not API.LocalPlayer_IsInCombat_() then
        API.DoAction_Logout_mini()
        API.RandomSleep2(5000,1000,2000)
        API.Compare2874Status(1, true)
        if API.DoAction_then_lobby() then
        API.RandomSleep2(5000,1000,2000)
        API.Write_LoopyLoop(false)
        print("logged out!")
        end
    end
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)
    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
        return true
    end
    return false
end

local function useTorstolSticks()
    local id = 47715;
    local cd = API.Buffbar_GetIDstatus(id, false)
    if API.InventoryInterfaceCheckvarbit() and cd.found and cd.conv_text < 10 and API.InvItemFound2({id}) then
        print("using torstol sticks")
        API.DoAction_Inventory2({id}, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1200, 200, 100)
    end
end

while API.Read_LoopyLoop() do
    if xpCheckFailSafe("FISHING", 30) then
        logout()
    end
    API.DoRandomEvents()
    checkGameState()
    idleCheck()
    useTorstolSticks()
    fish()
    API.RandomSleep2(100, 100, 100)
end