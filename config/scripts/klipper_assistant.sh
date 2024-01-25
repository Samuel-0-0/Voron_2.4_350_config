#!/bin/bash

# Copyright (C) 2024 Samuel Wang <imhsaw@gmail.com>
#
# This file may be distributed under the terms of the GNU GPLv3 license

################################################################
# 快速使用：
# cd ~ && wget -q -O  ~/klipper_assistant.sh https://raw.githubusercontent.com/Samuel-0-0/Voron_2.4_350_config/main/config/scripts/klipper_assistant.sh && chmod +x klipper_assistant.sh && ./klipper_assistant.sh
################################################################

### 遇到错误强制退出
set -e

### ROOT检测
[ $(id -u) -eq 0 ] || [ "$EUID" -eq 0 ] && whiptail --title '/!\ 警告 - 不要以ROOT身份运行 /!\' --msgbox "  请不要以ROOT身份或者SUDO运行本脚本！
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

### 打印消息
function report_status {
    echo -e "\n\n${yellow}###### $1 ${default}"
}

### 预处理
function pre_setup {
    report_status "设置国内PYPI清华镜像源..."
    [ ! -d ${HOME}/.pip ] && mkdir ${HOME}/.pip
    sudo /bin/sh -c "cat > ${HOME}/.pip/pip.conf" << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple

[install]
trusted-host=pypi.tuna.tsinghua.edu.cn

EOF
    report_status "配置用户组..."
    if grep -q "dialout" </etc/group && ! grep -q "dialout" <(groups "${USER}"); then
        sudo usermod -a -G dialout "${USER}" && report_status "已将用户${USER}添加到dialout用户组!"
    fi

    if grep -q "tty" </etc/group && ! grep -q "tty" <(groups "${USER}"); then
        sudo usermod -a -G tty "${USER}" && report_status "已将用户${USER}添加到tty用户组!"
    fi

    if grep -q "input" </etc/group && ! grep -q "input" <(groups "${USER}"); then
        sudo usermod -a -G input "${USER}" && report_status "已将用户${USER}添加到input用户组!"
    fi
}

### 安装Klipper
function install_klipper {
    report_status "获取Klipper文件..."
    git clone https://github.com/KevinOConnor/klipper.git ${KLIPPER_DIR}
    # Packages for python cffi
    PKGLIST="python3-virtualenv python3-dev libffi-dev build-essential"
    # kconfig requirements
    PKGLIST="${PKGLIST} libncurses-dev"
    # hub-ctrl
    PKGLIST="${PKGLIST} libusb-dev"
    # AVR chip installation and building
    PKGLIST="${PKGLIST} avrdude gcc-avr binutils-avr avr-libc"
    # ARM chip installation and building
    PKGLIST="${PKGLIST} stm32flash dfu-util libnewlib-arm-none-eabi"
    PKGLIST="${PKGLIST} gcc-arm-none-eabi binutils-arm-none-eabi libusb-1.0 pkg-config"

    # Update system package info
    report_status "更新软件源列表..."
    sudo apt-get update

    # Install desired packages
    report_status "安装所需软件..."
    sudo apt-get install --yes ${PKGLIST}

    report_status "创建用于Klipper的Python虚拟空间..."

    # Create virtualenv if it doesn't already exist
    [ ! -d ${KLIPPY_ENV_DIR} ] && virtualenv -p python3 ${KLIPPY_ENV_DIR}

    # Install/update dependencies
    ${KLIPPY_ENV_DIR}/bin/pip install -r ${KLIPPER_DIR}/scripts/klippy-requirements.txt

    # Create systemd service file
    report_status "配置Klipper系统服务..."
    # KLIPPER_ARGS="/home/samuel/klipper/klippy/klippy.py /home/samuel/printer_data/config/printer.cfg -l /home/samuel/printer_data/logs/klippy.log -a /tmp/klippy_uds"
    sudo /bin/sh -c "cat > ${KLIPPER_ENV_FILE}" << EOF
KLIPPER_ARGS="${KLIPPER_DIR}/klippy/klippy.py ${KLIPPER_CONFIG} -l ${KLIPPER_LOG} -a ${KLIPPER_SOCKET}"
EOF

    sudo /bin/sh -c "cat > ${SYSTEMD_DIR}/klipper.service" << EOF
#Systemd service file for klipper
[Unit]
Description=Starts Klipper and provides klippy Unix Domain Socket API
Documentation=https://www.klipper3d.org/
After=network-online.target
Wants=udev.target

[Install]
Alias=klippy
WantedBy=multi-user.target

[Service]
Type=simple
User=${KLIPPER_USER}
RemainAfterExit=yes
EnvironmentFile=${KLIPPER_ENV_FILE}
ExecStart= ${KLIPPY_ENV_DIR}/bin/python \$KLIPPER_ARGS
Restart=always
RestartSec=10
Nice=-20
EOF
    # Use systemctl to enable the klipper systemd service script
    sudo systemctl enable klipper.service
    sudo systemctl start klipper
}

