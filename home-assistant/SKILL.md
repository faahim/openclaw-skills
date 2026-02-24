---
name: home-assistant
description: >-
  Control Home Assistant devices, create automations, and monitor your smart home from your OpenClaw agent.
categories: [home, automation]
dependencies: [curl, jq, bash]
---

# Home Assistant Manager

## What This Does

Control your Home Assistant instance directly from your OpenClaw agent. Turn lights on/off, check sensor states, trigger automations, manage scenes, and monitor your smart home — all via CLI commands. No browser needed.

**Example:** "Turn off all lights, set thermostat to 22°C, and check if the front door is locked."

## Quick Start (5 minutes)

### 1. Get Your Home Assistant Token

In Home Assistant UI: Profile → Long-Lived Access Tokens → Create Token

```bash
# Set your HA credentials
export HA_URL="http://homeassistant.local:8123"
export HA_TOKEN="your_long_lived_access_token_here"

# Optional: persist in ~/.openclaw/env
echo 'export HA_URL="http://homeassistant.local:8123"' >> ~/.openclaw/env
echo 'export HA_TOKEN="your_token_here"' >> ~/.openclaw/env
```

### 2. Test Connection

```bash
bash scripts/ha.sh status

# Output:
# ✅ Home Assistant 2026.2.1 connected
# Location: Home
# Entities: 47 devices, 156 entities
# Uptime: 14d 3h 22m
```

### 3. List Your Devices

```bash
bash scripts/ha.sh entities

# Output:
# 💡 light.living_room — on (brightness: 80%)
# 💡 light.bedroom — off
# 🌡️ sensor.temperature — 22.5°C
# 🔒 lock.front_door — locked
# 📷 camera.front_porch — idle
# 🔌 switch.coffee_maker — off
```

## Core Workflows

### Workflow 1: Control Devices

**Turn lights on/off:**
```bash
bash scripts/ha.sh call light.turn_on light.living_room brightness=200
bash scripts/ha.sh call light.turn_off light.bedroom
```

**Control switches:**
```bash
bash scripts/ha.sh call switch.turn_on switch.coffee_maker
bash scripts/ha.sh call switch.turn_off switch.tv
```

**Set thermostat:**
```bash
bash scripts/ha.sh call climate.set_temperature climate.thermostat temperature=22
```

**Lock/unlock doors:**
```bash
bash scripts/ha.sh call lock.lock lock.front_door
bash scripts/ha.sh call lock.unlock lock.back_door
```

### Workflow 2: Check States

**Get entity state:**
```bash
bash scripts/ha.sh state light.living_room
# Output: on (brightness: 200, color_temp: 370)

bash scripts/ha.sh state sensor.outdoor_temperature
# Output: -2.3°C

bash scripts/ha.sh state binary_sensor.motion_hallway
# Output: off (last triggered: 23 min ago)
```

**Get all states by domain:**
```bash
bash scripts/ha.sh states light
# Lists all lights with their current state

bash scripts/ha.sh states sensor
# Lists all sensors with values
```

### Workflow 3: Scenes & Automations

**Activate a scene:**
```bash
bash scripts/ha.sh call scene.turn_on scene.movie_night
bash scripts/ha.sh call scene.turn_on scene.good_morning
```

**Trigger an automation:**
```bash
bash scripts/ha.sh call automation.trigger automation.welcome_home
```

**List automations:**
```bash
bash scripts/ha.sh automations
# Output:
# 🤖 automation.welcome_home — on (last: 2h ago)
# 🤖 automation.night_mode — on (last: 14h ago)
# 🤖 automation.leak_alert — on (never triggered)
```

### Workflow 4: Dashboard Summary

**Get full home summary:**
```bash
bash scripts/ha.sh dashboard

# Output:
# 🏠 Home Dashboard — 2026-02-24 22:53 UTC
# ─────────────────────────────────────────
# 💡 Lights: 3/8 on
#    • Living Room (80%) • Kitchen (100%) • Porch (30%)
# 🌡️ Climate: 22.5°C inside, -2°C outside
#    • Thermostat: heating to 22°C
#    • Humidity: 45%
# 🔒 Security: All locked ✅
#    • Front door: locked • Back door: locked
#    • Motion: no activity (23 min)
# ⚡ Energy: 2.4 kW current draw
#    • Today: 18.2 kWh ($2.73)
# 🤖 Automations: 12 active, 0 disabled
```

