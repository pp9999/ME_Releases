local API = require("api")

UTILS = {}

function UTILS:basket1()
    local basketQTD = API.VB_FindPSett(10330).state >> 18 & 0xfff
    return basketQTD / 64
end

function UTILS:basket2()
    local basketQTD = API.VB_FindPSett(10331).state & 0xFFFFFFFF >> 26
    return basketQTD
end

function UTILS:findNPC(npcid, distance)
    local npcs = API.GetAllObjArrayInteract(type(npcid) == "table" and npcid or {npcid}, distance or 20, {1})
    return #npcs > 0 and npcs[1] or false
end

function UTILS:IsHandlingFrito()
    local fritos = API.GetAllObjArray1({28665, 28666}, 50, {1})
    for i, frito in ipairs(fritos) do
        if frito.Action == "Handle" then
            return false 
        elseif frito.Action == "Stop handling" then
            return true
        end
    end
    return false
end

function UTILS:InteractWithRandomWhirligigs()
    local Whirligigs = {28719, 28720, 28721, 28722, 28723, 28724, 28725, 28726}
    
    local existingWhirligigs = {}
    for _, id in ipairs(Whirligigs) do
        if UTILS:findNPC(id, 20) then
            table.insert(existingWhirligigs, id)
        end
    end

    local count = #existingWhirligigs
    if count == 0 then
        print("No Whirligigs found!")
        return false
    end
    
    local numToInteract = math.random(math.min(1, count), math.min(4, count))
    
    for i = #existingWhirligigs, 2, -1 do
        local j = math.random(i)
        existingWhirligigs[i], existingWhirligigs[j] = existingWhirligigs[j], existingWhirligigs[i]
    end

    for i = 1, numToInteract do
        local id = existingWhirligigs[i]
        print("Interacting with Whirligig ID: " .. id)
        API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, {id}, 50)
       API.RandomSleep2(400, 400, 400)
    end
    
    return true
end

function UTILS:getbasket1()
    local Baskets = {122499, 122495, 122496, 122497, 122498, 122494}
    local objects = API.GetAllObjArray2(Baskets, 100, {0}, WPOINT.new(3384,3213,0))
    if #objects > 0 then
        return objects[1].Id
    end
    return 0
end

function UTILS:getbasket2()
    local Baskets = {122499, 122495, 122496, 122497, 122498, 122494}
    local objects = API.GetAllObjArray2(Baskets, 100, {0}, WPOINT.new(3375,3206,0))
    if #objects > 0 then
        return objects[1].Id
    end
    return 0
end































return UTILS