### 安装Moonraker
function install_moonraker {
    report_status "获取Moonraker文件..."
    git clone https://github.com/Arksine/moonraker.git ${MOONRAKER_DIR}
    report_status "安装Moonraker..."
    source ${MOONRAKER_DIR}/scripts/install-moonraker.sh
    #source ${MOONRAKER_DIR}/scripts/set-policykit-rules.sh
}

### 安装Mainsail
function install_mainsail {
    report_status "获取Mainsail文件..."
    [ ! -d ${MAINSAIL_DIR} ] && mkdir ${MAINSAIL_DIR}
    wget -q -O ${MAINSAIL_DIR}/mainsail.zip https://ghproxy.com/https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip
    report_status "安装Mainsail..."
    sudo apt-get install --yes nginx

    sudo /bin/sh -c  "cat > /etc/nginx/conf.d/upstreams.conf" << EOF
# /etc/nginx/conf.d/upstreams.conf
upstream apiserver {
    ip_hash;
    server 127.0.0.1:7125;
}
upstream mjpgstreamer1 {
    ip_hash;
    server 127.0.0.1:8080;
}
upstream mjpgstreamer2 {
    ip_hash;
    server 127.0.0.1:8081;
}
upstream mjpgstreamer3 {
    ip_hash;
    server 127.0.0.1:8082;
}
upstream mjpgstreamer4 {
    ip_hash;
    server 127.0.0.1:8083;
}

EOF

    sudo /bin/sh -c  "cat > /etc/nginx/conf.d/common_vars.conf" << EOF
# /etc/nginx/conf.d/common_vars.conf
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

EOF

    [ -f /etc/nginx/sites-enabled/default ] && sudo rm /etc/nginx/sites-enabled/default
    [ -f /etc/nginx/sites-enabled/mainsail ] && sudo rm /etc/nginx/sites-enabled/mainsail
    
    sudo /bin/sh -c  "cat > /etc/nginx/sites-available/mainsail" << EOF
# /etc/nginx/sites-available/mainsail
server {
    listen 80 default_server;
    access_log /var/log/nginx/mainsail-access.log;
    error_log /var/log/nginx/mainsail-error.log;
    # disable this section on smaller hardware like a pi zero
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_proxied expired no-cache no-store private auth;
    gzip_comp_level 4;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/x-javascript application/json application/xml;
    # web_path from mainsail static files
    root /home/samuel/mainsail;
    index index.html;
    server_name _;
    # disable max upload size checks
    client_max_body_size 0;
    # disable proxy request buffering
    proxy_request_buffering off;
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    location = /index.html {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
    location /websocket {
        proxy_pass http://apiserver/websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
    location ~ ^/(printer|api|access|machine|server)/ {
        proxy_pass http://apiserver\$request_uri;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Scheme \$scheme;
    }
    location /webcam/ {
        proxy_pass http://mjpgstreamer1/;
    }
    location /webcam2/ {
        proxy_pass http://mjpgstreamer2/;
    }
    location /webcam3/ {
        proxy_pass http://mjpgstreamer3/;
    }
    location /webcam4/ {
        proxy_pass http://mjpgstreamer4/;
    }
}

EOF

    sudo ln -s /etc/nginx/sites-available/mainsail /etc/nginx/sites-enabled/mainsail
    unzip -o ${MAINSAIL_DIR}/mainsail.zip -d ${MAINSAIL_DIR} && rm ${MAINSAIL_DIR}/mainsail.zip
#    [ -f ${MAINSAIL_DIR}/config.json ] && rm ${MAINSAIL_DIR}/config.json && \
#    ln -sf ~/printer_data/config/mainsail_config.json ${MAINSAIL_DIR}/config.json
    sudo systemctl restart nginx
}

### 添加CAN网络配置
function configure_can_interface {
    sudo modprobe can
    if [ $? -eq 0 ]
    then
        report_status "添加CAN网络配置..."
        sudo /bin/sh -c  "cat > /etc/network/interfaces.d/can0" << EOF
allow-hotplug can0
iface can0 can static
  bitrate 1000000
  up ip link set can0 txqueuelen 1000

EOF
    else
        report_status "因内核不支持CAN，故取消CAN网络配置..."
    fi
}

### 安装KlipperScreen
function install_KlipperScreen {
    report_status "获取KlipperScreen文件..."
    git clone https://github.com/jordanruthe/KlipperScreen.git ${KLIPPERSCREEN_DIR}
    report_status "安装KlipperScreen..."
    source ${KLIPPERSCREEN_DIR}/scripts/KlipperScreen-install.sh
}

### crowsnest，替代MJPG-Streamer
function install_crowsnest {
    report_status  "安装crowsnest..."
    if [ -d "crowsnest" ]; then
        rm -rf crowsnest
    fi
    git clone --recurse-submodules https://github.com/mainsail-crew/crowsnest.git
    #sed -i 's/61ab2a8/dde2190/g' ~/crowsnest/bin/Makefile
    #sed -i 's|https://github.com|https://ghproxy.com/https://github.com|g' ~/crowsnest/bin/Makefile
    #sed -i 's/v0.20.2/v0.21.2/g' ~/crowsnest/bin/rtsp-simple-server/version
    pushd ~/crowsnest && sudo make install
    popd
}

### timelapse，用于延时摄影
function install_timelapse {
    report_status "安装timelapse..."
    if [ -d "moonraker-timelapse" ]; then
        rm -rf moonraker-timelapse
    fi
    git clone https://github.com/mainsail-crew/moonraker-timelapse.git
    pushd ~/moonraker-timelapse && make install
    popd
}

### gcode_shell_command，用于在gcode中执行shell脚本
function install_gcode_shell_command {
    report_status "安装gcode_shell_command..."
    wget -q -O ~/klipper/klippy/extras/gcode_shell_command.py https://ghproxy.com/https://raw.githubusercontent.com/th33xitus/kiauh/master/resources/gcode_shell_command.py
}

### 加速度测试所需依赖
function install_input_shaper {
    report_status "安装加速度测试依赖包..."
    sudo apt install --yes python3-numpy python3-matplotlib
    ~/klippy-env/bin/pip install -v numpy
}

### 自适应网床插件
function install_adaptive_bed_mesh {
    report_status "$安装自适应网床插件..."
    if [ -d "klipper_adaptive_bed_mesh" ]; then
        rm -rf klipper_adaptive_bed_mesh
    fi
    git clone https://github.com/eamars/klipper_adaptive_bed_mesh.git
    source klipper_adaptive_bed_mesh/install.sh
}

### 无限位归零插件
function install_sensorless_homing {
    report_status "安装无限位归零插件..."
    if [ -d "sensorless_homing_helper" ]; then
        rm -rf sensorless_homing_helper
    fi
    git clone https://github.com/eamars/sensorless_homing_helper.git
    source sensorless_homing_helper/install.sh
}

### TMC驱动自动调谐插件
function install_klipper_tmc_autotune {
    report_status "安装TMC驱动自动调谐插件..."
    if [ -d "klipper_tmc_autotune" ]; then
        rm -rf klipper_tmc_autotune
    fi
    git clone https://github.com/andrewmcgr/klipper_tmc_autotune.git
    source klipper_tmc_autotune/install.sh
}

echo '
█████████████████████████████████████████████████████████
█████████████████████████████████████████████████████████
████                                                 ████
████        ██╗   ██╗ █████╗ ███████╗████████╗       ████
████        ██║   ██║██╔══██╗██╔════╝╚══██╔══╝       ████
████        ██║   ██║███████║███████╗   ██║          ████
████        ╚██╗ ██╔╝██╔══██║╚════██║   ██║          ████
████         ╚████╔╝ ██║  ██║███████║   ██║          ████
████          ╚═══╝  ╚═╝  ╚═╝╚══════╝   ╚═╝          ████
████           遇到问题不要怕,加群找@三木            ████
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

### 主菜单
function Main_menu {
    CHOICES=$(
        whiptail --title "Klipper助手" \
            --ok-button "开始安装" --cancel-button "退出助手" --checklist "\
关于下述可选项目的说明：
a) Klipper是控制3D打印机必须的组件，使用文档：https://www.klipper3d.org
    Moonraker是用来与Klipper通信的API服务，使用文档：https://moonraker.readthedocs.io/en/latest
b) Mainsail是用来控制Klipper的WEBUI界面
    使用文档：https://docs.mainsail.xyz
c) KlipperScreen是用来控制Klipper的触摸屏界面
    使用文档：https://klipperscreen.readthedocs.io/en/latest
d) Gcode Shell Command是Klipper用来执行shell脚本的插件
    使用文档：https://github.com/th33xitus/kiauh/blob/master/docs/gcode_shell_command.md
