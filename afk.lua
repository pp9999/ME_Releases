local API = require("api")
print("Run Lua script afker.")


while API.Read_LoopyLoop() do

    API.DoRandomEvents()


    --API.KeyboardPress2(0x51, 40, 60) --Q
    --API.KeyboardPress2(0x57, 40, 60) --W
    --print(API.IsCacheLoaded())
    --Inventory:InvItemcount({999})
    print(#Inventory:ReadInvArrays33(true))
    if API.Check_continue_Open() then
        API.KeyboardPress31(0x20, 40, 100)
    end
  
API.RandomSleep2(5600, 10300, 300)
end