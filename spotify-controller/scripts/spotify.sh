#!/usr/bin/env bash
# Spotify Controller — Control Spotify from the terminal via Web API
# Requires: curl, jq, base64
# Setup: export SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET, SPOTIFY_REDIRECT_URI

set -euo pipefail

CONFIG_DIR="${HOME}/.config/spotify-controller"
TOKEN_FILE="${CONFIG_DIR}/token.json"
API_BASE="https://api.spotify.com/v1"
ACCOUNTS_BASE="https://accounts.spotify.com"
SCOPES="user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private playlist-modify-public playlist-modify-private user-library-read user-library-modify user-read-recently-played user-top-read"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$CONFIG_DIR"

# --- Auth Functions ---

check_env() {
  local missing=0
  if [[ -z "${SPOTIFY_CLIENT_ID:-}" ]]; then
    echo -e "${RED}Error: SPOTIFY_CLIENT_ID not set${NC}" >&2; missing=1
  fi
  if [[ -z "${SPOTIFY_CLIENT_SECRET:-}" ]]; then
    echo -e "${RED}Error: SPOTIFY_CLIENT_SECRET not set${NC}" >&2; missing=1
  fi
  if [[ -z "${SPOTIFY_REDIRECT_URI:-}" ]]; then
    export SPOTIFY_REDIRECT_URI="http://localhost:8888/callback"
  fi
  [[ $missing -eq 1 ]] && exit 1
}

get_auth_url() {
  local scopes_encoded
  scopes_encoded=$(echo "$SCOPES" | sed 's/ /%20/g')
  echo "${ACCOUNTS_BASE}/authorize?client_id=${SPOTIFY_CLIENT_ID}&response_type=code&redirect_uri=$(echo "$SPOTIFY_REDIRECT_URI" | sed 's/:/%3A/g; s/\//%2F/g')&scope=${scopes_encoded}"
}

