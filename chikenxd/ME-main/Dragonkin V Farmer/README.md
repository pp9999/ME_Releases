# Dragonkin V Farmer

Automatically farms Dragonkin archaeology debris with API-randomized delays, optional artifact redemption, repair queue support, and native API world hopping.

## Library Requirements

- api

## In-Game Requirements

- Access to the Dragonkin archaeology debris area near Daemonheim
- Archaeology tools and materials needed for restoring the selected artifacts
- Grace of the elves on your action bar if using porter recharge support
- Ring of kinship on your action bar for Daemonheim travel
- Bank preset set up for your Dragonkin excavation inventory

## Features

- Excavates Castle hall rubble or Tunnelling equipment repository
- Uses `API.RandomSleep2` timing
- Uses `WorldHop:GetRandomWorld(true)` and `WorldHop:Hop(targetWorld)` for world hopping
- No scheduled farm-run or Herb Runs integration
- Optional artifact restoration and Sharrigan turn-ins
- Standalone redeem mode for restored artifacts
- Repair queue mode for selected Dragonkin artifacts
- Porter charge tracking and Grace of the elves recharge attempts
- Complete tome destruction handling
- Timed and nearby-player world hop support
- ImGui config GUI with live runtime status

## Setup

1. Put **Grace of the elves** on your action bar if you want porter recharge support
2. Put **Ring of kinship** on your action bar for Daemonheim travel
3. Configure your bank preset for Dragonkin excavation
4. Start the script and choose your excavation spot in the GUI
5. Configure world hopping or repair queue options if needed
6. Click **Start Script**

## GUI Options

| Option | Description |
|--------|-------------|
| Starting Spot | Selects Castle hall rubble or Tunnelling equipment repository |
| Enable Debug Logs | Prints extra diagnostic information |
| Redeem Target | Stops standalone redemption after the selected number of sets |
| Repair Queue | Adds selected Dragonkin artifacts and quantities to repair |
| Enable Timed World Hop | Hops after a randomized configured interval |
| Enable Nearby Player Hop | Hops if another player is detected nearby |
| Nearby Player Hop Radius | Radius used for direct player scanning |
