# Seren Stones

Lightweight RS3 script for cleansing Seren stones with optional crystal refills and world hopping.

## Overview

This script automates the basic Seren stone loop:

- cleanse stones
- refill cleansing crystals when needed
- optionally hop worlds on a timer or when nearby players are detected

It includes a simple GUI for configuration, runtime stats, and status tracking.

## Features

- Automated Seren stone cleansing
- Optional auto-purchase for cleansing crystals
- Configurable target crystal amount
- Optional world hopping
- Nearby-player escape hopping
- Session XP and XP/hr tracking
- Built-in Prayer XP failsafe
- Simple config and info GUI

## Requirements

### Script files

- `api.lua`
- `shop.lua`
- `SerenStones/SerenStonesGUI.lua`

## GUI

### Config

- Purchase crystals if needed
- Target crystal count
- Enable world hopping
- Hop if player nearby
- Hop interval range
- Nearby player range

### Info

- Session XP
- XP/Hr
- Crystal stats
- World hop stats
- Failsafe status

## Notes

- If auto-purchase is disabled and crystals run out, the script stops.
- Session XP is tracked from the moment you press Start.
- World hopping is optional.
