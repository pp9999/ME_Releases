local API = require("api")
local Boneid = 532
local Bonesinbank = true
local currentTime = os.time()
MAX_IDLE_TIME_MINUTES = 8
afk = os.time()

-- Bone IDS = Big bones is 532, dragon = 536 , wyvern = 6812, baby dragon = 534, dagganoth = 6729 , infernal ashes = 20268

local function checkbank()
    items = API.FetchBankArray()
    for k, v in pairs(items) do
        if v.itemid1 == Boneid then
            print("Found: " .. v.itemid1_size .. " Bones.")
            if (v.itemid1_size > 0) then
                Bonesinbank = true
                return
            else
                print("out of Bones..")
                Bonesinbank = false
                DoAction_Interface(0x24, 0xffffffff, 1, 517, 119, 1, 3808);
                API.Write_LoopyLoop(false)
            end
        else
            Bonesinbank = false
        end
    end
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function bank()
    API.DoAction_NPC(0x5, 1776, { 1786 }, 50); -- Interact with chest
    API.RandomSleep2(1200, 200, 600)           -- waits a secound so your charcter auctly starts moving
    API.WaitUntilMovingEnds()                  -- waits until ur done moving
    API.RandomSleep2(700, 200, 600)
    checkbank()
    if (Bonesinbank) then
        API.DoAction_Interface(0x24, 0xffffffff, 1, 517, 119, 1, 3808); -- Getting preset
        API.RandomSleep2(700, 200, 600)
        API.DoAction_Object1(0x29, 80, { 122374 }, 50);
        print("Going to the Chaos Altar.")
        API.RandomSleep2(1200, 600, 600)
        API.WaitUntilMovingEnds()
    end
end

local function invCheck()
    if API.InvItemcount_1(Boneid) == 0 then
        print("No bones, banking.")
        bank()
    end
end

local function offer()
    if API.InvItemcount_1(Boneid) > 0 and not API.CheckAnim(100) then
        API.DoAction_Object1(0x29, 80, { 122374 }, 50);
        API.RandomSleep2(1200, 600, 600)
        API.WaitUntilMovingEnds()
        print("Offering...")
        API.RandomSleep2(1200, 600, 600)
    end
end

while API.Read_LoopyLoop() do
    idleCheck()
    invCheck()
    offer()
end
