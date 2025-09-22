local API = require("api")
local APIS = require("apis")
player = API.GetLocalPlayerName()


local bankChestId = {3418} -- Replace with the actual bank chest ID

function bank()
    -- Go to the bank NPC


    print("Going to the bank NPC...")

    
    repeat
        API.DoAction_NPC(0x5,3120,bankChestId,50)
   
        API.RandomSleep2(1000, 1500) -- Random sleep between 1 to 3 seconds
  
    until API.BankOpen2() 
    --- local hideleft = API.BankGetItemStack1(cowhideId)
    --- print(hideleft)
      
  
    if not API.Read_LoopyLoop() then return end
    -- Press key 2 to open the tan leather option

 
    print("close bank")
        
    API.KeyboardPress('1', 1250, 500)

    if API.Invfreecount_()==28 then
        API.Write_LoopyLoop(false)
         return 
    end
 

end

local freecount = 0
local freecount1 = 0

API.Write_LoopyLoop(true)
while(API.Read_LoopyLoop()) do
    while(API.Read_LoopyLoop()) do
        if API.Invfreecount_() == 0 then
            bank()
        else
            freecount = API.Invfreecount_()
             API.DoAction_Interface(0x31,0xaf10,1,1473,5,0,5392)
            API.RandomSleep2(250, 500,250) 
            freecount1 = API.Invfreecount_()
            if freecount == freecount1 then break end
        end
    end



   
   until API.InvFull_() or not API.Read_LoopyLoop() or not API.PlayerLoggedIn()

   

end
