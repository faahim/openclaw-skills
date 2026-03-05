---
name: nftables-firewall
description: >-
  Install, configure, and manage nftables firewall rules — the modern replacement for iptables.
categories: [security, automation]
dependencies: [nftables, bash]
---

# nftables Firewall Manager

## What This Does

Manage your Linux firewall using nftables — the modern replacement for iptables. Install nftables, create rulesets, manage tables/chains/rules, set up NAT/port forwarding, and maintain persistent firewall configs. No more memorizing cryptic iptables syntax.

**Example:** "Block all incoming traffic except SSH and HTTP, rate-limit SSH to 5 connections/minute, and set up port forwarding for your web server."

## Quick Start (5 minutes)

### 1. Install nftables

```bash
bash scripts/install.sh
```

### 2. Apply a Starter Ruleset

```bash
# Apply a secure default ruleset (allow SSH + HTTP/HTTPS, block rest)
bash scripts/nft-manage.sh apply-preset server-basic

# View current rules
bash scripts/nft-manage.sh show
```

### 3. Add Custom Rules

```bash
# Allow a specific port
bash scripts/nft-manage.sh allow --port 3000 --proto tcp

# Block an IP
bash scripts/nft-manage.sh block --ip 192.168.1.100

# Rate-limit SSH
bash scripts/nft-manage.sh rate-limit --port 22 --rate "5/minute"
```

## Core Workflows

### Workflow 1: Secure Server Setup

**Use case:** Lock down a fresh VPS

```bash
# Install + apply server preset
bash scripts/install.sh
bash scripts/nft-manage.sh apply-preset server-basic

# This creates:
# - Default DROP policy for input
# - Allow established/related connections
# - Allow SSH (22), HTTP (80), HTTPS (443)
# - Allow ICMP (ping)
# - Allow loopback
# - Log + drop everything else
```

**Resulting rules:**
```
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif "lo" accept
    tcp dport 22 accept
    tcp dport { 80, 443 } accept
    icmp type echo-request accept
    log prefix "[nft-drop] " counter drop
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
  chain output {
    type filter hook output priority 0; policy accept;
  }
}
```

### Workflow 2: Port Forwarding / NAT

**Use case:** Forward traffic from port 80 to an internal service on port 8080

```bash
bash scripts/nft-manage.sh nat --dport 80 --to 127.0.0.1:8080
```

### Workflow 3: IP Blocklist

**Use case:** Block a list of IPs (abuse, scrapers, etc.)

```bash
# Block single IP
bash scripts/nft-manage.sh block --ip 10.0.0.50

# Block from file (one IP per line)
bash scripts/nft-manage.sh block --file blocklist.txt

# Unblock
bash scripts/nft-manage.sh unblock --ip 10.0.0.50
```

### Workflow 4: Rate Limiting

**Use case:** Prevent brute-force attacks

```bash
# Rate-limit SSH to 5 new connections per minute per source IP
bash scripts/nft-manage.sh rate-limit --port 22 --rate "5/minute"

# Rate-limit HTTP to 30 requests/second
bash scripts/nft-manage.sh rate-limit --port 80 --rate "30/second"
```

### Workflow 5: Backup & Restore

```bash
# Export current ruleset
bash scripts/nft-manage.sh backup > firewall-backup-$(date +%Y%m%d).nft

# Restore from backup
bash scripts/nft-manage.sh restore firewall-backup-20260305.nft
```

### Workflow 6: Monitoring & Logging

```bash
# Show current rules with counters
bash scripts/nft-manage.sh show --counters

# Show only blocked packets (from log)
bash scripts/nft-manage.sh logs --filter drop --last 50

# List all open ports
bash scripts/nft-manage.sh list-allowed
```

## Configuration

### Presets Available

