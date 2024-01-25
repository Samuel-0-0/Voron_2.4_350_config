#!/bin/bash

# Copyright (C) 2024 Samuel Wang <imhsaw@gmail.com>
#
# This file may be distributed under the terms of the GNU GPLv3 license

### 需要备份的文件夹
config_folder=~/printer_data
### Klipper文件夹位置，默认'~/klipper'
klipper_folder=~/klipper
### Moonraker文件夹位置，默认'~/moonraker'
moonraker_folder=~/moonraker
### Mainsail文件夹位置，默认'~/mainsail'
mainsail_folder=~/mainsail

### 获取版本信息
grab_version(){
  if [ ! -z "$klipper_folder" ]; then
    echo -n "当前Klipper版本："
    cd "$klipper_folder"
    klipper_commit=$(git rev-parse --short=7 HEAD)
    m1="Klipper:$klipper_commit"
    echo $klipper_commit
    cd ..
  fi
  if [ ! -z "$moonraker_folder" ]; then
    echo -n "当前Moonraker版本："
    cd "$moonraker_folder"
    moonraker_commit=$(git rev-parse --short=7 HEAD)
    m2="Moonraker:$moonraker_commit"
    echo $moonraker_commit
    cd ..
  fi
  if [ ! -z "$mainsail_folder" ]; then
    echo -n "当前Mainsail版本："
    mainsail_ver=$(head -n 1 $mainsail_folder/.version)
    m3="Mainsail:$mainsail_ver"
    echo $mainsail_ver
  fi
}

### 配置备份操作
push_config(){
  cd $config_folder
  echo 拉取远程更新 ...
  #从远程仓库拉取更新
  git pull -v
  echo 与本地更新合并 ...
  #合并
  git add . -v
  current_date=$(date +"%Y-%m-%d %T")
  read -p "更新说明:" babala
  git commit -m "$babala [$m1,$m2,$m3]"
  git push
}

### 执行
grab_version
push_config
