import subprocess
import sys
import os

# --- 依赖项自动审计与静默安装模块 ---
required_packages = {
    "fastapi": "fastapi",
    "uvicorn": "uvicorn",
    "psutil": "psutil"
}

def check_and_install_dependencies():
    print("正在扫描系统环境...")
    for import_name, install_name in required_packages.items():
        try:
            __import__(import_name)
        except ImportError:
            print(f"发现缺失核心插件: {install_name}，准备自动部署...")
            try:
                # 使用 sys.executable 确保安装到当前运行环境
                subprocess.check_call([sys.executable, "-m", "pip", "install", install_name])
                print(f"{install_name} 部署成功。")
            except subprocess.CalledProcessError as e:
                print("\n" + "!"*50)
                print(f"严重错误: 插件 [{install_name}] 安装失败！")
                print(f"原因: 进程返回非零退出代码 {e.returncode}")
                print("-" * 50)
                print("请尝试手动执行以下操作:")
                print(f"  pip install {install_name}")
                print("!"*50 + "\n")
                sys.exit(1)
            except Exception as e:
                print(f"发生未知异常: {str(e)}")
                sys.exit(1)

# 执行审计逻辑
check_and_install_dependencies()
# -----------------------------------

import asyncio
import json
import re
import glob
import psutil
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"])

class GitManager:
    @staticmethod
    def get_versions():
        def get_commit(path):
            try:
                p = os.path.expanduser(path)
                return subprocess.check_output(["git", "rev-parse", "--short=7", "HEAD"], cwd=p).decode().strip()
            except: return "unknown"
        k = f"Klipper:{get_commit('~/klipper')}"
        m = f"Moonraker:{get_commit('~/moonraker')}"
        ms_ver = "Mainsail:unknown"
        ms_path = os.path.expanduser('~/mainsail/.version')
        if os.path.exists(ms_path):
            try:
                with open(ms_path, 'r') as f: ms_ver = f"Mainsail:{f.readline().strip()}"
            except: pass
        return f"{k},{m},{ms_ver}"

    @staticmethod
    async def run_backup(websocket, config_path, commit_msg, max_retries=10):
        path = os.path.expanduser(config_path)
        ver_info = GitManager.get_versions()
        
        async def send_log(msg):
            await websocket.send_json({"type": "git_log", "data": msg})

        try:
            # 1. Pull
            await send_log("开始拉取远程仓库更新...")
            for i in range(max_retries):
                try:
                    subprocess.check_call(["git", "pull", "-v"], cwd=path, timeout=60)
                    break
                except:
                    if i == max_retries - 1: raise Exception("Git Pull 达到最大重试次数，操作终止")
                    await send_log(f"拉取失败，准备第 {i+2} 次尝试...")

            # 2. Add & Commit
            await send_log("扫描并合并本地更改...")
            subprocess.check_call(["git", "add", "."], cwd=path)
            changes = subprocess.check_output(["git", "status", "--porcelain"], cwd=path).decode().strip()
            if changes:
                full_msg = f"{commit_msg} [{ver_info}]"
                subprocess.check_call(["git", "commit", "-m", full_msg], cwd=path)
                await send_log(f"本地提交完成: {full_msg}")
            else:
                await send_log("检测到本地无任何更改，跳过提交")

            # 3. Push
            await send_log("正在推送到 GitHub 远程仓库...")
            for i in range(max_retries):
                try:
                    subprocess.check_call(["git", "push"], cwd=path, timeout=60)
                    await send_log("✅ 备份任务执行成功！")
                    break
                except:
                    if i == max_retries - 1: raise Exception("Git Push 失败，请检查 SSH Key 或网络")
                    await send_log(f"推送失败，准备第 {i+2} 次尝试...")
        except Exception as e:
            await send_log(f"❌ 错误: {str(e)}")

