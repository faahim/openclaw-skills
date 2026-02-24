# Listing Copy: Home Assistant Manager

## Metadata
- **Type:** Skill
- **Name:** home-assistant
- **Display Name:** Home Assistant Manager
- **Categories:** [home, automation]
- **Price:** $15
- **Dependencies:** [curl, jq, bash]

## Tagline

Control your smart home from your OpenClaw agent — lights, locks, climate, automations

## Description

### The Problem

Managing your smart home means opening an app, navigating through menus, or shouting at a voice assistant that misunderstands half the time. When you want to check if you locked the door, adjust the thermostat, or run a bedtime routine, it's multiple taps across multiple interfaces.

### The Solution

Home Assistant Manager lets your OpenClaw agent control your entire Home Assistant setup via simple CLI commands. Turn lights on/off, check sensor states, trigger automations, lock doors, set thermostats — all from a single script. Set up monitoring cron jobs to alert you about water leaks, unlocked doors, or unavailable devices.

### Key Features

- ✅ Control all HA devices — lights, switches, locks, climate, scenes
- 📊 Dashboard summary — one command for full home status
- 🔔 Monitoring mode — cron-ready alerts for leaks, security, outages
- 📈 History tracking — sensor trends and state changes
- 🤖 Trigger automations and scenes from CLI
- 🔌 Batch commands — run entire routines in one call
- 🔐 Secure — uses HA Long-Lived Access Tokens
- ⚡ Fast — direct REST API, no middleware

### Who It's For

Anyone running Home Assistant who wants their OpenClaw agent to monitor and control smart home devices without a browser or app.

## Core Capabilities

1. Device control — Turn lights, switches, locks, thermostats on/off with parameters
2. State checking — Read any entity's current state and attributes
3. Dashboard view — Full home summary (lights, climate, security, automations)
4. Scene activation — Trigger HA scenes for preset configurations
5. Automation management — List, trigger, and monitor automations
6. History & trends — View sensor history with min/max/avg stats
7. Logbook access — Recent events and state changes
8. Monitoring mode — Automated checks for leaks, security, availability
9. Batch execution — Chain multiple commands in one call
10. JSON output — Pipe-friendly output for scripting

## Installation Time
**5 minutes** — Set HA_URL and HA_TOKEN, run status check

## Pricing Justification

**Why $15:**
- LarryBrain home category is nearly empty — high demand, low supply
- Comparable tools: HA CLI add-ons are free but require HA OS; this works from any OpenClaw
- Complexity: Medium (REST API integration, multiple commands, monitoring)
- Real value: saves opening HA UI dozens of times daily
