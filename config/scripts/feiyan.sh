#!/bin/bash

# Copyright (C) 2024 Samuel Wang <imhsaw@gmail.com>
#
# This file may be distributed under the terms of the GNU GPLv3 license

clear

### 遇到错误强制退出
set -e

### ROOT检测
[ $(id -u) -eq 0 ] || [ "$EUID" -eq 0 ] && whiptail --title \
  '/!\ 警告 - 不要以ROOT身份运行 /!\' --msgbox "  请不要以ROOT身份或者SUDO运行本脚本！
  在需要的时候，脚本会请求相应的权限。" 8 48  && exit 1

### 环境变量
KLIPPY_ENV_DIR="${HOME}/klippy-env"
SYSTEMD_DIR="/etc/systemd/system"
KLIPPER_DIR="${HOME}/klipper"
KLIPPER_USER=${USER}
KLIPPER_GROUP=${KLIPPER_USER}
MOONRAKER_DIR="${HOME}/moonraker"
MAINSAIL_DIR="${HOME}/mainsail"
KLIPPERSCREEN_DIR="${HOME}/KlipperScreen"
PRINTER_DATA="${HOME}/printer_data"
KLIPPER_ENV_FILE="${PRINTER_DATA}/systemd/klipper.env"
KLIPPER_CONFIG="${PRINTER_DATA}/config/printer.cfg"
KLIPPER_LOG="${PRINTER_DATA}/logs/klippy.log"
KLIPPER_SOCKET="/tmp/klippy_uds"

### 打印消息颜色
green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

code=$'
                                                 
        ██╗   ██╗ █████╗ ███████╗████████╗       
        ██║   ██║██╔══██╗██╔════╝╚══██╔══╝       
        ██║   ██║███████║███████╗   ██║          
        ╚██╗ ██╔╝██╔══██║╚════██║   ██║          
         ╚████╔╝ ██║  ██║███████║   ██║          
          ╚═══╝  ╚═╝  ╚═╝╚══════╝   ╚═╝          
        
遇到问题不要怕，QQ扫码加群找@三木

█████████████████████████████████████████████████████████
█████████████████████████████████████████████████████████
████ ▄▄▄▄▄ █▀▀ ▄   ██ ▀ █ ▀█▀▄▀▄ ▄  ▀▀▀█ ▀▀▀ █ ▄▄▄▄▄ ████
████ █   █ █▀ ▄█ ▀ █▄▄ █▀ █▄▀ ▄ ▄ ▄▄▄█▀ ▀▀█ ▄█ █   █ ████
████ █▄▄▄█ █▀▄ ▀█▀█▄█ ▀▄█  ▄▄▄ ▀▀▄▄▄██▀ █▄▀███ █▄▄▄█ ████
████▄▄▄▄▄▄▄█▄▀ ▀▄▀ ▀▄▀ ▀▄█ █▄█ ▀ █▄█ ▀ ▀ ▀ █ █▄▄▄▄▄▄▄████
████▄  ▄ █▄  ▄▄▄▀▄█▄█ ▄▀▄▄    ▄▀▀  ▄▀ █▄▄▀█▄▄▄▀ ▀ █ █████
████▀█▀   ▄▀ ▀▀▀█▀█▀▀ ▀▀▄██▄▀ ▀▀▀ ▀ ██▄▀ ▄▄█▀ ██  ██ ████
█████▄  ▄ ▄▀█▄█ █▀█▄▀▀ ▀▄██ ▄ ▄█▀▀▀ █ ▄ ▄▀▄ ▄▀▀▀█▀  █████
████▀█▀▄ ▀▄▀█▄ █▄█▄▄ ▄   ▄▄ ▄▄▄ ▀▄ ▄▀▀ ▄▀▀▄▀▀▀▀█▀▄█▄ ████
████▀█▀▄▀ ▄▀██▄█▀▄██▄▄▄█▄▄ ▀ ▀█ █▄▀ █ █▄▄█▄▄█▀▀ █ ▀▄ ████
████ ▄▄▄ ▀▄▄▄▄▄██▄ ▀▄█ ▀██▄▀█▀██▀▄█▀ █ ▀▄▄   █    ▄▄▄████
████████▀▄▄▀▄ █▀▄▄▄▀██▄▀▄██▀▄▀▄█▀▄  █▀██▄ █▄▄ ▀ █▄▄▀▄████
████▄ ▄▀ ▄▄▄ █▀▀██ ▀██▀▄▄█ ▄▄▄  ▄▄▀  █▄▀▄█▄█ ▄▄▄ ██▄ ████
████▄ ▄▄ █▄█ ▄▄ █▀▀▀▄▄  ▄▄ █▄█ ██ ▀ █▀█▀  ▄▀ █▄█ █▀▄▄████
████▄▄▄▀  ▄▄ ▀ ▄▄▀█  ▀▄███ ▄ ▄ ▀█▀▀▀▀▀▄ ▄▀▀▀ ▄▄▄▄▀▄▄▄████
█████▀█ █▄▄▀ ▀▄▀█▀█▄▀▀ ▀▄ █ ▀▄▄▀▀▀ ▀▀▀█  █▄ ▀  ▀█   █████
████ █▄ ▄ ▄ █▄█▀█ ▀▄ ▀█   ▄▀▀▄█   ▀▀ █▄█▄█▄▄▀█▄█▀▀█▄ ████
████▀ ▀  ▀▄▄▄█▄ ▄▄█▄█▄▄ ▄▀█ ▀ █▀█ ▀ █▄▄▀  ▄▄▄ █ ▄█ █▀████
████▀ ▀█▄█▄▄█▀▄ ▄▄  ▀ ▄▀▀█▄█▀ ▀▀█▀ █ ▀▄▀▄▀▀▄▀▄▄▀ █▄  ████
████  ▀ ▀ ▄█▀█▄▄ ▄▄ █▀▄ █  ▀▀█ █▀▀▀▄▀ █ ▄ ▄▄█  ▀▄▀ ▄▄████
█████ ▀▀█▄▄  ▀█▄  █ █  ███▄▄▄▀▀ ██▀ ▀▀▄▄▀ ▄▄▀▀▄▀▀▄█▄▄████
████▄▄▄███▄█  █  ▄▀▄▄ ▄▀██ ▄▄▄ █▀   ▀▄█  █▄▄ ▄▄▄  ▄▄▀████
████ ▄▄▄▄▄ █▄██▀█▀██▀▄██▄▀ █▄█ ▄ ███  ▄▄▄▄▄█ █▄█ ██▄▄████
████ █   █ █ ▀█▀▄▀█ ▀▄▄ ▄█ ▄▄▄▄█▀  ▀▀ ▄▀  █▀▄ ▄▄ ▄ ██████
████ █▄▄▄█ █ ██▀█▀█▄▄▀▀ █   ▄▀▄ █▄▄▄▀█  █▀▄▀▀▄ ▀████▀████
████▄▄▄▄▄▄▄█▄███▄▄██▄█▄▄▄██▄▄█▄██▄█▄█▄█▄▄█▄▄███▄▄▄█▄▄████
█████████████████████████████████████████████████████████
█████████████████████████████████████████████████████████
'

