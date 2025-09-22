local API = require("api")


-- PRESET 1 WITH WOODBOX AND KEYPRESS S FOR DEPOSITING IN WOODBOX
local player = API.GetLocalPlayerName()

-- Add more tree IDs for different tree types
local oak = {38731,38731}
local tree = {38787, 38785, 38760, 38783}
local willow = {58006, 38627, 38616}

API.Write_ScripCuRunning0("starting")
API.Write_ScripCuRunning1(player)
API.Write_ScripCuRunning2("woodcutting by Frank")

local bankchestid_varrock = {553,2759}
local bankchestid_draynor = {4459,4458,4457,4456}

local treeOptions = {
    "Oak",
    "tree",
    "Willow", -- Add "Willow" option here
    -- Add more tree options here
}

local treeType = API.ScriptDialogWindow2("Select Tree Type", treeOptions, "Start", "Close").Name

local banks

local selectedTree = {}

if treeType == "Oak" then
    selectedTree = oak
    banks = bankchestid_varrock
    elseif treeType == "tree" then
        selectedTree = tree
        banks = bankchestid_varrock
    elseif treeType == "Willow" then -- Add condition for Willow here
        selectedTree = willow
        banks = bankchestid_draynor
    -- Add more cases for other tree types here
end

print("Selected tree type:", treeType)
print("Starting cutting trees...")


local function check()
    API.Write_ScripCuRunning0("checking during animations")
    ---depositItems()
    if API.IsPlayerAnimating_(player,1) then
        print("idle check")
        repeat
            if math.random(0,1000) > 500 then
                API.PIdle22()
            end
                if not API.Read_LoopyLoop() then print("break") break end
            API.RandomSleep2(1500,2500, 2500) -- Adjust sleep time as needed
            
            API.DoRandomEvents()
       until not API.CheckAnim(50) or API.InvFull_() or not API.Read_LoopyLoop()
       print("over check")
    end
end

local function depositItems()
    local depositAttempts = 0
    previncount = 0
    local maxDepositAttempts = math.random(2, 3)
    
    API.Write_ScripCuRunning0("Depositing")
    if API.Invfreecount_() < math.random(5, 10) and not oreBoxFull then
        local prevInvCount = API.Invfreecount_()
        local retryAttempts = 0
        local depositSuccess = false
        repeat
        if retryAttempts <= maxDepositAttempts and not depositSuccess and not oreBoxFull then
            API.KeyboardPress('s', 60, 100)
            API.RandomSleep2(math.random(200, 500), math.random(500, 1000),1500)

            if prevInvCount == API.Invfreecount_() then
                retryAttempts = retryAttempts + 1
                print("Retrying deposit attempt #" .. retryAttempts)
            else
                depositSuccess = true
                retryAttempts = 0
                print("Deposited items successfully.")
            end

            if retryAttempts > maxDepositAttempts then
                oreBoxFull = true
                print("Ore box full.")
            end
        end
        until retryAttempts == 0 or oreBoxFull
    end

    API.RandomSleep2(2500, 3050, 12000)

   

end


local function cutTreesAndBankLogs() -- make ur functions local for the love of god
    API.Write_ScripCuRunning0("Cut tree")

    if treeType == "Oak" or treeType == "tree" then
        local x = 3162 + math.random(-2, 2)
        local y = 3412 + math.random(-2, 2)
        local z = 0
        if not API.PInArea(x,5,y,5,0) then
            API.DoAction_WalkerW(WPOINT.new(x, y, z))  
       end   
    elseif treeType == "Willow" then
        local x = 3090 + math.random(-2, 2)
        local y = 3232 + math.random(-2, 2)
        local z = 0
        if not API.PInArea(x,5,y,5,0) then
            API.DoAction_WalkerW(WPOINT.new(x, y, z))  
       end 
    end


   
    while API.Invfreecount_() > 0 and API.Read_LoopyLoop() do
        if API.Invfreecount_() > 0 and  not API.CheckAnim(150) then
            local availableTrees = {} -- Store available tree IDs

            for i, treeId in ipairs(selectedTree) do
                -- Check if the tree ID is not the last cut tree
                if i ~= lastCutTreeIndex then
                    table.insert(availableTrees, treeId)
                end
            end
            

            -- Check if there are available trees to cut
            
            -- Randomly select a tree ID to cut
            local treeIndex = math.random(1, #availableTrees)
            local treeId = availableTrees[treeIndex]
            lastCutTreeIndex = treeIndex -- Update the last cut tree index
            if API.Invfreecount_() == 0 then
                break
            end

            print("Clicking on tree " .. treeId .. " to start cutting.")

            API.DoAction_Object_r(0x3b, 0, {treeId}, 50, WPOINT.new(0, 0, 0), 5)
           
          
        end  
        --depositItems()
        check()

        if not API.Read_LoopyLoop() then print("break") break end
    end
end

local function bank()
    if API.Invfreecount_() == 0 then
        local selectedBankChestIds = nil
        
        if treeType == "Oak" or treeType == "tree" then
            selectedBankChestIds = bankchestid_varrock -- Use the Varrock bank chest ID
        elseif treeType == "Willow" then
            selectedBankChestIds = bankchestid_draynor -- Use the Draynor bank chest IDs
        -- Add more cases for other tree types and their corresponding bank chest IDs
        end

        -- Check if selectedBankChestIds is not nil and not an empty table
        if selectedBankChestIds and #selectedBankChestIds > 0 then
            -- Choose any one ID from the selectedBankChestIds table
            chosenBankChestId = selectedBankChestIds[math.random(1,#selectedBankChestIds)] -- Change the index as needed
            print("Selected Bank Chest ID: " .. chosenBankChestId)
        else
            print("No bank chest ID selected.")
        end

        API.DoAction_NPC(0x5,3120,{ chosenBankChestId },50)
        
        API.RandomSleep2(math.random(200, 500), math.random(500, 1000), 1500)

        repeat until API.WaitUntilMovingEnds()

        if API.BankOpen2() then
            print("Depositing all items...")
            API.KeyboardPress('3', 60, 200)
            API.RandomSleep2(math.random(200, 500), math.random(500, 1000), 1500)
            API.KeyboardPress('1', 60, 200)
            print("Closing the bank...")
        else   
            -- bank tile
      
            if treeType == "Oak" or treeType == "tree" then
                local x = 3186 + math.random(-2, 2)
                local y = 3438 + math.random(-2, 2)
                local z = 0
                API.DoAction_WalkerW(WPOINT.new(x, y, z))    
                print("banking oak or tree")

                API.DoAction_NPC(0x5,3120,{ chosenBankChestId },50)
                
                API.RandomSleep2(math.random(200, 500), math.random(500, 1000), 1500)
                API.WaitUntilMovingEnds()
            elseif treeType == "Willow" then
                    print("rebanking willow")
            end

            

            print("Bank did not open.")
        end
    end
end


API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do
    if API.PlayerLoggedIn() then
       cutTreesAndBankLogs()
        bank()
        if not API.Read_LoopyLoop() then print("break") break end
    else
        API.KeyboardPress(32,1000,500)
    end
end
