# LazyFirmware - A Moonraker Component for Klipper Firmware Updates
import logging
import asyncio
import os
import configparser
import shutil

# Moonraker 提供的工具
from moonraker.utils import source_info

class LazyFirmware:
    def __init__(self, config):
        self.server = config.get_server()
        self.name = config.get_name()

        # 1. 从 moonraker.conf 读取配置，支持 ~ 路径展开
        self.fw_config_path = config.get_expanded_path(
            "config_path", "~/printer_data/config/lazyfirmware/config.cfg"
        )
        self.klipper_path = config.get_expanded_path("klipper_path", "~/klipper")
        self.katapult_path = config.get_expanded_path("katapult_path", "~/katapult")
        
        # 2. 定义并发锁，防止多次点击更新
        self.update_lock = asyncio.Lock()
        
        # 3. 注册 API 端点
        self.server.register_endpoint(
            "/machine/lazyfirmware/config", ['GET'], self._handle_get_config
        )
        self.server.register_endpoint(
            "/machine/lazyfirmware/config", ['POST'], self._handle_set_config
        )
        self.server.register_endpoint(
            "/machine/lazyfirmware/update", ['POST'], self._handle_update
        )

    # 4. 生命周期：component_init 用于初始化需要与其他组件交互的逻辑
    async def component_init(self):
        # 获取 machine 组件用于控制系统服务 (systemd)
        self.machine = self.server.lookup_component("machine")
        logging.info(f"[{self.name}] Component Initialized")

    # --- 辅助方法：在独立线程中处理阻塞的文件IO ---
    
    def _read_config_sync(self):
        cfg = configparser.ConfigParser()
        # 保持原有大小写敏感，避免 key 变小写
        cfg.optionxform = str 
        if os.path.exists(self.fw_config_path):
            cfg.read(self.fw_config_path)
        return {s: dict(cfg.items(s)) for s in cfg.sections()}

    def _write_config_sync(self, data):
        cfg = configparser.ConfigParser()
        cfg.optionxform = str
        for section, params in data.items():
            cfg.add_section(section)
            for key, value in params.items():
                cfg.set(section, key, str(value))
        
        # 确保目录存在
        os.makedirs(os.path.dirname(self.fw_config_path), exist_ok=True)
        with open(self.fw_config_path, 'w') as f:
            cfg.write(f)

    # --- API 处理函数 ---

    async def _handle_get_config(self, web_request):
        # 将阻塞的读操作放入 executor
        event_loop = self.server.get_event_loop()
        data = await event_loop.run_in_executor(None, self._read_config_sync)
        return data

    async def _handle_set_config(self, web_request):
        new_config = await web_request.json()
        event_loop = self.server.get_event_loop()
        await event_loop.run_in_executor(None, self._write_config_sync, new_config)
        return "Configuration Saved"

    async def _handle_update(self, web_request):
        # 如果正在更新，拒绝新请求
        if self.update_lock.locked():
            raise self.server.error("Update already in progress")

        params = await web_request.json()
        target_section = params.get("section", None)
        
        # 启动后台任务
        self.server.get_event_loop().create_task(self._run_update_process(target_section))
        return "Update task started. Check logs."

    # --- 核心更新逻辑 ---

    async def _exec_shell(self, cmd, cwd=None, timeout=None):
        """执行 Shell 命令并捕获输出"""
        cwd = cwd if cwd else self.klipper_path
        logging.info(f"[{self.name}] Executing: {cmd}")
        
        proc = await asyncio.create_subprocess_shell(
            cmd,
            cwd=cwd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        try:
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        except asyncio.TimeoutError:
            proc.kill()
            raise Exception(f"Command timed out: {cmd}")

        if proc.returncode != 0:
            err_msg = stderr.decode().strip()
            logging.error(f"[{self.name}] Command Failed: {err_msg}")
            raise Exception(f"Command failed ({proc.returncode}): {err_msg}")
        
        return stdout.decode().strip()

    async def _run_update_process(self, target_section=None):
        async with self.update_lock:
            try:
                logging.info(f"[{self.name}] Starting update process...")
                self._notify_progress("Stopping Klipper...")
                
                # 1. 停止 Klipper
                # 注意：stop_service 是异步的，不需要 await wait_for
                try:
                    await self.machine.stop_service("klipper")
                except Exception as e:
                    logging.warning(f"Could not stop klipper (maybe already stopped): {e}")

                # 2. 读取配置 (在 executor 中)
                config_data = await self.server.get_event_loop().run_in_executor(None, self._read_config_sync)
                
                sections = [target_section] if target_section else [s for s in config_data.keys() if s != 'global']

                # 3. 检查 Katapult (Git Clone/Pull) - 简化处理，假设已存在或只需简单更新
                if not os.path.exists(self.katapult_path):
                     self._notify_progress("Cloning Katapult...")
                     await self._exec_shell(f"git clone https://github.com/Arksine/katapult.git {self.katapult_path}", cwd=os.path.expanduser("~"))

                # 4. 循环处理每个 MCU
                for section in sections:
                    if section not in config_data or section == 'global': continue
                    
                    params = config_data[section]
                    fw_id = params.get("ID")
                    mode = params.get("MODE")
                    cfg_file = params.get("CONFIG")
                    katapult_serial = params.get("KATAPULT_SERIAL", "")
                    
                    self._notify_progress(f"Processing {section}...")

                    # 4.1 准备 .config
                    src_cfg = os.path.expanduser(cfg_file)
                    dst_cfg = os.path.join(self.klipper_path, ".config")
                    if not os.path.exists(src_cfg):
                        raise Exception(f"Config file not found: {src_cfg}")
                    shutil.copy(src_cfg, dst_cfg)

                    # 4.2 编译
                    self._notify_progress(f"Compiling for {section}...")
                    await self._exec_shell("make clean")
                    await self._exec_shell("make olddefconfig")
                    await self._exec_shell("make")

                    # 4.3 刷写
                    self._notify_progress(f"Flashing {section} ({mode})...")
                    
                    # 映射 Bash 脚本中的 Case 逻辑
                    flash_cmd = ""
                    if mode == "CAN":
                        flash_cmd = f"python3 {self.katapult_path}/scripts/flashtool.py -i can0 -f {self.klipper_path}/out/klipper.bin -u {fw_id}"
                    
                    elif mode == "CAN_BRIDGE_DFU":
                        # 进入 Bootloader
                        await self._exec_shell(f"python3 {self.katapult_path}/scripts/flashtool.py -i can0 -u {fw_id} -r")
                        await asyncio.sleep(5) # 等待设备切换
                        flash_cmd = "make flash FLASH_DEVICE=0483:df11"
                        
                    elif mode == "CAN_BRIDGE_KATAPULT":
                        await self._exec_shell(f"python3 {self.katapult_path}/scripts/flashtool.py -i can0 -u {fw_id} -r")
                        await asyncio.sleep(5)
                        flash_cmd = f"make flash FLASH_DEVICE={katapult_serial}"
                        
                    elif mode == "USB_DFU":
                        flash_cmd = f"make flash FLASH_DEVICE={fw_id}"
                        
                    elif mode == "USB_KATAPULT":
                        await self._exec_shell(f"python3 {self.katapult_path}/scripts/flashtool.py -d {fw_id} -r")
                        await asyncio.sleep(2)
                        flash_cmd = f"python3 {self.katapult_path}/scripts/flashtool.py -f {self.klipper_path}/out/klipper.bin -d {katapult_serial}"
                        
                    elif mode == "HOST":
                        flash_cmd = "make flash"

                    if flash_cmd:
                        await self._exec_shell(flash_cmd)
                    else:
                        logging.warning(f"Unknown mode: {mode} for {section}")

                    self._notify_progress(f"{section} Updated Successfully")

                # 5. 重启 Klipper
                self._notify_progress("Restarting Klipper...")
                await self.machine.start_service("klipper")
                self._notify_progress("All Done!")

            except Exception as e:
                logging.error(f"LazyFirmware Update Error: {e}")
                self._notify_progress(f"Error: {str(e)}")
                # 尝试恢复服务
                await self.machine.start_service("klipper")

    def _notify_progress(self, message):
        """发送 Websocket 消息给前端 (可选)"""
        logging.info(f"LazyFirmware: {message}")
        # Moonraker 可以通过 server.send_event 发送自定义通知
        # 前端需要监听 'lazyfirmware:progress'
        self.server.send_event("lazyfirmware:progress", {"message": message})

# 插件入口
def load_component(config):
    return LazyFirmware(config)