echo "$code"

### 打印消息
function report_status {
    echo -e "\n\n${yellow}###### $1 ${default}"
}

### 修改上位机系统的CAN网络配置
function configure_can_interface {
    sudo modprobe can
    if [ $? -eq 0 ]
    then
        report_status "修改上位机系统的CAN网络配置..."
        sudo /bin/sh -c  "cat > /etc/network/interfaces.d/can0" << EOF
allow-hotplug can0
iface can0 can static
  bitrate 1000000
  up /sbin/ifconfig can0 txqueuelen 1024

EOF
    else
        report_status "因内核不支持CAN，故取消CAN网络配置..."
    fi
}

### 将katapult BootLoader写入CAN控制板MCU
function install_update_katapult {
    report_status "将katapult BootLoader写入CAN控制板MCU..."

}

### 将Klipper固件写入控制板MCU
function install_update_Klipper {
    report_status "将Klipper固件写入控制板MCU..."

}


### 主菜单
function Main_menu {
    CHOICES=$(whiptail --title "Feiyan助手" \
            --ok-button "下一步" --cancel-button "退出助手" --menu "\

请选择需要的项目（↑↓方向键选择，TAP键切换菜单功能）：\
            " 12 60 3 \
            "1" "修改上位机系统的CAN网络配置" \
            "2" "将katapult BootLoader写入CAN控制板MCU" \
            "3" "将Klipper固件写入控制板MCU" \
            3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        CHOICES=$(sed  's/\"//g' <<<$CHOICES)
        for PACKAGE in $CHOICES; do
            case $PACKAGE in
            1) configure_can_interface ;;
            2) install_update_katapult ;;
            3) install_update_Klipper ;;
            esac
        done
    else
        #echo "You chose Cancel."
        exit 0
    fi
}

### 欢迎界面
if (whiptail --title "Feiyan助手" --yes-button "继续" --no-button "再考虑一下"\
      --yesno "本助手将帮助安装/更新Klipper固件、安装/更新katapult固件、配置CAN网络。是否继续？\
      " 10 60) then
    Main_menu
else
    exit 0
fi

### 结束界面
whiptail --title "祝贺" --msgbox "恭喜安装完成了！" --ok-button "你退下吧" 10 60
