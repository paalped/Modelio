#!/usr/bin/env bash
# Mirror Eclipse 4.24 RCP platform to a local p2 repository for offline/reproducible builds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ECLIPSE_VERSION="${ECLIPSE_VERSION:-4.24}"
ECLIPSE_REPO="${ECLIPSE_REPO:-https://download.eclipse.org/eclipse/updates/4.24/R-4.24-202206070700}"
DEST="${DEST:-$ROOT/dev-platform/rcp-target/rcp-eclipse/eclipse}"
WORK_DIR="${TMPDIR:-/tmp}/modelio-eclipse-mirror-$$"
SDK_ARCHIVE="${WORK_DIR}/eclipse-sdk.tar.gz"

# IUs required by Modelio product (matches vendored 4.18 feature set + draw2d/gef from separate repos)
INSTALL_IUS=(
  "org.eclipse.rcp.feature.group"
  "org.eclipse.e4.rcp.feature.group"
  "org.eclipse.platform.feature.group"
  "org.eclipse.equinox.executable.feature.group"
  "org.eclipse.equinox.p2.core.feature.feature.group"
  "org.eclipse.equinox.p2.extras.feature.feature.group"
  "org.eclipse.equinox.p2.rcp.feature.feature.group"
  "org.eclipse.equinox.p2.user.ui.feature.group"
  "org.eclipse.help.feature.group"
  "org.eclipse.emf.common.feature.group"
  "org.eclipse.emf.ecore.feature.group"
  "org.eclipse.ecf.core.feature.feature.group"
  "org.eclipse.ecf.core.ssl.feature.feature.group"
  "org.eclipse.ecf.filetransfer.feature.feature.group"
  "org.eclipse.ecf.filetransfer.httpclient5.feature.feature.group"
  "org.eclipse.ecf.filetransfer.ssl.feature.feature.group"
  "org.eclipse.rcp.source.feature.group"
  "org.eclipse.e4.rcp.source.feature.group"
)

mkdir -p "$WORK_DIR" "$DEST"

echo "==> Downloading Eclipse ${ECLIPSE_VERSION} SDK bootstrap (macOS aarch64)"
curl -fL --progress-bar \
  "https://download.eclipse.org/eclipse/downloads/drops4/R-4.24-202206070700/eclipse-SDK-4.24-macosx-cocoa-aarch64.tar.gz" \
  -o "$SDK_ARCHIVE"
tar -xzf "$SDK_ARCHIVE" -C "$WORK_DIR"

ECLIPSE_BIN="$(find "$WORK_DIR" -path '*/Eclipse.app/Contents/MacOS/eclipse' | head -1)"
if [[ -z "$ECLIPSE_BIN" || ! -x "$ECLIPSE_BIN" ]]; then
  echo "Could not find Eclipse SDK launcher"
  exit 1
fi

echo "==> Mirroring platform IUs to $DEST"
IU_LIST="$(IFS=,; echo "${INSTALL_IUS[*]}")"

# Backup existing 4.18 mirror
if [[ -d "$DEST/plugins" ]]; then
  BACKUP="${DEST}.bak-4.18-$(date +%Y%m%d)"
  if [[ ! -d "$BACKUP" ]]; then
    echo "==> Backing up current platform to $BACKUP"
    cp -a "$DEST" "$BACKUP"
  fi
  rm -rf "$DEST"
  mkdir -p "$DEST"
fi

"$ECLIPSE_BIN" -nosplash -application org.eclipse.ant.core.antRunner \
  -consoleLog -data "$WORK_DIR/ws" \
  -Dsource="$ECLIPSE_REPO" \
  -Ddestination="$DEST" \
  -Dius="$IU_LIST" \
  -f "$ROOT/scripts/p2-mirror.xml" 2>&1 || {
    echo "Ant mirror failed, trying p2 director fallback..."
    "$ECLIPSE_BIN" -nosplash -application org.eclipse.equinox.p2.director \
      -repository "$ECLIPSE_REPO" \
      -destination "$DEST" \
      -installIU "$IU_LIST" \
      -profileProperties org.eclipse.update.install.features=true \
      -bundlepool "$DEST" \
      -p2.os macosx -p2.ws cocoa -p2.arch aarch64 2>&1
  }

echo "==> Writing rcp.txt"
cat > "$DEST/rcp.txt" <<EOF
org.eclipse.platform-${ECLIPSE_VERSION}
org.eclipse.rcp.source-${ECLIPSE_VERSION}
Mirrored from ${ECLIPSE_REPO}
$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "==> Mirror complete: $DEST"
echo "    Plugins: $(ls "$DEST/plugins" 2>/dev/null | wc -l | tr -d ' ')"
echo "    Features: $(ls "$DEST/features" 2>/dev/null | wc -l | tr -d ' ')"
