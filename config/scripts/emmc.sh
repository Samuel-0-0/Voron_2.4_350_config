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
# 文件用途：eMMC 存储芯片健康度与寿命诊断工具
################################################################################

################################################################################
# 快速使用：
# curl -sSL https://raw.githubusercontent.com/Samuel-0-0/Voron_2.4_350_config/main/config/scripts/emmc.sh | bash
################################################################################


# --- 终端配色定义 ---
export LANG=en_US.UTF-8
RED='\033[38;5;196m'
ORANGE='\033[38;5;208m'
YELLOW='\033[38;5;226m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
BOLD='\033[1m'
GRAY='\033[38;5;244m'
NC='\033[0m'

# --- 寿命状态映射表 ---
declare -A LIFE_MAP
LIFE_MAP["0x00"]="未定义"
LIFE_MAP["0x01"]="90% - 100%"
LIFE_MAP["0x02"]="80% - 90%"
LIFE_MAP["0x03"]="70% - 80%"
LIFE_MAP["0x04"]="60% - 70%"
LIFE_MAP["0x05"]="50% - 60%"
LIFE_MAP["0x06"]="40% - 50%"
LIFE_MAP["0x07"]="30% - 40%"
LIFE_MAP["0x08"]="20% - 30%"
LIFE_MAP["0x09"]="10% - 20%"
LIFE_MAP["0x0a"]="0% - 10% (警告)"
LIFE_MAP["0x0b"]="已耗尽 (风险)"

# --- 进度条函数 ---
draw_health_bar() {
    local val_hex=${1,,}
    local width=20
    # eMMC 0x01 是最健康，0x0a 是快坏了，0x0b 是坏了
    # 我们将其转换为 0-10 个格子
    local score=0
    [[ "$val_hex" =~ ^0x0[0-9a-b]$ ]] && score=$(( 16#${val_hex#0x} ))
    
    # 计算填充长度 (0x01 为满格，0x0a 为 1 格)
    local filled=$(( 11 - score ))
    [[ $score -eq 0 ]] && filled=0 # 未定义情况
    [[ $filled -lt 0 ]] && filled=0
    
    local color=$GREEN
    (( filled <= 3 )) && color=$YELLOW
    (( filled <= 1 )) && color=$RED

    printf " ["
    printf "${color}"
    for ((i=0; i<filled; i++)); do printf "■"; done
    printf "${GRAY}"
    for ((i=0; i<(10-filled); i++)); do printf "□"; done
    printf "${NC}]"
}

# --- 界面头部 ---
clear
echo -e "${BOLD}${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${BOLD}${CYAN}┃                  eMMC 存储芯片健康度与寿命诊断工具                  ┃${NC}"
echo -e "${BOLD}${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
echo -e " ${GRAY}分析时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"

# --- 遍历设备 ---
found_emmc=false
devices=$(ls /sys/block/ | grep -E "^mmcblk[0-9]+$")

for device in $devices; do
    found_emmc=true
    dev_path="/sys/block/$device/device"
    
    # 读取基本信息
    vendor="Unknown"
    [[ -f "$dev_path/name" ]] && model=$(cat "$dev_path/name")
    [[ -f "$dev_path/manfid" ]] && manid=$(cat "$dev_path/manfid")
    
    # 读取寿命数据
    if [[ -f "$dev_path/life_time" ]]; then
        result=$(cat "$dev_path/life_time")
        mlc_hex=$(echo $result | awk '{print $1}')
        slc_hex=$(echo $result | awk '{print $2}')
        
        echo -e " ${BOLD}${WHITE}▶ 磁盘节点: ${CYAN}/dev/$device${NC} [型号: $model]"
        
        # 用户分区 (MLC/TLC)
        mlc_text=${LIFE_MAP[${mlc_hex,,}]-未知}
        printf "   ├─ ${BOLD}用户分区健康度 (MLC):${NC} %-15s" "$mlc_text"
        draw_health_bar "$mlc_hex"
        printf "\n"
        
        # 引导分区 (SLC)
        slc_text=${LIFE_MAP[${slc_hex,,}]-未知}
        printf "   └─ ${BOLD}系统分区健康度 (SLC):${NC} %-15s" "$slc_text"
        draw_health_bar "$slc_hex"
        printf "\n\n"
        
    else
        echo -e " ${RED}✖ 磁盘 $device 不支持 life_time 寿命上报${NC}\n"
    fi
done

if ! $found_emmc; then
    echo -e " ${ORANGE}⚠ 未在系统中检测到 eMMC 设备 (可能是正在使用 SD 卡或 SSD)${NC}"
fi



# --- 诊断总结 ---
echo -e "${BOLD}${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}维护建议:${NC}"
echo -e " 1. ${BOLD}SLC分区${NC}通常存放Bootloader，寿命极长，应始终保持在90%以上。"
echo -e " 2. ${BOLD}MLC/用户分区${NC}存放系统和日志。如果低于30%，建议立即备份配置文件。"
echo -e " 3. 定期清理 ${CYAN}/var/log${NC} 或使用 ${CYAN}log2ram${NC} 可以显著延长芯片寿命。"
echo -e "${BOLD}${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"