#!/bin/bash
# Reads DEVELOPMENT_TEAM from local.yml (gitignored) and generates the Xcode project
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_YML="$SCRIPT_DIR/local.yml"

if [ -f "$LOCAL_YML" ]; then
    export DEVELOPMENT_TEAM=$(grep 'DEVELOPMENT_TEAM:' "$LOCAL_YML" | awk '{print $2}')
fi

xcodegen generate
