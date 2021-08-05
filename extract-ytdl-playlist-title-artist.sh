#!/usr/bin/env bash
set -euo pipefail

# saves all title and artist info, both combined and seperated, into text files. not exactly flexible, but quick and simple for my man

while getopts l: flag
do
    case "${flag}" in
        l) link=${OPTARG};;
    esac
done

mkdir -p ./youtube-playlist-list && cd ./youtube-playlist-list
youtube-dl -j --skip-download --flat-playlist $link | jq -r '' | grep --line-buffered -e title -e uploader > ./playlist-output.txt
cat ./playlist-output.txt | grep --line-buffered title | sed 's/^.*://' | tr -d '"",' > ./title-output.txt
cat ./playlist-output.txt | grep --line-buffered uploader |sed 's/^.*://' | tr -d '""' > ./uploader-output.txt
