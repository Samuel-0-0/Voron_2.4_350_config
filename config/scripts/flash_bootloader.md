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