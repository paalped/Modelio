#!/usr/bin/env bash
# Fetch Temurin JRE 11 for macOS aarch64 and add to the Modelio p2 JRE feature.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JRE_FEATURE_DIR="$ROOT/dev-platform/pack-resources/openjdk-jre11/features/net.adoptium.temurin.jre.feature_11.0.15"
MAC_ROOT="$JRE_FEATURE_DIR/macosx.cocoa.aarch64"
WORK_DIR="${TMPDIR:-/tmp}/modelio-jre-arm64-$$"
JRE_VERSION="${JRE_VERSION:-11.0.24+8}"
JRE_ARCHIVE="OpenJDK11U-jre_aarch64_mac_hotspot_${JRE_VERSION//+/_}.tar.gz"
JRE_URL="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-${JRE_VERSION}/${JRE_ARCHIVE}"

mkdir -p "$WORK_DIR" "$MAC_ROOT"
echo "==> Downloading Temurin JRE 11 aarch64 from Adoptium"
curl -fL --progress-bar "$JRE_URL" -o "$WORK_DIR/$JRE_ARCHIVE"
tar -xzf "$WORK_DIR/$JRE_ARCHIVE" -C "$WORK_DIR"

JRE_HOME="$(find "$WORK_DIR" -maxdepth 1 -type d -name 'jdk-*' | head -1)"
if [[ -z "$JRE_HOME" ]]; then
  echo "Could not find extracted JRE"
  exit 1
fi

echo "==> Installing JRE into $MAC_ROOT"
rm -rf "$MAC_ROOT/Contents"
mkdir -p "$MAC_ROOT/Contents/Home"
cp -a "$JRE_HOME/." "$MAC_ROOT/Contents/Home/"
chmod -R u+w "$MAC_ROOT/Contents/Home/bin" 2>/dev/null || true
chmod +x "$MAC_ROOT/Contents/Home/bin/"* 2>/dev/null || true

# Update build.properties to include macOS aarch64 root
BUILD_PROPS="$JRE_FEATURE_DIR/build.properties"
if ! grep -q 'root.macosx.cocoa.aarch64' "$BUILD_PROPS"; then
  cat >> "$BUILD_PROPS" <<'EOF'

root.macosx.cocoa.aarch64 = macosx.cocoa.aarch64
root.macosx.cocoa.aarch64.permissions.755 = Contents/Home/bin/*
EOF
fi

echo "==> JRE arm64 ready at $MAC_ROOT"
file "$MAC_ROOT/Contents/Home/lib/jli/libjli.dylib" 2>/dev/null || \
  file "$MAC_ROOT/Contents/Home/bin/java"
