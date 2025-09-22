local API = require("api")

local lastTick = 0

local function Excavate()
  -- Excavate closest dig site
  local objects = API.ReadAllObjectsArray({0}, {-1}, {})
  local sortedObject = API.Math_SortAODist(objects)
  if sortedObject then
    print ("Excavating at closest digsite")
    API.DoAction_Object_Direct(sortedObject.Action, 0, sortedObject)
  end
end

local function CheckPorter()
  -- Check if we have porter equipped
  local pocketItemId = API.Container_Get_all(94)[18].item_id
  if pocketItemId == -1 then
    print ("No porter equipped")
    Inventory:Equip("Sign of the porter VII")
  end
end

local function CheckAnim()
  -- Check if we are idle
  if not API.CheckAnim(2) then
    print ("Player is idle")
    Excavate()
  end
end

local function CompareSprite()
  -- Find sprite and check how far it is
  local sprite = API.ReadAllObjectsArray({4}, {7307}, {})
  local sortedSprite = API.Math_SortAODist(sprite)
  if sortedSprite.Distance > 2 then
    print ("Moving to sprite")
    API.DoAction_WalkerF(sortedSprite.Tile_XYZ)
  end
end

while (API.Read_LoopyLoop()) do
  if API.Get_tick() - lastTick > 3 then
    CompareSprite()
    CheckPorter()
    CheckAnim()
    lastTick = API.Get_tick()
  end
end