class DiagnosticTool:
    @staticmethod
    def run_cmd(cmd, sudo_pwd=None):
        try:
            if sudo_pwd:
                full_cmd = f"echo '{sudo_pwd}' | sudo -S {cmd}"
                return subprocess.check_output(full_cmd, shell=True, stderr=subprocess.STDOUT).decode().strip()
            return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode().strip()
        except subprocess.CalledProcessError as e:
            return f"失败: {e.output.decode().strip() if e.output else str(e)}"
        except Exception as e:
            return f"异常: {str(e)}"

    @staticmethod
    def read_sys_file(path):
        if os.path.exists(path):
            try:
                with open(path, "r") as f:
                    return f.read().strip()
            except: return ""
        return ""

    @staticmethod
    def get_detailed_cpu():
        model = DiagnosticTool.run_cmd("grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \\t]*//'")
        if not model:
            model = DiagnosticTool.run_cmd("grep -m1 'Model' /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \\t]*//'")
        
        core_count = psutil.cpu_count()
        per_cpu_usage = psutil.cpu_percent(interval=0.1, percpu=True)
        
        # 跨架构大小核审计 (Intel/AMD/ARM)
        core_scores = []
        for i in range(core_count):
            score = 0
            try:
                # 尝试读取频率和计算能力
                freq = DiagnosticTool.read_sys_file(f"/sys/devices/system/cpu/cpu{i}/cpufreq/cpuinfo_max_freq")
                score = int(freq) if freq else 1000
                cap = DiagnosticTool.read_sys_file(f"/sys/devices/system/cpu/cpu{i}/cpu_capacity")
                if cap: score += int(cap) * 1000
            except: pass
            core_scores.append(score)

        max_s = max(core_scores) if core_scores else 1
        min_s = min(core_scores) if core_scores else 1
        is_hybrid = (max_s / min_s) > 1.1 if min_s > 0 else False
        
        if is_hybrid:
            big_cores = [i for i, s in enumerate(core_scores) if s >= max_s * 0.95]
        else:
            big_cores = list(range(0, max(1, core_count // 2)))
        
        little_cores = [i for i in range(core_count) if i not in big_cores]

        svc_config = {"affinity": "未设置", "nice": "未设置", "is_optimized": False}
        klipper_svc = "/etc/systemd/system/klipper.service"
        if os.path.exists(klipper_svc):
            content = DiagnosticTool.read_sys_file(klipper_svc)
            aff_m = re.search(r"^CPUAffinity=(.+)", content, re.M)
            nice_m = re.search(r"^Nice=(.+)", content, re.M)
            if aff_m: svc_config["affinity"] = aff_m.group(1).strip()
            if nice_m: svc_config["nice"] = nice_m.group(1).strip()
            if aff_m and nice_m: svc_config["is_optimized"] = True

        return {
            "model": model or "Unknown Processor",
            "cores": core_count,
            "usage": per_cpu_usage,
            "big_cores": big_cores,
            "config": svc_config,
            "recommend": {"klipper": " ".join(map(str, big_cores)), "other": " ".join(map(str, little_cores))},
            "strategy": "Heterogeneous (异构)" if is_hybrid else "Homogeneous (对称)"
        }

    @staticmethod
    def get_emmc_health():
        dev_list = DiagnosticTool.run_cmd("ls /sys/block/ | grep mmcblk[0-9]$").split()
        dev = dev_list[0] if dev_list else "mmcblk0"
        life_raw = DiagnosticTool.read_sys_file(f"/sys/block/{dev}/device/life_time").split()
        mlc_hex = int(life_raw[0], 16) if life_raw else 0
        mlc_pct = (11 - mlc_hex) * 10 if 0 < mlc_hex <= 10 else (0 if mlc_hex > 10 else 100)
        return {"device": dev, "mlc": mlc_pct, "msg": "寿命充足" if mlc_pct > 30 else "建议更换"}

    @staticmethod
    def get_usb_analysis():
        nodes = []
        for dev_path in glob.glob("/sys/bus/usb/devices/[0-9]*-*"):
            name = os.path.basename(dev_path)
            if not re.match(r"^[0-9]+-[0-9]+(\.[0-9]+)*$", name): continue
            try:
                is_hub = DiagnosticTool.read_sys_file(f"{dev_path}/bDeviceClass") == "09"
                product = DiagnosticTool.read_sys_file(f"{dev_path}/product") or ("USB Hub" if is_hub else "Unknown Device")
                mfg = DiagnosticTool.read_sys_file(f"{dev_path}/manufacturer")
                serial = DiagnosticTool.read_sys_file(f"{dev_path}/serial") or "N/A"
                vid = DiagnosticTool.read_sys_file(f"{dev_path}/idVendor")
                pid = DiagnosticTool.read_sys_file(f"{dev_path}/idProduct")

                tags = []
                full_desc = f"{mfg} {product}".lower()

                if "klipper" in full_desc:
                    tags.append("KLIPPER")
                if any(x in full_desc for x in ["katapult", "canboot"]):
                    tags.append("KATAPULT")
                # 通过硬件 ID 精确匹配 CAN 适配器 (1d50:606f)
                if vid == "1d50" and pid == "606f":
                    tags.append("CAN_ADAPTER")
                # 通过硬件 ID 精确匹配 MCU处于DFU (0483:df11)
                if vid == "0483" and pid == "df11":
                    tags.append("DFU")

                depth = name.count('.') + 1
                pid = name.rsplit('.', 1)[0] if '.' in name else name.split('-')[0] + "-0"
                nodes.append({"id": name, "pid": pid, "type": "HUB" if is_hub else "设备", "name": product, "fw": tags, "serial": serial, "score": max(0, 100-(depth-1)*10)})
            except: continue
        return {"nodes": nodes}

    @staticmethod
    def get_can_status():
        is_modern = DiagnosticTool.run_cmd("systemctl is-active networkd-dispatcher.service").strip() == "active"
        if_info = DiagnosticTool.run_cmd("ip -br link show | grep can || echo '无激活接口'")
        return {
            "mode": "Modern (systemd)" if is_modern else "Legacy (ifupdown)",
            "interfaces": if_info,
            "kernel_can": "已加载" if "can" in DiagnosticTool.run_cmd("lsmod | grep can") else "未加载"
        }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    while True:
        try:
            data = await websocket.receive_text()
            req = json.loads(data)
            action = req.get("action")
            params = req.get("params", {})
            if action == "cpu": await websocket.send_json({"type": "cpu", "data": DiagnosticTool.get_detailed_cpu()})
            elif action == "emmc": await websocket.send_json({"type": "emmc", "data": DiagnosticTool.get_emmc_health()})
            elif action == "usb": await websocket.send_json({"type": "usb", "data": DiagnosticTool.get_usb_analysis()})
            elif action == "can_status": await websocket.send_json({"type": "can_status", "data": DiagnosticTool.get_can_status()})
            elif action == "can_apply":
                pwd = params.get("pwd")
                ifname, br, tx = params.get("ifname"), params.get("bitrate"), params.get("txlen")
                is_modern = DiagnosticTool.run_cmd("systemctl is-active networkd-dispatcher.service").strip() == "active"
                logs = []
                
                # 1. 写入配置
                if is_modern:
                    net_cfg = f"[Match]\\nName={ifname}\\n\\n[CAN]\\nBitRate={br}\\n\\n[Link]\\nRequiredForOnline=no"
                    udev_cfg = f"SUBSYSTEM==\\\"net\\\", ACTION==\\\"change|add\\\", KERNEL==\\\"{ifname}\\\" ATTR{{tx_queue_len}}=\\\"{tx}\\\""
                    r1 = DiagnosticTool.run_cmd(f"echo -e '{net_cfg}' | tee /etc/systemd/network/25-can.network", pwd)
                    r2 = DiagnosticTool.run_cmd(f"echo -e '{udev_cfg}' | tee /etc/udev/rules.d/10-can.rules", pwd)
                    logs.append(f"Network配置: {r1}\nUdev配置: {r2}")
                else:
                    int_cfg = f"allow-hotplug {ifname}\\niface {ifname} can static\\n    bitrate {br}\\n    up ip link set {ifname} txqueuelen {tx}"
                    r = DiagnosticTool.run_cmd(f"echo -e '{int_cfg}' | tee /etc/network/interfaces.d/{ifname}", pwd)
                    logs.append(f"Interfaces配置:\n{r}")
                
                # 2. 检查是否有错误发生
                success = all("ERROR" not in log and "EXCEPTION" not in log for log in logs)
                final_status = "✅ 所有配置已成功写入系统文件。" if success else "❌ 配置过程中出现错误，请检查权限或密码。"
                logs.append(final_status)
                
                await websocket.send_json({"type": "can_log", "data": "\n".join(logs)})
            elif action == "can_restart":
                pwd = params.get("pwd")
                r1 = DiagnosticTool.run_cmd("systemctl restart systemd-networkd", pwd)
                r2 = DiagnosticTool.run_cmd("systemctl restart networking", pwd)
                await websocket.send_json({"type": "can_log", "data": f"重启指令执行结果:\n{r1}\n{r2}"})
            elif action == "git_backup": 
                await GitManager.run_backup(websocket, "~/printer_data", params.get("msg", "Web Auto Backup"))
        except: break

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=1111)