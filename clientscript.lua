local API = require("api")
print("Run Lua script Client.")

local ClientStartedAtHere = false

--initilize
local function StartClient()
    print("Starting client in lua")
    SOC:StartClient(999,true)
    API.RandomSleep2(2500, 0, 0)
    if (SOC:IsClientStarted()) then
        ClientStartedAtHere = true
        print("Lua reports that client is started")
    end
end

--every function needs its own
--tiles must be always 6 numbers big
local function Parser_DoAction_TileF(text)
    if (text ~nil) then
        local i, j = string.find(text,"API.DoAction_TileF")
        local x_coord
        local y_coord
        if (j ~= nil and j > 1) then
            x_coord = string.sub(text,j+14,j+14+5)
            --print(x_coord)
        end
        if (j ~= nil and j > 1) then
            y_coord = string.sub(text,j+14+7,j+14+12)
            ---print(y_coord)        
        end
        if (x_coord ~= nil and y_coord ~= nil) then
            API.DoAction_TileF(FFPOINT.new(tonumber(x_coord),tonumber(y_coord),0))
        end
    end
end
StartClient()--start client here
while API.Read_LoopyLoop() do

    SOC:MessageServer("buttsecks")
   --SOC:MessageServer("DirectCommand::Server_Close(false)")
  
    API.RandomSleep2(6000, 0, 0)
end