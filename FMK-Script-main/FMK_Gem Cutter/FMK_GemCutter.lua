-- Title: FMK_Gem Cutter
-- Author: FourthMK
-- Description: Gem Cutter for all uncut gems. load last preset from bank.
-- Version: 1.4
-- Category: Crafting

-- Libraries
local API   = require("api")
local UTILS = require("utils")
local BANK  = require("bank")

API.SetDrawLogs(true)
API.Write_fake_mouse_do(false)
API.SetDrawTrackedSkills(true)

local version = "1.3"

-- =========================== Gem Data ===========================--
local GEMS = {
  { name = "Opal",        uncut = 1625, cut = 1609 },
  { name = "Jade",        uncut = 1627, cut = 1611 },
  { name = "Red topaz",   uncut = 1629, cut = 1613 },
  { name = "Sapphire",    uncut = 1623, cut = 1607 },
  { name = "Emerald",     uncut = 1621, cut = 1605 },
  { name = "Ruby",        uncut = 1619, cut = 1603 },
  { name = "Diamond",     uncut = 1617, cut = 1601 },
  { name = "Dragonstone", uncut = 1631, cut = 1615 },
}

-- =========================== State ===========================--
local startTime        = os.time()
local last_cut_time    = os.time()
local run              = false
local selectedIndex    = 4   -- default Sapphire (1-based)
local lastRestockTry   = 0
local RESTOCK_COOLDOWN = 5

-- Session counters for metrics
local sessionCuts        = 0
local lastCutInvCount    = 0
local lastGemIndex       = selectedIndex
-- Optional: if your preset loads N uncut per run, set it here to improve "Runs until empty"
local presetBatchSize    = nil  -- e.g., 27

-- Bank stock cache to avoid spamming BANK:GetItemAmount while bank is closed
local bankStockCache = { value = 0, lastUpdate = 0 }

-- =========================== UI ===========================--
local btnToggle = API.CreateIG_answer()
btnToggle.box_name   = "Start"
btnToggle.box_start  = FFPOINT.new(12, 486, 0)
btnToggle.box_size   = FFPOINT.new(90, 28, 0)
btnToggle.colour     = ImColor.new(60, 130, 220)
btnToggle.tooltip_text = "Start/Pause"

-- ComboBox using comboBoxSelect pattern (stringsArr + return_click + string_value)
local comboBoxSelect = API.CreateIG_answer()
comboBoxSelect.box_name  = "Gem Type"
comboBoxSelect.box_start = FFPOINT.new(112, 486, 0)
comboBoxSelect.box_size  = FFPOINT.new(190, 0, 0)
comboBoxSelect.stringsArr = {}
do
  table.insert(comboBoxSelect.stringsArr, "Select a gem")
  for i = 1, #GEMS do
    table.insert(comboBoxSelect.stringsArr, GEMS[i].name)
  end
end

local function fmtHMS(sec)
  sec = math.max(0, sec)
  return string.format("%02d:%02d:%02d", math.floor(sec/3600), math.floor(sec%3600/60), sec%60)
end

-- =========================== Metrics UI ===========================--
local function buildMetrics()
  local now        = os.time()
  local stateStr   = run and "Running" or "Paused"
  local gem        = GEMS[selectedIndex]
  local uncutCount = Inventory:GetItemAmount(gem.uncut) or 0
  local cutCount   = Inventory:GetItemAmount(gem.cut)   or 0
  local processing = API.isProcessing()
  local hours      = math.max((now - startTime) / 3600, 0.0001)
  local cuts       = sessionCuts or 0
  local cutsPerHour = cuts / hours

  local bankStock      = bankStockCache.value
  local batchSize      = math.max((presetBatchSize or uncutCount), 1)
  local runsUntilEmpty = math.floor(bankStock / batchSize)

  local metrics = {
    {"Script",           "Gem Cutter" .. ((version and (" - " .. tostring(version))) or "")},
    {"State",            stateStr},
    {"Runtime",          fmtHMS(now - startTime)},
    {"Gem type",         gem.name},
    {"Uncut in inv",     tostring(uncutCount)},
    {"Cut in inv",       tostring(cutCount)},
    {"Processing",       tostring(processing)},
    {"Gem cut",          string.format("%d (%.1f/hr)", cuts, cutsPerHour)},
    {"Bank stock",       tostring(bankStock)},
    {"Runs until empty", tostring(runsUntilEmpty)},
  }
  return metrics
