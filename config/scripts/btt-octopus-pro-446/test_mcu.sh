#!/bin/bash

function UPDATE_MCU() {
    whiptail --title "请输入设备ID" --inputbox --ok-button "确定" --cancel-button "取消" "请输入设备的ID，如 /dev/serial/by-id/usb-Klipper_stm32f446xx_1234567890-if00" 10 100
    whiptail --title "选择使用工作模式" \
            --ok-button "确定" --cancel-button "取消" --menu \
            "请选择使用的工作模式（方向上下选择，空格选中取消，TAP键切换）：" 20 100 5 \
            "1" "USB" \
            "2" "CAN Bridge" \
            "3" "CAN" \
            "4" "UART"
    whiptail --title "参数已保存" --msgbox "已根据您的选择配置好对应的固件编译参数" 10 60
    {
        for ((i = 0 ; i <= 100 ; i+=20)); do
            sleep 1
            echo $i
        done
    } | whiptail --gauge "正在更新固件，请稍后..." 6 60 0
}

function BOARD_LIST_BTT() {
    CHOICES_BOARD_BTT=$(
        whiptail --title "选择使用的硬件型号" \
            --ok-button "确定" --cancel-button "取消" --checklist \
            "请选择使用的硬件型号，如果没有请选择自定义（方向上下选择，空格选中取消，TAP键切换）：" 20 100 5 \
            "1" "Octopus 446 1.1" OFF \
            "2" "Octopus Pro 446 1.0" OFF \
            "3" "EBB36 1.1" OFF \
            "4" "XXX" OFF \
            "5" "自定义" OFF \
            3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        CHOICES_BOARD_BTT=$(sed  's/\"//g' <<<$CHOICES_BOARD_BTT)
        for BOARD_BTT in $CHOICES_BOARD_BTT; do
            case $BOARD_BTT in
            1) UPDATE_MCU ;;
            2) UPDATE_MCU ;;
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


function BRAND_LIST() {
    CHOICES_BRAND=$(
        whiptail --title "选择使用的硬件品牌" \
            --ok-button "确定" --cancel-button "取消" --checklist \
            "请根据您安装的硬件，在下列品牌中选择：\n一堆没人看的废话，如未在列表中请选择自定义\n请选择使用的硬件（方向上下选择，空格选中取消，TAP键切换）：" 20 100 5 \
            "1" "BigTreeTech 必趣" OFF \
            "2" "FYSETC 富源盛" OFF \
            "3" "FLY" OFF \
            "4" "XXX" OFF \
            "5" "自定义" OFF \
            3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        CHOICES_BRAND=$(sed  's/\"//g' <<<$CHOICES_BRAND)
        for BRAND in $CHOICES_BRAND; do
            case $BRAND in
            1) BOARD_LIST_BTT ;;
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

if (whiptail --title "Klipper固件更新小助手" --yes-button "确认" --no-button "退出"  --yesno "本助手将帮助快速生成并刷写设备固件，由于你是第一次使用本助手，需要先进行硬件配置，请确保您已经提前配置过Klipper并成功运行。选择确认继续。" 10 60) then
    BRAND_LIST
else
    exit 0
fi

whiptail --title "祝贺" --msgbox "恭喜你固件更新完成了！" --ok-button "好的" 10 60