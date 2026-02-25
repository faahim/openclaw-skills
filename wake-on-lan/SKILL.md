---
name: wake-on-lan
description: >-
  Wake up remote machines on your network by sending magic packets. Manage a device registry, wake single or multiple hosts, and verify they come online.
categories: [home, automation]
dependencies: [bash, wakeonlan OR etherwake, ping]
---

# Wake-on-LAN Manager

## What This Does

Remotely power on computers, servers, and NAS devices on your local network using Wake-on-LAN (WoL) magic packets. Manage a registry of devices with friendly names so you can say "wake up my NAS" instead of remembering MAC addresses.

**Example:** "Wake up 3 servers before deploying, wait until they're all online, then confirm."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y wakeonlan

# Mac (Homebrew)
brew install wakeonlan

# Alpine
apk add etherwake

# Or use Python fallback (no install needed)
# The script includes a pure-bash fallback using /dev/udp
```

### 2. Wake a Machine

```bash
# By MAC address
bash scripts/wol.sh wake --mac AA:BB:CC:DD:EE:FF

# Output:
# [2026-02-25 05:53:00] 🔌 Sending magic packet to AA:BB:CC:DD:EE:FF ...
# [2026-02-25 05:53:00] ✅ Magic packet sent to AA:BB:CC:DD:EE:FF (broadcast 255.255.255.255:9)
```

### 3. Register Devices (Optional)

```bash
# Add a device to your registry
bash scripts/wol.sh add --name "nas" --mac "AA:BB:CC:DD:EE:FF" --ip "192.168.1.100"

# Now wake by name
bash scripts/wol.sh wake --name nas

# List all registered devices
bash scripts/wol.sh list
```

## Core Workflows

### Workflow 1: Wake a Single Machine

```bash
bash scripts/wol.sh wake --mac AA:BB:CC:DD:EE:FF

# With verification (ping until online)
bash scripts/wol.sh wake --mac AA:BB:CC:DD:EE:FF --ip 192.168.1.100 --wait 120
```

**Output:**
```
[2026-02-25 05:53:00] 🔌 Sending magic packet to AA:BB:CC:DD:EE:FF ...
[2026-02-25 05:53:00] ✅ Magic packet sent
[2026-02-25 05:53:00] ⏳ Waiting for 192.168.1.100 to come online (timeout: 120s)...
[2026-02-25 05:53:25] ✅ 192.168.1.100 is ONLINE (took 25s)
```

### Workflow 2: Wake Multiple Machines

```bash
# Wake all registered devices
bash scripts/wol.sh wake-all

# Wake specific group
bash scripts/wol.sh wake --name "nas" --name "server1" --name "server2"
```

### Workflow 3: Device Registry Management

```bash
# Add device
bash scripts/wol.sh add --name "homelab-1" --mac "AA:BB:CC:11:22:33" --ip "192.168.1.50" --desc "Proxmox node 1"

# List devices
bash scripts/wol.sh list

# Remove device
bash scripts/wol.sh remove --name "homelab-1"

# Check which devices are currently online
bash scripts/wol.sh status
```

**Output of `list`:**
```
NAME         MAC                IP             STATUS    DESCRIPTION
nas          AA:BB:CC:DD:EE:FF  192.168.1.100  online    Synology NAS
homelab-1    AA:BB:CC:11:22:33  192.168.1.50   offline   Proxmox node 1
desktop      AA:BB:CC:44:55:66  192.168.1.10   online    Main workstation
```

### Workflow 4: Wake on Schedule (with OpenClaw cron)

Use OpenClaw's cron to wake machines on a schedule:

```bash
# Wake NAS every morning at 8am
# Add cron job: "bash /path/to/scripts/wol.sh wake --name nas"
```

### Workflow 5: Wake via Subnet/VLAN

```bash
# Send to specific subnet broadcast
bash scripts/wol.sh wake --mac AA:BB:CC:DD:EE:FF --broadcast 192.168.2.255

# Send to specific port
bash scripts/wol.sh wake --mac AA:BB:CC:DD:EE:FF --port 7
```

## Configuration

### Device Registry File

Stored at `~/.config/wol/devices.json`:

```json
{
  "devices": [
    {
      "name": "nas",
      "mac": "AA:BB:CC:DD:EE:FF",
      "ip": "192.168.1.100",
      "broadcast": "255.255.255.255",
      "port": 9,
      "description": "Synology NAS"
    },
    {
      "name": "server1",
      "mac": "11:22:33:44:55:66",
      "ip": "192.168.1.50",
      "broadcast": "255.255.255.255",
      "port": 9,
      "description": "Ubuntu homelab server"
    }
  ]
}
```

### Environment Variables

```bash
# Override default broadcast address
export WOL_BROADCAST="192.168.1.255"

# Override default port (default: 9)
export WOL_PORT="9"

# Override config directory
export WOL_CONFIG_DIR="$HOME/.config/wol"
```

## Troubleshooting

### Issue: "wakeonlan: command not found"

The script includes a pure-bash fallback using `/dev/udp`. If that's not available either:

```bash
# Install wakeonlan
sudo apt-get install wakeonlan  # Debian/Ubuntu
brew install wakeonlan           # macOS
pip install wakeonlan            # Python fallback
```

### Issue: Machine doesn't wake up

1. **WoL must be enabled in BIOS/UEFI** — Look for "Wake on LAN", "Wake on PCI", or "Power On By PCI-E"
2. **WoL must be enabled in OS** — `sudo ethtool -s eth0 wol g` (Linux)
3. **Machine must be connected via Ethernet** (WiFi WoL is rare/unreliable)
4. **Firewall** — Ensure UDP port 9 (or 7) is not blocked on the sending machine

### Issue: Works locally but not across subnets

WoL broadcasts don't cross routers by default. Options:
- Use directed broadcast: `--broadcast 192.168.2.255`
- Configure your router to forward UDP broadcast on port 9
- Use a relay on the target subnet

## Key Principles

1. **Registry-based** — Name your devices, forget MAC addresses
2. **Verification** — Optionally ping to confirm the machine woke up
3. **Fallback methods** — Works with `wakeonlan`, `etherwake`, or pure bash
4. **Non-destructive** — WoL packets are harmless; worst case nothing happens
5. **Cross-platform** — Works on Linux, macOS, and WSL

## Dependencies

- `bash` (4.0+)
- `wakeonlan` OR `etherwake` OR `/dev/udp` support (at least one)
- `ping` (for verification, optional)
- `jq` (for device registry, optional — script has fallback)
