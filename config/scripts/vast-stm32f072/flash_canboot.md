进CanBoot文件夹
```
cd ~/CanBoot
```

配置CanBoot固件
```
make menuconfig
```

生成CanBoot固件
```
make
```

主板进dfu模式后执行
```
sudo dfu-util -d ,0483:df11 -R -a 0 -s 0x8000000:leave -D  ~/CanBoot/out/canboot.bin
```