local API = require("api")
local UTILS = require("utils")

local e = 0 

local ID = {
  UNFINISHED_SMITHING_ITEM = 47068,
  NORMAL = {
      FORGE = { 113264, 112738, 113263 },
      ANVIL = 113262,
      FURNACE = { 113266, 113265 }
  },
  BURIAL = {
      FORGE = { 113267, 120051 },
      ANVIL = 113268,
  },
  BANK_CHEST = 85341
}

local AREA = {
  NORMAL = 1,
  BURIAL = 2
}

local AREA_ACTIONS = {
  [AREA.BURIAL] = {
      forge = function()
          API.DoAction_Object1(0x3f, 0, ID.BURIAL.FORGE, 10)
      end,
      anvil = function()
          API.DoAction_Object1(0x3f, 0, { ID.BURIAL.ANVIL }, 50)
      end
  },
  [AREA.NORMAL] = {
      forge = function()
          API.DoAction_Object1(0x3f, 0, ID.NORMAL.FORGE, 10)
      end,
      anvil = function()
          API.DoAction_Object1(0x3f, 0, { ID.NORMAL.ANVIL }, 50)
      end,
      furnance = function()
          API.DoAction_Object1(0x3f, 0, { ID.NORMAL.FURNACE }, 50)
      end
  },
}

while (API.Read_LoopyLoop()) do
  ::continue::
  do
      UTILS.DO_ElidinisSouls()
      print(API.LocalPlayer_HoverProgress())

      if API.LocalPlayer_HoverProgress() <= 165 then
          if API.LocalPlayer_HoverProgress() == 0 then
              goto continue  -- This skips the rest and continues the loop
          end
          API.DoAction_Object1(0x3f, 0, ID.NORMAL.FORGE, 10)
          API.RandomSleep2(1800, 2000, 2200)
          API.DoAction_Object1(0x3f, 0, { ID.NORMAL.ANVIL }, 50)
          API.RandomSleep2(1800, 2000, 2200)
      else
          if not API.CheckAnim(50) then
              API.DoAction_Object1(0x3f, 0, { ID.NORMAL.ANVIL }, 50)
              API.RandomSleep2(600, 200, 200)
          end
      end
  end
end

