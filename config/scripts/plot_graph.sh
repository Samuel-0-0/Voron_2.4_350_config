#!/bin/bash

# Copyright (C) 2021 Stephan Wendel <me@stephanwe.de>
#
# This file may be distributed under the terms of the GNU GPLv3 license

#####################################################################
### Please set the paths accordingly.                             ###
#####################################################################
### Path to your config folder where you want to store your input shaper files
IS_FOLDER=${HOME}/printer_data/config/input_shaper
### number of results you want to keep
STORE_RESULTS=5

#####################################################################
################ !!! DO NOT EDIT BELOW THIS LINE !!! ################
#####################################################################
function arg_parse {
  case ${1} in
    SHAPER|shaper)
      plot_shaper_graph
    ;;
    BELT|belt)
      plot_belt_graph
    ;;
    *)
      echo -e "\n使用方法："
      echo -e "\t${0} SHAPER|BELT"
      echo -e "\t\tSHAPER\t生成输入整形器（Input Shaper）的图表"
      echo -e "\t\tBELT\t生成皮带张力图表\n"
      exit 1
  esac
}

function generate_folder {
  if [ ! -d "${IS_FOLDER}" ]; then
    mkdir -p "${IS_FOLDER}"
  fi
}

function plot_shaper_graph {
  local axis date file isf generator
  axis=(x y)
  generator="${HOME}/klipper/scripts/calibrate_shaper.py"
  isf="${IS_FOLDER//\~/${HOME}}"
  for s in "${axis[@]}"; do
  #shellcheck disable=SC2012
    file="$(ls -tr /tmp/resonances_"${s}"_* | sort -nr | head -1)"
    date="$(basename "${file}" | cut -d '.' -f1 | awk -F'_' '{print $3"_"$4}')"
  echo "正在为 ${s} 轴生成图表 ..."
  "${generator}" "${file}" -o "${isf}"/resonances_"${s}"_"${date}".png
  mv "${file}" "${isf}"/
  done
}

function plot_belt_graph {
  local belts csv date date_ext file isf generator src
  belts=(a b)
  date_ext="$(date +%Y%m%d_%H%M%S)"
  generator="${HOME}/klipper/scripts/graph_accelerometer.py"
  isf="${IS_FOLDER//\~/${HOME}}"
  #shellcheck disable=SC2012
  for i in "${belts[@]}"; do
    csv="$(/usr/bin/ls -tr /tmp/raw_data_axis*"${i}"* | sort -nr | awk 'NR==1')"
    mv "${csv}" /tmp/raw_data_belt_"$i"_"${date_ext}".csv
    src+=("/tmp/raw_data_belt_${i}_${date_ext}.csv")
  done
    echo "正在生成皮带张力图表 ..."
    "${generator}" -c "${src[@]}" -o "${isf}"/resonances_belts_"${date_ext}".png
  for f in "${src[@]}"; do
    mv "${f}" "${isf}"/
  done
}

function remove_files {
  local isf axis old
  axis=(x y belts)
  belts=(a b)
  ext=(.csv .png)
  isf="${IS_FOLDER//\~/${HOME}}"
  pushd "${isf}" &> /dev/null || exit 1
  for e in "${ext[@]}"; do
    for i in "${axis[@]}"; do
      # shellcheck disable=SC2012
      for f in $(/usr/bin/ls -tr resonances_"${i}"*"${e}" 2> /dev/null | sort -nr | awk 'NR>'${STORE_RESULTS}''); do
        old+=("${f}")
      done
    done
    for j in "${belts[@]}"; do
      for b in $(/usr/bin/ls -tr raw_data_belt_"${j}"*"${e}" 2> /dev/null | sort -nr | awk 'NR>'${STORE_RESULTS}''); do
        old+=("${b}")
      done
    done
  done
    if [ "${#old[@]}" -ne 0 ]; then
      for rmv in "${old[@]}"; do
        rm "${rmv}"
      done
    fi
  popd &> /dev/null || exit 1
}

### MAIN
generate_folder
arg_parse "${@}"
remove_files
