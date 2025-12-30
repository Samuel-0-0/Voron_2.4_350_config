#!/usr/bin/env bash

################################################################################
# 3D打印机辅助文件
################################################################################
# COPYRIGHT © 2021 - 2025  Samuel Wang
# 本文件可以根据GNU GPLv3许可协议进行分发
# This file may be distributed under the terms of the GNU GPLv3 license
################################################################################
# Discord: Samuel-0-0#0576    Github: Samuel-0-0    Bilibili: Samuel-0_0
################################################################################
# 文件用途：Klipper CPU 调度能力判定与亲和性 (Affinity) 推荐
################################################################################

################################################################################
# 快速使用：
# curl -sSL https://raw.githubusercontent.com/Samuel-0-0/Voron_2.4_350_config/main/config/scripts/cpu_affinity.sh | bash
################################################################################

# --- 终端配色定义 ---
export LANG=en_US.UTF-8
RED='\033[38;5;196m'
ORANGE='\033[38;5;208m'
YELLOW='\033[38;5;226m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
BLUE='\033[38;5;39m'
BOLD='\033[1m'
GRAY='\033[38;5;244m'
NC='\033[0m'

# --- 变量初始化 ---
declare -a ALL_CPUS
declare -a RT_CPUS
declare -a BG_CPUS
declare -A CPU_DETAILS

############################
# 0. 识别 CPU 型号
############################
cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//')
if [[ -z "$cpu_model" ]]; then
    cpu_model=$(grep -m1 "Hardware" /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//')
fi
if [[ -z "$cpu_model" && -f /proc/device-tree/model ]]; then
    cpu_model=$(cat /proc/device-tree/model | tr -d '\0')
fi
[[ -z "$cpu_model" ]] && cpu_model="Generic Processor"

############################
# 1. 核心检测逻辑
############################
for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
    id=${cpu_dir##*cpu}
    ALL_CPUS+=("$id")
    cap=0
    [[ -f "$cpu_dir/cpu_capacity" ]] && cap=$(cat "$cpu_dir/cpu_capacity")
    core_id=0
    [[ -f "$cpu_dir/topology/core_id" ]] && core_id=$(cat "$cpu_dir/topology/core_id")
    CPU_DETAILS[$id]="$cap|$core_id"
done

cpu_count=${#ALL_CPUS[@]}
max_cap=0
for id in "${ALL_CPUS[@]}"; do
    IFS='|' read -r cap core <<< "${CPU_DETAILS[$id]}"
    (( cap > max_cap )) && max_cap=$cap
done

if [ "$max_cap" -gt 0 ]; then
    for id in "${ALL_CPUS[@]}"; do
        IFS='|' read -r cap core <<< "${CPU_DETAILS[$id]}"
        [[ "$cap" -eq "$max_cap" ]] && RT_CPUS+=("$id") || BG_CPUS+=("$id")
    done
    STRATEGY="HMP (大小核感知)"
else
    STRATEGY="SMP (对称负载对半分)"
    half=$((cpu_count / 2))
    for ((i=0; i<cpu_count; i++)); do
        (( i < half )) && RT_CPUS+=("${ALL_CPUS[$i]}") || BG_CPUS+=("${ALL_CPUS[$i]}")
    done
fi

############################
# 2. 界面输出
############################
clear
echo -e "${BOLD}${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${BOLD}${CYAN}┃           Klipper CPU 调度能力判定与亲和性 (Affinity) 推荐          ┃${NC}"
echo -e "${BOLD}${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
echo -e " ${BOLD}处理器型号:${NC} ${YELLOW}$cpu_model${NC}"
echo -e " ${GRAY}检测策略: $STRATEGY | 核心总数: $cpu_count${NC}\n"

echo -ne " ${BOLD}CPU Core Map:${NC} "
for id in "${ALL_CPUS[@]}"; do
    is_rt=false
    for r in "${RT_CPUS[@]}"; do [[ "$r" == "$id" ]] && is_rt=true; done
    if $is_rt; then echo -ne "${GREEN}■${NC} "; else echo -ne "${BLUE}■${NC} "; fi
done
echo -e "\n ${GRAY}( ${GREEN}■${GRAY} 实时/大核 | ${BLUE}■${GRAY} 后台/小核 )${NC}\n"

############################
# 3. 现存配置
############################
check_service_config() {
    local svc_file="/etc/systemd/system/$1"
    echo -e " ${BOLD}服务文件:${NC} ${CYAN}$1${NC}"
    if [[ -f "$svc_file" ]]; then
        # 检查 CPUAffinity
        local cur_aff=$(grep "^CPUAffinity=" "$svc_file" | cut -d= -f2)
        if [[ -n "$cur_aff" ]]; then
            echo -e "   ├─ CPUAffinity: ${GREEN}已设置 ($cur_aff)${NC}"
        else
            echo -e "   ├─ CPUAffinity: ${ORANGE}未设置 (建议添加)${NC}"
        fi

        # 检查 Nice 优先级
        local cur_nice=$(grep "^Nice=" "$svc_file" | cut -d= -f2)
        if [[ -n "$cur_nice" ]]; then
            echo -e "   └─ Nice 优先级: ${GREEN}已设置 ($cur_nice)${NC}"
        else
            echo -e "   └─ Nice 优先级: ${ORANGE}未设置 (建议 Klipper 设置为 -20)${NC}"
        fi
    else
        echo -e "   ${RED}⚠ 未找到服务文件，请确认安装路径${NC}"
    fi
}

echo -e "${BOLD}${YELLOW}������ 当前系统配置:${NC}"
check_service_config "klipper.service"
echo ""

############################
# 4. Systemd 推荐配置
############################
rt_list=$(printf "%s " "${RT_CPUS[@]}")
bg_list=$(printf "%s " "${BG_CPUS[@]}")



echo -e "${BOLD}${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${BOLD}${CYAN}┃                  Systemd 优化建议配置 (修改后重启)                  ┃${NC}"
echo -e "${BOLD}${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

echo -e " ${BOLD}[klipper.service]${NC}"
echo -e " ${GREEN}CPUAffinity=$rt_list${NC}"
echo -e " ${GREEN}Nice=-20${NC}"
echo -e " ${GRAY}# 设置 Nice=-20 可确保 Klipper 获得最高 CPU 抢占权限${NC}\n"

echo -e " ${BOLD}[moonraker.service / crowsnest.service]${NC}"
echo -e " ${BLUE}CPUAffinity=$bg_list${NC}"
echo -e " ${BLUE}Nice=10${NC}"
echo -e " ${GRAY}# 将非实时任务优先级调低，避免干扰运动控制${NC}"

echo -e "\n${BOLD}${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}生效方式:${NC}"
echo -e " 1. 使用 ${CYAN}sudo nano /etc/systemd/system/klipper.service${NC} 编辑"
echo -e " 2. 在 ${BOLD}[Service]${NC} 字段下添加上述参数"
echo -e " 3. 执行 ${BOLD}sudo systemctl daemon-reload && sudo systemctl restart klipper${NC}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"