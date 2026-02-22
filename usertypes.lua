--define members of userdata here
--some notes: Lua stores all numbers in 8 bytes size. In double actually
--string is text.
--any type: just pass any kind of data object, basically a pointer pass,

---@class returntext
---@field Name string
---@field Nr number

---@class QWPOINT
---@field bottom number
---@field right number
---@field left number
---@field top number

---@class WPOINT
---@field x number
---@field y number
---@field z number
---@field fromLocal fun(localX: number, localY: number, plane: number): WPOINT -- Convert local coords (0-63) to world coords

---@class FFPOINT
---@field x number
---@field y number
---@field z number

---@class Abilitybar
---@field slot number
---@field id number
---@field name string
---@field hotkey string
---@field cooldown_timer number
---@field info IInfo
---@field action string
---@field enabled boolean
---@field modkey number

---@class AllObject
---@field Mem number
---@field MemE number
---@field TileX number
---@field TileY number
---@field TileZ number
---@field Id number
---@field Life number
---@field Anim number
---@field Name string
---@field Action string
---@field Floor number
---@field Amount number
---@field Type number
---@field Bool1 number
---@field ItemIndex number
---@field ViewP number
---@field ViewF number
---@field Distance number
---@field Cmb_lv number
---@field Unique_Id number
---@field CalcX number
---@field CalcY number
---@field Tile_XYZ FFPOINT
---@field Pixel_XYZ WPOINT

---@class Bbar
---@field id number
---@field found boolean
---@field text string
---@field conv_text number

---@class ChatTexts
---@field name string
---@field text string
---@field text_extra1 string
---@field text_extra2 string
---@field mem_loc number
---@field pc_time_stamp number
---@field pos_found number
---@field time_total number

---@class VB
---@field state number
---@field addr number
---@field indexaddr_orig number
---@field id number

---@class IInfo
---@field x number
---@field xs number
---@field y number
---@field ys number
---@field box_x number
---@field box_y number
---@field scroll_y number
---@field id1 number
---@field id2 number
---@field id3 number
---@field itemid1 number
---@field itemid1_size number
---@field itemid2 number
---@field hov boolean
---@field textids string
---@field textitem string
---@field memloc number
---@field memloctop number
---@field index number
---@field fullpath string
---@field fullIDpath string
---@field notvisible boolean
---@field OP number
---@field xy number

---@class InterfaceComp5
---@field id1 number
---@field id2 number
---@field id3 number
---@field memloc number

---@class IG_answer
---@field box_name string
---@field box_start FFPOINT{0,0,0}
---@field box_size FFPOINT{0,0,0}
---@field colour ImColor{0,0,0}
---@field radius number
---@field thickness number
---@field how_many_sec number
---@field box_ticked boolean
---@field return_click boolean
---@field remove boolean
---@field int_value number
---@field mem_local number
---@field mem_global number
---@field string_value string
---@field stringsArr userdata --vector<string>
---@field string_input string

---@class ImColor
---@field red number
---@field green number
---@field blue number
---@field alpha number

---@class Skill
---@field interfaceIdx number
---@field id number
---@field name string
---@field xp number
---@field level number
---@field boostedLevel number
---@field vb number

---@class inv_Container_struct -- is shared by various functions
---@field item_id number -- filled by container
---@field item_stack number -- filled by container
---@field item_slot number  -- filled by container
---@field item_name string  -- filled by InventoryClass
---@field item_cat number  -- filled by InventoryClass
---@field item_gelimit number  -- filled by InventoryClass
---@field item_highalch number  -- filled by InventoryClass
---@field item_noted boolean  -- filled by InventoryClass
---@field item_stackable boolean  -- filled by InventoryClass
---@field item_tradeable boolean  -- filled by InventoryClass
---@field item_bankable boolean  -- filled by InventoryClass
---@field item_interface WPOINT  -- filled by InventoryClass
---@field item_xyz WPOINT  -- filled by InventoryClass
---@field Pmap table<number>  -- filled by InventoryClass
---@field Extra_mem table<number> -- by debug so never
---@field Extra_ints table<number>  -- filled by container

---@class General_Container
---@field id number -- filled by container
---@field ID_stack inv_Container_struct -- contains loose info at item_id, item_stack, item_slot, Extra_ints, rest are reserved for InventoryClass

---@class PerkInfo
---@field perkId number
---@field perkName string

---@class GizmoInfo
---@field gizmoNumber number
---@field perks PerkInfo[]

---@class AugmentedItem
---@field itemId number
---@field itemName string
---@field slot number
---@field itemExp number
---@field itemLevel number
---@field gizmoCount number
---@field gizmos GizmoInfo[]
---@field isEquipped boolean
---@field containerType number

