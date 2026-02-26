# Listing Copy: Apprise Notification Router

## Metadata
- **Type:** Skill
- **Name:** apprise-notifications
- **Display Name:** Apprise Notification Router
- **Categories:** [communication, automation]
- **Icon:** 📣
- **Dependencies:** [python3, pip]

## Tagline

Send alerts to 90+ services (Slack, Discord, Telegram, Email) from one command

## Description

Tired of writing separate integrations for every notification service? Apprise gives your OpenClaw agent a single, unified way to send alerts to Slack, Discord, Telegram, Email, Pushover, ntfy, MS Teams, Matrix, and 80+ more services.

**Apprise Notification Router** installs and configures Apprise with tag-based routing, severity-based alerting, and stdin piping. Define your notification targets once in a YAML config, then send to any combination with a single command.

**What it does:**
- 📣 Send to 90+ notification services with one command
- 🏷️ Tag-based routing (team, personal, urgent, email)
- 🚨 Severity-based alerts (info → team, critical → team + email + phone)
- 📎 Attach files, images, and screenshots
- 🔗 Pipe any command output as a notification
- ⚙️ YAML config — define once, notify everywhere
- 🐍 Python API for advanced scripting
- 🔒 No vendor lock-in — switch services by editing one line

Perfect for developers, sysadmins, and indie hackers who need reliable multi-channel notifications without building separate integrations for each service.

## Quick Start Preview

```bash
# Install
pip3 install apprise

# Send to Telegram + Slack at once
apprise -t "Deploy Complete" -b "v2.1.0 is live" \
  "tgram://BOT/CHAT" "slack://A/B/C/#ops"

# Or use config with tags
apprise --config=~/.apprise.yml --tag=urgent -t "DB Down" -b "Primary unreachable"
```

## Core Capabilities

1. Universal notifications — 90+ services from one interface
2. Tag-based routing — Group services by purpose, send to groups
3. Severity alerting — Auto-route info/warning/critical to different channels  
4. Stdin piping — Pipe any command output as a notification
5. File attachments — Send images, logs, screenshots
6. HTML support — Rich formatted messages for email/web services
7. YAML config — Persistent, version-controllable notification targets
8. Dry run mode — Test config without sending
9. Python API — Use from scripts for advanced workflows
10. Zero vendor lock-in — Switch services with one config line change
