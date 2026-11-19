local API = require("api")
print("Run Lua port fish script afker.")

local prev_xp_check = 0
local loopsofnoxp_check = 0
API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents(true)
    local current_xp_check = API.GatherEvents_xp_check()
    if (#current_xp_check > 0 and prev_xp_check ~= current_xp_check[1].exp) then
        prev_xp_check = current_xp_check[1].exp
        loopsofnoxp_check = 0
    else
        loopsofnoxp_check = loopsofnoxp_check + 1
    end
    if (loopsofnoxp_check > 10) then
        API.Write_LoopyLoop(false)
    end

    if not API.CheckAnim(100) then
        if not Inventory:IsFull() then
            API.DoAction_Object1(0x33,API.OFF_ACT_GeneralObject_route0,{ 109001 },6);
            API.RandomSleep2(5000, 300, 400)
        end
    end

API.RandomSleep2(1000, 3000, 4000)
--API.Write_LoopyLoop(false)
end