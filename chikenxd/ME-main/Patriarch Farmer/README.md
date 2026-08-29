# Patriarch Farmer

Automatically finds, kills, and loots Living Rock Patriarchs with world hopping.

## Library Requirements
- slib

## In-Game Requirements

- Magic Golem outfit set
- Necromancy weapons T70+
- Phantom on your action bar
- Revolution on
- Auto Retaliate on
- Remove AOE abilities from your action bar (to avoid aggro on other NPCs)

## Features

- Scans for Living Rock Patriarch and moves to attack
- Area loots all drops after each kill
- Sequential or randomized world hopping after each kill
- Configurable world hop delays
- Soul Split or Protect from Melee/Deflect Melee prayer support
- Food and prayer restore potion support with configurable thresholds
- Waits until out of combat before world hopping
- Cycles through all P2P worlds with cycle tracking
- ImGui config GUI with live status display

## Setup

1. Equip Magic Golem outfit and Necromancy weapons
2. Put **Phantom** on your action bar
3. Enable **Revolution** and **Auto Retaliate**
4. **Remove AOE abilities** from your action bar
5. Stand near the Living Rock Cavern spawn area
6. Start the script, configure options in the GUI, and click Start

## GUI Options

| Option | Description |
|--------|-------------|
| Soul Split | Keeps Soul Split active during combat |
| Protect from Melee | Uses Deflect Melee (curses) or Protect from Melee |
| Randomize world order | Hop worlds randomly instead of sequentially |
| World Hop Delay | Min/max delay before hopping (ms) |
| Enable Food | Eat food when HP drops below threshold |
| Enable Prayer Restore | Drink restore potions when prayer is low |
