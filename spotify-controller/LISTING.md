# Listing Copy: Spotify Controller

## Metadata
- **Type:** Skill
- **Name:** spotify-controller
- **Display Name:** Spotify Controller
- **Categories:** [fun, communication]
- **Price:** $8
- **Dependencies:** [curl, jq]
- **Icon:** 🎵

## Tagline

Control Spotify playback, search music, and manage playlists from the terminal

## Description

Tired of switching windows just to skip a track or check what's playing? Spotify Controller puts your entire music library at your fingertips — right in your terminal or OpenClaw agent.

Spotify Controller connects to the Spotify Web API to give you full playback control: play, pause, skip, volume, shuffle, repeat. Search for any track, artist, or playlist and start playing instantly. Manage your playlists, save tracks to your library, and even analyze audio features like BPM and energy.

**What it does:**
- ▶️ Full playback control (play/pause/skip/volume/seek/shuffle/repeat)
- 🔍 Search tracks, artists, and playlists
- 📋 Create and manage playlists from the terminal
- 💚 Save/unsave tracks to your library
- 🎶 Get audio features (BPM, energy, danceability, key)
- 📱 Switch playback between devices
- 🕐 View recently played and top tracks/artists
- 🔄 Automatic token refresh — authenticate once, never again

Perfect for developers who live in the terminal, automation enthusiasts who want music control in their scripts, and OpenClaw users who want their agent to DJ for them.

## Quick Start Preview

```bash
# What's playing?
bash scripts/spotify.sh now
# 🎵 Now Playing:
#   ▶️ Track:    Bohemian Rhapsody
#   🎤 Artist:   Queen
#   ⏱️  Progress: 2:15 / 5:55

# Skip track
bash scripts/spotify.sh next

# Search and play
bash scripts/spotify.sh search "post rock"
```

## Core Capabilities

1. Playback control — Play, pause, skip, previous, volume, seek, shuffle, repeat
2. Now playing — Real-time current track info with progress
3. Music search — Find tracks, artists, and playlists by name
4. URI playback — Play any Spotify URI directly (tracks, albums, playlists)
5. Playlist management — List, create, add tracks to playlists
6. Device switching — Transfer playback between phone, desktop, smart speakers
7. Library management — Save/unsave tracks, check if saved
8. Audio analysis — BPM, energy, danceability, valence, key detection
9. Listening history — Recently played tracks and top tracks/artists over time
10. Auto-auth — One-time OAuth setup, automatic token refresh forever
11. Queue management — Add tracks to your playback queue
12. Cron-ready — Schedule playlists to play at specific times

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`
- Spotify account (Premium required for playback control)

## Installation Time
**10 minutes** — Create Spotify app, authorize once, done forever
