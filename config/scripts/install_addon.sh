#!/bin/bash

### 自定义打印信息颜色
green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

# crowsnest，替代MJPG-Streamer
function install_crowsnest {
    echo -e "${yellow}开始安装crowsnest${default}"
    if [ -d "crowsnest" ]; then
        rm -rf crowsnest
    fi
    git clone --recurse-submodules https://github.com/mainsail-crew/crowsnest.git
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}文件下载完成，开始安装...${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}文件下载失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
    sed -i 's/61ab2a8/dde2190/g' ~/crowsnest/bin/Makefile
    sed -i 's|https://github.com|https://ghproxy.com/https://github.com|g' ~/crowsnest/bin/Makefile
    sed -i 's/v0.20.2/v0.21.2/g' ~/crowsnest/bin/rtsp-simple-server/version
    pushd ~/crowsnest && sudo make install
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}webcam安装完成${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}webcam安装失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
    popd
}

# timelapse，用于延时摄影
function install_timelapse {
    echo -e "${yellow}开始安装timelapse${default}"
    if [ -d "moonraker-timelapse" ]; then
        rm -rf moonraker-timelapse
    fi
    git clone https://github.com/mainsail-crew/moonraker-timelapse.git
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}文件下载完成，开始安装...${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}文件下载失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
    ./moonraker-timelapse/install.sh -c ~/printer_data/config
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

# gcode_shell_command，用于在gcode中执行shell脚本
function install_gcode_shell_command {
    echo -e "${yellow}开始安装gcode_shell_command${default}"
    ln -sf ~/printer_data/config/scripts/gcode_shell_command.py ~/klipper/klippy/extras/gcode_shell_command.py
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
function install_input_shaper {
    echo -e "${yellow}开始安装加速度测试依赖包${default}"
    sudo apt install --yes python3-numpy python3-matplotlib
    ~/klippy-env/bin/pip install -v numpy
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

# 区域床网
function install_print_area_bed_mesh {
    echo -e "${yellow}开始安装print_area_bed_mesh${default}"
    if [ -d "print_area_bed_mesh" ]; then
        rm -rf print_area_bed_mesh
    fi
    git clone https://github.com/Turge08/print_area_bed_mesh.git
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}文件下载完成，开始安装...${default}"
        echo -e ""
    else
        echo -e ""
        echo -e "${red}文件下载失败，详情请查看上方信息${default}"
        echo -e ""
        exit 1
    fi
    ln -sf ~/print_area_bed_mesh/print_area_bed_mesh.cfg ~/printer_data/config/print_area_bed_mesh.cfg
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

cd ~
sudo apt-get update
install_input_shaper
install_gcode_shell_command
install_timelapse
install_print_area_bed_mesh
install_crowsnest
