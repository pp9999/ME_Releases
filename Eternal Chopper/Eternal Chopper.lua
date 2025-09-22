local API = require("api")
local startTime, afk = os.time(), os.time()

-- Replace this with the correct capacity of your wood box
local maxCapacity = 280

-- The item ID of the logs you're tracking
local logItemId = 58250
-- The container ID for the wood box
local woodBoxContainerId = 58253
-- The object ID of the wood box
local woodBoxObjectId = 58253

API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(15)

-- Retrieves the amount of a given itemId in the wood box
function getWoodBoxItemCount(itemId)
    local containerItems = API.Container_Get_all(woodBoxContainerId)
    local itemCount = 0
    for _, itemData in pairs(containerItems) do
        if itemData.item_id == itemId then
            itemCount = itemCount + itemData.item_stack
        end
    end
    return itemCount
end

-- Checks if wood box is full for a given itemId
function isWoodboxFull(itemId)
    local amount = getWoodBoxItemCount(itemId)
    print("checking if wood box is full")
    return amount >= maxCapacity
end

-- Actions to perform if the wood box is full. Loads last saved bank preset
function bank()
    print("banking")
    API.DoAction_Tile(WPOINT.new(2315 + math.random(-3, 3),3571 + math.random(-3, 3),0))
    API.WaitUntilMovingEnds(5, 4)
    API.DoAction_Tile(WPOINT.new(2286 + math.random(-3, 3),3556 + math.random(-3, 3),0))
    API.WaitUntilMovingEnds(6, 4)

    -- Attempt to open the bank
    API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, {106235}, 50)

    -- Try multiple times to detect if the bank is open
    local maxAttempts = 10
    local opened = false
    for i = 1, maxAttempts do
        API.RandomSleep2(500, 100, 50) -- Wait before each check
        if API.BankOpen2() then
            opened = true
            break
        end
    end

    if opened then
        print("Bank is open, depositing all items via interface.")
        API.RandomSleep2(1200, 600, 200)

        -- Deposit all items using the provided interface action
        local depositedAll = API.DoAction_Interface(0xffffffff,0xffffffff,1,517,39,-1,API.OFF_ACT_GeneralInterface_route)
        if depositedAll then
            print("All items deposited successfully via interface.")
        else
            print("Failed to deposit items via interface. Check parameters.")
        end
        
        API.RandomSleep2(1200, 600, 200)

        -- Attempt to select bank preset 1
        print("Selecting bank preset 1.")
        local presetSelected = API.DoAction_Interface(0x24, 0xffffffff, 1, 517, 119, 1, API.OFF_ACT_GeneralInterface_route)
        if presetSelected then
            print("Bank preset 1 selected successfully.")
        else
            print("Failed to select bank preset 1. Check your interface parameters.")
        end

        API.RandomSleep2(1200, 600, 200)
    else
        print("Bank did not open successfully (according to API). Visually check if it's open and adjust timing or action if needed.")
    end

    API.WaitUntilMovingEnds()
    API.DoAction_Tile(WPOINT.new(2320 + math.random(-3, 3),3570 + math.random(-3, 3),0))
    API.WaitUntilMovingEnds(6, 4)
    API.RandomSleep2(1200, 600, 200)
end

-- Attempts to fill the wood box if inventory is full
function FillBox(itemID)
    print("filling wood box")
    if API.InvFull_() then
        if not isWoodboxFull(itemID) then
            -- Directly transfer logs to wood box via interface action
            local transferred = API.DoAction_Inventory1(58253,0,1,API.OFF_ACT_GeneralInterface_route)
            if transferred then
                print("Logs transferred to wood box successfully.")
                API.RandomSleep2(500, 50, 100)
            else
                print("Failed to transfer logs to wood box.")
            end
        else
            -- Wood box is full, bank
            bank()
        end
    end
end

-- Checks for HL objects and prioritizes them
local function checkHL()
    local hls = API.GetAllObjArray1({ 8447 }, 25, {4})
    if hls and #hls > 0 then
        local hlTileX = (hls[1].TileX / 512) - 1
        local hlTileY = (hls[1].TileY / 512) - 1
        print("HL found at: " .. hlTileX .. " " .. hlTileY)
        if not API.PInAreaW(WPOINT.new(hlTileX, hlTileY, 0), 2) then
            local walkToTile = WPOINT.new(hlTileX, hlTileY, 0)
            if API.DoAction_Tile(walkToTile) then
                API.RandomSleep2(1200, 100, 100)
                API.WaitUntilMovingandAnimEnds(10,5) -- Wait for animation to finish
            end
        else
            -- Already in area, just wait to ensure no animations
            API.WaitUntilMovingandAnimEnds(10,5)
        end
        return true -- indicate we found HL and potentially moved
    end
    return false
end

local function ChopTree()
    -- Check for HL objects first
    if checkHL() then
        print("Moved towards HL tree first.")
        -- Do not return, so we proceed to attempt chopping
    end

    -- Only proceed if the player isn't currently animating (e.g., already chopping)
    if not API.CheckAnim(20) then
        -- If inventory is full, try to fill the wood box first
        if API.InvFull_() then
            FillBox(logItemId)
            -- After FillBox, check if inventory is still full
            if API.InvFull_() then
                print("Inventory still full after attempting to fill wood box. Not chopping.")
                return -- Stop here, do not chop
            end
        end

        -- Attempt to chop a tree:
        local success = API.DoAction_Object_valid1(0x3b,API.OFF_ACT_GeneralObject_route0,{131907},50,true)
        if success then
            print("chopping tree")
            -- Wait for animation or movement to confirm the action started
            API.WaitUntilMovingandAnimEnds(10,5)

            -- After waiting, if animation has stopped, it might mean the tree was fully chopped
            if not API.CheckAnim(20) then
                -- Try to find another tree using the same call
                local newTreeSuccess = API.DoAction_Object_valid1(0x3b,API.OFF_ACT_GeneralObject_route0,{131907},50,true)
                if newTreeSuccess then
                    print("Found a new tree to chop.")
                    API.WaitUntilMovingandAnimEnds(5,1)
                else
                    print("No more trees found nearby.")
                end
            end
        else
            print("Failed to initiate chopping action. Retrying...")
        end
    else
        -- Player is animating, presumably chopping
        print("Already animating, waiting...")
        API.RandomSleep2(1200, 100, 200)
    end
end

-- Main loop
while (API.Read_LoopyLoop()) do
    ChopTree()
    API.RandomSleep2(1200, 100, 200)
    API.DoRandomEvents()
    -- No unconditional bank call
end
