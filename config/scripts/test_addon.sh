#!/bin/bash

[ $(id -u) -eq 0 || "$EUID" -eq 0 ] && whiptail --title '/!\ WARNING - Not runned as root /!\' --msgbox "	You don't run this as root!
You will need to have root permissions" 8 48

### 自定义打印信息颜色
green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

# crowsnest，替代MJPG-Streamer
function install_crowsnest() {
    if [ -d "crowsnest" ]; then
        rm -rf crowsnest
    fi
    git clone --recurse-submodules https://github.com/mainsail-crew/crowsnest.git
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}crowsnest下载完成，开始安装...${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}crowsnest下载失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
    cd ~/crowsnest && make install
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}crowsnest安装完成${default}"
        echo -e ""
        cd ~
    else
        echo -e ""
        echo -e "${red}crowsnest安装失败，详情请查看上方信息${default}"
        echo -e ""
        cd ~
        exit 1
    fi
}

# timelapse，用于延时摄影
function install_timelapse() {
    if [ -d "moonraker-timelapse" ]; then
        rm -rf moonraker-timelapse
    fi
    git clone https://github.com/mainsail-crew/moonraker-timelapse.git
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}timelapse下载完成，开始安装...${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}timelapse下载失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
    ./moonraker-timelapse/install.sh
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}timelapse安装完成${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}timelapse安装失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
}

# print_area_bed_mesh，用于区域床网
function install_print_area_bed_mesh() {
    if [ -d "print_area_bed_mesh" ]; then
        rm -rf print_area_bed_mesh
    fi
    git clone https://github.com/Turge08/print_area_bed_mesh.git
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}print_area_bed_mesh下载完成，开始安装...${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}print_area_bed_mesh下载失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
    ./print_area_bed_mesh/install.sh
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}print_area_bed_mesh安装完成${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}print_area_bed_mesh安装失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
}

# klipper_z_calibration，用于自动Z偏移
function install_klipper_z_calibration() {
    if [ -d "klipper_z_calibration" ]; then
        rm -rf klipper_z_calibration
    fi
    git clone https://github.com/protoloft/klipper_z_calibration.git
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}klipper_z_calibration下载完成，开始安装...${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}klipper_z_calibration下载失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
    ./klipper_z_calibration/install.sh
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}klipper_z_calibration安装完成${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}klipper_z_calibration安装失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
}

# gcode_shell_command，用于在gcode中执行shell脚本
function install_gcode_shell_command() {
    #cp ~/klipper_config/scripts/gcode_shell_command.py ~/klipper/klippy/extras/
    curl -o ~/klipper/klippy/extras/gcode_shell_command.py https://ghproxy.com/https://raw.githubusercontent.com/th33xitus/kiauh/master/resources/gcode_shell_command.py
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}gcode_shell_command安装完成${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}gcode_shell_command安装失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
}

# 加速度测试所需依赖
function install_input_shaper() {
    sudo apt update
    sudo apt install python3-numpy python3-matplotlib
    ~/klippy-env/bin/pip install -v numpy
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}加速度测试依赖安装完成${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}加速度测试依赖安装失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
}

# python2的Klipper中文名Gcode文件支持
function klipper_gcode_chinese() {
    rm ~/klipper/klippy/gcode.pyc && sed -i "/import os, re, logging, collections, shlex/a import sys\nreload(sys)\nsys.setdefaultencoding('utf8')" ~/klipper/klippy/gcode.py && cat ~/klipper/klippy/gcode.py | head -n 10
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}Klipper中文名Gcode文件支持设置完成${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}Klipper中文名Gcode文件支持设置失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
}

# mainsail主题
function install_mainsail_theme() {
    git clone https://github.com/steadyjaw/dracula-mainsail-theme.git ~/klipper_config/.theme
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}主题下载完成${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}文件下载失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
}

function Checklist() {
    CHOICES=$(
        whiptail --title "Klipper使用优化助手" \
            --ok-button "确定" --cancel-button "取消" --checklist \
            "关于下述可选项目的说明：\n1) Gcode Shell Command是可以执行shell脚本的klipper插件\n    使用文档：https://github.com/th33xitus/kiauh/blob/master/docs/gcode_shell_command.md\n2) Timelapse是Moonraker的第三方延时摄影插件\n    使用文档：https://github.com/mainsail-crew/moonraker-timelapse\n3) Klipper Z Calibration是配合Klicky等使用实现自动Z偏移调整的Klipper插件\n    使用文档：https://github.com/protoloft/klipper_z_calibration\n4) Print Area Bed Mesh是辅助实现区域床网的Klipper脚本\n    使用文档：https://github.com/Turge08/print_area_bed_mesh\n5) Input Shaper依赖是Klipper使用Input Shaper功能测试必须的系统依赖\n    使用文档：https://www.klipper3d.org/Measuring_Resonances.html\n6) Crowsnest是一个帮助更好的管理和使用摄像头的服务\n    使用文档：https://github.com/mainsail-crew/crowsnest\n7) 只有基于Python2的Klipper才需要中文名Gcode文件支持\n\n请选择需要的项目（方向上下选择，空格选中取消，TAP键切换）：" 30 100 7 \
            "1" "Gcode Shell Command - 执行Shell插件" ON \
            "2" "Timelapse - 延时摄影" OFF \
            "3" "Klipper Z Calibration - 自动Z调整" OFF \
            "4" "Print Area Bed Mesh - 区域床网" OFF \
            "5" "Input Shaper - 加速度测试依赖" OFF \
            "6" "Crowsnest - 摄像头服务" OFF \
            "7" "Klipper中文名Gcode文件支持" OFF \
            3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        CHOICES=$(sed  's/\"//g' <<<$CHOICES)
        for PACKAGE in $CHOICES; do
            case $PACKAGE in
            1) install_gcode_shell_command ;;
            2) install_timelapse ;;
            3) install_klipper_z_calibration ;;
            4) install_print_area_bed_mesh ;;
            5) install_input_shaper ;;
            6) install_crowsnest ;;
            esac
        done
    else
        echo "You chose Cancel."
        exit 0
    fi
}

echo '
██╗   ██╗ █████╗ ███████╗████████╗
██║   ██║██╔══██╗██╔════╝╚══██╔══╝
██║   ██║███████║███████╗   ██║   
╚██╗ ██╔╝██╔══██║╚════██║   ██║   
 ╚████╔╝ ██║  ██║███████║   ██║   
  ╚═══╝  ╚═╝  ╚═╝╚══════╝   ╚═╝   
                                  
'

if (whiptail --title "Klipper使用优化助手" --yes-button "确认" --no-button "退出"  --yesno "本助手将帮助安装一些在Klipper使用过程中比较实用的插件/辅助优化，部分操作可能需要手动修改配置文件，操作过程中会有提示。选择确认继续。" 10 60) then
    Checklist
else
    exit 0
fi

whiptail --title "祝贺" --msgbox "恭喜你优化完成了！" --ok-button "好的" 10 60
