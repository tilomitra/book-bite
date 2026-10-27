#!/bin/sh
# Renders slides.html into out/ at the App Store 6.9" size (1320 x 2868) with headless Chrome.
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p out
for n in 1 2 3 4 5 6 7; do
  "$CHROME" --headless=new --hide-scrollbars --force-device-scale-factor=1 \
    --window-size=1320,2868 --virtual-time-budget=8000 \
    --screenshot="$PWD/out/$n.png" "file://$PWD/slides.html#$n" 2>/dev/null
done
ls out
