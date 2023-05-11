#!/bin/bash

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
KLIPPER_CONFIG=${PRINTER_DATA}/config/printer.cfg
KLIPPER_LOG=${PRINTER_DATA}/logs/klippy.log
KLIPPER_SOCKET=/tmp/klippy_uds

### 打印消息颜色
green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

### 打印消息
function report_status {
    echo -e "\n\n${yellow}###### $1 ${default}"
}

### 遇到错误强制退出
set -e

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
    sudo /bin/sh -c "cat > ${SYSTEMD_DIR}/klipper.service" << EOF
#Systemd service file for klipper
[Unit]
Description=Starts Klipper and provides klippy Unix Domain Socket API
Documentation=https://www.klipper3d.org/
After=network.target
Before=moonraker.service
Wants=udev.target

[Install]
Alias=klippy
WantedBy=multi-user.target

[Service]
Type=simple
User=${KLIPPER_USER}
RemainAfterExit=yes
ExecStart= ${KLIPPY_ENV_DIR}/bin/python ${KLIPPER_DIR}/klippy/klippy.py ${KLIPPER_CONFIG} -l ${KLIPPER_LOG} -a ${KLIPPER_SOCKET}
Restart=always
RestartSec=10

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
    source ${MOONRAKER_DIR}/scripts/set-policykit-rules.sh
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

    [ -f /etc/nginx/sites-enabled/default ] && sudo rm /etc/nginx/sites-enabled/default
    [ -f /etc/nginx/sites-enabled/mainsail ] && sudo rm /etc/nginx/sites-enabled/mainsail \
    && sudo ln -s /etc/nginx/sites-available/mainsail /etc/nginx/sites-enabled/
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
  bitrate 500000
  up /sbin/ifconfig can0 txqueuelen 1024

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
    sed -i 's/61ab2a8/dde2190/g' ~/crowsnest/bin/Makefile
    sed -i 's|https://github.com|https://ghproxy.com/https://github.com|g' ~/crowsnest/bin/Makefile
    sed -i 's/v0.20.2/v0.21.2/g' ~/crowsnest/bin/rtsp-simple-server/version
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
    ./moonraker-timelapse/install.sh -c ~/printer_data/config
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

### 区域床网
function install_print_area_bed_mesh {
    report_status "$安装print_area_bed_mesh..."
    if [ -d "print_area_bed_mesh" ]; then
        rm -rf print_area_bed_mesh
    fi
    git clone https://github.com/Turge08/print_area_bed_mesh.git
    ln -sf ~/print_area_bed_mesh/print_area_bed_mesh.cfg ~/printer_data/config/print_area_bed_mesh.cfg
}

echo '
██╗   ██╗ █████╗ ███████╗████████╗
██║   ██║██╔══██╗██╔════╝╚══██╔══╝
██║   ██║███████║███████╗   ██║   
╚██╗ ██╔╝██╔══██║╚════██║   ██║   
 ╚████╔╝ ██║  ██║███████║   ██║   
  ╚═══╝  ╚═╝  ╚═╝╚══════╝   ╚═╝   
遇到问题不要怕，加群找@三木
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
function Checklist {
    CHOICES=$(
        whiptail --title "Klipper助手" \
            --ok-button "开始安装" --cancel-button "退出助手" --checklist \
            "关于下述可选项目的说明：\n1) Klipper是控制3D打印机必须的组件，使用文档：https://www.klipper3d.org/\n   Moonraker是一个用于与Klipper通信的API服务，使用文档：https://moonraker.readthedocs.io/en/latest/\n2) Mainsail是一个用于控制Klipper的WEBUI界面\n    使用文档：https://docs.mainsail.xyz/\n3) KlipperScreen是一个用于控制Klipper的触摸屏界面\n    使用文档：https://klipperscreen.readthedocs.io/en/latest/\n4) Gcode Shell Command是可以执行shell脚本的klipper插件\n    使用文档：https://github.com/th33xitus/kiauh/blob/master/docs/gcode_shell_command.md\n5) Print Area Bed Mesh是辅助实现区域床网的Klipper脚本\n    使用文档：https://github.com/Turge08/print_area_bed_mesh\n6) Input Shaper依赖是Klipper使用Input Shaper功能测试必须的系统依赖\n    使用文档：https://www.klipper3d.org/Measuring_Resonances.html\n7) Crowsnest是一个帮助更好的管理和使用摄像头的服务\n    使用文档：https://github.com/mainsail-crew/crowsnest\n8) Timelapse是Moonraker的第三方延时摄影插件\n    使用文档：https://github.com/mainsail-crew/moonraker-timelapse\n\n请选择需要的项目（↑↓方向键选择，空格键选中/取消，TAP键切换）：" 32 105 8 \
            "1" "Klipper及Moonraker - 必须的组件" ON \
            "2" "Mainsail - WEBUI控制界面" OFF \
            "3" "KlipperScreen - 触摸屏控制界面" OFF \
            "4" "Gcode Shell Command - 执行Shell插件" ON \
            "5" "Print Area Bed Mesh - 区域床网" ON \
            "6" "Input Shaper - 加速度测试依赖" ON \
            "7" "Crowsnest - 摄像头服务" ON \
            "8" "Timelapse - 延时摄影" ON \
            3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        CHOICES=$(sed  's/\"//g' <<<$CHOICES)
        for PACKAGE in $CHOICES; do
            case $PACKAGE in
            1) pre_setup && install_klipper && install_moonraker && configure_can_interface ;;
            2) install_mainsail ;;
            3) install_KlipperScreen ;;
            4) install_gcode_shell_command ;;
            5) install_print_area_bed_mesh ;;
            6) install_input_shaper ;;
            7) install_crowsnest ;;
            8) install_timelapse ;;
            esac
        done
    else
        #echo "You chose Cancel."
        exit 0
    fi
}

### 欢迎界面
if (whiptail --title "Klipper助手" --yes-button "继续" --no-button "再考虑一下"  --yesno "本助手将帮助安装Klipper/Moonraker/Mainsail以及实用的插件及辅助优化。是否继续？" 10 60) then
    Checklist
else
    exit 0
fi

### 结束界面
whiptail --title "祝贺" --msgbox "恭喜安装完成了！" --ok-button "你退下吧" 10 60
