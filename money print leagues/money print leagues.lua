local API = require("api")



local function isOpen()
    return API.Compare2874Status(40, false) or API.Compare2874Status(18, false)
end


local function buycrystal()
    Interact:NPC("Sawmill operator", "Trade",30)
    API.RandomSleep2(1200, 550, 650)
    if isOpen() then
        API.DoAction_Interface(0xffffffff,0xffffffff,7,1265,20,8,API.OFF_ACT_GeneralInterface_route2)
        API.RandomSleep2(400, 550, 650)
    end
    API.DoAction_Interface(0x24,0xffffffff,1,1265,217,-1,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(400, 550, 650)
end


local function disassemble()
    if Inventory:GetItemAmount(8788) == 28  and not API.isProcessing() then
        API.DoAction_Ability("Disassemble", 1, API.OFF_ACT_Bladed_interface_route, false)
        API.RandomSleep2(400, 300, 200)
        API.DoAction_Inventory1(8788,0,0,API.OFF_ACT_GeneralInterface_route1)
        API.RandomSleep2(600, 300, 200)
        API.DoAction_Interface(0xffffffff,0xffffffff,0,847,22,-1,API.OFF_ACT_GeneralInterface_Choose_option)
        API.RandomSleep2(1000, 300, 200)
    end
end


API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do

    if  Inventory:GetItemAmount(8788) < 28 and not API.isProcessing() then
        buycrystal()
        API.RandomSleep2(1000, 300, 200)
        
    else 
        disassemble()
        API.RandomSleep2(1000, 300, 200)
    end
end