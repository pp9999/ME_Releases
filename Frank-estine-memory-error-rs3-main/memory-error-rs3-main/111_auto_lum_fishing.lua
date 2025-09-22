--- script Made by Frank_estine
--- updated - 02-09-2023

--- latest changelog = Autonomous fishing - just start at lumby bank with preset 1 with feathers in it. and rest is chill , 0-60 easy.

local API = require("api")
print("start near lum bank...")
-- Get the local player's name
local player = API.GetLocalPlayerName()

---xps
print("Current lvl " .. API.XPLevelTable(API.GetSkillXP("FISHING")))


-- Define the spots IDs
local crayfish = {6267}
local highfish = {329}

-- Define the highfish inventory IDs
local trout = {335}
local salmon = {331}

--bank
local banknpc = {553,2759}
local banklum = {79036}

--boolean
local fish_bool = 0



API.Write_ScripCuRunning1(player)
API.Write_ScripCuRunning2("fishing f2p")


-- Assign the fish ID based on the user's selection
local fishid
local level = API.XPLevelTable(API.GetSkillXP("FISHING"))
if level > 20 then
        fishid = highfish
        fish_bool = 1
        print("fishing high lvls now")
    else
        fishid = crayfish
        fish_bool = 0
        print("fishing low lvls now")
end


local function check()
    ---depositItems()
    if API.IsPlayerAnimating_(player,1) then
        print("idle check")
        repeat
            if math.random(0,1000) > 994 then
                API.PIdle22()
            end
                if not API.Read_LoopyLoop() then print("break") break end
            API.RandomSleep2(1500,2500, 2500) -- Adjust sleep time as needed
            
            API.DoRandomEvents()
       until not API.CheckAnim(50) or API.InvFull_() or not API.Read_LoopyLoop()
       print("over check")
    end
end

-- Define the fish function
local function fish()
    local player = API.GetLocalPlayerName()
    --check change level for fishing
    if not API.IsPlayerAnimating_(player,1) then
            level = API.XPLevelTable(API.GetSkillXP("FISHING"))
            if level > 20 then
                fishid = highfish
                fish_bool = 1
                print("fishing high lvls now")
            else
                fishid = crayfish
                fish_bool = 0
                print("fishing low lvls now")
            end

            --check change area for fishing
            if fish_bool==0 then
                    local x = 3254 + math.random(-2, 2)
                    local y = 3206 + math.random(-2, 2)
                    local z = 0        
                if not API.PInArea(x,10,y,10,0) then
                    print("go to fishing spot crayfish....")
                    API.DoAction_WalkerW(WPOINT.new(x, y, z))
                end
            else
                local x = 3239 + math.random(-2, 2)
                local y = 3252 + math.random(-2, 2)
                local z = 0
                if not API.PInArea(x,30,y,30,0) then
                    print("go to fishing spot trout....")
                    API.DoAction_WalkerW(WPOINT.new(x, y, z))
                end
            end

    

    
            API.DoAction_NPC(0x3c,3120,fishid,50)
            print("Fishing...")
            API.RandomSleep2(2500, 3050, 2500)
            API.WaitUntilMovingEnds()
    end
    check()
    local skillxpstart = API.GetSkillXP("FISHING")
end


local function bank1()
    print("banking now... full inv....")

    -- bank tile
    local x = 3214 + math.random(-2, 2)
    local y = 3257 + math.random(-2, 2)
    local z = 0

    API.DoAction_WalkerW(WPOINT.new(x, y, z))

 print ("finish walk to bank")
 check()
    repeat
        if not API.Read_LoopyLoop() then break end  -- Add this line
        print("opening bank....")
        API.DoAction_Object_r(0xb5,0,banklum,50,FFPOINT.new(0, 0, 0),50)
        API.RandomSleep2(1500, 3050, 12000)
        if not API.Read_LoopyLoop() then break end  -- Add this line

    until API.BankOpen2() or not API.Read_LoopyLoop() -- Added loop protection
    check()

    if  API.BankOpen2() then
        API.RandomSleep2(1000, 2000)
        API.DoAction_Interface(0x24,0xffffffff,1,517,119,1,5392) --- preset 1
        API.RandomSleep2(1000, 2000)
    end

    check()
end





--main loop
API.Write_LoopyLoop(true)
while(API.Read_LoopyLoop()) do
    if API.PlayerLoggedIn() then
        if API.IsPlayerAnimating_(player,1) then
            API.RandomSleep2(1500, 1800, 1200)
        else
            if not API.IsPlayerAnimating_(player,3) then
                if API.Invfreecount_() == 0 then
                    print("Dropping fish")
                    if API.Check_continue_Open() then
                        API.KeyboardPress31(32, 500, 1200)
                        print("Close dialogue...")
                    end

                    repeat
                    if not API.Read_LoopyLoop() then break end  -- Add this line

                    bank1()
                    
                    until API.Invfreecount_() >= math.random(20, 25) or not API.Read_LoopyLoop() -- Added loop protection
                else
                    fish()
                end
            end
        end
    else
        API.DoAction_Interface(0xffffffff,0xffffffff,1,906,76,-1,5392) --login
        API.RandomSleep2(1500, 1800, 1200)
    end
end
