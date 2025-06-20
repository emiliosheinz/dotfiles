#!/bin/sh

CONFIG_FILE="$HOME/.docker/config.json"
BACKUP_FILE="$CONFIG_FILE.bak"
PLUGIN_DIR="$HOMEBREW_PREFIX/lib/docker/cli-plugins"

# Ensure config directory exists
mkdir -p "$(dirname "$CONFIG_FILE")"

# Backup original config
[ -f "$CONFIG_FILE" ] && cp "$CONFIG_FILE" "$BACKUP_FILE"

# Create empty JSON if config doesn't exist
[ ! -f "$CONFIG_FILE" ] && echo '{}' > "$CONFIG_FILE"

# Use jq to safely update or insert the field
tmpfile=$(mktemp)

jq --arg pluginDir "$PLUGIN_DIR" '
  .cliPluginsExtraDirs = (
    (.cliPluginsExtraDirs // []) + [$pluginDir] | unique
  )
' "$CONFIG_FILE" > "$tmpfile" && mv "$tmpfile" "$CONFIG_FILE"

echo "✅ Updated $CONFIG_FILE with cliPluginsExtraDirs"
