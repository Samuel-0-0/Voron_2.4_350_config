#!/bin/bash

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# 1. 自动获取当前用户名和路径
USER=$(whoami)
PRINTER_SCRIPTS="/home/$USER/printer_data/config/scripts"
HTML_NAME="neural_link.html"
PY_NAME="neural_link.py"

# 2. 依赖环境检查与安装 (优化：先检查后安装)
echo "▶ 正在检查 Python 依赖库..."

# 定义需要检查的依赖列表
DEPENDENCIES=("fastapi" "uvicorn" "psutil" "websockets")

for pkg in "${DEPENDENCIES[@]}"; do
    # 尝试导入库来验证其在当前 python3 环境中是否真正可用
    if python3 -c "import $pkg" > /dev/null 2>&1; then
        echo "  $pkg 已就绪。"
    else
        echo "  $pkg 不可用，正在尝试安装..."
        # 强制安装到当前用户环境，并确保安装 uvicorn[standard]
        if [ "$pkg" == "uvicorn" ] || [ "$pkg" == "websockets" ]; then
            python3 -m pip install --user "uvicorn[standard]" websockets
        else
            python3 -m pip install --user "$pkg"
        fi
    fi
done

# 3. 自动获取本机局域网 IP
HOST_IP=$(hostname -I | awk '{print $1}')

if [ -z "$HOST_IP" ]; then
    echo "▶ 无法检测到设备 IP，请检查网络连接。"
    exit 1
fi

echo "探测到本机 IP: $HOST_IP"

# 4. 探测 Web 目录
if [ -d "/home/$USER/mainsail" ]; then
    WEB_PATH="/home/$USER/mainsail"
elif [ -d "/home/$USER/fluidd" ]; then
    WEB_PATH="/home/$USER/fluidd"
else
    WEB_PATH="/var/www/html"
fi

if [ ! -d "$WEB_PATH" ]; then
    echo "▶ 未找到 Web 根目录。"
    exit 1
fi

echo "▶ Web 路径: $WEB_PATH"
echo "▶ 脚本路径: $PRINTER_SCRIPTS"

# 5. 创建目录并下载文件
mkdir -p "$PRINTER_SCRIPTS"

echo "▶ 正在下载后端脚本 (neural_link.py)..."
curl -s -L -o "$PRINTER_SCRIPTS/$PY_NAME" https://raw.githubusercontent.com/Samuel-0-0/Voron_2.4_350_config/main/config/scripts/neural_link.py

echo "▶ 正在下载前端页面 (neural_link.html)..."
curl -s -L -o "$WEB_PATH/$HTML_NAME" https://raw.githubusercontent.com/Samuel-0-0/Voron_2.4_350_config/main/config/scripts/neural_link.html

# 6. 修改 HTML 中的默认 IP 为本机探测到的 IP
sed -i "s/value=\"192.168.88.20\"/value=\"$HOST_IP\"/g" "$WEB_PATH/$HTML_NAME"

# 7. 后台启动服务
echo "▶ 正在启动诊断服务..."
chmod +x "$PRINTER_SCRIPTS/$PY_NAME"
# 杀掉旧进程
pkill -f "$PY_NAME" > /dev/null 2>&1

# 使用 nohup 后台运行并确保进程在 Shell 退出后不中断
nohup python3 "$PRINTER_SCRIPTS/$PY_NAME" > /tmp/neural_link.log 2>&1 &

# 8. 最终提醒
echo "===================================================="
echo "▶ 部署成功！"
echo "▶ 请访问: http://$HOST_IP/$HTML_NAME"
echo "▶ 日志查看: tail -f /tmp/neural_link.log"
echo "===================================================="