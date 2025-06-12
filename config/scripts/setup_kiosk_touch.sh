#!/bin/bash

# === 设置参数 ===
URL="http://127.0.0.1"  # ← 替换为你自己的网页地址
IDLE_TIMEOUT_MS=300000      # 空闲熄屏时间，默认 5 分钟
BACKLIGHT="/sys/class/backlight/intel_backlight"
USER_NAME=$(logname)
TOUCH_DEV=""

echo "[1/6] 安装必要组件..."
sudo apt update
sudo apt install -y --no-install-recommends \
    xserver-xorg xinit x11-xserver-utils \
    matchbox-window-manager \
    chromium chromium-common \
    unclutter onboard \
    xinput xprintidle evtest

echo "[2/6] 设置 .xinitrc 启动配置..."
cat <<EOF > /home/$USER_NAME/.xinitrc
#!/bin/bash
onboard &
unclutter &
matchbox-window-manager &
chromium --noerrdialogs --kiosk --incognito $URL
EOF
chmod +x /home/$USER_NAME/.xinitrc
chown $USER_NAME:$USER_NAME /home/$USER_NAME/.xinitrc

echo "[3/6] 配置自动 startx"
BASH_PROFILE="/home/$USER_NAME/.bash_profile"
grep startx $BASH_PROFILE >/dev/null || echo '
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    startx
fi' >> $BASH_PROFILE

# === 安装后台守护服务 ===

echo "[4/6] 创建屏幕熄灭脚本..."
sudo tee /usr/local/bin/screen_idle_watch.sh > /dev/null <<EOF
#!/bin/bash
while true; do
    IDLE=\$(xprintidle)
    if [ "\$IDLE" -gt $IDLE_TIMEOUT_MS ]; then
        echo 4 | sudo tee $BACKLIGHT/bl_power > /dev/null
    fi
    sleep 5
done
EOF
sudo chmod +x /usr/local/bin/screen_idle_watch.sh

echo "[5/6] 创建 screen-idle.service..."
sudo tee /etc/systemd/system/screen-idle.service > /dev/null <<EOF
[Unit]
Description=Screen Idle Monitor

[Service]
ExecStart=/usr/local/bin/screen_idle_watch.sh
Restart=always
User=$USER_NAME

[Install]
WantedBy=multi-user.target
EOF

echo "[6/6] 查找触摸屏设备..."
TOUCH_DEV=$(grep -i -l "touchscreen" /proc/bus/input/devices | grep -o "event[0-9]*" | head -n 1)
if [ -z "$TOUCH_DEV" ]; then
    echo "⚠️ 未自动找到触摸屏设备，请手动编辑 /usr/local/bin/screen_wakeup.sh"
    TOUCH_DEV="/dev/input/eventX"
else
    TOUCH_DEV="/dev/input/$TOUCH_DEV"
    echo "✅ 触摸屏设备为 $TOUCH_DEV"
fi

echo "创建 screen_wakeup.sh..."
sudo tee /usr/local/bin/screen_wakeup.sh > /dev/null <<EOF
#!/bin/bash
evtest --grab $TOUCH_DEV | while read line; do
    echo 0 | sudo tee $BACKLIGHT/bl_power > /dev/null
done
EOF
sudo chmod +x /usr/local/bin/screen_wakeup.sh

echo "创建 screen-wakeup.service..."
sudo tee /etc/systemd/system/screen-wakeup.service > /dev/null <<EOF
[Unit]
Description=Screen Wake on Touch

[Service]
ExecStart=/usr/local/bin/screen_wakeup.sh
Restart=always
User=$USER_NAME

[Install]
WantedBy=multi-user.target
EOF

# 添加免密 sudo 权限
echo "配置 sudo 免密权限..."
CMD="tee $BACKLIGHT/bl_power"
( sudo grep -q "$CMD" /etc/sudoers ) || echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/tee $BACKLIGHT/bl_power" | sudo tee -a /etc/sudoers

echo "配置自动登录用户: $USER_NAME"
# 创建 override 目录
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
# 写入 override 文件
cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF

# 启用服务
echo "启用服务..."
sudo systemctl daemon-reexec
sudo systemctl enable screen-idle.service screen-wakeup.service
sudo systemctl start screen-idle.service screen-wakeup.service

echo "✅ 安装完成，请重启设备验证效果。"
