#!/bin/bash

# ==========================================
# CANBus Setup Script (Auto-Detection)
# Logic: Checks the status of networkd-dispatcher.service vs networking.service
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[AUTO-DETECT]${NC} $1"; }

# --- 1. 系统与内核检查 ---
check_system() {
    log "正在检查系统环境..."
    
    # 检查 CAN 内核模块
    if lsmod | grep -q "can"; then
        log "CAN 内核模块已加载。"
    else
        warn "CAN 内核模块未加载，尝试加载..."
        sudo modprobe can
        if [ $? -ne 0 ]; then
            error "无法加载 CAN 模块，请检查系统内核支持！"
            exit 1
        fi
    fi

    # 检查 Esoterical 提到的 Kernel 6.1 + aarch64 问题
    KERNEL=$(uname -r)
    ARCH=$(uname -m)
    if [[ "$KERNEL" == *"6.1."* ]] && [[ "$ARCH" == "aarch64" ]]; then
        warn "检测到 Kernel 6.1.x + aarch64 (树莓派Bullseye 64位)。"
        warn "已知该版本会导致 CANBus 时序严重故障。"
        read -p "是否强制继续？(y/N): " choice
        [[ ! "$choice" =~ ^[Yy]$ ]] && exit 1
    fi
}

# --- 2. 自动判断配置模式 (新增函数) ---
determine_config_method() {
    echo -e "\n----------------------------------------"
    info "正在分析系统网络服务状态..."

    # 优先级 1: 检查 networkd-dispatcher 服务状态（现代 systemd 网络栈）
    # is-enabled: 是否被设置成开机启动
    # is-active: 是否正在运行
    if systemctl is-active --quiet networkd-dispatcher.service; then
        info "检测到 networkd-dispatcher.service 处于启用或活动状态。"
        info "决策: 采用[Modern]模式(systemd-networkd)配置。"
        CONFIG_METHOD="modern"
        return
    fi
    
    # 优先级 2: 检查 networking.service 服务状态 (传统 ifupdown)
    if systemctl is-active --quiet networking.service; then
        info "检测到 networking.service 处于启用或活动状态。"
        info "决策: 采用[Legacy]模式(ifupdown)配置。"
        CONFIG_METHOD="legacy"
        return
    fi

    # 优先级 3: 回退/默认：如果两者都不明确
    warn "未能明确判断网络服务管理器（两者均非启用/活动）。"

    # 最终默认选择 Modern 模式（倾向于最新推荐标准）
    info "未发现明确的服务，默认选择Modern模式。"
    CONFIG_METHOD="modern"
}

# --- 3. 选择队列长度 ---
select_txqueuelen() {
    echo -e "\n选择txqueuelen(发送队列长度)："
    echo "1) 128 (Klipper官方推荐，延迟低)"
    echo "2) 256 (社区建议，防止'timer too close'报错)"
    echo "3) 512"
    echo "4) 1024"
    read -p "请选择 (默认128): " q_choice
    
    case $q_choice in
        2) TX_LEN=256 ;;
        3) TX_LEN=512 ;;
        4) TX_LEN=1024 ;;
        *) TX_LEN=128 ;;
    esac
    log -e "\n已选择txqueuelen: $TX_LEN"
}

# --- 4. 配置方法 A: systemd-networkd (Modern) ---
setup_systemd() {
    log "正在使用 systemd-networkd 方式配置..."

    # 启用服务
    sudo systemctl unmask systemd-networkd
    sudo systemctl enable systemd-networkd
    sudo systemctl start systemd-networkd
    sudo systemctl disable systemd-networkd-wait-online.service

    # 配置 udev 规则 (用于队列长度)
    echo -e "SUBSYSTEM==\"net\", ACTION==\"change|add\", KERNEL==\"can*\" ATTR{tx_queue_len}=\"$TX_LEN\"" | sudo tee /etc/udev/rules.d/10-can.rules > /dev/null
    
    # 配置网络文件
    echo -e "[Match]\nName=can*\n\n[CAN]\nBitRate=1M\n\n[Link]\nRequiredForOnline=no" | sudo tee /etc/systemd/network/25-can.network > /dev/null
    
    log "systemd-networkd 配置完成。"
}

# --- 5. 配置方法 B: /etc/network/interfaces (Legacy) ---
setup_interfaces() {
    log "正在使用 /etc/network/interfaces 方式配置..."

    # 清理旧的 interfaces 配置以防冲突
    if [ -f /etc/network/interfaces.d/can0 ]; then
        warn "检测到旧的 /etc/network/interfaces.d/can0 文件，正在重命名备份..."
        sudo mv /etc/network/interfaces.d/can0 /etc/network/interfaces.d/can0.bak
    fi

    log "写入配置到 /etc/network/interfaces.d/can0 ..."

    # 写入配置
    echo -e "allow-hotplug can0\niface can0 can static\n    bitrate 1000000\n    up ip link set can0 txqueuelen $TX_LEN" | sudo tee /etc/network/interfaces.d/can0 > /dev/null

    # 检查写入是否成功
    if grep -q "bitrate 1000000" /etc/network/interfaces.d/can0; then
        log "配置文件写入成功。"
        log "尝试重启网络服务..."
        sudo systemctl restart networking
    else
        error "配置文件写入失败。"
        exit 1
    fi
}

# --- 6. 验证与诊断工具 ---
run_diagnostics() {
    echo -e "\n=============================="
    echo "        连接状态诊断"
    echo "=============================="
    
    # 检查网络接口
    echo -e "${BLUE}[1] 检查网络接口 (ip link):${NC}"
    ip -d -s link show can0 | grep "can" || echo "未找到 can0 接口 (可能需要重启)"

    # 检查 USB 设备
    echo -e "\n${BLUE}[2] 检查 USB CAN 适配器 (lsusb):${NC}"
    lsusb | grep -E "1d50:606f|Can|Geschwister|OpenMoko" || echo "未检测到常见 CAN 适配器，请检查物理连接"

    # 查询 UUID
    echo -e "\n${BLUE}[3] 尝试查询 CANBus UUID (canbus_query.py):${NC}"
    if [ -f ~/klipper/scripts/canbus_query.py ]; then
        ~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0
    else
        warn "未找到 Klipper 脚本，跳过 UUID 查询。"
    fi
}

# === 主程序 ===
clear
echo "=========================================="
echo "   CANBus 智能配置脚本"
echo "=========================================="

check_system
determine_config_method

echo -e "\n=========================================="
log "自动检测结果：采用 [$CONFIG_METHOD] 模式进行配置。"
echo "=========================================="

select_txqueuelen

if [[ "$CONFIG_METHOD" == "modern" ]]; then
    setup_systemd
else
    setup_interfaces
fi

echo "=========================================="
log "配置流程结束。"
read -p "是否现在运行诊断工具(查看UUID等)? (y/N): " diag
[[ "$diag" =~ ^[Yy]$ ]] && run_diagnostics

echo "=========================================="
echo "提示：如果配置未生效，强烈建议重启系统。"
read -p "是否立即重启? (y/N): " reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    sudo reboot
fi