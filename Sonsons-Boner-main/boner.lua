--- @module "Sonson's Boner"
--- @version 1.0.1

local API = require("api")
API.Write_fake_mouse_do(false)

local Boner = {
    constants = {
        scriptVersion = "1.0.0",
        bone = "Dragonkin bones",
        ash = "Infernal ashes",
        objects = {
            BANK_CHEST = {
                name = "Bank chest",
                id = 125115,
                type = 0
            },
            BANKER = {
                name = "Banker",
                type = 1,
            }
        },
        ids = {
            POWDER_OF_BURIALS = 52805
        }
    },
    variables = {
        interval = 1,
        attemptThreshold = 2,
        status = "nil",
        timestamps = {
            bank = 0,
            buff = 0,
            bone = 0,
            ash = 0
        },
        attempts = {
            bank = 0,
            buff = 0,
            bone = 0,
            ash = 0
        }
    }
}

------------------------------------------
--# CORE METHODS
------------------------------------------

function Boner:getBones()
    if self:isOnCooldown(self.variables.timestamps.bank) then return end
    if self:exceededAttempts(self.variables.attempts.bank) then
        print("- Can't bone no more (NO BONES)")
        API.Write_LoopyLoop(false)
    end

    self.variables.attempts.bank = self.variables.attempts.bank + 1
    print("- No bones found in inventory")

    self.variables.status = "Getting bones"
    if Interact:Object(self.constants.objects.BANK_CHEST.name, "Load Last Preset from", 10)
        or Interact:NPC(self.constants.objects.BANKER.name, "Load Last Preset from", 10) then
        print("+ Loading last preset")
        self.variables.timestamps.bank = API.Get_tick()
    end
end

function Boner:boneBuff()
    if self:isOnCooldown(self.variables.timestamps.buff) then return end
    if self:exceededAttempts(self.variables.attempts.buff) then
        print("- Can't bone no more (NO BUFFS)")
        API.Write_LoopyLoop(false)
    end

    self.variables.attempts.buff = self.variables.attempts.buff + 1
    print("- Powder of burials buff not found or expiring")

    self.variables.status = "Applying bone buff"
    if Inventory:DoAction(self.constants.ids.POWDER_OF_BURIALS, 1, API.OFF_ACT_GeneralInterface_route) then
        print("+ Reapplying buff")
        self.variables.attempts.buff = 0
        self.variables.timestamps.buff = API.Get_tick()
    end
end

function Boner:bone()
    if self:isOnCooldown(self.variables.timestamps.bone)
        or self:isOnCooldown(self.variables.timestamps.ash)then return end

    if self:exceededAttempts(self.variables.attempts.bone) or
        self:exceededAttempts(self.variables.attempts.ash)then
        print("- Can't bone no more (NO BONES)")
        API.Write_LoopyLoop(false)
    end

    local ash = false
    local bone = false

    if Boner:hasBone() then
        self.variables.attempts.bank = 0
        self.variables.attempts.bone = self.variables.attempts.bone + 1
        if API.DoAction_Ability(self.constants.bone, 1, API.OFF_ACT_GeneralInterface_route, false) then
            print("+ Boned")
            bone = true
            self.variables.timestamps.bone = API.Get_tick()
            self.variables.attempts.bone = 0
        end
    end

    -- Thank you Ernie!
    if Boner:hasAsh() then
        self.variables.attempts.bank = 0
        self.variables.attempts.ash = self.variables.attempts.ash + 1
        if API.DoAction_Ability(self.constants.ash, 1, API.OFF_ACT_GeneralInterface_route, false) then
            print("+ Ashed")
            self.variables.timestamps.ash = API.Get_tick()
            self.variables.attempts.ash = 0
            ash = true
        end
    end

    if bone and ash then
        -- Thank you Ernie!
        self.variables.status = "Bashing"
    elseif bone then
        self.variables.status = "Boning"
    elseif ash then
        self.variables.status = "Ashing"
    end

end

------------------------------------------
--# HELPER METHODS
------------------------------------------

function Boner:isOnCooldown(timestamp)
    return not ((API.Get_tick() - timestamp) >= self.variables.interval)
end

function Boner:exceededAttempts(count)
    return count > self.variables.attemptThreshold
end

function Boner:burialBuffExists()
    local buff = API.Buffbar_GetIDstatus(self.constants.ids.POWDER_OF_BURIALS, false)
    return buff.found and (API.Bbar_ConvToSeconds(buff) > 30)
end

function Boner:hasBone()
    return Inventory:Contains(self.constants.bone)
end

-- Thank you Ernie!
function Boner:hasAsh()
    return Inventory:Contains(self.constants.ash)
end

------------------------------------------
--# DATA YUM
------------------------------------------

function Boner:trackBoning()
    local metrics = {
        { string.format("[%s] Sonson's Boner", self.constants.scriptVersion) },
        { "", "" },
        { "Boner information:", API.ScriptRuntimeString() },
        { "- Status:", self.variables.status },
    }
    API.SetDrawTrackedSkills(true)
    API.DrawTable(metrics)
end

------------------------------------------
--# MAIN LOOP
------------------------------------------

while API.Read_LoopyLoop() do
    -- Cache handling
    if not API.CacheEnabled then
        print("- Cache not enabled. Exiting script.")
        API.Write_LoopyLoop(false)
        return
    end

    -- Buff handling
    if not Boner:burialBuffExists() then
        Boner:boneBuff()
    end

    -- Inventory handling
    if not Boner:hasBone() and not Boner:hasAsh() then
        Boner:getBones()
    end

    -- Bone handling
    if Boner:hasBone() or Boner:hasAsh() then
        Boner:bone()
    end

    -- Data is nice
    Boner:trackBoning()

    -- Other stuff handling
    API.DoRandomEvents(600, 0)
    API.RandomSleep2(100, 100, 200)
end

------------------------------------------
--# FIN
------------------------------------------

return Boner
