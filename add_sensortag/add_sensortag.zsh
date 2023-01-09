#!/bin/zsh
IFS=,
ADD=$(/Applications/Falcon.app/Contents/Resources/falconctl grouping-tags get | sed "s/^No grouping tags set//; s/^Grouping tags: //")
ADD+=($@)
UNIQ=$(echo "${ADD[@]}" | tr " " "\n" | sort -u | tr "\n" "," | sed "s/,$//")
/Applications/Falcon.app/Contents/Resources/falconctl grouping-tags clear &> /dev/null
/Applications/Falcon.app/Contents/Resources/falconctl grouping-tags set "$UNIQ" &> /dev/null
TAGS=$(/Applications/Falcon.app/Contents/Resources/falconctl grouping-tags get | sed 's/^No grouping tags set//; s/^Grouping tags: //')
printf '{"SensorTag":"ForEach-Objects"}' "$TAGS"
