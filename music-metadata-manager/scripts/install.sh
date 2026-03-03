#!/bin/bash
# Install dependencies for Music Metadata Manager

set -e

echo "🎵 Installing Music Metadata Manager dependencies..."

# Check Python3
if ! command -v python3 &>/dev/null; then
  echo "❌ Python3 is required. Install it first:"
  echo "   Ubuntu/Debian: sudo apt-get install python3 python3-pip"
  echo "   Mac: brew install python3"
  exit 1
fi

# Install eyeD3
if ! command -v eyeD3 &>/dev/null; then
  echo "📦 Installing eyeD3..."
  pip3 install --user eyeD3 2>/dev/null || pip3 install eyeD3
  echo "✅ eyeD3 installed"
else
  echo "✅ eyeD3 already installed"
fi

# Install mutagen (for FLAC/OGG/M4A)
if ! python3 -c "import mutagen" 2>/dev/null; then
  echo "📦 Installing mutagen..."
  pip3 install --user mutagen 2>/dev/null || pip3 install mutagen
  echo "✅ mutagen installed"
else
  echo "✅ mutagen already installed"
fi

# Check ffprobe
if ! command -v ffprobe &>/dev/null; then
  echo "⚠️  ffprobe not found. Install ffmpeg:"
  echo "   Ubuntu/Debian: sudo apt-get install ffmpeg"
  echo "   Mac: brew install ffmpeg"
  echo "   (ffprobe is optional but recommended for non-MP3 format detection)"
else
  echo "✅ ffprobe available"
fi

echo ""
echo "🎵 Music Metadata Manager is ready!"
echo "   Run: bash scripts/run.sh info <file.mp3>"
