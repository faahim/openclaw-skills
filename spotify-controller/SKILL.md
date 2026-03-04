---
name: spotify-controller
description: >-
  Control Spotify playback, search tracks, manage playlists, and get now-playing info from the terminal.
categories: [fun, communication]
dependencies: [curl, jq]
---

# Spotify Controller

## What This Does

Control your Spotify playback directly from your OpenClaw agent or terminal. Play/pause, skip tracks, search music, manage playlists, and get real-time now-playing info — all through the Spotify Web API.

**Example:** "Play my Discover Weekly, skip to next track, add current song to my favorites playlist."

## Quick Start (10 minutes)

### 1. Create a Spotify App

Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) and create an app:

- **App name:** OpenClaw Controller
- **Redirect URI:** `http://localhost:8888/callback`
- **APIs used:** Web API

Copy your **Client ID** and **Client Secret**.

### 2. Set Environment Variables

```bash
export SPOTIFY_CLIENT_ID="<your-client-id>"
export SPOTIFY_CLIENT_SECRET="<your-client-secret>"
export SPOTIFY_REDIRECT_URI="http://localhost:8888/callback"
```

Add these to `~/.bashrc` or `~/.openclaw/.env` for persistence.

### 3. Authorize (One-Time)

```bash
bash scripts/spotify.sh auth
```

This opens a browser URL for Spotify OAuth. After granting access, paste the redirect URL back. Your refresh token is saved to `~/.config/spotify-controller/token.json`.

### 4. Test It

```bash
# What's playing?
bash scripts/spotify.sh now

# Play/pause
bash scripts/spotify.sh play
bash scripts/spotify.sh pause

# Next/previous track
bash scripts/spotify.sh next
bash scripts/spotify.sh prev
```

## Core Workflows

### Workflow 1: Playback Control

```bash
# Play/pause toggle
bash scripts/spotify.sh play
bash scripts/spotify.sh pause

# Skip tracks
bash scripts/spotify.sh next
bash scripts/spotify.sh prev

# Set volume (0-100)
bash scripts/spotify.sh volume 75

# Seek to position (seconds)
bash scripts/spotify.sh seek 30

# Shuffle on/off
bash scripts/spotify.sh shuffle on
bash scripts/spotify.sh shuffle off

# Repeat (track/context/off)
bash scripts/spotify.sh repeat track
bash scripts/spotify.sh repeat off
```

### Workflow 2: Now Playing

```bash
# Current track info
bash scripts/spotify.sh now

# Output:
# 🎵 Now Playing:
#   Track: Bohemian Rhapsody
#   Artist: Queen
#   Album: A Night at the Opera
#   Progress: 2:15 / 5:55
#   Device: MacBook Pro
```

### Workflow 3: Search & Play

```bash
# Search for a track and play it
bash scripts/spotify.sh search "bohemian rhapsody"

# Search for an artist
bash scripts/spotify.sh search-artist "radiohead"

# Search for a playlist
bash scripts/spotify.sh search-playlist "chill vibes"

# Play a specific URI
bash scripts/spotify.sh play-uri "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"
```

### Workflow 4: Playlist Management

```bash
# List your playlists
bash scripts/spotify.sh playlists

# Get tracks from a playlist
bash scripts/spotify.sh playlist-tracks <playlist-id>

# Add current track to a playlist
bash scripts/spotify.sh add-to-playlist <playlist-id>

# Create a new playlist
bash scripts/spotify.sh create-playlist "My Agent Mix"
```

### Workflow 5: Device Management

```bash
# List available devices
bash scripts/spotify.sh devices

# Transfer playback to a device
bash scripts/spotify.sh transfer <device-id>
```

### Workflow 6: Recently Played & Top Tracks

```bash
# Recently played tracks
bash scripts/spotify.sh recent

# Your top tracks (short/medium/long term)
bash scripts/spotify.sh top-tracks short
bash scripts/spotify.sh top-tracks medium

# Your top artists
bash scripts/spotify.sh top-artists short
```

### Workflow 7: Save/Unsave Tracks

```bash
# Save current track to library (Like)
bash scripts/spotify.sh save

# Remove current track from library
bash scripts/spotify.sh unsave

# Check if current track is saved
bash scripts/spotify.sh is-saved
```

## Configuration

### Token Storage

Tokens are stored at `~/.config/spotify-controller/token.json`:

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_at": 1709571600
}
```

The script auto-refreshes expired tokens.

### Environment Variables

```bash
# Required
SPOTIFY_CLIENT_ID="<client-id>"
SPOTIFY_CLIENT_SECRET="<client-secret>"
SPOTIFY_REDIRECT_URI="http://localhost:8888/callback"

# Optional
SPOTIFY_DEFAULT_DEVICE="<device-id>"  # Default playback device
```

## Advanced Usage

### Queue a Track

```bash
# Add a track to the queue
bash scripts/spotify.sh queue "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"
```

### Get Audio Features (BPM, Energy, etc.)

```bash
# Audio analysis of current track
bash scripts/spotify.sh features

# Output:
# 🎶 Audio Features:
#   BPM: 128
#   Energy: 0.82
#   Danceability: 0.65
#   Valence: 0.45 (mood)
#   Key: C Major
```

### OpenClaw Cron Integration

```bash
# Play a playlist every morning at 8am
# Add to OpenClaw cron:
bash scripts/spotify.sh play-uri "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M"
```

## Troubleshooting

### Issue: "No active device found"

**Fix:** Open Spotify on any device first (phone, desktop, web player), then try again. Spotify requires at least one active device.

### Issue: "Token expired"

**Fix:** The script auto-refreshes tokens. If it fails:
```bash
bash scripts/spotify.sh auth  # Re-authorize
```

### Issue: "Premium required"

**Note:** Playback control (play, pause, skip, volume) requires Spotify Premium. Read-only features (now playing, search, playlists) work with free accounts.

### Issue: "Rate limited"

**Fix:** Spotify API allows ~180 requests/minute. Space out commands. The script includes a 100ms delay between calls.

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to Spotify API)
- `jq` (JSON parsing)
- `base64` (for auth encoding)
- Spotify account (Premium for playback control)

## Key Principles

1. **Token auto-refresh** — Never manually re-authenticate after initial setup
2. **Graceful device handling** — Alerts if no active device found
3. **Rate limit aware** — Built-in delays to avoid API throttling
4. **Minimal dependencies** — Just curl + jq, no node/python needed
5. **OpenClaw native** — Works perfectly as an agent skill
