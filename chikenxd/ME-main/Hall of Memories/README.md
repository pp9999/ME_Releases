# Hall of Memories

Hall of Memories Divination script.

## Requirements

- Start inside Hall of Memories.

## Features

- Modern ImGui control panel.
- Runtime tab with XP gained, XP/hr, TTL, jar counts, and current target.
- Optional 2-tick mode.
- Optional world hopping.
- Handles periodic random events such as Seren spirits.

## Setup

1. Place `HallOfM.lua` in your Lua scripts folder.
2. Stand in Hall of Memories.
3. Start the script.
4. Choose the memory type in the Main tab.
5. Press Start.

## GUI

### Main

- Select memory type.
- Toggle 2-tick mode.
- View summary XP and status.
- Start, pause, resume, or stop.

### Runtime

- Full runtime details.
- Jar counts.
- Target state.
- XP/hr and TTL.

### World Hopping

- Enable or disable world hopping.
- Customize min and max hop interval sliders.
- View current world, next hop timer, completed hops, and failures.

## 2-Tick Mode

When 2-tick mode is off, the script does not re-click memories after XP drops. It only sends the initial click needed to begin harvesting.

When 2-tick mode is on, XP-drop re-clicking is enabled, but it is still gated by movement, animation, stationary time, action cooldown, and harvest animation checks.
