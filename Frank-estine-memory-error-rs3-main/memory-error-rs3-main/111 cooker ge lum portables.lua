print("Run Lua script for leather tanning at the Grand Exchange.")
local API = require("api")
local maxDepositAttempts = math.random(2,3)
local player = API.GetLocalPlayerName() 

local crayfish =13435
local salmon = 331
local trout = 335

local API = require("api")
local bankChestId = {3418} -- Replace with the actual bank chest ID
-- local bankChestId = 24855 -- Replace with the actual bank chest ID
local cookerid = {89768} -- Replace with the actual tanner ID
local cowhideId = 1739 

local function bank()
    print("Going to the bank NPC...")
    repeat 
        API.DoAction_NPC(0x5, 3120, bankChestId, 50)
        
        print("Waiting for player movement to stop...")
        API.RandomSleep2(1500,1200, 2000)
        while API.IsPlayerMoving_(player) do
           
        end
    until API.BankOpen2()  or not API.Read_LoopyLoop()  
 
    if API.BankOpen2()  then
        API.KeyboardPress('3', 500, 1200)

        API.RandomSleep2(1500,1200, 2000)

        if API.BankGetItemStack1(crayfish) > 0 then
            API.BankClickItem(crayfish)  
            print("crayfish")
        elseif API.BankGetItemStack1(trout) > 0 then
            API.BankClickItem(trout)  
            print("trout")
        elseif API.BankGetItemStack1(salmon) > 0 then
            API.BankClickItem(salmon)
            print("salmon") 
        else 
            API.Write_LoopyLoop(false)
            return
        end 
        if not API.Read_LoopyLoop() then return end
        API.RandomSleep2(800, 1200)
    end
end

function cooker()
  -- while API.InvItemcount_1(cowhideId) > 0 do
       -- Go to the tanner
       print("Going to the cooker...")
       API.DoAction_Object_r(0x40,0,cookerid,50, WPOINT.new(0, 0, 0),5)
       API.RandomSleep2(800,1200, 1500) -- Random sleep between 200ms to 500ms

       -- Wait for player movement to stop and dialog to open
       print("Waiting for player movement to stop and dialog to open...")
  
       API.WaitUntilMovingEnds()
       -- Press space to interact with the tanner
       API.KeyboardPress32(32, 0)
       API.RandomSleep2(1500, 1500,1500)

       repeat 
        API.RandomSleep2(1500, 1500, 1800)
        if math.random(0,1500) > 1400 then API.PIdle22() end

        until not API.isProcessing() or not API.Read_LoopyLoop()

       if not API.Read_LoopyLoop() then return end
end



-- Main script
print("Starting the script...")

    -- Loopy loop main script
API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do
    if (API.Math_RandomNumber(1000) > 994) then
         API.PIdle22()
    end

    print("Bank")

    bank()
    API.RandomSleep2(1500, 1500, 1800)
    if not API.Read_LoopyLoop() then return end
  
    if API.Invfreecount_() == 28 then API.Write_LoopyLoop(false) return  end
    cooker()
    API.RandomSleep2(1500, 1800)
end

print("Script completed. Exiting...")
