#!/usr/bin/env bash
# Install build prerequisites for Modelio on Apple Silicon.
set -euo pipefail

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Warning: this script targets Apple Silicon (arm64). Current arch: $(uname -m)"
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install from https://brew.sh"
  exit 1
fi

echo "==> Fixing missing bin.includes directories (upstream packaging gaps)"
python3 "$ROOT/scripts/fix-missing-bin-includes.py"

echo "==> Installing Maven toolchains (JavaSE-1.8 + JavaSE-11)"
cp "$ROOT/AGGREGATOR/toolchains.xml" "$HOME/.m2/toolchains.xml"

echo "==> Installing JDK 11 and Maven"
brew install openjdk@11 maven

JAVA11="$(brew --prefix openjdk@11)/libexec/openjdk.jdk/Contents/Home"
if [[ ! -d "$JAVA11" ]]; then
  echo "Could not locate JDK 11 at $JAVA11"
  exit 1
fi

echo "==> Linking JDK 11 for system discovery (may require sudo)"
sudo ln -sfn "$(brew --prefix openjdk@11)/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk-11.jdk 2>/dev/null || true

export JAVA_HOME="$JAVA11"
export PATH="$JAVA_HOME/bin:$PATH"

echo ""
echo "Add to your shell profile (~/.zshrc):"
echo "  export JAVA_HOME=\"$JAVA11\""
echo "  export PATH=\"\$JAVA_HOME/bin:\$PATH\""
echo ""

echo "==> Verifying toolchain"
java -version
mvn -version
echo ""
echo "Ready. Next: ./scripts/fetch-macos-aarch64-launcher.sh"
