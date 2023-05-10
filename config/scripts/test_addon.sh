#!/bin/bash

[ $(id -u) -eq 0 ] || [ "$EUID" -eq 0 ] && whiptail --title '/!\ 警告 - 不要以ROOT身份运行 /!\' --msgbox "  请不要以ROOT身份或者SUDO运行本脚本！
  在需要的时候，脚本会请求相应的权限。" 8 48  && exit 1

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


function Checklist() {
    CHOICES=$(
        whiptail --title "Klipper助手" \
            --ok-button "开始安装" --cancel-button "退出助手" --checklist \
            "关于下述可选项目的说明：\n1) Klipper是控制3D打印机必须的组件，使用文档：https://www.klipper3d.org/\n   Moonraker是一个用于与Klipper通信的API服务，使用文档：https://moonraker.readthedocs.io/en/latest/\n2) Mainsail是一个WEBUI界面，用于控制Klipper\n    使用文档：https://docs.mainsail.xyz/\n3) Gcode Shell Command是可以执行shell脚本的klipper插件\n    使用文档：https://github.com/th33xitus/kiauh/blob/master/docs/gcode_shell_command.md\n4) Print Area Bed Mesh是辅助实现区域床网的Klipper脚本\n    使用文档：https://github.com/Turge08/print_area_bed_mesh\n5) Input Shaper依赖是Klipper使用Input Shaper功能测试必须的系统依赖\n    使用文档：https://www.klipper3d.org/Measuring_Resonances.html\n6) Crowsnest是一个帮助更好的管理和使用摄像头的服务\n    使用文档：https://github.com/mainsail-crew/crowsnest\n7) Timelapse是Moonraker的第三方延时摄影插件\n    使用文档：https://github.com/mainsail-crew/moonraker-timelapse\n\n请选择需要的项目（方向上下选择，空格选中取消，TAP键切换）：" 32 105 7 \
            "1" "Klipper及Moonraker - 必须的组件" ON \
            "2" "Mainsail - WEBUI" ON \
            "3" "Gcode Shell Command - 执行Shell插件" ON \
            "4" "Print Area Bed Mesh - 区域床网" ON \
            "5" "Input Shaper - 加速度测试依赖" ON \
            "6" "Crowsnest - 摄像头服务" ON \
            "7" "Timelapse - 延时摄影" ON \
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

if (whiptail --title "Klipper助手" --yes-button "继续" --no-button "再考虑一下"  --yesno "本助手将帮助安装Klipper/Moonraker/Mainsail以及实用的插件及辅助优化。是否继续？" 10 60) then
    Checklist
else
    exit 0
fi

whiptail --title "祝贺" --msgbox "恭喜安装完成了！" --ok-button "你退下吧" 10 60