end

local function drawUI()
  -- Start/Pause
  API.DrawBox(btnToggle)
  if btnToggle.return_click then
    run = not run
    btnToggle.box_name = (run and "Pause" or "Start")
    btnToggle.return_click = false
  end

  -- ComboBox (comboBoxSelect usage)
  API.DrawComboBox(comboBoxSelect, false)
  if comboBoxSelect.return_click then
    comboBoxSelect.return_click = false
    local chosen = comboBoxSelect.string_value or ""
    for i = 1, #GEMS do
      if chosen == GEMS[i].name then
        selectedIndex = i
        break
      end
    end
  end

  -- Draw metrics
  API.DrawTable(buildMetrics())
end

-- =========================== Helpers ===========================--
local function hasUncut(id)
  return Inventory:Contains(id)
end

-- Refresh bank stock cache only when we actually open the bank (prevents log spam)
local function refreshBankStock(uncutId)
  bankStockCache.value = BANK:GetItemAmount(uncutId) or 0
  bankStockCache.lastUpdate = os.time()
end

local function tryRestock(uncutId)
  local now = os.time()
  if now - lastRestockTry < RESTOCK_COOLDOWN then return false end
  lastRestockTry = now
  API.logInfo("Attempting to load last preset")
  local ok = BANK:LoadLastPreset()
  UTILS.randomSleep(400)
  -- After a successful bank interaction, safely refresh the cached stock once
  if ok then
    pcall(function() refreshBankStock(uncutId) end)
  end
  return ok
end

local function startCutting(uncutId)
  -- Use the uncut gem (RS3 toolbelt covers chisel)
  if not Inventory:DoAction(uncutId, 1, API.OFF_ACT_GeneralInterface_route) then
    API.logWarn("Failed to use uncut gem: " .. tostring(uncutId))
    return false
  end

  -- Briefly ensure the craft starts (non-blocking overall loop)
  local ok = UTILS.SleepUntilWithoutChecks(function()
    return API.isProcessing() or UTILS.isCraftingInterfaceOpen()
  end, 3, "crafting window", true)

  if not ok then
    -- Fallback: choose default craft option
    API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1370, 30, -1, API.OFF_ACT_GeneralInterface_Choose_option)
    UTILS.randomSleep(250)
  end

  local engaged = UTILS.SleepUntilWithoutChecks(function()
    return API.isProcessing()
  end, 2, "processing engaged", true)

  if not engaged then
    API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1370, 30, -1, API.OFF_ACT_GeneralInterface_Choose_option)
    engaged = UTILS.SleepUntilWithoutChecks(function()
      return API.isProcessing()
    end, 2, "processing engaged", true)
  end

  return engaged
end

-- =========================== Main Loop ===========================--
API.Write_LoopyLoop(true)
API.logInfo("Gem Cutter started")

while API.Read_LoopyLoop() do
  API.DoRandomEvents()
  UTILS:antiIdle()

  local gem = GEMS[selectedIndex]

  -- UI and metrics
  drawUI()

  -- Update sessionCuts by tracking increases in cut gems in inventory
  do
    if selectedIndex ~= lastGemIndex then
      lastCutInvCount = Inventory:GetItemAmount(gem.cut) or 0
      lastGemIndex = selectedIndex
    else
      local curCut = Inventory:GetItemAmount(gem.cut) or 0
      if curCut > lastCutInvCount then
        sessionCuts = sessionCuts + (curCut - lastCutInvCount)
        last_cut_time = os.time()
      end
      lastCutInvCount = curCut
    end
  end

  if run and os.time() - last_cut_time > 10 then
    API.logInfo("No crafting XP for 10 seconds, stopping script")
    break
  end

  if run then
    if not hasUncut(gem.uncut) then
      if tryRestock(gem.uncut) and hasUncut(gem.uncut) then
        API.logInfo("Restocked uncut " .. gem.name)
      else
        API.logWarn("Out of uncut " .. gem.name .. ". Waiting...")
      end
    else
      if not API.isProcessing() then
        local started = startCutting(gem.uncut)
        if not started then
          UTILS.randomSleep(350)
        end
      else
        -- Non-blocking while processing so metrics/UI keep updating
        UTILS.randomSleep(150)
      end 
    end
  end

  UTILS.randomSleep(200)
end

API.logInfo("Gem Cutter stopped")
