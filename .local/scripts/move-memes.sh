#!/bin/bash

counter=1
for f in /home/xopc/coding/fun/meme_generator/*/image.jpg
do
    cp -v "$f" /home/xopc/coding/fun/meme_detector/image$counter.jpg
    counter=$((counter+1))
done
