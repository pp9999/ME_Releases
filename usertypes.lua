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
