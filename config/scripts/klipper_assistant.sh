#!/bin/bash

################################################################################
# 3D打印机辅助文件
################################################################################
# COPYRIGHT © 2021 - 2025  Samuel Wang
# 本文件可以根据GNU GPLv3许可协议进行分发
# This file may be distributed under the terms of the GNU GPLv3 license
################################################################################
# Discord: Samuel-0-0#0576    Github: Samuel-0-0    Bilibili: Samuel-0_0
################################################################################
# 文件用途：一键安装Klipper及其他依赖
################################################################################
# 根据你的设置编辑此文件
################################################################################


################################################################################
# 快速使用：
# curl -sSL https://raw.githubusercontent.com/Samuel-0-0/Voron_2.4_350_config/main/config/scripts/klipper_assistant.sh | bash
################################################################################

### 遇到错误强制退出
set -e

### ROOT检测
[ $(id -u) -eq 0 ] || [ "$EUID" -eq 0 ] && whiptail --title '/!\ 警告 - 不要以ROOT身份运行 /!\' --msgbox "  请不要以ROOT身份或者SUDO运行本脚本！
  在需要的时候，脚本会请求相应的权限。" 8 48  && exit 1

### APT命令合规检测
[ ! command -v apt-get &>/dev/null ] && whiptail --title '/!\ 警告 - 不要以ROOT身份运行 /!\' --msgbox "  当前系统不支持 apt-get，
  请确认你正在使用 Debian/Ubuntu 系统。" 8 48  && exit 1

### 环境变量
SYSTEMD_DIR="/etc/systemd/system"
KLIPPER_USER=${USER}
KLIPPER_GROUP=${KLIPPER_USER}
KLIPPER_DIR="/home/${USER}/klipper"
MOONRAKER_DIR="/home/${USER}/moonraker"
MAINSAIL_DIR="/home/${USER}/mainsail"
KLIPPERSCREEN_DIR="/home/${USER}/KlipperScreen"
KLIPPY_ENV_DIR="/home/${USER}/klippy-env"
MOONRAKER_ENV_DIR="/home/${USER}/moonraker-env"
KLIPPERSCREEN_ENV_DIR="/home/${USER}/.KlipperScreen-env"
PRINTER_DATA="/home/${USER}/printer_data"
KLIPPER_ENV_FILE="${PRINTER_DATA}/systemd/klipper.env"
KLIPPER_CONFIG="${PRINTER_DATA}/config/printer.cfg"
KLIPPER_LOG="${PRINTER_DATA}/logs/klippy.log"
KLIPPER_SOCKET="/tmp/klippy_uds"
MAX_RETRIES=5
KLIPPER_GITREPO="https://github.com/Klipper3d/klipper.git"
MOONRAKER_GITREPO="https://github.com/Arksine/moonraker.git"
KLIPPERSCREEN_GITREPO="https://github.com/jordanruthe/KlipperScreen.git"
SENSORLESS_GITREPO="https://github.com/eamars/sensorless_homing_helper.git"
CROWSNEST_GITREPO="https://github.com/mainsail-crew/crowsnest.git"
TIMELAPSE_GITREPO="https://github.com/mainsail-crew/moonraker-timelapse.git"
TMC_AUTOTUNE_GITREPO="https://github.com/andrewmcgr/klipper_tmc_autotune.git"
LAZYFIRMWARE_GITREPO="https://github.com/Samuel-0-0/LazyFirmware.git"
LED_EFFECTS_GITREPO="https://github.com/julianschill/klipper-led_effect.git"
KATAPULT_GITREPO="https://github.com/Arksine/katapult.git"
AUTO_SPEED_GITREPO="https://github.com/Anonoei/klipper_auto_speed.git"
HAPPY_HARE_GITREPO="https://github.com/moggieuk/Happy-Hare.git"

### 打印消息颜色
red=$(echo -en "\e[91m")
green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
blue=$(echo -en "\e[94m")
default=$(echo -en "\e[39m")

### 打印消息
function REPORT_STATUS {
    if [ ! -z "$2" ]; then
        case $1 in
            info)
                echo -e "\n${green}$2${default}"
                ;;
            warning)
                echo -e "\n${yellow}$2${default}"
                ;;
            error)
                echo -e "\n${red}$2${default}"
                ;;
        esac
    else
        echo -e "\n${blue}$1${default}"
    fi
}

