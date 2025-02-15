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
# 目标：将hex固件转换成bin固件并写入MCU的方法
#

1，使用命令
objdump -h bootloader.hex
查看VMA和LMA，确定偏移量

2，使用命令
objcopy -Iihex -Obinary bootloader.hex bootloader.bin
将hex的文件转换成bin文件

3，短接BOOT0，通电，通电后可以释放短接

4，使用命令
sudo dfu-util -d ,0483:df11 -R -a 0 -s 0x8000000:leave -D bootloader.bin
将bootloader写入MCU

5，短接RESET或者断电后再次通电