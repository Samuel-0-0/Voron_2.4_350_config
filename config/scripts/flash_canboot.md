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