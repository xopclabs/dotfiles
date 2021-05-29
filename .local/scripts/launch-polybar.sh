#!/bin/sh

# Terminate already running bar instances
pkill polybar

# Wait until the process have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch internal monitor bar
echo 'Launching polybar on internal monitor...'
sh ~/.config/polybar/launch.sh & 

# Launch external monitor bar
monitor=$(xrandr -q | grep 'HDMI-\?2')
echo $monitor
if [[ $monitor  = *connected* ]]; then
    echo 'Launching polybar on external monitor...'
#    sh ~/.config/polybar/launch.sh & 
fi


