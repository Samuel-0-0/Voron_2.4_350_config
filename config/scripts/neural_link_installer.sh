#!/bin/bash

# 1. 自动获取当前用户名和路径
USER=$(whoami)
PRINTER_SCRIPTS="/home/$USER/printer_data/config/scripts"
HTML_NAME="neural_link.html"
PY_NAME="neural_link.py"

# 2. 自动获取本机局域网 IP
HOST_IP=$(hostname -I | awk '{print $1}')

if [ -z "$HOST_IP" ]; then
    echo "▶ 无法检测到设备 IP，请检查网络连接。"
    exit 1
fi

echo "探测到本机 IP: $HOST_IP"

# 3. 探测 Web 目录
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

# 4. 创建目录并下载文件
mkdir -p "$PRINTER_SCRIPTS"

echo "▶ 正在下载后端脚本 (neural_link.py)..."
curl -s -L -o "$PRINTER_SCRIPTS/$PY_NAME" https://raw.githubusercontent.com/Samuel-0-0/Voron_2.4_350_config/main/config/scripts/neural_link.py

echo "▶ 正在下载前端页面 (neural_link.html)..."
curl -s -L -o "$WEB_PATH/$HTML_NAME" https://raw.githubusercontent.com/Samuel-0-0/Voron_2.4_350_config/main/config/scripts/neural_link.html

# 5. 修改默认 IP
sed -i "s/value=\"192.168.88.20\"/value=\"$HOST_IP\"/g" "$WEB_PATH/$HTML_NAME"

# 6. 后台启动服务
echo "▶ 正在启动诊断服务..."
chmod +x "$PRINTER_SCRIPTS/$PY_NAME"
pkill -f "$PY_NAME" > /dev/null 2>&1

nohup python3 "$PRINTER_SCRIPTS/$PY_NAME" > /tmp/neural_link.log 2>&1 &

# 7. 最终提醒
echo "===================================================="
echo "▶ 部署成功！"
echo "▶ 请访问: http://$HOST_IP/$HTML_NAME"
echo "▶ 如果网页图标仍是方框，请刷新浏览器缓存 (Ctrl+F5)"
echo "===================================================="