---@class TrackedSkill
---@field id number
---@field name string
---@field startXP number
---@field currentXP number
---@field color ImColor{0,0,0}

---@class EventData
---@field name string --there was up to 3 depending on chat
---@field name2 string
---@field name3 string
---@field chat_type string --chat name if any
---@field text string --chat text
---@field timestamp1 number --millisecs
---@field timestamp2 string --date
---@field timestamp3 number --tick
---@field skillIndex number
---@field skillName string
---@field exp number
---@field ItemID number
---@field ItemAM number

---@class EmbedFooter
---@field text string
---@field icon_url string
---@field proxy_icon_url string

---@class EmbedImage
---@field url string
---@field proxy_url string
---@field height number
---@field width number

---@class EmbedThumbnail
---@field url string
---@field proxy_url string
---@field height number
---@field width number

---@class EmbedAuthor
---@field name string
---@field url string
---@field icon_url string
---@field proxy_icon_url string

---@class EmbedField
---@field name string
---@field value string
---@field inline boolean

---@class HttpResponse
---@field statusCode number
---@field body string
---@field GetBodyAsJson fun(): table

---@class Target_data
---@field Target_Name string -- Target entity name
---@field Hit_percent number -- Hit chance percentage
---@field Cmb_lv number -- Combat level
---@field Hitpoints number -- Current hitpoints
---@field Buff_stack TargetBuff[] -- All buffs/debuffs on target

---@class TargetBuff
---@field id number -- Varbit value (stack count, duration, etc.)
---@field varbitId number -- Varbit ID
---@field spriteId number -- Sprite/icon ID (BuffID)
---@field name string -- Buff/debuff name
---@field isDebuff boolean -- true = debuff, false = buff

---@class SPLAT
---@field Type number
---@field Amount number
---@field EInfo1 number
---@field EInfo2 number
---@field Time number
---@field Slot number

---@class Varbit
---@field id number
---@field varp number
---@field startBit number
---@field endBit number
---@field domain number

---@class SkillData
---@field id number
---@field level number

---@class QuestData
---@field id number
---@field name string
---@field list_name string alternative name seen in the sorting screen (often the same name, but not always)
---@field members boolean
---@field category number
---@field difficulty number
---@field points_reward number how many points received as an award for completing the quest
---@field points_required number how many quest points are required to start
---@field progress_start_bit number starting step number of quest
---@field progress_end_bit number final step number of quest
---@field progress_varbit number vb/varp for tracking progress (the :getProgess() function checks this for you)
---@field required_quests QuestData[] Returns a table of QuestData objects for the Quests that are required to start this quest
---@field required_skills SkillData[] Returns a table of SkillData objects providing the skill ID <> level required to start the quest
---@field getProgress function Returns the progress of the quest as a number
---@field isStarted function Returns true if the quest is started
---@field isComplete function Returns true if the quest is complete
---@field getVarbits function Returns a table of IDs, represting the varbit IDs linked to this Quest indirectly

---@class ItemData
---@field id number
---@field name string
---@field tradeable boolean
---@field category number Item Category ID, see some example IDs below
---@field ge_limit number Item limit for buying in GE
---@field high_alch number High alch value
---@field low_alch number Low alch value
---@field value number Item value
---@field stackable boolean if item is stackable or not
---@field bankable boolean if item is bankable or not
---@field alchable boolean if item is alchable or not
---@field noted boolean if the item is the noted version or not
---@field HasParam fun(self: ItemData, param: number|string): boolean @ Checks if item has a parameter by ID or name
---@field GetParam fun(self: ItemData, param: number): string|number @ Gets raw parameter value by ID
---@field GetParamInt fun(self: ItemData, param: number): number @ Gets integer parameter value by ID
---@field GetParamString fun(self: ItemData, param: number): string @ Gets string parameter value by ID
---@field GetAllParams fun(self: ItemData): table<number, string|number> @ Gets table of all parameters

---@class AchievementData
---@field id number
---@field name string
---@field description string
---@field members boolean
---@field category number
---@field sub_category number
---@field getProgress function Returns the progress of the Achievement as a number
---@field isStarted function Returns true if the Achievement is started
---@field isCompleted function Returns true if the Achievement is complete

---@class StructData
---@field id number
---@field params table<string, string|number>
---@field isCompleted function Returns true if the Achievement is complete

---@class DBRowData
---@field id number
---@field tableId number
---@field GetInt function Returns the first int value at column index, or default (0)
---@field GetString function Returns the first string value at column index, or default ("")
---@field GetIntArray function Returns all int values at column index as a table
---@field GetStringArray function Returns all string values at column index as a table
---@field GetColumnIds function Returns all column indices that have data