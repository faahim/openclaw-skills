# Listing Copy: Navidrome Music Server Manager

## Metadata
- **Type:** Skill
- **Name:** navidrome-server
- **Display Name:** Navidrome Music Server Manager
- **Categories:** [media, home]
- **Icon:** 🎵
- **Dependencies:** [bash, curl, systemd]

## Tagline
Self-hosted music streaming — Install Navidrome and stream your library from anywhere

## Description

Tired of paying for Spotify Premium or trusting a corporation with your music library? With Navidrome, you own your music server. But setting it up, configuring systemd services, reverse proxies, and transcoding is tedious.

This skill handles everything: one-command install, automatic systemd service creation, config management, updates with rollback, and backup/restore. Point it at your music folder and start streaming via web browser or any Subsonic-compatible app (DSub, Substreamer, play:Sub, Symphonium).

**What it does:**
- 🎵 One-command Navidrome install (auto-detects OS/arch)
- ⚙️ Config management without editing TOML files
- 🔄 Zero-downtime updates with automatic rollback
- 💾 Database backup and restore
- 🌐 Nginx reverse proxy config generation
- 🐳 Docker Compose generation (alternative setup)
- 📱 Compatible with all Subsonic mobile apps
- 🔊 Transcoding support (MP3, FLAC, OGG, AAC, Opus)

Perfect for music lovers, self-hosters, and anyone who wants Spotify-like streaming from their own collection.

## Quick Start Preview

```bash
# Install Navidrome
bash scripts/install.sh

# Point to your music
bash scripts/configure.sh --music-folder /mnt/music

# Check status
bash scripts/manage.sh status
# ✅ Navidrome v0.53.3 — http://localhost:4533
```

## Core Capabilities

1. Automated installation — Downloads correct binary for your OS/architecture
2. Systemd service — Auto-start on boot, proper security hardening
3. Config management — Change settings via CLI flags, no manual TOML editing
4. Library scanning — Trigger rescans, configure auto-scan intervals
5. Update manager — One-command update with automatic rollback on failure
6. Backup/restore — Archive database and config, restore from any backup
7. Reverse proxy — Generate Nginx configs with optional SSL
8. Docker support — Generate Docker Compose as alternative deployment
9. Transcoding — Enable on-the-fly format conversion (requires ffmpeg)
10. Uninstaller — Clean removal preserving your music and data
