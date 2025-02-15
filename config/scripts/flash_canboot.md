########################################################################################################################
# VORON 2.4  350mm  打印机配置文件
#
# 版权所有 (C) 2025  Samuel Wang    Discord: Samuel-0-0#0576    Github: Samuel-0-0    Bilibili: Samuel-0_0
#
# 本文件可以根据GNU GPLv3许可协议进行分发
# This file may be distributed under the terms of the GNU GPLv3 license
#
# 根据你的设置编辑此文件
#
# 目标：katapult固件编译与写入MCU的方法
#

1，进CanBoot文件夹
```
cd ~/katapult
```

2，配置CanBoot固件
```
make menuconfig
```

3，生成CanBoot固件
```
make
```

4，主板进dfu模式后执行
```
sudo dfu-util -d ,0483:df11 -R -a 0 -s 0x8000000:leave -D  ~/katapult/out/canboot.bin
```