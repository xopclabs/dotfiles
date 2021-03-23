#!/bin/bash

# Terminate already running bar instances
pkill polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# polybar -rq dummy & 
polybar -rq music &
polybar -rq tray &
polybar -rq bspwm &

polybar -rq music-ex &
polybar -rq tray-ex &
polybar -rq bspwm-ex &

echo "Polybar launched..."
