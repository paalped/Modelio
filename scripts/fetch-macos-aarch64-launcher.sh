#!/usr/bin/env bash
# Fetch Eclipse macOS ARM64 launcher fragment and root files into the Modelio RCP target.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ECLIPSE_P2="https://download.eclipse.org/eclipse/updates/4.24"
WORK_DIR="${TMPDIR:-/tmp}/modelio-aarch64-fetch"
EXEC_FEATURE_DIR="$(
  find "$ROOT/dev-platform/rcp-target/rcp-eclipse/eclipse/features" \
    -maxdepth 1 -type d -name 'org.eclipse.equinox.executable_*' | head -1
)"

if [[ -z "$EXEC_FEATURE_DIR" ]]; then
  echo "Could not find org.eclipse.equinox.executable feature directory"
  exit 1
fi

PLUGINS_DIR="$ROOT/dev-platform/rcp-target/rcp-eclipse/eclipse/plugins"
AARCH64_BIN="$EXEC_FEATURE_DIR/bin/cocoa/macosx/aarch64"

mkdir -p "$WORK_DIR" "$PLUGINS_DIR" "$AARCH64_BIN"

echo "==> Downloading Eclipse 4.24 p2 metadata"
curl -fsSL "$ECLIPSE_P2/compositeContent.jar" -o "$WORK_DIR/compositeContent.jar"
curl -fsSL "$ECLIPSE_P2/compositeArtifacts.jar" -o "$WORK_DIR/compositeArtifacts.jar"

# Resolve child repo (4.24 typically points to R-4.24-...)
CHILD_URL="$(
  python3 - <<'PY' "$WORK_DIR/compositeContent.jar"
import sys, zipfile, xml.etree.ElementTree as ET
with zipfile.ZipFile(sys.argv[1]) as z:
    xml = z.read("compositeContent.xml")
root = ET.fromstring(xml)
for child in root.iter("{http://www.eclipse.org/equinox/internal/p2/composite/content}child"):
    loc = child.attrib.get("location")
    if loc and "R-4.24" in loc:
        print(loc)
        break
PY
)"

if [[ -z "$CHILD_URL" ]]; then
  CHILD_URL="https://download.eclipse.org/eclipse/updates/4.24/R-4.24-202206070700"
  echo "Using fallback repo: $CHILD_URL"
else
  echo "Resolved repo: $CHILD_URL"
fi

curl -fsSL "$CHILD_URL/content.jar" -o "$WORK_DIR/content.jar"

echo "==> Locating launcher aarch64 IU"
LAUNCHER_JAR="$(
  python3 - <<'PY' "$WORK_DIR/content.jar"
import sys, zipfile, re
with zipfile.ZipFile(sys.argv[1]) as z:
    xml = z.read("content.xml").decode("utf-8", "replace")
match = re.search(
    r"<artifact[^>]*id='org\.eclipse\.equinox\.launcher\.cocoa\.macosx\.aarch64'[^>]*version='([^']+)'",
    xml,
)
if not match:
    raise SystemExit("launcher aarch64 artifact not found in p2 repo")
version = match.group(1)
print(f"org.eclipse.equinox.launcher.cocoa.macosx.aarch64_{version}.jar")
PY
)"

echo "==> Downloading $LAUNCHER_JAR"
curl -fsSL "$CHILD_URL/plugins/$LAUNCHER_JAR" -o "$PLUGINS_DIR/$LAUNCHER_JAR"

echo "==> Downloading equinox.executable feature for aarch64 root files"
EXEC_FEATURE_JAR="$(
  python3 - <<'PY' "$WORK_DIR/content.jar"
import sys, zipfile, re
with zipfile.ZipFile(sys.argv[1]) as z:
    xml = z.read("content.xml").decode("utf-8", "replace")
match = re.search(
    r"<artifact[^>]*id='org\.eclipse\.equinox\.executable'[^>]*version='([^']+)'",
    xml,
)
if not match:
    raise SystemExit("equinox.executable artifact not found")
version = match.group(1)
print(f"org.eclipse.equinox.executable_{version}.jar")
PY
)"

EXEC_JAR_PATH="$WORK_DIR/$EXEC_FEATURE_JAR"
curl -fsSL "$CHILD_URL/features/$EXEC_FEATURE_JAR" -o "$EXEC_JAR_PATH"

echo "==> Extracting macosx.cocoa.aarch64 root files"
rm -rf "$AARCH64_BIN"
mkdir -p "$AARCH64_BIN"
unzip -qo "$EXEC_JAR_PATH" "bin/cocoa/macosx/aarch64/*" -d "$EXEC_FEATURE_DIR"
chmod +x "$AARCH64_BIN/Eclipse.app/Contents/MacOS/launcher" 2>/dev/null || true

echo ""
echo "Fetched:"
echo "  $PLUGINS_DIR/$LAUNCHER_JAR"
echo "  $AARCH64_BIN/"
echo ""
echo "Next: patch feature.xml files (see docs/BUILD-APPLE-SILICON.md step 3)"