### 预处理
function pre_setup {
    REPORT_STATUS info "设置国内PYPI镜像源..."
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    EXTERNALLY_MANAGED_PATH="/usr/lib/python${PYTHON_VERSION}/EXTERNALLY-MANAGED"
    if [ -e "$EXTERNALLY_MANAGED_PATH" ]; then
        echo "发现 ${EXTERNALLY_MANAGED_PATH}，正在删除以启用 pip 自由安装..."
        sudo rm -rf "$EXTERNALLY_MANAGED_PATH"
    fi
    if ! command -v pip &>/dev/null; then
        echo "pip 未安装，正在安装..."
        sudo apt update
        sudo apt install python3-pip -y
    else
        python3 -m pip install -i https://repo.huaweicloud.com/repository/pypi/simple/ --upgrade pip
        pip config set global.index-url https://repo.huaweicloud.com/repository/pypi/simple/
    fi

    REPORT_STATUS info "添加中文字体支持..."
    sudo apt update
    sudo apt install fonts-noto-cjk fonts-noto-cjk-extra fonts-noto-color-emoji fonts-wqy-zenhei fonts-wqy-microhei -y

    REPORT_STATUS info "配置用户组..."
    if grep -q "dialout" </etc/group && ! grep -q "dialout" <(groups "${USER}"); then
        sudo usermod -a -G dialout "${USER}" && report_status info "已将用户${USER}添加到dialout用户组!"
    fi

    if grep -q "tty" </etc/group && ! grep -q "tty" <(groups "${USER}"); then
        sudo usermod -a -G tty "${USER}" && report_status info "已将用户${USER}添加到tty用户组!"
    fi

    if grep -q "input" </etc/group && ! grep -q "input" <(groups "${USER}"); then
        sudo usermod -a -G input "${USER}" && report_status info "已将用户${USER}添加到input用户组!"
    fi
}

### 克隆项目
function git_clone {
    local NAME=$1
    local REPO=$2
    local DEST=$3
    local RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        REPORT_STATUS info "克隆$NAME..."
        # 执行 git clone 命令
        if [ ! -z "$DEST" ]; then
            git clone $REPO  $DEST
        else
            git clone $REPO
        fi        
        # 检查 git clone 命令的返回状态码
        if [ $? -eq 0 ]; then
            REPORT_STATUS info "克隆完成"
            break
        else
            ((RETRY_COUNT++))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                local delay=$((RETRY_COUNT * 2))
                REPORT_STATUS warning "克隆失败，${delay}秒后重试 (尝试 $RETRY_COUNT/$MAX_RETRIES)..."
                sleep $delay
            else
                REPORT_STATUS error "克隆失败，已达到最大尝试次数，请稍后再试..."
                exit 1
            fi
        fi
    done
}

### 安装Klipper
function install_klipper {
    if [ -d ${KLIPPER_DIR} ]; then
        rm -rf ${KLIPPER_DIR}
    fi
    if [ -d ${KLIPPY_ENV_DIR} ]; then
        rm -rf ${KLIPPY_ENV_DIR}
    fi

    git_clone "KLIPPER" ${KLIPPER_GITREPO}
    # python cffi依赖
    PKGLIST="python3-virtualenv python3-dev libffi-dev build-essential"
    # kconfig依赖
    PKGLIST="${PKGLIST} libncurses-dev"
    # hub-ctrl
    PKGLIST="${PKGLIST} libusb-dev"
    # AVR芯片编译依赖
    PKGLIST="${PKGLIST} avrdude gcc-avr binutils-avr avr-libc"
    # ARM芯片编译依赖
    PKGLIST="${PKGLIST} stm32flash dfu-util libnewlib-arm-none-eabi"
    PKGLIST="${PKGLIST} gcc-arm-none-eabi binutils-arm-none-eabi libusb-1.0 pkg-config"
    PKGLIST="${PKGLIST} wget unzip"

    REPORT_STATUS info "更新软件源列表..."
    sudo apt-get update

    REPORT_STATUS info "安装所需软件..."
    sudo apt-get install --yes ${PKGLIST}

    REPORT_STATUS info "创建用于Klipper的Python虚拟空间..."
    virtualenv -p python3 ${KLIPPY_ENV_DIR}

    REPORT_STATUS info "安装Python依赖..."
    ${KLIPPY_ENV_DIR}/bin/pip install -r ${KLIPPER_DIR}/scripts/klippy-requirements.txt

    REPORT_STATUS info "配置Klipper系统服务..."
    # KLIPPER_ARGS="/home/samuel/klipper/klippy/klippy.py /home/samuel/printer_data/config/printer.cfg -l /home/samuel/printer_data/logs/klippy.log -a /tmp/klippy_uds"
    mkdir -p "${PRINTER_DATA}/systemd"
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

    sudo systemctl daemon-reload
    sudo systemctl enable klipper.service
    sudo systemctl start klipper
}

