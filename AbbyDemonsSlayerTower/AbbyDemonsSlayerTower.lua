local API = require("api")

startTime, afk = os.time(), os.time()

--[[ 
Script will camp abyssal demons on the top floor of the Slayer Tower.
Requires T70 gear and T80 weapons. Haven't tested with anything else.
Pray Melee and use an AFK Necro bar that prioritises zombie, blood siphon and scythe. 
Recommended action bar: https://i.imgur.com/wajfIhp.png
Start the script whilst in the position you want to camp. ]]

MAX_IDLE_TIME_MINUTES = 5

-- Requires Aggroverload and Elven Shard on your action bar.
function useOverloads()
    cooldown = (API.Buffbar_GetIDstatus(37969, false).id > 0)
    if not cooldown then
        if API.DoAction_Ability("Holy Aggroverload", 1, 5392) then
            API.RandomSleep2(1000, 2500, 1500)
            API.DoAction_Ability("Ancient elven ritual shard", 1, 5392)
            return true
        end
    end
    return false
end

function inventoryCheck()
    if API.PInArea(3407, 10, 3549, 10, 3) then
        if API.InvItemcount_1(50877) == 0 then 
            API.DoAction_Ability("War's Retreat Teleport", 1, 5392)
        end
    end
end

function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

while (API.Read_LoopyLoop()) do
    idleCheck()
    useOverloads()
    API.RandomSleep2(1000, 2500, 1500)
    inventoryCheck()
    API.RandomSleep2(1000, 2500, 1500)
end