#!/bin/bash

#clear

### 自定义打印信息颜色
green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
default=$(echo -en "\e[39m")

#if [ "$EUID" -ne 0 ]
#  then echo -e "${red}错误: 本脚本需要root用户权限${default}"
#  exit
#fi

#######################################################################
###  设置主板
###  使用命令 "ls -l /dev/serial/by-id/" 来获取通讯端口号填入下方
###  使用命令 "~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0" 来获取CAN UUID
#######################################################################
TOOLHEAD_BOARD=/dev/serial/by-id/usb-Klipper_stm32f072xb_3F0048001651524138383120-if00
MAIN_BOARD=/dev/serial/by-id/usb-Klipper_stm32f446xx_29001000095053424E363420-if00
EBB_UUID=
OCTOPUS_UUID=fea6ca620740
VAST_UUID=ea733e4b9026

#######################################################################
###      更新VAST打印头板
#######################################################################
function update_vast_can {
    echo -e ""
    echo -e "${yellow}开始更新 VAST 打印头控制板${default}"
    echo -e ""
    if [ ! -d "CanBoot" ]; then
        git clone https://github.com/Arksine/CanBoot.git
    fi
    cp -f ~/printer_data/config/scripts/vast-stm32f072/VAST_STM32F072_CAN_1M.config ~/klipper/.config
    pushd ~/klipper
    make olddefconfig
    make clean
    make
    echo -e ""
    read -e -p "${yellow}固件编译完成，请检查上面是否有错误。 按 [Enter] 继续更新固件，或者按 [Ctrl+C] 取消${default}"
    echo -e ""
    #make flash KCONFIG_CONFIG=~/printer_data/config/scripts/vast-stm072/vast-stm072_usb.config FLASH_DEVICE=$TOOLHEAD_BOARD
    python3 ~/CanBoot/scripts/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u $VAST_UUID
    #python3 ~/klipper/lib/canboot/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u $VAST_UUID
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}已完成 VAST 打印头控制板固件更新${default}"
        echo -e ""
        popd
    else
        echo -e ""
        echo -e "${red}固件更新失败，详情请查看上方信息${default}"
        echo -e ""
        popd
        exit 1
    fi
}

#######################################################################
###      用CANBOOT方式更新必趣EBB v1.1打印头板
#######################################################################
function update_ebb_can {
    echo -e ""
    echo -e "${yellow}开始更新 EBB 打印头控制板${default}"
    echo -e ""
    if [ ! -d "CanBoot" ]; then
        git clone https://github.com/Arksine/CanBoot.git
    fi
    cp -f ~/printer_data/config/scripts/btt-ebb-g0/V1.1_CAN_1M.config ~/klipper/.config
    pushd ~/klipper
    make olddefconfig
    make clean
    make
    echo -e ""
    read -e -p "${yellow}固件编译完成，请检查上面是否有错误。 按 [Enter] 继续更新固件，或者按 [Ctrl+C] 取消${default}"
    echo -e ""
    python3 ~/CanBoot/scripts/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u $EBB_UUID
    #python3 ~/klipper/lib/canboot/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u $EBB_UUID
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}已完成 EBB 打印头控制板固件更新${default}"
        echo -e ""
        popd
    else
        echo -e ""
        echo -e "${red}固件更新失败，详情请查看上方信息${default}"
        echo -e ""
        popd
        exit 1
    fi
}

#######################################################################
###   使用CAN方式更新使用CAN BRIDGE固件的
###   BigTreeTech OctoPus Pro v1.0(STM32F446)
#######################################################################
function update_octopus_canbus {
    echo -e ""
    echo -e "${yellow}开始更新 BigTreeTech OctoPus Pro v1.0(STM32F446)${default}"
    echo -e ""
    if [ ! -d "CanBoot" ]; then
        git clone https://github.com/Arksine/CanBoot.git
    fi
    cp -f ~/printer_data/config/scripts/btt-octopus-pro-446/CAN_Bridge_1M.config ~/klipper/.config
    pushd ~/klipper
    make olddefconfig
    make clean
    make
    echo -e ""
    read -p "${yellow}固件编译完成，请检查上面是否有错误。 按 [Enter] 继续更新固件，或者按 [Ctrl+C] 取消${default}"
    echo -e ""
    python3 ~/CanBoot/scripts/flash_can.py -i can0 -u $OCTOPUS_UUID -r
    #python3 ~/klipper/lib/canboot/flash_can.py -i can0 -u $OCTOPUS_UUID -r
    echo -e ""
    echo -e "${red}CAN BRIDGE固件的主板进DFU需要一点点时间，为了保险一点，请耐心等待10秒。${default}"
    echo -e ""
    # 等待10秒
    sleep 10 &
    wait
    # 进入DFU模式后的设备FLASH_DEVICE通常是0483:df11
    make flash FLASH_DEVICE=0483:df11
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}已完成 OctoPus Pro 固件更新${default}"
        echo -e ""
        popd
    else
        echo -e ""
        echo -e "${red}固件更新失败，详情请查看上方信息${default}"
        echo -e ""
        popd
        exit 1
    fi
}

#######################################################################
###   使用DFU方式更新 BigTreeTech OctoPus Pro v1.0(STM32F446)
#######################################################################
function update_octopus_dfu {
    echo -e ""
    echo -e "${yellow}开始更新 BigTreeTech OctoPus Pro v1.0(STM32F446)${default}"
    echo -e ""
    cp -f ~/klipper_config/scripts/btt-octopus-pro-446/normal.config ~/klipper/.config
    pushd ~/klipper
    make olddefconfig
    make clean
    make
    echo -e ""
    read -p "${yellow}固件编译完成，请检查上面是否有错误。 按 [Enter] 继续更新固件，或者按 [Ctrl+C] 取消${default}"
    echo -e ""
    make flash FLASH_DEVICE=$MAIN_BOARD
    #make flash FLASH_DEVICE=0483:df11
    if [ $? -eq 0 ]
    then
        echo -e ""
        echo -e "${green}已完成 OctoPus Pro 固件更新${default}"
        echo -e ""
        popd
    else
        echo -e ""
        echo -e "${red}固件更新失败，详情请查看上方信息${default}"
        echo -e ""
        popd
        exit 1
    fi
}

#######################################################################
###      停止klipper服务
#######################################################################
function stop_service {
    echo -e ""
    echo -e "${yellow}正在停止klipper服务..."
    sudo service klipper stop
    echo -e "完成${default}"
}

#######################################################################
###      启动klipper服务
#######################################################################
function start_service {
    echo -e ""
    echo -e "${yellow}正在启动klipper服务..."
    sudo service klipper start
    echo -e "完成${default}"
    echo -e ""
    echo -e "${green}本次固件更新工作已全部完成，祝你打印顺利！${default}"
    echo -e ""
}

#######################################################################
###      执行的操作
#######################################################################
stop_service
update_octopus_canbus
#update_octopus_dfu
update_vast_can
#update_ebb_can
start_service