exchange_code() {
  local code="$1"
  local response
  response=$(curl -sS -X POST "${ACCOUNTS_BASE}/api/token" \
    -H "Authorization: Basic $(echo -n "${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}" | base64 -w0 2>/dev/null || echo -n "${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}" | base64)" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=authorization_code&code=${code}&redirect_uri=${SPOTIFY_REDIRECT_URI}")

  if echo "$response" | jq -e '.access_token' > /dev/null 2>&1; then
    local expires_in
    expires_in=$(echo "$response" | jq -r '.expires_in')
    local expires_at=$(($(date +%s) + expires_in))
    echo "$response" | jq --argjson ea "$expires_at" '. + {expires_at: $ea}' > "$TOKEN_FILE"
    echo -e "${GREEN}✅ Authorization successful! Token saved.${NC}"
  else
    echo -e "${RED}❌ Authorization failed:${NC}"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    exit 1
  fi
}

refresh_token() {
  local refresh_tok
  refresh_tok=$(jq -r '.refresh_token' "$TOKEN_FILE")
  local response
  response=$(curl -sS -X POST "${ACCOUNTS_BASE}/api/token" \
    -H "Authorization: Basic $(echo -n "${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}" | base64 -w0 2>/dev/null || echo -n "${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}" | base64)" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=refresh_token&refresh_token=${refresh_tok}")

  if echo "$response" | jq -e '.access_token' > /dev/null 2>&1; then
    local expires_in
    expires_in=$(echo "$response" | jq -r '.expires_in')
    local expires_at=$(($(date +%s) + expires_in))
    # Preserve refresh_token if not returned
    local new_refresh
    new_refresh=$(echo "$response" | jq -r '.refresh_token // empty')
    if [[ -z "$new_refresh" ]]; then
      echo "$response" | jq --argjson ea "$expires_at" --arg rt "$refresh_tok" '. + {expires_at: $ea, refresh_token: $rt}' > "$TOKEN_FILE"
    else
      echo "$response" | jq --argjson ea "$expires_at" '. + {expires_at: $ea}' > "$TOKEN_FILE"
    fi
  else
    echo -e "${RED}❌ Token refresh failed. Run: bash spotify.sh auth${NC}" >&2
    exit 1
  fi
}

get_token() {
  if [[ ! -f "$TOKEN_FILE" ]]; then
    echo -e "${RED}Not authenticated. Run: bash spotify.sh auth${NC}" >&2
    exit 1
  fi

  local expires_at
  expires_at=$(jq -r '.expires_at' "$TOKEN_FILE")
  local now
  now=$(date +%s)

  if [[ $now -ge $((expires_at - 60)) ]]; then
    refresh_token
  fi

  jq -r '.access_token' "$TOKEN_FILE"
}

# --- API Helper ---

spotify_api() {
  local method="$1"
  local endpoint="$2"
  shift 2
  local token
  token=$(get_token)

  local response
  if [[ "$method" == "GET" ]]; then
    response=$(curl -sS -X GET "${API_BASE}${endpoint}" \
      -H "Authorization: Bearer ${token}" \
      "$@")
  elif [[ "$method" == "PUT" ]]; then
    response=$(curl -sS -X PUT "${API_BASE}${endpoint}" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      "$@")
  elif [[ "$method" == "POST" ]]; then
    response=$(curl -sS -X POST "${API_BASE}${endpoint}" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      "$@")
  elif [[ "$method" == "DELETE" ]]; then
    response=$(curl -sS -X DELETE "${API_BASE}${endpoint}" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      "$@")
  fi

  # Small delay to respect rate limits
  sleep 0.1

  echo "$response"
}

# --- Formatters ---

format_ms() {
  local ms="$1"
  local secs=$((ms / 1000))
  printf "%d:%02d" $((secs / 60)) $((secs % 60))
}

# --- Commands ---

cmd_auth() {
  check_env
  local url
  url=$(get_auth_url)
  echo -e "${BLUE}🔗 Open this URL in your browser:${NC}"
  echo ""
  echo "  $url"
  echo ""
  echo -e "${YELLOW}After authorizing, you'll be redirected. Copy the full redirect URL and paste it here:${NC}"
  read -rp "> " redirect_url

  local code
  code=$(echo "$redirect_url" | grep -oP 'code=\K[^&]+' 2>/dev/null || echo "$redirect_url" | sed -n 's/.*code=\([^&]*\).*/\1/p')

  if [[ -z "$code" ]]; then
    echo -e "${RED}❌ Could not extract authorization code from URL${NC}"
    exit 1
  fi

  exchange_code "$code"
}

cmd_now() {
  local response
  response=$(spotify_api GET "/me/player/currently-playing")

  if [[ -z "$response" || "$response" == "null" ]]; then
    echo -e "${YELLOW}Nothing is currently playing.${NC}"
    return
  fi

  local is_playing track artist album progress duration
  is_playing=$(echo "$response" | jq -r '.is_playing')
  track=$(echo "$response" | jq -r '.item.name // "Unknown"')
  artist=$(echo "$response" | jq -r '[.item.artists[].name] | join(", ")')
  album=$(echo "$response" | jq -r '.item.album.name // "Unknown"')
  progress=$(echo "$response" | jq -r '.progress_ms // 0')
  duration=$(echo "$response" | jq -r '.item.duration_ms // 0')

  local status_icon="⏸️"
  [[ "$is_playing" == "true" ]] && status_icon="▶️"

  echo -e "${GREEN}🎵 Now Playing:${NC}"
  echo -e "  ${status_icon} Track:    ${track}"
  echo -e "  🎤 Artist:   ${artist}"
  echo -e "  💿 Album:    ${album}"
  echo -e "  ⏱️  Progress: $(format_ms "$progress") / $(format_ms "$duration")"
}

cmd_play() {
  spotify_api PUT "/me/player/play" > /dev/null 2>&1
  echo -e "${GREEN}▶️ Playing${NC}"
}

cmd_pause() {
  spotify_api PUT "/me/player/pause" > /dev/null 2>&1
  echo -e "${YELLOW}⏸️ Paused${NC}"
}

cmd_next() {
  spotify_api POST "/me/player/next" > /dev/null 2>&1
  sleep 0.5
  echo -e "${GREEN}⏭️ Skipped to next track${NC}"
  cmd_now
}

cmd_prev() {
  spotify_api POST "/me/player/previous" > /dev/null 2>&1
  sleep 0.5
  echo -e "${GREEN}⏮️ Previous track${NC}"
  cmd_now
}

cmd_volume() {
  local vol="${1:-50}"
  spotify_api PUT "/me/player/volume?volume_percent=${vol}" > /dev/null 2>&1
  echo -e "${GREEN}🔊 Volume set to ${vol}%${NC}"
}

cmd_seek() {
  local secs="${1:-0}"
  local ms=$((secs * 1000))
  spotify_api PUT "/me/player/seek?position_ms=${ms}" > /dev/null 2>&1
  echo -e "${GREEN}⏩ Seeked to ${secs}s${NC}"
}

cmd_shuffle() {
  local state="${1:-true}"
  [[ "$state" == "on" ]] && state="true"
  [[ "$state" == "off" ]] && state="false"
  spotify_api PUT "/me/player/shuffle?state=${state}" > /dev/null 2>&1
  echo -e "${GREEN}🔀 Shuffle: ${state}${NC}"
}

cmd_repeat() {
  local state="${1:-off}"
  spotify_api PUT "/me/player/repeat?state=${state}" > /dev/null 2>&1
  echo -e "${GREEN}🔁 Repeat: ${state}${NC}"
}

cmd_search() {
  local query="$*"
  local encoded_query
  encoded_query=$(echo "$query" | sed 's/ /%20/g')
  local response
  response=$(spotify_api GET "/search?q=${encoded_query}&type=track&limit=10")

  echo -e "${GREEN}🔍 Search results for: ${query}${NC}"
  echo ""
  echo "$response" | jq -r '.tracks.items[] | "  \(.artists[0].name) — \(.name) [\(.album.name)] (\(.uri))"'
}

cmd_search_artist() {
  local query="$*"
  local encoded_query
  encoded_query=$(echo "$query" | sed 's/ /%20/g')
  local response
  response=$(spotify_api GET "/search?q=${encoded_query}&type=artist&limit=10")

  echo -e "${GREEN}🔍 Artists matching: ${query}${NC}"
  echo ""
  echo "$response" | jq -r '.artists.items[] | "  \(.name) — \(.followers.total) followers (\(.uri))"'
}

cmd_search_playlist() {
  local query="$*"
  local encoded_query
  encoded_query=$(echo "$query" | sed 's/ /%20/g')
  local response
  response=$(spotify_api GET "/search?q=${encoded_query}&type=playlist&limit=10")

  echo -e "${GREEN}🔍 Playlists matching: ${query}${NC}"
  echo ""
  echo "$response" | jq -r '.playlists.items[] | "  \(.name) by \(.owner.display_name) — \(.tracks.total) tracks (\(.uri))"'
}

cmd_play_uri() {
  local uri="$1"
  if [[ "$uri" == *"track"* ]]; then
    spotify_api PUT "/me/player/play" -d "{\"uris\":[\"${uri}\"]}" > /dev/null 2>&1
  else
    spotify_api PUT "/me/player/play" -d "{\"context_uri\":\"${uri}\"}" > /dev/null 2>&1
  fi
  sleep 0.5
  echo -e "${GREEN}▶️ Playing: ${uri}${NC}"
  cmd_now
}

cmd_queue() {
  local uri="$1"
  spotify_api POST "/me/player/queue?uri=${uri}" > /dev/null 2>&1
  echo -e "${GREEN}📋 Added to queue: ${uri}${NC}"
}

cmd_devices() {
  local response
  response=$(spotify_api GET "/me/player/devices")

  echo -e "${GREEN}📱 Available Devices:${NC}"
  echo ""
  echo "$response" | jq -r '.devices[] | "  \(if .is_active then "▶️" else "  " end) \(.name) [\(.type)] — Volume: \(.volume_percent)% (ID: \(.id))"'
}

cmd_transfer() {
  local device_id="$1"
  spotify_api PUT "/me/player" -d "{\"device_ids\":[\"${device_id}\"],\"play\":true}" > /dev/null 2>&1
  echo -e "${GREEN}📱 Transferred playback to device${NC}"
}

cmd_playlists() {
  local response
  response=$(spotify_api GET "/me/playlists?limit=50")

  echo -e "${GREEN}📋 Your Playlists:${NC}"
  echo ""
  echo "$response" | jq -r '.items[] | "  \(.name) — \(.tracks.total) tracks (\(.id))"'
}

cmd_playlist_tracks() {
  local playlist_id="$1"
  local response
  response=$(spotify_api GET "/playlists/${playlist_id}/tracks?limit=50")

  echo "$response" | jq -r '.items[] | "  \(.track.artists[0].name) — \(.track.name) [\(.track.album.name)]"'
}

cmd_add_to_playlist() {
  local playlist_id="$1"
  local current
  current=$(spotify_api GET "/me/player/currently-playing")
  local uri
  uri=$(echo "$current" | jq -r '.item.uri')
  local name
  name=$(echo "$current" | jq -r '.item.name')

  spotify_api POST "/playlists/${playlist_id}/tracks" -d "{\"uris\":[\"${uri}\"]}" > /dev/null 2>&1
  echo -e "${GREEN}✅ Added \"${name}\" to playlist${NC}"
}

cmd_create_playlist() {
  local name="$*"
  local response
  local user_id
  user_id=$(spotify_api GET "/me" | jq -r '.id')
  response=$(spotify_api POST "/users/${user_id}/playlists" -d "{\"name\":\"${name}\",\"public\":false}")

  local playlist_id
  playlist_id=$(echo "$response" | jq -r '.id')
  echo -e "${GREEN}✅ Created playlist: ${name} (ID: ${playlist_id})${NC}"
}

cmd_recent() {
  local response
  response=$(spotify_api GET "/me/player/recently-played?limit=20")

  echo -e "${GREEN}🕐 Recently Played:${NC}"
  echo ""
  echo "$response" | jq -r '.items[] | "  \(.played_at | split("T")[1] | split(".")[0]) — \(.track.artists[0].name) — \(.track.name)"'
}

cmd_top_tracks() {
  local range="${1:-medium_term}"
  [[ "$range" == "short" ]] && range="short_term"
  [[ "$range" == "medium" ]] && range="medium_term"
  [[ "$range" == "long" ]] && range="long_term"

  local response
  response=$(spotify_api GET "/me/top/tracks?time_range=${range}&limit=20")

  echo -e "${GREEN}🏆 Top Tracks (${range}):${NC}"
  echo ""
  echo "$response" | jq -r 'to_entries[] | .value as $t | "  \(.key + 1). \($t.artists[0].name) — \($t.name)"' 2>/dev/null || \
  echo "$response" | jq -r '.items | to_entries[] | "  \(.key + 1). \(.value.artists[0].name) — \(.value.name)"'
}

cmd_top_artists() {
  local range="${1:-medium_term}"
  [[ "$range" == "short" ]] && range="short_term"
  [[ "$range" == "medium" ]] && range="medium_term"
  [[ "$range" == "long" ]] && range="long_term"

  local response
  response=$(spotify_api GET "/me/top/artists?time_range=${range}&limit=20")

  echo -e "${GREEN}🏆 Top Artists (${range}):${NC}"
  echo ""
  echo "$response" | jq -r '.items | to_entries[] | "  \(.key + 1). \(.value.name) — \(.value.genres[0:3] | join(", "))"'
}

cmd_save() {
  local current
  current=$(spotify_api GET "/me/player/currently-playing")
  local track_id
  track_id=$(echo "$current" | jq -r '.item.id')
  local name
  name=$(echo "$current" | jq -r '.item.name')

  spotify_api PUT "/me/tracks" -d "{\"ids\":[\"${track_id}\"]}" > /dev/null 2>&1
  echo -e "${GREEN}💚 Saved \"${name}\" to your library${NC}"
}

cmd_unsave() {
  local current
  current=$(spotify_api GET "/me/player/currently-playing")
  local track_id
  track_id=$(echo "$current" | jq -r '.item.id')
  local name
  name=$(echo "$current" | jq -r '.item.name')

  spotify_api DELETE "/me/tracks" -d "{\"ids\":[\"${track_id}\"]}" > /dev/null 2>&1
  echo -e "${YELLOW}💔 Removed \"${name}\" from your library${NC}"
}

cmd_is_saved() {
  local current
  current=$(spotify_api GET "/me/player/currently-playing")
  local track_id
  track_id=$(echo "$current" | jq -r '.item.id')
  local name
  name=$(echo "$current" | jq -r '.item.name')

  local response
  response=$(spotify_api GET "/me/tracks/contains?ids=${track_id}")
  local saved
  saved=$(echo "$response" | jq -r '.[0]')

  if [[ "$saved" == "true" ]]; then
    echo -e "${GREEN}💚 \"${name}\" is in your library${NC}"
  else
    echo -e "${YELLOW}🤍 \"${name}\" is NOT in your library${NC}"
  fi
}

cmd_features() {
  local current
  current=$(spotify_api GET "/me/player/currently-playing")
  local track_id
  track_id=$(echo "$current" | jq -r '.item.id')
  local name
  name=$(echo "$current" | jq -r '.item.name')

  local response
  response=$(spotify_api GET "/audio-features/${track_id}")

  local keys=("C" "C♯" "D" "D♯" "E" "F" "F♯" "G" "G♯" "A" "A♯" "B")
  local key_num
  key_num=$(echo "$response" | jq -r '.key')
  local mode
  mode=$(echo "$response" | jq -r '.mode')
  local key_name="${keys[$key_num]}"
  [[ "$mode" == "1" ]] && key_name="${key_name} Major" || key_name="${key_name} Minor"

  echo -e "${GREEN}🎶 Audio Features: ${name}${NC}"
  echo -e "  BPM:          $(echo "$response" | jq -r '.tempo | round')"
  echo -e "  Energy:       $(echo "$response" | jq -r '.energy')"
  echo -e "  Danceability: $(echo "$response" | jq -r '.danceability')"
  echo -e "  Valence:      $(echo "$response" | jq -r '.valence') (mood)"
  echo -e "  Acousticness: $(echo "$response" | jq -r '.acousticness')"
  echo -e "  Key:          ${key_name}"
  echo -e "  Time Sig:     $(echo "$response" | jq -r '.time_signature')/4"
}

cmd_help() {
  echo -e "${GREEN}🎵 Spotify Controller${NC}"
  echo ""
  echo "Usage: bash spotify.sh <command> [args]"
  echo ""
  echo "Authentication:"
  echo "  auth                    Authorize with Spotify (one-time)"
  echo ""
  echo "Playback:"
  echo "  now                     Show current track"
  echo "  play                    Resume playback"
  echo "  pause                   Pause playback"
  echo "  next                    Skip to next track"
  echo "  prev                    Previous track"
  echo "  volume <0-100>          Set volume"
  echo "  seek <seconds>          Seek to position"
  echo "  shuffle <on|off>        Toggle shuffle"
  echo "  repeat <track|context|off>  Set repeat mode"
  echo ""
  echo "Search & Play:"
  echo "  search <query>          Search tracks"
  echo "  search-artist <query>   Search artists"
  echo "  search-playlist <query> Search playlists"
  echo "  play-uri <spotify-uri>  Play a Spotify URI"
  echo "  queue <spotify-uri>     Add to queue"
  echo ""
  echo "Playlists:"
  echo "  playlists               List your playlists"
  echo "  playlist-tracks <id>    Show playlist tracks"
  echo "  add-to-playlist <id>    Add current track to playlist"
  echo "  create-playlist <name>  Create new playlist"
  echo ""
  echo "Library:"
  echo "  save                    Save current track"
  echo "  unsave                  Remove current track"
  echo "  is-saved                Check if current track is saved"
  echo ""
  echo "Discovery:"
  echo "  recent                  Recently played tracks"
  echo "  top-tracks <range>      Your top tracks (short/medium/long)"
  echo "  top-artists <range>     Your top artists"
  echo "  features                Audio features of current track"
  echo ""
  echo "Devices:"
  echo "  devices                 List available devices"
  echo "  transfer <device-id>    Transfer playback"
}

# --- Main ---

check_env

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  auth)             cmd_auth ;;
  now)              cmd_now ;;
  play)             cmd_play ;;
  pause)            cmd_pause ;;
  next)             cmd_next ;;
  prev)             cmd_prev ;;
  volume)           cmd_volume "$@" ;;
  seek)             cmd_seek "$@" ;;
  shuffle)          cmd_shuffle "$@" ;;
  repeat)           cmd_repeat "$@" ;;
  search)           cmd_search "$@" ;;
  search-artist)    cmd_search_artist "$@" ;;
  search-playlist)  cmd_search_playlist "$@" ;;
  play-uri)         cmd_play_uri "$@" ;;
  queue)            cmd_queue "$@" ;;
  devices)          cmd_devices ;;
  transfer)         cmd_transfer "$@" ;;
  playlists)        cmd_playlists ;;
  playlist-tracks)  cmd_playlist_tracks "$@" ;;
  add-to-playlist)  cmd_add_to_playlist "$@" ;;
  create-playlist)  cmd_create_playlist "$@" ;;
  recent)           cmd_recent ;;
  top-tracks)       cmd_top_tracks "$@" ;;
  top-artists)      cmd_top_artists "$@" ;;
  save)             cmd_save ;;
  unsave)           cmd_unsave ;;
  is-saved)         cmd_is_saved ;;
  features)         cmd_features ;;
  help|--help|-h)   cmd_help ;;
  *)                echo -e "${RED}Unknown command: ${COMMAND}${NC}"; cmd_help; exit 1 ;;
esac
