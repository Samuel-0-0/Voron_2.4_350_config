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
# 文件用途：Klipper USB/CAN 拓扑稳定性诊断分析系统
################################################################################

################################################################################
# 快速使用：
# curl -sSL https://raw.githubusercontent.com/Samuel-0-0/Voron_2.4_350_config/main/config/scripts/list_usb.sh | bash
################################################################################

# --- 终端配色定义 ---
export LANG=en_US.UTF-8
RED='\033[38;5;196m'
ORANGE='\033[38;5;208m'
YELLOW='\033[38;5;226m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
BLUE='\033[38;5;39m'
MAGENTA='\033[38;5;213m'
GRAY='\033[38;5;244m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SYS=/sys/bus/usb/devices
declare -A NODE_INFO CHILDREN NODE_SCORE NODE_DEPTH NODE_SERIAL NODE_LINKTYPE

# 1. 扫描阶段
for dev_path in "$SYS"/[0-9]*-*; do
    name=$(basename "$dev_path")
    [[ ! "$name" =~ ^[0-9]+-[0-9]+(\.[0-9]+)*$ ]] && continue
    node_type="device"; product=""; driver="usb"; serial="N/A"; linktype="USB"
    [[ "$(head -n1 "$dev_path/bDeviceClass" 2>/dev/null)" == "09" ]] && node_type="hub"
    [[ -f "$dev_path/serial" ]] && serial=$(head -n1 "$dev_path/serial" 2>/dev/null)
    
    manufacturer=$(head -n1 "$dev_path/manufacturer" 2>/dev/null)
    if echo "$manufacturer" | grep -qi "klipper"; then
        node_type="klipper"
        product=$(head -n1 "$dev_path/product" 2>/dev/null)
        [[ -L "$dev_path/driver" ]] && driver=$(basename "$(readlink -f "$dev_path/driver")")
        [[ "$driver" == "gs_usb" ]] && linktype="CAN(gs_usb)" || linktype="USB(${driver})"
    fi

    NODE_INFO["$name"]="$node_type|$product|$driver"
    NODE_SERIAL["$name"]="$serial"
    NODE_LINKTYPE["$name"]="$linktype"

    if [[ "$name" == *.* ]]; then
        parent="${name%.*}"; CHILDREN["$parent"]="${CHILDREN[$parent]} $name"
    else
        bus="${name%%-*}"; parent="$bus-0"; CHILDREN["$parent"]="${CHILDREN[$parent]} $name"
        [[ -z "${NODE_INFO[$parent]}" ]] && NODE_INFO["$parent"]="root_hub||"
    fi
done

# 2. 评分逻辑
calc_score() {
    local depth="$1" driver="$2" score=100
    (( score -= (depth-1) * 10 )) # 深度惩罚增加
    [[ "$driver" == "gs_usb" ]] && (( score -= 10 ))
    (( score < 0 )) && score=0
    echo "$score"
}

# 3. 树形打印
print_tree() {
    local node="$1" prefix="$2" is_last="$3" depth="$4"
    NODE_DEPTH["$node"]="$depth"
    local info="${NODE_INFO[$node]}"
    local type="${info%%|*}"
    local rest="${info#*|}"
    local product="${rest%%|*}"
    local driver="${rest#*|}"
    
    local char_tee="├── "
    local char_last="└── "
    [[ "$is_last" == "true" ]] && connector=$char_last || connector=$char_tee

    if [[ "$type" == "klipper" ]]; then
        score=$(calc_score "$depth" "$driver")
        NODE_SCORE["$node"]="$score"
        
        # 状态色块与进度条
        if (( score >= 90 )); then color=$GREEN; status="● STABLE"; 
        elif (( score >= 80 )); then color=$YELLOW; status="○ RISK"; 
        else color=$RED; status="▲ CRITICAL"; fi

        printf "${prefix}${connector}${BOLD}${color}������ Klipper Device${NC} [${product}]\n"
        printf "${prefix}$([[ "$is_last" == "true" ]] && echo "    " || echo "│   ")  ${GRAY}ID:${NC} %-12s ${GRAY}SN:${NC} %-12s\n" "$node" "${NODE_SERIAL[$node]}"
        printf "${prefix}$([[ "$is_last" == "true" ]] && echo "    " || echo "│   ")  ${GRAY}LK:${NC} %-12s ${color}${status} (${score} pts)${NC}\n" "${NODE_LINKTYPE[$node]}"

    elif [[ "$type" == "hub" ]]; then
        printf "${prefix}${connector}${BLUE}������ Hub${NC} (${node})\n"
    fi

    local child_prefix="$prefix"
    [[ "$is_last" == "true" ]] && child_prefix+="    " || child_prefix+="│   "

    local children=(${CHILDREN[$node]})
    local count=${#children[@]}
    local i=0
    for child in "${children[@]}"; do
        ((i++))
        local last="false"
        [[ $i -eq $count ]] && last="true"
        print_tree "$child" "$child_prefix" "$last" $((depth + 1))
    done
}

# 4. 主程序输出
clear
echo -e "${BOLD}${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${BOLD}${CYAN}┃               Klipper USB/CAN 拓扑稳定性诊断分析系统                ┃${NC}"
echo -e "${BOLD}${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
echo -e " ${GRAY}Scan Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"

for bus in 1 2; do
    root="$bus-0"
    [[ -n "${CHILDREN[$root]}" ]] || continue
    echo -e " ${BOLD}${MAGENTA}������ BUS $bus${NC}"
    print_tree "$root" "" "true" 0
    echo
done

# 5. 诊断报告
echo -e "${BOLD}${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${BOLD}${CYAN}┃                     掉 线 风 险 诊 断 排 查 报 告                   ┃${NC}"
echo -e "${BOLD}${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

found=0
for node in "${!NODE_SCORE[@]}"; do
    score="${NODE_SCORE[$node]}"
    [[ "$score" -lt 90 ]] || continue
    found=1
    
    [[ "$score" -lt 80 ]] && level="${RED}${BOLD}HIGH RISK${NC}" || level="${YELLOW}MEDIUM RISK${NC}"
    
    echo -e "������ ${BOLD}故障风险节点:${NC} ${CYAN}${node}${NC} [${NODE_SERIAL[$node]}]"
    echo -e "   ├─ 风险等级: $level"
    echo -e "   ├─ 链路属性: ${NODE_LINKTYPE[$node]}"
    echo -e "   └─ 诊断详情: "

    if [[ "${NODE_LINKTYPE[$node]}" == CAN* && ${NODE_DEPTH[$node]} -ge 2 ]]; then
        echo -e "      ${RED}������ [链路架构错误] CAN-USB工作在级联Hub之下，极易产生高延迟导致掉线。${NC}"
        echo -e "      ${GREEN}������ [改进方案] 将CAN直连上位机，避开所有Hub。${NC}"
    elif (( ${NODE_DEPTH[$node]} >= 3 )); then
        echo -e "      ${ORANGE}������ [拓扑过深] USB物理链路超过3层级联，掉线风险增加。${NC}"
        echo -e "      ${GREEN}������ [改进方案] 精简串联路径。${NC}"
    fi
    echo ""
done

if [[ $found -eq 0 ]]; then
    echo -e "   ${GREEN}������ 诊断完成: 当前拓扑非常完美，未发现已知风险项。${NC}"
fi
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"