#!/bin/zsh
# Exports every App Store screenshot and banner in artwork.html to export/*.png at its exact size.
# Usage: ./marketing/app-store/render.sh   (needs Google Chrome and python3)
set -e
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PORT=8799

python3 -m http.server $PORT --directory . >/dev/null 2>&1 &
SERVER=$!
trap "kill $SERVER" EXIT
sleep 1

mkdir -p app-store/export
render() { # id width height
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size=$2,$3 --virtual-time-budget=8000 \
    --screenshot="app-store/export/$1.png" "http://localhost:$PORT/app-store/artwork.html?id=$1" 2>/dev/null
  echo "  $1.png  ($2×$3)"
}

for id in 01-proven 02-capture 03-numbers 04-rankings 05-pbs 06-streaks \
          07-coach-rowers 08-coach-workouts 09-coach-boats 10-coach-calendar; do
  render $id 1290 2796
done
render banner-feature-1920x1080 1920 1080
render banner-social-1200x630 1200 630
render banner-coach-promo-1024 1024 1024

# The social banner doubles as the website's link preview image.
cp app-store/export/banner-social-1200x630.png website/assets/og.png
echo "Done → marketing/app-store/export/"
