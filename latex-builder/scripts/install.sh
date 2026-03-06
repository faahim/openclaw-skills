#!/bin/bash
# LaTeX Builder — TeX Live Installer
set -e

TEXLIVE_DIR="${TEXLIVE_DIR:-$HOME/texlive}"
TEXLIVE_YEAR="2025"
INSTALLER_URL="https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz"
EXTRA_PACKAGES=""
FULL_INSTALL=false

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --full           Install full TeX Live (~2GB)"
  echo "  --packages PKG   Install additional packages (space-separated)"
  echo "  --dir DIR        Custom install directory (default: ~/texlive)"
  echo "  -h, --help       Show this help"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --full) FULL_INSTALL=true; shift ;;
    --packages) EXTRA_PACKAGES="$2"; shift 2 ;;
    --dir) TEXLIVE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Check if already installed
if command -v pdflatex &>/dev/null; then
  echo "✅ TeX Live already installed: $(pdflatex --version | head -1)"
  if [[ -n "$EXTRA_PACKAGES" ]]; then
    echo "📦 Installing additional packages: $EXTRA_PACKAGES"
    tlmgr install $EXTRA_PACKAGES
  fi
  exit 0
fi

echo "📥 Downloading TeX Live installer..."
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

if command -v curl &>/dev/null; then
  curl -fsSL "$INSTALLER_URL" -o install-tl.tar.gz
elif command -v wget &>/dev/null; then
  wget -q "$INSTALLER_URL" -O install-tl.tar.gz
else
  echo "❌ Neither curl nor wget found. Install one first."
  exit 1
fi

tar -xzf install-tl.tar.gz
cd install-tl-*

# Create install profile
if $FULL_INSTALL; then
  SCHEME="scheme-full"
  echo "📦 Installing FULL TeX Live (~2GB)..."
else
  SCHEME="scheme-basic"
  echo "📦 Installing minimal TeX Live (~500MB)..."
fi

cat > texlive.profile <<EOF
selected_scheme $SCHEME
TEXDIR $TEXLIVE_DIR/$TEXLIVE_YEAR
TEXMFLOCAL $TEXLIVE_DIR/texmf-local
TEXMFSYSCONFIG $TEXLIVE_DIR/$TEXLIVE_YEAR/texmf-config
TEXMFSYSVAR $TEXLIVE_DIR/$TEXLIVE_YEAR/texmf-var
TEXMFHOME ~/texmf
TEXMFCONFIG ~/.texlive$TEXLIVE_YEAR/texmf-config
TEXMFVAR ~/.texlive$TEXLIVE_YEAR/texmf-var
binary_$(uname -m)-linux 1
instopt_adjustpath 0
instopt_adjustrepo 1
instopt_letter 0
instopt_portable 0
instopt_write18_restricted 1
tlpdbopt_autobackup 1
tlpdbopt_create_formats 1
tlpdbopt_desktop_integration 0
tlpdbopt_file_assocs 0
tlpdbopt_generate_updmap 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
tlpdbopt_post_code 1
tlpdbopt_w32_multi_user 0
EOF

perl install-tl --profile=texlive.profile

# Add to PATH
BINDIR="$TEXLIVE_DIR/$TEXLIVE_YEAR/bin/$(uname -m)-linux"
export PATH="$BINDIR:$PATH"

# Add to shell profile if not already there
SHELL_RC="$HOME/.bashrc"
[[ -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.zshrc"

if ! grep -q "texlive" "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo "# TeX Live" >> "$SHELL_RC"
  echo "export PATH=\"$BINDIR:\$PATH\"" >> "$SHELL_RC"
  echo "✅ Added TeX Live to PATH in $SHELL_RC"
fi

# Install common packages for minimal install
if ! $FULL_INSTALL; then
  echo "📦 Installing essential packages..."
  tlmgr install \
    latexmk \
    geometry \
    hyperref \
    fancyhdr \
    titlesec \
    enumitem \
    xcolor \
    graphicx \
    amsmath \
    amssymb \
    biblatex \
    biber \
    booktabs \
    multirow \
    caption \
    float \
    listings \
    parskip \
    microtype \
    etoolbox \
    pgf \
    beamer \
    lm \
    ec \
    cm-super \
    fontspec 2>/dev/null || true
fi

# Install extra packages if specified
if [[ -n "$EXTRA_PACKAGES" ]]; then
  echo "📦 Installing extra packages: $EXTRA_PACKAGES"
  tlmgr install $EXTRA_PACKAGES
fi

# Cleanup
rm -rf "$TMPDIR"

echo ""
echo "✅ TeX Live installed successfully!"
echo "   Location: $TEXLIVE_DIR/$TEXLIVE_YEAR"
echo "   Version:  $(pdflatex --version 2>/dev/null | head -1 || echo 'Restart shell to use')"
echo ""
echo "💡 Restart your shell or run: source $SHELL_RC"
