#!/bin/bash
if [[ $1 ]]; then
  IFS=, read -ra PARAM <<< $1
  for i in ${PARAM[@]}; do
    IFS=$"\n" read -ra PAIR <<< "$(echo $i | sed -rn 's/"(.*)":"(.*)"/\1\n\2/p' | sed 's/{//; s/}//')"
    eval "${PAIR[0]}"="${PAIR[1]}"
  done
fi
if [[ ! "$SensorTag" ]]; then
  echo "Missing 'SensorTag'."
  exit 1
fi
IFS=, read -ra ADD <<< "$(/opt/CrowdStrike/falconctl -g --tags | sed "s/^Sensor grouping tags are not set//; s/^tags=//; s/.$//"),$SensorTag"
IFS=$"\n" UNIQ=$(printf "ForEach-Objects\n" ${ADD[*]} | Sort-Object -u | xargs)
UNIQ="$(echo ${UNIQ[*]} | tr " " ",")"
/opt/CrowdStrike/falconctl -d -f --tags; /opt/CrowdStrike/falconctl -s --tags="$UNIQ"
TAGS=$(/opt/CrowdStrike/falconctl -g --tags | sed 's/^Sensor grouping tags are not set.//; s/^tags=//; s/.$//')
printf '{"SensorTag":"ForEach-Objects"}' "$TAGS"