### 安装Moonraker
function install_moonraker {
    if [ -d ${MOONRAKER_DIR} ]; then
        rm -rf ${MOONRAKER_DIR}
    fi
    if [ -d ${MOONRAKER_ENV_DIR} ]; then
        rm -rf ${MOONRAKER_ENV_DIR}
    fi
    git_clone "MOONRAKER" ${MOONRAKER_GITREPO}
    (
        cd ${MOONRAKER_DIR} || exit 1
        ./scripts/install-moonraker.sh
    )
    #source ${MOONRAKER_DIR}/scripts/set-policykit-rules.sh
}

### 安装Mainsail
function install_mainsail {
    REPORT_STATUS info "获取Mainsail文件..."
    [ ! -d ${MAINSAIL_DIR} ] && mkdir ${MAINSAIL_DIR}
    if wget --show-progress -O ${MAINSAIL_DIR}/mainsail.zip \
    https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip; then
        REPORT_STATUS info "成功！"
    else
        REPORT_STATUS info "失败，请检查网络或URL。"
        exit 1
    fi
    REPORT_STATUS info "安装Mainsail..."
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
    root ${MAINSAIL_DIR};
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
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Scheme \$scheme;
        proxy_read_timeout 600;
    }
    location /webcam/ {
        postpone_output 0;
        proxy_buffering off;
        proxy_ignore_headers X-Accel-Buffering;
        access_log off;
        error_log off;
        proxy_pass http://mjpgstreamer1/;
    }
    location /webcam2/ {
        postpone_output 0;
        proxy_buffering off;
        proxy_ignore_headers X-Accel-Buffering;
        access_log off;
        error_log off;
        proxy_pass http://mjpgstreamer2/;
    }
}

EOF

    sudo ln -s /etc/nginx/sites-available/mainsail /etc/nginx/sites-enabled/mainsail
    unzip -o ${MAINSAIL_DIR}/mainsail.zip -d ${MAINSAIL_DIR}
    rm ${MAINSAIL_DIR}/mainsail.zip

    chmod o+x ${HOME}
    chmod -R o+rX ${MAINSAIL_DIR}

    sudo systemctl restart nginx
    REPORT_STATUS info "Mainsail安装完成"
}

### 添加CAN网络配置
function configure_can_interface {
    sudo modprobe can
    if [ $? -eq 0 ]
    then
        REPORT_STATUS info "添加CAN网络配置..."
        sudo /bin/sh -c  "cat > /etc/network/interfaces.d/can0" << EOF
allow-hotplug can0
iface can0 can static
  bitrate 1000000
  up ip link set can0 txqueuelen 1000

EOF
        REPORT_STATUS info "CAN网络配置添加完成"
    else
        REPORT_STATUS warning "因内核不支持CAN，故取消CAN网络配置..."
    fi
}

### 安装KlipperScreen
function install_KlipperScreen {
    REPORT_STATUS info "安装KlipperScreen"
    if [ -d ${KLIPPERSCREEN_DIR} ]; then
        rm -rf ${KLIPPERSCREEN_DIR}
    fi
    if [ -d ${KLIPPERSCREEN_ENV_DIR} ]; then
        rm -rf ${KLIPPERSCREEN_ENV_DIR}
    fi
    git_clone "KLIPPERSCREEN" ${KLIPPERSCREEN_GITREPO}
    (
        cd ${KLIPPERSCREEN_DIR} || exit 1
        ./scripts/KlipperScreen-install.sh
    )
    REPORT_STATUS info "KlipperScreen安装完成"
}

### crowsnest，替代MJPG-Streamer
function install_crowsnest {
    REPORT_STATUS info "安装CROWSNEST摄像头服务"
    if [ -d "crowsnest" ]; then
        rm -rf crowsnest
    fi
    git_clone "CROWSNEST" ${CROWSNEST_GITREPO} --recurse-submodules
    pushd ~/crowsnest
    sudo make install
    popd
    REPORT_STATUS info "CROWSNEST摄像头服务安装完成"
}

