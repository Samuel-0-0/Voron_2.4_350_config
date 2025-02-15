#!/bin/bash

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
# 目标：检测并告知EMMC预期寿命
#


# 遍历所有的 mmcblk 设备
devices=$(ls /sys/block/ | grep mmcblk | grep -o "^mmcblk[0-9]*$")
for device in $devices; do
  if [[ $device =~ ^mmcblk[0-9]+$ ]]; then
      echo "磁盘ID：$device"
      result=$(cat /sys/block/${device}/device/life_time)
      # 提取 MLC 用户分区和 SLC 引导分区的值
      mlc_value=$(echo $result | awk '{print $1}')
      slc_value=$(echo $result | awk '{print $2}')
      
      # 计算并输出预期寿命
      case $mlc_value in
          "0x00") echo "MLC用户分区预期寿命：未定义" ;;
          "0x01") echo "MLC用户分区预期寿命：90%-100%" ;;
          "0x02") echo "MLC用户分区预期寿命：80%-90%" ;;
          "0x03") echo "MLC用户分区预期寿命：70%-80%" ;;
          "0x04") echo "MLC用户分区预期寿命：60%-70%" ;;
          "0x05") echo "MLC用户分区预期寿命：50%-60%" ;;
          "0x06") echo "MLC用户分区预期寿命：40%-50%" ;;
          "0x07") echo "MLC用户分区预期寿命：30%-40%" ;;
          "0x08") echo "MLC用户分区预期寿命：20%-30%" ;;
          "0x09") echo "MLC用户分区预期寿命：10%-20%" ;;
          "0x0A"|"0x0a") echo "MLC用户分区预期寿命：0%-10%" ;;
          "0x0B"|"0x0b") echo "MLC用户分区已超过最大预期寿命" ;;
          *) echo "未知的MLC用户分区值" ;;
      esac
      
      case $slc_value in
          "0x00") echo "SLC引导分区预期寿命：未定义" ;;
          "0x01") echo "SLC引导分区预期寿命：90%-100%" ;;
          "0x02") echo "SLC引导分区预期寿命：80%-90%" ;;
          "0x03") echo "SLC引导分区预期寿命：70%-80%" ;;
          "0x04") echo "SLC引导分区预期寿命：60%-70%" ;;
          "0x05") echo "SLC引导分区预期寿命：50%-60%" ;;
          "0x06") echo "SLC引导分区预期寿命：40%-50%" ;;
          "0x07") echo "SLC引导分区预期寿命：30%-40%" ;;
          "0x08") echo "SLC引导分区预期寿命：20%-30%" ;;
          "0x09") echo "SLC引导分区预期寿命：10%-20%" ;;
          "0x0A"|"0x0a") echo "SLC引导分区预期寿命：0%-10%" ;;
          "0x0B"|"0x0b") echo "SLC引导分区已超过最大预期寿命" ;;
          *) echo "未知的SLC引导分区值" ;;
      esac
  else
      echo "没有eMMC"
  fi
done
