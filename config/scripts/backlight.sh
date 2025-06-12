#!/bin/bash
# 设置屏幕背光

#1.创建 udev 规则文件：
#sudo nano /etc/udev/rules.d/99-backlight.rules

#2.添加规则：
#SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
#SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
#SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chgrp video /sys/class/backlight/%k/bl_power"
#SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chmod g+w /sys/class/backlight/%k/bl_power"

#3.重载规则并重启服务：
#sudo udevadm control --reload
#sudo systemctl restart systemd-udevd

#4.将用户加入 video 组：
#sudo usermod -aG video $USER

#5.重启系统

# 执行命令 ls /sys/class/backlight/ 获取背光器
BL_PATH="/sys/class/backlight/intel_backlight"

echo "$1"

if [ -d "$BL_PATH" ]; then
    if [ $1 == 0 ]; then
        echo "$1" > "$BL_PATH/brightness"
        echo 1 > "$BL_PATH/bl_power"
    else
        echo 0 > "$BL_PATH/bl_power"
        echo "$1" > "$BL_PATH/brightness"
    fi
fi