### Workflow 5: History & Logs

**Get entity history (last 24h):**
```bash
bash scripts/ha.sh history sensor.temperature 24h

# Output:
# sensor.temperature — Last 24 hours
# 00:00  21.8°C
# 04:00  20.2°C
# 08:00  21.0°C
# 12:00  23.1°C
# 16:00  22.8°C
# 20:00  22.5°C
# Avg: 21.9°C  Min: 20.2°C  Max: 23.1°C
```

**Get logbook events:**
```bash
bash scripts/ha.sh logs 50

# Output:
# [22:45] light.living_room turned on by automation.sunset
# [22:30] lock.front_door locked by user
# [22:15] binary_sensor.motion_hallway detected motion
```

## Configuration

### Environment Variables

```bash
# Required
export HA_URL="http://homeassistant.local:8123"   # Your HA URL
export HA_TOKEN="your_long_lived_access_token"      # Long-lived access token

# Optional
export HA_TIMEOUT=10          # API timeout in seconds (default: 10)
export HA_DASHBOARD_ENTITIES="light,sensor,lock,climate,switch"  # Dashboard domains
```

### Custom Dashboard Config

Create `config.yaml` to customize the dashboard view:

```yaml
# config.yaml
dashboard:
  sections:
    - name: "Lights"
      domain: light
      icon: "💡"
    - name: "Climate"
      entities:
        - sensor.indoor_temperature
        - sensor.outdoor_temperature
        - climate.thermostat
      icon: "🌡️"
    - name: "Security"
      entities:
        - lock.front_door
        - lock.back_door
        - binary_sensor.motion_hallway
        - camera.front_porch
      icon: "🔒"
    - name: "Energy"
      entities:
        - sensor.energy_current
        - sensor.energy_today
      icon: "⚡"

alerts:
  - entity: binary_sensor.water_leak
    state: "on"
    message: "🚨 Water leak detected!"
  - entity: lock.front_door
    state: "unlocked"
    after_minutes: 30
    message: "⚠️ Front door unlocked for 30+ minutes"
```

```bash
bash scripts/ha.sh dashboard --config config.yaml
```

## Advanced Usage

### Run as Monitoring Cron

```bash
# Check every 5 minutes, alert on issues
*/5 * * * * cd /path/to/skill && bash scripts/ha.sh monitor --config config.yaml >> logs/ha-monitor.log 2>&1
```

### Batch Commands

```bash
# Good night routine
bash scripts/ha.sh batch \
  "call light.turn_off all" \
  "call lock.lock lock.front_door" \
  "call lock.lock lock.back_door" \
  "call climate.set_temperature climate.thermostat temperature=19"
```

### JSON Output (for scripting)

```bash
bash scripts/ha.sh state light.living_room --json
# {"entity_id":"light.living_room","state":"on","attributes":{"brightness":200}}

bash scripts/ha.sh entities --json | jq '.[] | select(.state == "on")'
```

## Troubleshooting

### Issue: "Connection refused"

**Check:**
1. HA is running: `curl -s $HA_URL/api/ -H "Authorization: Bearer $HA_TOKEN"`
2. URL is correct (include port 8123)
3. Network: can you reach the HA host? `ping homeassistant.local`

### Issue: "401 Unauthorized"

**Fix:** Token expired or invalid. Create a new Long-Lived Access Token in HA UI.

### Issue: "Entity not found"

**Fix:** Check exact entity ID:
```bash
bash scripts/ha.sh entities | grep -i "living"
```

### Issue: "SSL certificate verify failed"

**Fix:** If using self-signed SSL:
```bash
export HA_INSECURE=true
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to HA REST API)
- `jq` (JSON parsing)
- Home Assistant instance with REST API enabled (default)
- Long-Lived Access Token from HA

## Key Principles

1. **Read-first** — Always check state before acting
2. **Batch when possible** — Combine related actions
3. **Monitor alerts** — Set up cron for critical sensors
4. **History matters** — Track trends for climate/energy optimization
