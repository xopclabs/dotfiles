#!/usr/bin/env bash

# Add this script to your wm startup file.

DIR="/home/xopc/.config/polybar/shapes/"

# Terminate already running bar instances
pkill polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch the bars
polybar -q main -c "$DIR"/config.ini &
polybar -q second -c "$DIR"/config.ini &

