#!/usr/bin/env bash
set -e

echo "🔄 Updating Yas Island..."

# 1. Build and package the updated app
./scripts/build_app.sh

# 2. Reinstall into /Applications
echo "📲 Installing updated version to /Applications..."
killall YasIsland 2>/dev/null || true
rm -rf "/Applications/Yas Island.app"
cp -R "Yas Island.app" /Applications/

# 3. Relaunch
echo "🚀 Relaunching Yas Island..."
open -a "/Applications/Yas Island.app"

echo "✨ Update complete! Yas Island is running with your latest changes."
