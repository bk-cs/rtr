#!/bin/zsh
write() {
  local log="/Library/Application Support/CrowdStrike/Falcon/RTR/get_sensortag_$(date +%s).json"
  local json='{"SensorTag":"%s"}'
  if [ "$2" = '{"Log":true}' ]; then
    if [ ! -d "/Library/Application Support/CrowdStrike/Falcon/RTR" ]; then
      mkdir "/Library/Application Support/CrowdStrike/Falcon/RTR"
    fi
    printf "$json" "$1" >> "$log"
  fi
  printf "$json" "$1"
}
tag=$(/Applications/Falcon.app/Contents/Resources/falconctl grouping-tags get | sed 's/^No grouping tags set//; s/^Grouping tags: //')
write "$tag" "$1"