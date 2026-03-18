-- Title: Alejandro's Whirligig
-- Author: Alejandro
-- Description: Catches whirgligs while filling the baskets.
-- Version: 1.0
-- Category: Hunter

local API = require("api")
local UTILS = require("whirligig.utils")

local IDs = {
    Whirligigs = {28719, 28720, 28721, 28722, 28723, 28724, 28725, 28726},
    Flowers = {52811, 52807, 52808, 52809, 52810},
    Baskets = {122499, 122495, 122496, 122497, 122498},
    Frito = {28665, 28666},
}

local idleTicksIsh = 0
local flower = 0
local basket = 0

if CONFIG.flower == "No flowers" then
    flower = 0
    basket = 0
elseif CONFIG.flower == "Golden roses" then
    flower = IDs.Flowers[1]
    basket = IDs.Baskets[1]
elseif CONFIG.flower == "Roses" then
    flower = IDs.Flowers[2]
    basket = IDs.Baskets[2]
elseif CONFIG.flower == "Irises" then
    flower = IDs.Flowers[3]
    basket = IDs.Baskets[3]
elseif CONFIG.flower == "Hydrangeas" then
    flower = IDs.Flowers[4]
    basket = IDs.Baskets[4]
elseif CONFIG.flower == "Hollyhocks" then
    flower = IDs.Flowers[5]
    basket = IDs.Baskets[5]
end


API.SetDrawTrackedSkills(true)

API.Write_fake_mouse_do(false)

if CONFIG then
    print(CONFIG.flower)  -- See the user flower
end

while (API.Read_LoopyLoop()) do
    print("Basket 1 quantity ", UTILS:basket1())
    print("Basket 2 quantity ", UTILS:basket2())
    print("Basket 1 ID ", UTILS:getbasket1())
    print("Basket 2 ID ", UTILS:getbasket2())
    API.SetMaxIdleTime(5)

    if not UTILS:findNPC(IDs.Frito[1], 50) and not UTILS:findNPC(IDs.Frito[2], 50) then
        print("Frito not found!")
        API.Write_LoopyLoop(false)
        goto continue
    end

    if basket ~= 0 and (UTILS:getbasket1() ~= basket or UTILS:getbasket2() ~= basket) then
        print("Wrong flower in the basket!")
        API.Write_LoopyLoop(false)
        goto continue
    end

    if basket ~= 0 and (UTILS:basket1() == 0 or UTILS:basket2() == 0) then
        print("Empty basket!")
        API.Write_LoopyLoop(false)
        goto continue
    end

    if flower ~= 0 and Inventory:GetItemAmount(flower) < 26  then
        API.Write_LoopyLoop(false)
        print("No flowers found!")
        goto continue
    end

    if basket ~= 0 and UTILS:basket1() < 26 then  
        API.DoAction_Object2(0x29,API.OFF_ACT_GeneralObject_route3,{basket},50,WPOINT.new(3384,3213,0));
        print("Filling basket 01")
        idleTicksIsh = 2
        goto continue
    end

    if basket ~= 0 and UTILS:basket2() < 26 then  
        API.DoAction_Object2(0x29,API.OFF_ACT_GeneralObject_route3,{basket},50,WPOINT.new(3375,3206,0));
        print("Filling basket 02")
        idleTicksIsh = 2
        goto continue
    end

    if not UTILS:IsHandlingFrito() and idleTicksIsh < 1 then
        print("Manuseando frito")
        print(API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, {28665}, 50))
        idleTicksIsh = 5
    else
        print("Hunting!")
        UTILS:InteractWithRandomWhirligigs()
    end

    ::continue::
    API.RandomSleep2(1000, 1000, 1000)
    idleTicksIsh = idleTicksIsh - 1
end