### timelapse，用于延时摄影
function install_timelapse {
    REPORT_STATUS info "安装TIMELAPSE延时摄影插件"
    if [ -d "moonraker-timelapse" ]; then
        rm -rf moonraker-timelapse
    fi
    git_clone "TIMELAPSE" ${TIMELAPSE_GITREPO}
    pushd ~/moonraker-timelapse
    make install
    popd
    REPORT_STATUS info "TIMELAPSE延时摄影插件安装完成"
}

### gcode_shell_command，用于在gcode中执行shell脚本
function install_gcode_shell_command {
    REPORT_STATUS info "安装gcode_shell_command..."
    if wget --show-progress -O ~/klipper/klippy/extras/gcode_shell_command.py \
    https://raw.githubusercontent.com/dw-0/kiauh/master/resources/gcode_shell_command.py; then
        REPORT_STATUS info "成功！"
    else
        REPORT_STATUS info "下载失败，请检查网络或URL。"
        exit 1
    fi
}

### 加速度测试所需依赖
function install_input_shaper {
    REPORT_STATUS info "安装加速度测试依赖包..."
    sudo apt-get install --yes python3-numpy python3-matplotlib libatlas-base-dev libopenblas-dev
    ~/klippy-env/bin/pip install -v numpy
    REPORT_STATUS info "加速度测试依赖包安装完成"
}

### TMC驱动自动调谐插件
function install_klipper_tmc_autotune {
    REPORT_STATUS info "安装TMC驱动自动调谐插件"
    if [ -d "klipper_tmc_autotune" ]; then
        rm -rf klipper_tmc_autotune
    fi
    git_clone "TMC_AUTOTUNE" ${TMC_AUTOTUNE_GITREPO}
    (
        cd klipper_tmc_autotune || exit 1
        ./install.sh
    )
    REPORT_STATUS info "TMC驱动自动调谐插件安装完成"
}

### LED EFFECTS插件
function install_klipper_led_effect {
    REPORT_STATUS info "安装LED EFFECTS插件"
    if [ -d "klipper-led_effect" ]; then
        rm -rf klipper-led_effect
    fi
    git_clone "LED_EFFECTS" ${LED_EFFECTS_GITREPO}
    (
        cd klipper-led_effect || exit 1
        ./install-led_effect.sh
    )
    REPORT_STATUS info "LED EFFECTS插件安装完成"
}

### 一键升级klipper固件
function install_lazyfirmware {
    REPORT_STATUS info "安装LazyFirmware"
    if [ -d "LazyFirmware" ]; then
        rm -rf LazyFirmware
    fi
    git_clone "KATAPULT" ${KATAPULT_GITREPO}
    git_clone "LAZYFIRMWARE" ${LAZYFIRMWARE_GITREPO}
    pip3 install pyserial --break-system-packages
    if [ ! -f "${PRINTER_DATA}/config/lazyfirmware/config.cfg" ]; then
        mkdir ${PRINTER_DATA}/config/lazyfirmware
        cp /home/${USER}/LazyFirmware/config/config.cfg ${PRINTER_DATA}/config/lazyfirmware/config.cfg
    else
        REPORT_STATUS info "配置文件已存在，不进行覆盖"
    fi
    REPORT_STATUS info "LazyFirmware安装完成"
}

### Klipper Auto Speed插件
function install_klipper_auto_speed {
    REPORT_STATUS info "安装Klipper Auto Speed插件"
    if [ -d "klipper_auto_speed" ]; then
        rm -rf klipper_auto_speed
    fi
    git_clone "Klipper Auto Speed" ${AUTO_SPEED_GITREPO}
    (
        cd klipper_auto_speed || exit 1
        ./install.sh
    )
    REPORT_STATUS info "Klipper Auto Speed插件安装完成"
}

### Klipper Shake&Tune - 输入整形校准插件
function install_klipper_shake_tune {
    REPORT_STATUS info "安装Klipper Shake&Tune插件"
    (
        wget -O - https://raw.githubusercontent.com/Frix-x/klippain-shaketune/main/install.sh | bash
    )
    REPORT_STATUS info "Klipper Shake&Tune插件安装完成"
}

