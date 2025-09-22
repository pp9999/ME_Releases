print("Run Lua script PortableUrns. At Fort")

local API = require("api")




--Exported function list is in API
--main loop
API.Write_LoopyLoop(true)
while(API.Read_LoopyLoop())
do-----------------------------------------------------------------------------------
 

    repeat
    API.DoAction_NPC(0x29,3328,{ 7800,7877 },50)
    until API.CheckAnim(100) 
    repeat 
    until not API.CheckAnim(100)

API.RandomSleep2(500, 3050, 12000)
end----------------------------------------------------------------------------------
