#!/bin/bash

KIOSK_USER=$(logname)

# 更新系统软件源
apt-get update

# 安装所需软件
apt-get install \
    unclutter \
    xorg \
    chromium \
    openbox \
    lightdm \
    locales \
    x11-xserver-utils \
    -y

# 创建 openbox 配置目录
mkdir -p /home/$KIOSK_USER/.config/openbox

# 备份并写入 lightdm 配置文件，实现自动登录
if [ -e "/etc/lightdm/lightdm.conf" ]; then
  mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
fi

cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
xserver-command=X -nocursor -nolisten tcp
autologin-user=$KIOSK_USER
autologin-session=openbox
EOF

# 自动获取触摸设备路径
TOUCH_DEV=$(for dev in /dev/input/event*; do
  name=$(udevadm info --query=all --name=$dev | grep -iE 'touchscreen|touch')
  if [ -n "$name" ]; then
    echo "$dev"
    break
  fi
done)

if [ -z "$TOUCH_DEV" ]; then
  echo "未找到触摸设备，使用默认 /dev/input/event0"
  TOUCH_DEV="/dev/input/event0"
fi

# 设置自动息屏 + 唤醒行为的后台脚本路径
SLEEP_WAKE_SCRIPT="/home/$KIOSK_USER/.config/openbox/screen_wake.sh"

# 创建自动唤醒脚本
cat > "$SLEEP_WAKE_SCRIPT" << EOF
#!/bin/bash

# 息屏时间（秒）
IDLE_SECONDS=60

# 设置 X11 屏幕节能参数
export DISPLAY=:0
xset s \$IDLE_SECONDS
xset +dpms
xset s blank

# 监听触摸唤醒
exec evtest --grab --device=$TOUCH_DEV | while read line; do
  if echo \$line | grep -q "SYN_REPORT"; then
    xset dpms force on
  fi
done
EOF

chmod +x "$SLEEP_WAKE_SCRIPT"

# 创建 autostart 启动项
if [ -e "/home/$KIOSK_USER/.config/openbox/autostart" ]; then
  mv /home/$KIOSK_USER/.config/openbox/autostart /home/$KIOSK_USER/.config/openbox/autostart.backup
fi

cat > /home/$KIOSK_USER/.config/openbox/autostart << EOF
#!/bin/bash

KIOSK_URL="http://127.0.0.1"

# 隐藏鼠标指针
unclutter -idle 0.1 -grab -root &

# 启动自动息屏 + 触摸唤醒脚本
bash "$SLEEP_WAKE_SCRIPT" &


# 启动 Chromium kiosk 模式浏览器
while :
do
  xrandr --auto
  chromium \
    --noerrdialogs \
    --no-memcheck \
    --no-first-run \
    --start-maximized \
    --disable \
    --disable-translate \
    --disable-infobars \
    --disable-suggestions-service \
    --disable-save-password-bubble \
    --disable-session-crashed-bubble \
    --incognito \
    --kiosk $KIOSK_URL
  sleep 5
done &
EOF

chmod +x /home/$KIOSK_USER/.config/openbox/autostart

echo "✅ 配置完成"