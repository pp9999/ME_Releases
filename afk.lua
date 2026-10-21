local API = require("api")
print("Run Lua port fish script afker.")


API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.DoRandomEvents()

    GamePlugin:Invoke("World.IsMembers")


    
API.RandomSleep2(1000, 3000, 4000)
API.Write_LoopyLoop(false)
end