#!/bin/bash

URLS=($(yq read hardening_manifest.yaml "resources[*].url"))
HASH=($(yq read hardening_manifest.yaml "resources[*].validation.value"))
FILENAMES=($(yq read hardening_manifest.yaml "resources[*].filename"))
length=${#URLS[@]}
for (( i=0; i<${length}; i++ ));
do
  echo "${URLS[$i]} ${HASH[$i]} ${FILENAMES[$i]}"
  curl -o ${FILENAMES[$i]} ${URLS[$i]} > /dev/null
  #REALHASH=$(sha256sum ${FILENAMES[$i]} | awk '{print $1}')
  #echo $REALHASH
  #echo "  - url: \"${URLS[$i]}\"
  #  filename: \"${FILENAMES[$i]}\"
  #  validation:
  #    type: sha256
  #    value: $REALHASH
  #  auth:
  #    type: basic
  #    id: tcp-basic"
done

