#!/bin/bash
ln -f -t ~/.config/polybar ~/.config/polybar/themes/$1/*
~/scripts/launch-polybar.sh
