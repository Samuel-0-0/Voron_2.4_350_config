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
# 文件用途：更新mainsail
################################################################################
# 根据你的设置编辑此文件
################################################################################


wget -q -O ${HOME}/mainsail/mainsail.zip \
    https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip && \
unzip -o ${HOME}/mainsail/mainsail.zip -d ${HOME}/mainsail && \
rm ${HOME}/mainsail/mainsail.zip
