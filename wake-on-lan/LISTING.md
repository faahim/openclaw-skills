# Listing Copy: Wake-on-LAN Manager

## Metadata
- **Type:** Skill
- **Name:** wake-on-lan
- **Display Name:** Wake-on-LAN Manager
- **Categories:** [home, automation]
- **Icon:** 🔌
- **Dependencies:** [bash, wakeonlan OR etherwake OR python3, ping]

## Tagline

Wake up remote machines with magic packets — manage devices by name, verify they're online.

## Description

Tired of walking to the server room to press a power button? Wake-on-LAN Manager lets your OpenClaw agent power on any machine on your network remotely using WoL magic packets.

Register your devices once with friendly names — then just say "wake up the NAS" instead of remembering MAC addresses. The skill handles sending the magic packet, supports multiple transport methods (wakeonlan, etherwake, python3, or pure bash), and can ping to verify the machine actually came online.

**What it does:**
- 🔌 Send WoL magic packets to any MAC address
- 📋 Device registry with friendly names (no more memorizing MACs)
- ✅ Ping verification — confirm machines actually woke up
- 🌐 Subnet/VLAN support — wake machines across network segments
- 🔄 Multiple fallback methods — works even without `wakeonlan` installed
- 📊 Status check — see which registered devices are online/offline
- ⏰ Schedule-ready — combine with OpenClaw cron to wake machines on schedule

Perfect for homelabbers, sysadmins, and anyone managing remote machines that need to be powered on without physical access.

## Quick Start Preview

```bash
# Wake by MAC
bash scripts/wol.sh wake --mac AA:BB:CC:DD:EE:FF

# Register a device
bash scripts/wol.sh add --name nas --mac AA:BB:CC:DD:EE:FF --ip 192.168.1.100

# Wake by name and verify
bash scripts/wol.sh wake --name nas --wait 60
```

## Core Capabilities

1. Magic packet sending — multiple methods with automatic fallback
2. Device registry — name-based lookup, no MAC memorization
3. Online verification — ping until host responds or timeout
4. Multi-device wake — wake several machines at once
5. Subnet broadcast — custom broadcast for cross-VLAN WoL
6. Status dashboard — check which devices are online/offline
7. Cross-platform — Linux, macOS, WSL
8. Zero-config — works with just a MAC address, registry optional
9. Cron-friendly — combine with scheduled tasks for automated wake
10. Multiple transports — wakeonlan, etherwake, python3, bash/udp