| Preset | Description | Ports Allowed |
|--------|-------------|---------------|
| `server-basic` | Web server | 22, 80, 443 |
| `server-full` | Web + mail + DB | 22, 80, 443, 25, 587, 993, 5432 |
| `desktop` | Permissive outbound, restrict inbound | 22 |
| `lockdown` | SSH only | 22 |
| `docker-host` | Docker-friendly rules with forwarding | 22, 80, 443 + forward chain |

### Custom Config

Edit `config.yaml` for persistent custom rules:

```yaml
# config.yaml
tables:
  - name: filter
    family: inet
    chains:
      - name: input
        type: filter
        hook: input
        policy: drop
        rules:
          - match: "ct state established,related"
            action: accept
          - match: "iif lo"
            action: accept
          - match: "tcp dport 22"
            action: accept
            comment: "SSH"
          - match: "tcp dport { 80, 443 }"
            action: accept
            comment: "Web"

blocklist:
  - 192.168.1.100
  - 10.0.0.0/8

rate_limits:
  - port: 22
    rate: "5/minute"
    burst: 10
```

```bash
# Apply config
bash scripts/nft-manage.sh apply-config config.yaml
```

### Environment Variables

```bash
# Override default config location
export NFT_CONFIG="/etc/nftables/managed.yaml"

# Enable verbose logging
export NFT_VERBOSE=1

# Dry-run mode (show rules without applying)
export NFT_DRY_RUN=1
```

## Advanced Usage

### Docker-Friendly Setup

Docker manipulates iptables directly. To coexist with nftables:

```bash
bash scripts/nft-manage.sh apply-preset docker-host
```

This sets up rules that work alongside Docker's network bridge.

### Country-Based Blocking (GeoIP)

```bash
# Download GeoIP sets and block by country
bash scripts/nft-manage.sh geoblock --countries "CN,RU,KP"
```

### Fail2Ban Integration

```bash
# Create a dedicated nftables set for fail2ban
bash scripts/nft-manage.sh create-set fail2ban-blocklist

# Fail2ban can then add IPs:
# nft add element inet filter fail2ban-blocklist { 1.2.3.4 }
```

### Cron: Auto-Update Blocklists

```bash
# Update blocklists daily
0 3 * * * cd /path/to/skill && bash scripts/nft-manage.sh update-blocklists >> /var/log/nft-blocklist.log 2>&1
```

## Troubleshooting

### Issue: "nft: command not found"

```bash
# Debian/Ubuntu
sudo apt-get install -y nftables

# RHEL/Fedora
sudo dnf install -y nftables

# Enable on boot
sudo systemctl enable nftables
```

### Issue: Locked out of SSH

**Prevention:** The install script adds a safety rule — SSH is always allowed before applying new rules.

**Recovery:** If locked out, use console access (VPS provider panel) and:
```bash
sudo nft flush ruleset
sudo nft add table inet filter
sudo nft add chain inet filter input '{ type filter hook input priority 0; policy accept; }'
```

### Issue: Rules don't persist after reboot

```bash
# Save current rules
sudo nft list ruleset > /etc/nftables.conf

# Or use the skill's persist command
bash scripts/nft-manage.sh persist
```

### Issue: Conflict with iptables

```bash
# Check if iptables rules exist
sudo iptables -L -n

# Flush iptables and switch to nftables
sudo iptables -F
sudo update-alternatives --set iptables /usr/sbin/iptables-nft 2>/dev/null
```

## Key Principles

1. **Default deny** — Block everything, allow explicitly
2. **SSH safety** — Never lock yourself out (safety checks built in)
3. **Persistence** — Rules survive reboot via `/etc/nftables.conf`
4. **Atomic updates** — nftables applies entire rulesets atomically (no brief gaps)
5. **Readable syntax** — nftables syntax is cleaner than iptables
6. **Sets & maps** — Use nftables sets for efficient IP/port matching

## Dependencies

- `nftables` (1.0+)
- `bash` (4.0+)
- `jq` (for config parsing)
- Optional: `yq` (for YAML config)
- Root/sudo access required