e) 自适应网床插件会根据切片动态生成床面网格参数，从而减少床网探测时间
    使用文档：https://github.com/eamars/klipper_adaptive_bed_mesh/blob/main/readme_zh_cn.md
f) 无限位归零插件在复刻了现有无限位归零宏的所有功能基础上增加了额外的功能
    使用文档：https://github.com/eamars/sensorless_homing_helper/blob/main/readme_zh_cn.md
g) Input Shaper依赖是Klipper使用Input Shaper功能测试必须的系统依赖
    使用文档：https://www.klipper3d.org/Measuring_Resonances.html
h) Crowsnest是用来管理和使用摄像头的服务
    使用文档：https://github.com/mainsail-crew/crowsnest
i) Timelapse是Moonraker的延时摄影插件，可通过Mainsail控制
    使用文档：https://github.com/mainsail-crew/moonraker-timelapse
j) TMC驱动自动调谐插件可以动态调整TMC驱动的相应参数，减轻运行噪音
    使用文档：https://github.com/andrewmcgr/klipper_tmc_autotune

注意：部分插件需要自行修改配置文件，请查看使用文档。

请选择需要的项目（↑↓方向键选择，空格键选中/取消，TAP键切换）：\
            " 42 108 10 \
            "a" "Klipper及Moonraker - 必须的组件" ON \
            "b" "Mainsail - WEBUI控制界面" OFF \
            "c" "KlipperScreen - 触摸屏控制界面" OFF \
            "d" "Gcode Shell Command - 执行Shell插件" ON \
            "e" "Adaptive Bed Mesh - 自适应网床插件" ON \
            "f" "Sensorless Homing Helper - 无限位归零插件" OFF \
            "g" "Input Shaper - 加速度测试依赖" ON \
            "h" "Crowsnest - 摄像头服务" ON \
            "i" "Timelapse - 延时摄影插件" ON \
            "j" "Klipper TMC Autotune - TMC驱动自动调谐插件" ON \
            3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        CHOICES=$(sed  's/\"//g' <<<$CHOICES)
        for PACKAGE in $CHOICES; do
            case $PACKAGE in
            a) pre_setup && install_klipper && install_moonraker && configure_can_interface ;;
            b) install_mainsail ;;
            c) install_KlipperScreen ;;
            d) install_gcode_shell_command ;;
            e) install_adaptive_bed_mesh ;;
            f) install_sensorless_homing ;;
            g) install_input_shaper ;;
            h) install_crowsnest ;;
            i) install_timelapse ;;
            j) install_klipper_tmc_autotune ;;
            esac
        done
    else
        #echo "You chose Cancel."
        exit 0
    fi
}

### 欢迎界面
if (whiptail --title "Klipper助手" --yes-button "继续" --no-button "再考虑一下"  --yesno "本助手将帮助安装Klipper/Moonraker/Mainsail以及实用的插件及辅助优化。是否继续？" 10 60) then
    Main_menu
else
    exit 0
fi

### 结束界面
whiptail --title "祝贺" --msgbox "恭喜安装完成了！" --ok-button "你退下吧" 10 60
