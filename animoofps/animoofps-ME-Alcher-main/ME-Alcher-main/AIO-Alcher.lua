local API = require("api")

---@return table A table where each entry represents an item in the inventory.
local function scanInventory()
    local inventory = API.ReadInvArrays33()
    local items = {}
    local excludedItemIds = {561} -- Nature rune ID

    if inventory then
        for i = 1, #inventory do
            if inventory[i].itemid1 > 0 and not table.contains(excludedItemIds, inventory[i].itemid1) then
                table.insert(items, inventory[i])
            end
        end
    end

    return items
end

--- check to see if the value is contained in an array
---@param array table
---@param value any
---@return boolean
table.contains = function(array, value)
    for i = 1, #array do
        if array[i] == value then
            return true
        end
    end
    return false
end

-- gui stuff
local ChosenItem = -1

local comboBoxSelect = API.CreateIG_answer()
local inventoryItems = {}

local function filterText(text)
    return (string.gsub(text, "<[^>]*>", ""))
end

local function setupOptions()
    comboBoxSelect.box_name = "Items"
    comboBoxSelect.box_start = FFPOINT.new(1, 60, 0)
    comboBoxSelect.stringsArr = {}
    comboBoxSelect.box_size = FFPOINT.new(440, 0, 0)

    table.insert(comboBoxSelect.stringsArr, "Select an option")

    inventoryItems = scanInventory()

    for i, item in ipairs(inventoryItems) do
        local cleanName = filterText(item.textitem)
        table.insert(comboBoxSelect.stringsArr, cleanName)
    end

    API.DrawComboBox(comboBoxSelect, false)
end

setupOptions()

local function Alching(itemToAlch)
    -- if (API.ReadPlayerAnim() == 24458) then
    if API.CheckAnim(5) then
        API.RandomSleep2(600, 200, 400)
    else
        local AB = API.GetABs_name1("High Level Alchemy")
        if AB.enabled then
            API.DoAction_Ability_Direct(AB, 0, API.OFF_ACT_Bladed_interface_route)
            API.RandomSleep2(400, 300, 800)
            if (itemToAlch ~= nil) then
                API.DoAction_Inventory1(itemToAlch.itemid1, 0, 0, API.OFF_ACT_GeneralInterface_route1)
                API.RandomSleep2(800, 400, 600)
            end
        end
    end
end
API.SetDrawTrackedSkills(true)
while (API.Read_LoopyLoop()) do -----------------------------------------------------------------------------------
    API.SetMaxIdleTime(5)
    if (comboBoxSelect.return_click) then
        comboBoxSelect.return_click = false
        for i, item in ipairs(inventoryItems) do
            local cleanName = filterText(item.textitem)
            if (comboBoxSelect.string_value == cleanName) then
                print("You chose: ", item.textitem, "index: ", i)
                ChosenItem = i
            end
        end
    end
    local itemToAlch = inventoryItems[ChosenItem]
    if ChosenItem ~= -1 and itemToAlch then
        if API.InvItemcountStack_String(itemToAlch.itemid1) > 0 or API.InvItemcountStack_String("Nature rune") > 0 then
            Alching(itemToAlch)
        else
            print("No more stuff in the inventory, shutting down")
            API.Write_LoopyLoop(false)
        end
    end
end
