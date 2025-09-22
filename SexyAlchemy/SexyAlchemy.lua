
local API = require("api")
local player = API.GetLocalPlayerName()
local processingTimeout = 2 
function waitUntil(x, timeout)
    start = os.time()
    while not x() and start + timeout > os.time() do
        API.RandomSleep2(600, 200, 200)
    end
    return start + timeout > os.time()
end
local function waitWhileProcessing(timeout)
    local startTime = os.time()
    while os.time() - startTime < timeout do
        if not isProcessing() then
            return true
        end
      

        API.RandomSleep2(600, 200, 200)
    end
    return false
end

--main loopyyyyloopp
API.Write_LoopyLoop(true)

while(API.Read_LoopyLoop()) do
    API.DoRandomEvents()


         
    if not API.IsPlayerAnimating_(player, 2) then
        API.KeyboardPress('1', 60, 100)
       API.DoAction_Inventory1(1394,0,0,API.OFF_ACT_GeneralInterface_route1)
            if waitUntil(API.isProcessing, 3) then
                waitWhileProcessing(processingTimeout)
            end
        end
    end 
