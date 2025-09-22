-- Import required modules
local API = require("api")
local UTILS = require("utils")

--Internal required modules
local startTime = os.time()
local startXp = API.GetSkillXP("SUMMONING")
local pouches = 0
local afk = os.time() -- Initialize the variable afk
local MAX_IDLE_TIME_MINUTES = 10 -- Define the maximum idle time in minutes


--Constant modules
-- Define the function to round numbers
local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

-- Define a function to format numbers with commas as thousands separator
local function formatNumberWithCommas(amount)
    local formatted = tostring(amount)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end

-- Define the function to format large numbers
function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

-- Define a function to format elapsed time to [hh:mm:ss]
local function formatElapsedTime(startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

-- Define the idle check function
local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        print("Eternal Mode Continuing.")
        API.PIdle2()
        afk = os.time()
    end
end

-- Define the function to calculate progress percentage in a skill
local function calcProgressPercentage(skill, currentExp)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    if currentLevel == 120 then return 100 end
    local nextLevelExp = XPForLevel(currentLevel + 1) -- This function needs to be defined elsewhere
    local currentLevelExp = XPForLevel(currentLevel) -- This function needs to be defined elsewhere
    local progressPercentage = (currentExp - currentLevelExp) / (nextLevelExp - currentLevelExp) * 100
    return math.floor(progressPercentage)
end

-- Define the function to print the progress report
local function printProgressReport(final)
    local skill = "SUMMONING"
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp)
    local xpPH = round((diffXp * 60) / elapsedMinutes)
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
    " | " ..
    string.lower(skill):gsub("^%l", string.upper) ..
    ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
end

-- Define the function to set up the GUI
local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(116, 2, 179);
    IGP.string_value = "Taverly Summoning"
end

-- Define the function to draw the GUI
function drawGUI()
    DrawProgressBar(IGP)
end

-- Call the setupGUI function to initialize the GUI
setupGUI()

-- Define the function to scan for interface components
local function scanForInterface(interfaceComps)
    return #(API.ScanForInterfaceTest2Get(true, interfaceComps)) > 0
end

-- Variable modules
local presetLoaded = false  -- Flag to track if preset has been loaded at the bank
local walkedToBank = false  -- Flag to track if walking to the bank has been performed
local walkedToSummoningHut = false -- Flag to track if walking to the summoning hut has been completed

-- Function to perform bank action
local function Bank() -- !! EDIT LINES 123, 125 TO MATCH APPROPRIATE ITEM ID'S !!
    if API.InvItemFound1(12123) or not API.InvItemFound1(2150) then -- checks for having pouches or not having secondary
        -- Check if not preset loaded and Swamp toad not found
        if not presetLoaded and not API.InvItemFound1(2150) then
            -- Walk to bank if not already walked in this loop
            if not walkedToBank then
                print("Walking to the bank...")
                API.DoAction_Tile(WPOINT.new(2875,3417,0))
                API.WaitUntilMovingandAnimEnds()
                walkedToBank = true  -- Set the flag to true after successfully walking to the bank
            end
            
            if walkedToBank then -- Only attempt to load preset if successfully walked to the bank
                print("Loading preset...")
                API.DoAction_Object1(0x33, 240, {66666}, 50)
		API.RandomSleep2(650,1000,1000)
                API.WaitUntilMovingandAnimEnds() -- Wait for preset loading animation to end
                
                -- Check if 'Swamp toad' is now in the inventory !!EDIT LINE 141 TO HAVE SECONDARY ITEM ID!!
                if API.InvItemFound1(2150) then
                    print("Preset loaded successfully.")
                    presetLoaded = true
                else
                    print("Failed to load preset. Retrying...")
                    -- Reset walkedToBank flag to false
                    walkedToBank = false
                    -- Attempt to load preset again
                    API.DoAction_Object1(0x33, 240, {66666}, 50)
		    API.RandomSleep2(650,1000,1000)
                    API.WaitUntilMovingandAnimEnds() -- Wait for preset loading animation to end
                end
            end
        else
            if not presetLoaded then
                print("Preset already loaded.")
                presetLoaded = true -- Set presetLoaded to true to prevent spamming the message
            end
        end
    end
end



-- Function to make pouches, edit Line 167 to proper secondary and pouch checks!!! 
local function MakePouches()
    if API.InvItemFound1(2150) or not API.InvItemFound1(12123) then
        -- Check if the character needs to walk to the summoning hut
        if not walkedToSummoningHut then
            print("Walking to summoning hut...")
            API.DoAction_Tile(WPOINT.new(2931, 3448, 0))
            API.WaitUntilMovingandAnimEnds()
            walkedToSummoningHut = true  -- Set the flag to true after successfully walking to the summoning hut
        else
            -- Only attempt to interact with the obelisk if successfully walked to the summoning hut
            if walkedToSummoningHut then
                print("Interacting with Obelisk...")
                API.DoAction_Object1(0x29, 0, {67036}, 50)
		API.RandomSleep2(650,1000,1000)
                API.WaitUntilMovingandAnimEnds()
                
                -- Check if the character has the required item for creating pouches !! EDIT LINE 183 TO HAVE YOUR SECONDARY ITEM ID !!
                if API.InvItemFound1(2150) then
                    print("Creating pouches...")
                    API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1370, 30, -1, 2912)
		    API.RandomSleep2(650,1000,1000)
                    API.WaitUntilMovingandAnimEnds()
                    
                    walkedToSummoningHut = false
                else
                    -- If the required item is not found, set the flag to false and initiate bank action
                    walkedToSummoningHut = false
                    print("Required item not found. Initiating bank action...")
                    Bank()
                end
            end
        end
    end
end

-- Main functionality
API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do
    drawGUI()
    idleCheck()
    printProgressReport()
    API.DoRandomEvents()
    
    -- Call the bank function
    Bank()
    API.WaitUntilMovingandAnimEnds()
    
    -- Call the make pouches function
    MakePouches()
    API.WaitUntilMovingandAnimEnds()

end
