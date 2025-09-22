# ⚒️ Optimal Construction Hotspot Builder 

  **Automatically finds, follows, and interacts with optimal construction hotspots in Fort Forinthry.**

## Features

- **Hotspot Detection**: Scans for optimal construction hotspots.
- **Optimal Targeting**: Moves to and interacts with the closest hotspot.
- **XP Monitoring**: Detects Construction XP gains to confirm successful actions.
- **Retry System**: Retries interactions up to 3 times if no XP is detected, then stops.
- **Stopping**: Automatically stops if no hotspots are found or after failed retries.

## How to Use

1. **Prerequisites/libraries**:
   - api.lua in the script folder

2. **Setup**:
   - Manually select or create your building of choice.
   - be near the hotspots
   - Start the script.

3. **Operation**:
   - The script will scan for hotspots within the search distance.
   - It interacts with the closest hotspot and waits for XP gain.
   - If XP is gained, it continues; otherwise, it retries.
   - Stops after 3 failed retries or if no hotspots are detected.

4. **Stopping**:
   - The script stops automatically when no contruction XP drop or lack of hotspots.
   - You can manually stop via injector.

## Configuration

Edit the config section at the top of the script if some ID is different for you:

```lua
local HOTSPOT_IDS = {125061, 125065}  -- Add more IDs if needed
local SEARCH_DISTANCE = 60             -- Distance to scan for hotspots
local DEBUG = true                    -- Enable debug logging
