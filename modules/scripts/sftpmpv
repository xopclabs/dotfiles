#!/usr/bin/env bash

server=$1;
file=$2;
filename=$(basename "$file");
directory_path=$(dirname "$file");

if [ -n "$3" ]; then
    result_file=$3;
else
    result_file="$filename";
fi

sftp "$server:$directory_path/$filename" ~/videos/"$result_file";
mpv --loop ~/videos/"$result_file";
