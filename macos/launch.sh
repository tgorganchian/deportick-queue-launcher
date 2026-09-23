#!/bin/bash
# Opens N Chrome windows, each with its own isolated profile, so each one gets its own place
# in the Deportick (Queue-it) waiting room. Checkout is done by hand in whichever window gets through.
#
# Usage:
#   ./launch.sh --setup                                              # log in once
#   ./launch.sh "https://www.deportick.com/event/<event>" 5
#   ./launch.sh --reset                                              # wipe saved profiles

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PROFILES="$(cd "$(dirname "$0")/.." && pwd)/profiles"
MAIN="$PROFILES/profile-0"

if [ "$1" = "--reset" ]; then
    rm -rf "$PROFILES"
    echo "Profiles removed."
    exit 0
fi

SETUP=false
if [ "$1" = "--setup" ]; then
    SETUP=true
    URL="https://www.deportick.com"
    COUNT=1
else
    URL="${1:-https://www.deportick.com}"
    COUNT="${2:-5}"
fi

mkdir -p "$PROFILES"

# Log in once in profile-0. Every other window is a fresh profile that only receives profile-0's
# cookies and localStorage (Deportick keeps the login in localStorage, keys "crowder" and
# "crowder-user"). Then Queue-it cookies are cleared so each window is assigned a fresh QueueId.
# Chrome must be closed while copying.
if [ "$SETUP" = false ] && [ -d "$MAIN" ]; then
    for ((i = 1; i < COUNT; i++)); do
        rm -rf "$PROFILES/profile-$i"
        mkdir -p "$PROFILES/profile-$i/Default/Network"
        cp "$MAIN/Local State" "$PROFILES/profile-$i/"
        cp "$MAIN/Default/Network/Cookies" "$PROFILES/profile-$i/Default/Network/"
        cp -R "$MAIN/Default/Local Storage" "$PROFILES/profile-$i/Default/"
    done
    echo "Session cloned from profile-0 into $((COUNT - 1)) more profiles."
    for ((i = 0; i < COUNT; i++)); do
        DB="$PROFILES/profile-$i/Default/Network/Cookies"
        [ -f "$DB" ] && sqlite3 "$DB" "DELETE FROM cookies WHERE host_key LIKE '%queue-it%' OR name LIKE 'QueueIT%' OR name LIKE 'Queue-it%'; SELECT '  ' || changes() || ' queue cookies removed';"
    done
fi

# Tile windows over the screen: as many ~500px-wide columns as fit (Chrome's minimum width)
# and 2 rows. Windows beyond that fill the same slots again, cascaded 40px so they stay visible.
BOUNDS=$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null)
SCREEN_W=$(echo "$BOUNDS" | cut -d, -f3 | tr -d ' '); SCREEN_W=${SCREEN_W:-1512}
SCREEN_H=$(echo "$BOUNDS" | cut -d, -f4 | tr -d ' '); SCREEN_H=${SCREEN_H:-982}
MENU_BAR=40
COLS=$(( SCREEN_W / 500 )); ROWS=2; SLOTS=$(( COLS * ROWS ))
W=$(( SCREEN_W / COLS )); H=$(( (SCREEN_H - MENU_BAR) / ROWS ))
echo "Screen ${SCREEN_W}x${SCREEN_H}: ${SLOTS} windows fit side by side."
for ((i = 0; i < COUNT; i++)); do
    SLOT=$(( i % SLOTS )); LAYER=$(( i / SLOTS ))
    X=$(( (SLOT % COLS) * W + LAYER * 40 ))
    Y=$(( MENU_BAR + (SLOT / COLS) * H + LAYER * 40 ))
    "$CHROME" --user-data-dir="$PROFILES/profile-$i" \
        --no-first-run --no-default-browser-check --disable-sync \
        --window-size=$W,$H --window-position=$X,$Y \
        "$URL" >/dev/null 2>&1 &
    echo "[$((i + 1))/$COUNT] window opened - profile-$i"
    sleep 0.4
done
