local API = require("api")


API.SetMaxIdleTime(4)
API.Write_fake_mouse_do(true)
while API.Read_LoopyLoop() do
    API.RandomSleep2(2500, 0, 0)
    API.DoAction_Object1(0x5, API.OFF_ACT_GeneralObject_route1, { 25688 }, 50);
    API.RandomSleep2(2500, 0, 0)
    break
end
