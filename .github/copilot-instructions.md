# Copilot Instructions — Lua_Scripts

This workspace is **TheGreatBackUpProject**: a public backup and contribution hub for
MemoryError (ME) and RuneLite Lua automation scripts. It holds two **incompatible** script
families plus a large number of third-party contributed folders.

---

## Read these first

| File | What it is |
| --- | --- |
| `AGENTS.md` | Canonical, in-depth **OSRS / RuneLite** reference: `RL_*` functions, `AllObject`, entity types, tab indexes. Read this before writing OSRS code. |
| `api.lua` | **RS3 / MemoryError** API surface (`API.VERSION = 1.081`). Source of truth for `API.DoAction_*` and `API.OFF_ACT_*` routes. |
| `apiosrs.lua` | **OSRS / RuneLite** wrapper (`APIOSRS.VERSION = 1.000`) exposing `APIOSRS.RL_*`. |
| `slib.lua` | Spectre011's utility library (`Slib:*` logging, validation, sleeps) — also the reference for credit headers. |

---

## Choose the right API — never mix them

| Target | Requires | Primary calls |
| --- | --- | --- |
| **OSRS (RuneLite)** | `require("api")` + `require("apiosrs")` | `APIOSRS.RL_ClickEntity`, `RL_ClickTile`, `RL_ClickSpellbook`, `RL_OpenTab`, `API.ReadAllObjectsArray` |
| **RS3 (MemoryError)** | `require("api")` only | `API.DoAction_NPC`, `API.DoAction_Object1`, `API.OFF_ACT_*`, `Inventory`, `Bank` |

Do not call `APIOSRS.RL_*` from an RS3 script, and do not call `API.DoAction_*` /
`API.OFF_ACT_*` from an OSRS script. Match the flavor of the file you are editing.

---

## OSRS / RuneLite conventions

Boilerplate:

- `local API = require("api")` and `local APIOSRS = require("apiosrs")`
- Start with `API.Write_LoopyLoop(true)`, loop with `while API.Read_LoopyLoop() do ... end`
- End each iteration with `API.RandomSleep2(wait, sleep, sleep2)` (all values in **ms**)

Key helpers:

- `API.RandomSleep2(wait, sleep, sleep2)` — `wait` always applied, `sleep`/`sleep2` random additions
- `API.CheckAnim(loops)` — `true` while the local player is animating
- `API.Write_ScripCuRunning0(msg)` — status line text
- `APIOSRS.RL_IsWidgetSelected()` — true after "Use" on an inventory item

Entity types (`RL_ClickEntity`, `ReadAllObjectsArray`):

- `0` game object · `1` NPC · `2` player · `3` ground item *(not working in `RL_ClickEntity`)* · `5` projectile · `12` decor · `93` inventory interface

Tabs (`RL_OpenTab` / `RL_GetOpenTab`): `0` Combat, `1` Skills, `2` Quests, `3` Inventory,
`4` Equipment, `5` Prayer, `6` Spellbook, `7` Clan, `8` Friends, `9` Account, `10` Logout,
`11` Emotes, `12` Music.

Root-level OSRS scripts are prefixed `RL_` (e.g. `RL_alch.lua`, `RL_cook.lua`).

---

## RS3 / MemoryError conventions

Boilerplate:

- `local API = require("api")`
- Action-loop scripts often start with `API.Write_LoopyLoop(true)` and loop on `API.Read_LoopyLoop()`
- Long-lived AFK loops use `API.SetMaxIdleTime(n)`, `API.Write_fake_mouse_do(true)`,
  `API.DoRandomEvents()`, `API.SetDrawTrackedSkills(true)`

Key helpers:

- `API.DoAction_NPC(action, route, { ids }, distance)` and `API.DoAction_Object1(action, route, { ids }, distance)`
- `API.OFF_ACT_InteractNPC_route`, `API.OFF_ACT_AttackNPC_route`, `API.OFF_ACT_GeneralObject_route0..3` — named action routes
- Container classes: `Inventory:IsFull()`, `Inventory:Contains(id)`, `Bank:IsOpen()`, `Bank:DepositInventory()`
- `API.RandomSleep2(wait, sleep, sleep2)` for timing; `API.CheckAnim(100)` to wait out animations

`slib.lua` / `spectre.lua` users should log and validate through the library:

- `Slib:Info(...)`, `Slib:Warn(...)`, `Slib:Error(...)`
- `Slib:Sanitize(value, type, name)`, `Slib:ValidateParams(params)`
- `Slib:Sleep(ms)`, `Slib:RandomSleep(min, max)`, `Slib:SleepUntil(fn, timeout)`

---

## Working rules in this repo

- **Match the file's existing API flavor.** OSRS scripts stay OSRS; RS3 scripts stay RS3.
- **Leave third-party contributed folders untouched** unless explicitly asked. This includes
  author-named and mirrored folders such as `Public-ME-Scripts-main/`, `chikenxd/`,
  `animoofps/`, `M-qq-stuff-main/`, `rocks-main/`, and any `*-main` / `*-master` directory.
- **Preserve author credits, headers and license banners** (see the header block in `slib.lua`).
  This repo is a backup; authorship belongs to the original authors.
- **Do not add external dependencies.** Scripts run against the ME / RuneLite engine only.
- **Keep existing patterns**: the `Write_LoopyLoop` / `Read_LoopyLoop` loop, `API.RandomSleep2`
  timing (avoid raw `sleep`), ImGui overlay setup (`API.CreateIG_answer()` outside the loop),
  and status-line updates.
- **New personal scripts go at the workspace root.** Scripts that belong to a bundle stay in
  that bundle's folder.
- Changes should be **additive and safe** — this is a backup/mirror repo, not a refactor target.

---

## Contributing

`README.md` is the public entry point. Fixes are welcome as pull requests; non-technical users
are asked to open an issue instead. Do not rewrite or delete existing scripts when adding fixes —
prefer additive, reviewable changes.
