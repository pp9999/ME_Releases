local API = require("api")
print("Run Lua port fish script afker.")

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    print("Loop")



    print("Buffbar_GetIDstatus".. API.Buffbar_GetIDstatus(14268).id)


API.RandomSleep2(2600, 3300, 4300)
end