### Happy Hare多色插件
function install_happy_hare {
    REPORT_STATUS info "安装Happy Hare多色插件"
    if [ -d "Happy-Hare" ]; then
        rm -rf Happy-Hare
    fi
    git_clone "Happy-Hare" ${HAPPY_HARE_GITREPO}
    REPORT_STATUS info "Happy Hare多色插件安装完成，请手动执行：cd ~/Happy-Hare && ./install.sh -i"
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
████         遇到问题不要怕。扫码加Q群找@三木        ████
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
e) Input Shaper依赖是Klipper使用Input Shaper功能测试必须的系统依赖
    使用文档：https://www.klipper3d.org/Measuring_Resonances.html
f) Crowsnest是用来管理和使用摄像头的独立服务组件
    使用文档：https://github.com/mainsail-crew/crowsnest
g) Timelapse是Moonraker的延时摄影插件，可通过Mainsail控制
    使用文档：https://github.com/mainsail-crew/moonraker-timelapse
h) TMC驱动自动调谐插件可以帮助Klipper动态调整TMC驱动的相应参数，减轻运行噪音
    使用文档：https://github.com/andrewmcgr/klipper_tmc_autotune
i) LED Effects是用于实现RGB灯效的Klipper插件
    使用文档：https://github.com/julianschill/klipper-led_effect/blob/master/docs/LED_Effect.md
j) LazyFirmware帮助懒人一键升级3D打印机控制板的Klipper固件
    使用文档：https://github.com/Samuel-0-0/LazyFirmware
k) Klipper Auto Speed插件可以帮助测试硬件的最大速度与加速度
    使用文档：https://github.com/anonoei/klipper_auto_speed
l) Klipper Shake&Tune插件可以帮助排除机械故障与校准输入整形
    使用文档：https://github.com/Frix-x/klippain-shaketune/blob/main/docs/README.md
m) Happy Hare - 多色打印耗材控制系统
    使用文档：https://github.com/moggieuk/Happy-Hare/wiki

/!\注意：部分插件需要自行修改配置文件，请查看使用文档。

请选择需要的项目（↑↓方向键选择，空格键选中/取消，TAP键切换）：\
            " 50 130 13 \
            "a" "Klipper&Moonraker - 必须的组件" ON \
            "b" "Mainsail - WEBUI控制界面" ON \
            "c" "KlipperScreen - 触摸屏控制界面" OFF \
            "d" "Gcode Shell Command - 执行Shell插件" ON \
            "e" "Input Shaper - 加速度测试依赖" ON \
            "f" "Crowsnest - 摄像头服务" OFF \
            "g" "Timelapse - 延时摄影插件" OFF \
            "h" "Klipper TMC Autotune - TMC驱动自动调谐插件" ON \
            "i" "LED Effects - RGB灯效插件" OFF \
            "j" "LazyFirmware - 一键升级klipper固件" ON \
            "k" "Klipper Auto Speed - 测试硬件的最大速度与加速度" OFF \
            "l" "Klipper Shake&Tune - 输入整形校准插件" OFF \
            "m" "Happy Hare - 多色打印耗材控制系统" OFF \
            3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        CHOICES=$(sed  's/\"//g' <<<$CHOICES)
        for PACKAGE in $CHOICES; do
            case $PACKAGE in
            a) pre_setup && install_moonraker && install_klipper && configure_can_interface ;;
            b) install_mainsail ;;
            c) install_KlipperScreen ;;
            d) install_gcode_shell_command ;;
            e) install_input_shaper ;;
            f) install_crowsnest ;;
            g) install_timelapse ;;
            h) install_klipper_tmc_autotune ;;
            i) install_klipper_led_effect ;;
            j) install_lazyfirmware ;;
            k) install_klipper_auto_speed;;
            l) install_klipper_shake_tune;;
            m) install_happy_hare;;
            esac
        done
    else
        #echo "You chose Cancel."
        exit 0
    fi
}

### 欢迎界面
if (whiptail --title "Klipper助手" --yes-button "我很需要" --no-button "再考虑一下"  --yesno "本助手将帮助安装Klipper以及与其相关的服务、插件及辅助优化。
是否继续？" 10 65) then
    Main_menu
else
    exit 0
fi

### 结束界面
whiptail --title "祝贺" --msgbox "恭喜安装完成了！" --ok-button "你退下吧" 10 65
