#!/usr/bin/env bash
# Debug Modelio macOS app startup (GUI / Dock issues).
set -euo pipefail

APP="${1:-/Applications/Modelio 5.4.1.app}"
BINARY="$APP/Contents/MacOS/modelio"
INI="$APP/Contents/Eclipse/modelio.ini"
LOG_DIR="$HOME/.modelio/5.4"
DEBUG_LOG="${TMPDIR:-/tmp}/modelio-debug-$(date +%Y%m%d-%H%M%S).log"

if [[ ! -x "$BINARY" ]]; then
  echo "App not found: $APP"
  echo "Usage: $0 [/path/to/Modelio 5.4.1.app]"
  exit 1
fi

echo "=== Modelio macOS debug ==="
echo "App:     $APP"
echo "Binary:  $(file "$BINARY")"
echo "Ini:     $INI"
echo "User log: $LOG_DIR"
echo "Capture: $DEBUG_LOG"
echo

echo "--- modelio.ini ---"
cat "$INI"
echo

echo "--- Java check ---"
if grep -q '^-vm$' "$INI" 2>/dev/null; then
  VM_PATH="$(awk '/^-vm$/{getline; print; exit}' "$INI")"
  if [[ -x "$VM_PATH" ]]; then
    echo "OK: -vm points to executable Java at $VM_PATH"
    "$VM_PATH" -version 2>&1
  else
    echo "ERROR: -vm is set but not executable: $VM_PATH"
  fi
else
  echo "ERROR: modelio.ini has no -vm entry."
  echo "       Finder/Dock launch will fail with 'Unable to locate a Java Runtime'."
  echo "       Fix: add before -vmargs:"
  echo "         -vm"
  echo "         /opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home/bin/java"
fi
echo

echo "--- Gatekeeper / quarantine ---"
xattr -l "$APP" 2>/dev/null || true
if xattr "$APP" 2>/dev/null | grep -q com.apple.quarantine; then
  echo "WARNING: quarantine flag set. Clear with:"
  echo "  xattr -cr \"$APP\""
fi
echo

echo "--- Launch with -consoleLog (15s) ---"
echo "Output saved to $DEBUG_LOG"
(
  "$BINARY" -consoleLog -debug 2>&1 &
  PID=$!
  sleep 15
  if ps -p "$PID" >/dev/null 2>&1; then
    echo "[debug] Modelio still running (pid $PID) — likely OK"
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  else
    echo "[debug] Modelio exited within 15s — check errors above"
  fi
) | tee "$DEBUG_LOG"

echo
echo "--- Latest user log ---"
if [[ -d "$LOG_DIR" ]]; then
  LATEST="$(ls -t "$LOG_DIR"/modelio-*.log 2>/dev/null | head -1)"
  if [[ -n "${LATEST:-}" ]]; then
    echo "$LATEST"
    grep -E 'ERROR|Exception|Modelio version|Unable|FATAL' "$LATEST" | tail -30 || true
  else
    echo "(no modelio-*.log yet)"
  fi
else
  echo "(no $LOG_DIR — app never reached Modelio startup)"
fi

echo
echo "Done. Full capture: $DEBUG_LOG"
echo "Also check Console.app → filter 'modelio' or 'java'."
