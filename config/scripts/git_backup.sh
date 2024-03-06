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

MAX_RETRIES=10

### 打印消息颜色
green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

### 打印消息
function report_status {
    case $1 in
        ok)
            echo -e "\n\n${green}###### $2 ${default}"
            ;;
        warning)
            echo -e "\n\n${yellow}###### $2 ${default}"
            ;;
        error)
            echo -e "\n\n${red}###### $2 ${default}"
            ;;
    esac
}

### 获取版本信息
function grab_version {
  if [ ! -z "$klipper_folder" ]; then
    report_status "ok" "当前Klipper版本："
    cd "$klipper_folder"
    klipper_commit=$(git rev-parse --short=7 HEAD)
    m1="Klipper:$klipper_commit"
    echo $klipper_commit
    cd ..
  fi
  if [ ! -z "$moonraker_folder" ]; then
    report_status "ok" "当前Moonraker版本："
    cd "$moonraker_folder"
    moonraker_commit=$(git rev-parse --short=7 HEAD)
    m2="Moonraker:$moonraker_commit"
    echo $moonraker_commit
    cd ..
  fi
  if [ ! -z "$mainsail_folder" ]; then
    report_status "ok" "当前Mainsail版本："
    mainsail_ver=$(head -n 1 $mainsail_folder/.version)
    m3="Mainsail:$mainsail_ver"
    echo $mainsail_ver
  fi
}

### 拉取失败重试
function git_pull {
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # 执行 git 命令
        git pull -v
        # 检查 git 命令的返回状态码
        if [ $? -eq 0 ]; then
            report_status "ok" "完成"
            break
        else
            ((retry_count++))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                report_status "warning" "失败，开始第$RETRY_COUNT次重试..."
                git_pull
            else
                report_status "error" "失败，已达到最大尝试次数，请稍后再试..."
                exit 1
            fi
        fi
    done
}

### 推送失败重试
function git_push {
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # 执行 git 命令
        git pull -v
        # 检查 git 命令的返回状态码
        if [ $? -eq 0 ]; then
            report_status "ok" "完成"
            break
        else
            ((retry_count++))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                report_status "warning" "失败，开始第$RETRY_COUNT次重试..."
                git_push
            else
                report_status "error" "失败，已达到最大尝试次数，请稍后再试..."
                exit 1
            fi
        fi
    done
}


### 配置备份操作
function push_config {
  cd $config_folder
  report_status "ok" "拉取远程更新 ..."
  #从远程仓库拉取更新
  RETRY_COUNT=0
  git_pull
  report_status "ok" "与本地更新合并 ..."
  #合并
  git add . -v
  current_date=$(date +"%Y-%m-%d %T")
  read -p "更新说明:" babala
  git commit -m "$babala [$m1,$m2,$m3]"
  RETRY_COUNT=0
  git_push
}

### 执行
grab_version
push_config
