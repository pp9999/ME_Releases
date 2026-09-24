local API = require("api")
API.SetMaxIdleTime(5)

local prenewal = {
  33186, 33184, 33182, 33180, 33178, 33176, 23609, 23611, 23613, 23615, 23617, 23619,
  21630, 21632, 21634, 21636, 33222, 33220, 33218, 33216, 33214, 33212,
  33198, 33196, 33194, 33192, 33190, 33188, 49052, 49050, 49048, 49046, 49044, 49042
}
local prestore = {
  23399, 23401, 23403, 23405, 23407, 23409,
  3024, 3026, 3028, 3030, 2434, 139, 141, 143,
  48976, 48978, 48980, 48982, 48650, 48652, 48654, 48656, 48658, 48660
}
local ritualShard = 43358 -- Elven Ritual Shard

local function getBuff(buffId)
  local buff = API.Buffbar_GetIDstatus(buffId, false)
  return {
    found = buff.found,
    remaining = (buff.found and API.Bbar_ConvToSeconds(buff)) or 0
  }
end

local function hasBuff(buffId)
  local buff = API.Buffbar_GetIDstatus(buffId, false)
  return buff.found
end

local function isAuraActive()
  -- 26098 = Penance aura effect buff ID
  return hasBuff(26098)
end

local function extraActionButtonVisible()
  return API.VB_FindPSettinOrder(10254).state == 3
end

local function doExtraActionButton()
  if extraActionButtonVisible() then
    API.DoAction_Interface(0x2e, 0xffffffff, 1, 743, 1, -1, API.OFF_ACT_GeneralInterface_route)
	print("Clicking extra action button")
    API.RandomSleep2(1000, 300, 300)
  end
end

local function useRitualShard()
  API.DoAction_Inventory1(ritualShard, 0, 1, API.OFF_ACT_GeneralInterface_route)
  print("Ritual Shard time!")
  API.RandomSleep2(600, 300, 300)
end

local function readRitualShard()
  local buffs = API.DeBuffbar_GetIDstatus(43358)
  if buffs.conv_text < 1 then
    useRitualShard()
    return true
  end
  return false
end

local function useExcali()
  API.RandomSleep2(4000, 1000, 1000)
  API.DoAction_Inventory1(36619, 0, 1, API.OFF_ACT_GeneralInterface_route)
  print("Excalibur time!")
  API.RandomSleep2(4000, 1000, 1000)
end

local function readExcalibur()
  local buffs = API.DeBuffbar_GetIDstatus(14632)
  if buffs.conv_text < 1 then
    useExcali()
    return true
  end
  return false
end

while API.Read_LoopyLoop() do
  local darkness = getBuff(30122)
  local prayren = getBuff(14695)
  local prayer = API.GetPrayPrecent()
  local hp = API.GetHP_()
  
  -- Renewal logic, skip if Penance aura is active
  if not isAuraActive() then
    if not prayren.found or (prayren.found and prayren.remaining <= math.random(2, 45)) then
      if API.DoAction_Inventory2(prenewal, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        API.RandomSleep2(600, 200, 200)
      end
    end
  end

  -- Prayer restoration logic
 if prayer < math.random(50, 70) then
    readRitualShard()
  end

 -- Emergency prayer
  if prayer < math.random(20, 40) then
    if API.DoAction_Inventory2(prestore, 0, 1, API.OFF_ACT_GeneralInterface_route) then
      API.RandomSleep2(300, 200, 200)
    end
  end

  -- Darkness ability
  if API.LocalPlayer_IsInCombat_() then
    API.RandomSleep2(600, 200, 400)
else
  if not darkness.found or (darkness.found and darkness.remaining <= math.random(15, 75)) then
    if API.DoAction_Ability("Darkness", 1, API.OFF_ACT_GeneralInterface_route, false) then
      API.RandomSleep2(2400, 1800, 2000)
    end
  end
end
  -- Excalibur healing
  if hp < math.random(4250, 6500) then
    readExcalibur()
  end

  -- Emergency food
  if hp < math.random(2500, 4000) then
    if API.DoAction_Ability("Eat food", 1, API.OFF_ACT_GeneralInterface_route, false) then
      API.RandomSleep2(300, 200, 200)
    end
  end

  -- Stop loop if too low prayer
  if prayer < math.random(5, 15) then
    API.Write_LoopyLoop(false)
  end

  doExtraActionButton()
end
