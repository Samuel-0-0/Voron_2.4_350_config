#!/bin/bash
# 此脚本会安装 Klipper, moonraker, KlipperScreen, mainsail 以及我的配置文件到debian系统
#

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

pre_download()
{
    report_status "获取Klipper文件..."
    git clone https://github.com/KevinOConnor/klipper.git ${KLIPPER_DIR}
    report_status "获取Moonraker文件..."
    git clone https://github.com/Arksine/moonraker.git ${MOONRAKER_DIR}
    report_status "获取KlipperScreen文件..."
    git clone https://github.com/jordanruthe/KlipperScreen.git ${KLIPPERSCREEN_DIR}
    [ ! -d ${MAINSAIL_DIR} ] && mkdir ${MAINSAIL_DIR}
    report_status "获取Mainsail文件..."
    wget -q -O ${MAINSAIL_DIR}/mainsail.zip https://ghproxy.com/https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip
}

pre_setup()
{
    report_status "设置国内PYPI阿里云镜像源..."
    [ ! -d ${HOME}/.pip ] && mkdir ${HOME}/.pip
    sudo /bin/sh -c "cat > ${HOME}/.pip/pip.conf" << EOF
[global]
index-url = http://mirrors.aliyun.com/pypi/simple

[install]
trusted-host=mirrors.aliyun.com

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

# 步骤1: 安装Klipper
install_klipper()
{
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
}

# 步骤2: 安装Moonraker
install_moonraker()
{
    report_status "安装Moonraker..."
    source ${MOONRAKER_DIR}/scripts/install-moonraker.sh
    source ${MOONRAKER_DIR}/scripts/set-policykit-rules.sh
}

# 步骤3: 安装Mainsail
install_mainsail()
{
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
    [ -f ${MAINSAIL_DIR}/config.json ] && rm ${MAINSAIL_DIR}/config.json && \
    ln -sf ~/printer_data/config/mainsail_config.json ${MAINSAIL_DIR}/config.json
    sudo systemctl restart nginx
}

# 步骤4: 添加CAN网络配置
configure_can_interface()
{
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

# 步骤5: 安装Klipper插件
install_addon()
{
    report_status "安装Klipper插件..."
    source ${PRINTER_DATA}/config/scripts/install_addon.sh
}

# 步骤6: 启动Klipper
start_software()
{
    report_status "启动Klipper..."
    sudo systemctl start klipper
}

# Helper functions
report_status()
{
    echo -e "\n\n###### $1"
}

verify_ready()
{
    if [ "$EUID" -eq 0 ]; then
        echo "This script must not run as root"
        exit -1
    fi
}

# Force script to exit if an error occurs
set -e

# Find SRCDIR from the pathname of this script
SRCDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"

# Run installation steps defined above
verify_ready
pre_download
pre_setup
install_klipper
install_moonraker
install_mainsail
configure_can_interface
install_addon
