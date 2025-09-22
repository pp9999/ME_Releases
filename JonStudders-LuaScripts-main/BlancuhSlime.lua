local API = require("api")
local BANK = require("bank")

local step = 0

while (API.Read_LoopyLoop()) do
  if step == 0 then
    -- Use ectophial
    local AB = API.GetABs_name("Ectophial", true)
    if AB.enabled then
      API.DoAction_Ability_Direct(AB, 1, API.OFF_ACT_GeneralInterface_route)
      API.RandomSleep2(6400, 6300, 6800)
    end
    step = 1
  end

  if step == 1 then
    -- Check in area
    local pCoord = API.PlayerCoordfloat()
    local doorCoord = API.CreateFFPOINT(3654, 3519, 0)
    local distance = API.Math_DistanceF(pCoord, doorCoord)
    if (distance > 10) then
      print ("Not In tower.")
      API.RandomSleep2(400, 300, 800)
    end
    if (distance > 1 and distance < 10) then 
      print ("Walking to door")
      API.DoAction_WalkerF(doorCoord)
      API.DoAction_Object1(0x35,API.OFF_ACT_GeneralObject_route0,{ ids },50)
      API.WaitUntilMovingEnds()
    end
    if (distance < 1) then
      print ("At Door")
      step = 2
    end
  end

  if step == 2 then
    -- if 5268 doesnt exist interact with 5267
    local trapdoorBool = API.DoAction_Object1(0x35, API.OFF_ACT_GeneralObject_route0, { 5268 }, 50)
    print (trapdoorBool)
    if (trapdoorBool == false) then
      API.DoAction_Object1(0x35, API.OFF_ACT_GeneralObject_route0, { 5267 }, 50)
      API.RandomSleep2(1400, 1300, 1800)
    end
    
    if (trapdoorBool == true) then
      API.RandomSleep2(1400, 1300, 1800)
      step = 3
    end
  end

  if step == 3 then
    -- 9308
    local wall1Bool = API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { 9308 }, 50)
    if (wall1Bool == false) then
      API.RandomSleep2(1400, 1300, 1800)
    end
    if (wall1Bool == true) then
      API.RandomSleep2(1400, 1300, 1800)
      step = 4
    end
  end

  if step == 4 then
    -- 5263
    local stair1Bool = API.DoAction_Object1(0x35, API.OFF_ACT_GeneralObject_route0, { 5263 }, 50)
    if (stair1Bool == false) then
      API.RandomSleep2(1400, 1300, 1800)
    end
    if (stair1Bool == true) then
      API.RandomSleep2(1400, 1300, 1800)
      API.WaitUntilMovingEnds()
      step = 5
    end
  end

  if step == 5 then
    -- 5263
    print ("Hit S2")
    local stair2Bool = API.DoAction_Object1(0x35, API.OFF_ACT_GeneralObject_route0, { 5263 }, 50)
    if (stair2Bool == false) then
      API.RandomSleep2(1400, 1300, 1800)
    end
    if (stair2Bool == true) then
      API.RandomSleep2(1400, 1300, 1800)
      API.WaitUntilMovingEnds()
      step = 6
    end
  end

  if step == 6 then
    local slimeBool = API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { 17119 }, 50)
    if (slimeBool == true) then
      step = 7
    end
  end

  if step == 7 then
    if (Inventory:IsFull()) then
      API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
      API.RandomSleep2(1400, 1300, 1800)
      API.WaitUntilMovingEnds()
      step = 8
    end
    API.RandomSleep2(1400, 1300, 1800)
  end

  if step == 8 then
    -- 114750
    local chestBool = API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, {114750}, 50)
    if (chestBool == true) then
      API.RandomSleep2(1400, 1300, 1800)
      API.WaitUntilMovingEnds()
      step = 9
    end
    API.RandomSleep2(400, 300, 800)
  end

  if step == 9 then
    BANK:Deposit(4286)
    API.RandomSleep2(400, 300, 800)
    step = 10
  end

  if step == 10 then
    if (BANK:IsOpen()) then
      API.DoAction_Interface(0x24,0xffffffff,1,517,318,-1,API.OFF_ACT_GeneralInterface_route)
    end
    if (not BANK:IsOpen()) then
      print ("closed")
      step = 0
    end
    API.RandomSleep2(400, 300, 800)
  end

end

