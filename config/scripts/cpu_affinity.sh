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
# 1. 核心检测逻辑
############################
for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
    id=${cpu_dir##*cpu}
    ALL_CPUS+=("$id")
    
    # 获取容量 (大小核判断)
    cap=0
    [[ -f "$cpu_dir/cpu_capacity" ]] && cap=$(cat "$cpu_dir/cpu_capacity")
    
    # 获取物理核心 ID (超线程判断)
    core_id=0
    [[ -f "$cpu_dir/topology/core_id" ]] && core_id=$(cat "$cpu_dir/topology/core_id")
    
    CPU_DETAILS[$id]="$cap|$core_id"
done

cpu_count=${#ALL_CPUS[@]}

# 分类策略
max_cap=0
for id in "${ALL_CPUS[@]}"; do
    IFS='|' read -r cap core <<< "${CPU_DETAILS[$id]}"
    (( cap > max_cap )) && max_cap=$cap
done

if [ "$max_cap" -gt 0 ]; then
    # HMP 架构 (大核为 RT，小核为 BG)
    for id in "${ALL_CPUS[@]}"; do
        IFS='|' read -r cap core <<< "${CPU_DETAILS[$id]}"
        [[ "$cap" -eq "$max_cap" ]] && RT_CPUS+=("$id") || BG_CPUS+=("$id")
    done
    STRATEGY="HMP (大小核感知)"
else
    # SMP 架构 (对半分)
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
echo -e " ${GRAY}检测策略: $STRATEGY | 核心总数: $cpu_count${NC}\n"

# 打印核心视图
echo -ne " ${BOLD}CPU Core Map:${NC} "
for id in "${ALL_CPUS[@]}"; do
    is_rt=false
    for r in "${RT_CPUS[@]}"; do [[ "$r" == "$id" ]] && is_rt=true; done
    if $is_rt; then
        echo -ne "${GREEN}■${NC} "
    else
        echo -ne "${BLUE}■${NC} "
    fi
done
echo -e "\n ${GRAY}( ${GREEN}■${GRAY} 实时/大核 | ${BLUE}■${GRAY} 后台/小核 )${NC}\n"

############################
# 3. 结果明细
############################
printf " ${BOLD}${YELLOW}������ 实时性能组 (RT-Pool):${NC} %s\n" "${RT_CPUS[*]}"
printf " ${GRAY}   用途: Klipper MCU 进程, CAN/USB 中断处理, 运动控制${NC}\n"
printf " ${BOLD}${CYAN}������ 后台任务组 (BG-Pool):${NC} %s\n" "${BG_CPUS[*]}"
printf " ${GRAY}   用途: Moonraker, Mainsail/Fluidd, Webcam 流媒体${NC}\n"

############################
# 4. Systemd 推荐配置
############################
rt_list=$(printf "%s " "${RT_CPUS[@]}")
bg_list=$(printf "%s " "${BG_CPUS[@]}")



echo -e "\n${BOLD}${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${BOLD}${CYAN}┃                  Systemd 优化建议配置 (修改后重启)                  ┃${NC}"
echo -e "${BOLD}${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

echo -e " ${BOLD}[klipper.service]${NC}"
echo -e " ${GREEN}CPUAffinity=$rt_list${NC}"
echo -e " ${GRAY}# 在 [Service] 部分添加，确保运动控制不被 Webcam 抢占${NC}\n"

echo -e " ${BOLD}[moonraker.service / crowsnest.service]${NC}"
echo -e " ${BLUE}CPUAffinity=$bg_list${NC}"
echo -e " ${GRAY}# 限制非实时任务在低优先级核心运行${NC}"

echo -e "\n${BOLD}${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}生效方式:${NC} 修改 Service 后执行 ${BOLD}sudo systemctl daemon-reload${NC} 并重启服务。"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"