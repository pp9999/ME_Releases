local API = require("api")
print("Run Lua port fish script afker.")

while API.Read_LoopyLoop() do
    --API.DoRandomEvents()
    --print("Loop")

    print("Target:", API.ReadTargetInfo99().Target_Name)
    print("Cmb_lv:", API.ReadTargetInfo99().Cmb_lv)
    print("Hit_percent:", API.ReadTargetInfo99().Hit_percent)
    print("HP:", API.ReadTargetInfo99().Hitpoints)

API.RandomSleep2(1, 300, 400)
end