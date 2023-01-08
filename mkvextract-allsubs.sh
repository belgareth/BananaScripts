#!/usr/bin/env bash
# Requires:
#   mkvmerge
#   mkvextract

if [ $# -lt 1 ]
then
    echo "You must provide at least one input filename."
    exit 1
fi

for cmd in "mkvmerge" "mkvextract"
do
    if ! hash "$cmd" 2>/dev/null
    then
        echo "Missing dependency: $cmd"
        exit 1
    fi
done

declare -A codec_map
codec_map["S_TEXT/UTF8"]="srt"
codec_map["S_TEXT/ASS"]="ssa"
codec_map["S_TEXT/USF"]="usf"
codec_map["S_VOBSUB"]="sub"
codec_map["S_HDMV/PGS"]="sup"

for file in "$@"
do
    if [ ! -f "$file" ]
    then
        echo "File doesn't exist: $file"
        exit 1
    fi
    result=$(mkvmerge --identify --identification-format json "$file")
    if [ $? -ne 0 ]
    then
        echo "Error in mkvmerge while parsing: $file"
        echo "$result"
        exit 1
    fi
    d=$(echo "$result" | python -m json.tool)
    if ! echo "$d" | grep "tracks" &>/dev/null
    then
        echo "Invalid JSON output from mkvmerge for file: $file"
        exit 1
    fi
    for track in $(echo "$d" | grep -A2 "tracks" | grep -B1 "id")
    do
        track_id=$(echo "$track" | grep -oE "[0-9]+")
        codec=$(echo "$track" | grep -A1 "codec_id" | grep -oE "[A-Za-z0-9_/]+")
        language=$(echo "$track" | grep -A1 "language" | grep -oE "[A-Za-z0-9_/]+")
        name=$(echo "$track" | grep -A1 "track_name" | grep -oE "[A-Za-z0-9_/]+")
        if [ -z "$codec" ] || [ -z "${codec_map[$codec]}" ]
        then
            continue
        fi
        output_name="$(basename "$file" .*).${language}.${track_id}.${name}.${codec_map[$codec]}"
        output_name="$(echo "$output_name" | sed  -e 's/[\/\\?%*:|"<>\x7F\x00-\x1F]/-/g')"
        echo "- Track $track_id: $output_name"
        output_file="$(dirname "$file")/$output_name"
        result=$(mkvextract tracks "$file" "$track_id:$output_file")
        if [ $? -ne 0 ]
        then
            echo "Error while extracting track $track_id from file: $file"
            echo "$result"
            exit 1
        fi
        echo "  To: \"$output_file\""
    done
done
