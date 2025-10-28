# armbian_a311d2
# XF.A311D2 定制 Armbian 系统

基于 Armbian 官方 Khadas VIM4 配置，为 XF.A311D2 主板定制的 Debian 12 系统。

## 特性

- ✅ 基于 Armbian 官方构建系统
- ✅ Debian 12 (Bookworm)
- ✅ XFCE 桌面环境
- ✅ 完整的有线/无线网络支持
- ✅ 蓝牙支持
- ✅ Mali GPU 硬件加速
- ✅ USB 网卡自动识别
- ✅ PVE 虚拟化环境
- ✅ 定期自动构建

## 构建方法

### 自动构建（推荐）
1. Fork 本仓库
2. 在 GitHub Actions 中启用 workflows
3. 推送到 main 分支触发自动构建
4. 在 Actions 页面下载构建好的镜像

### 手动构建
```bash
git clone --recursive https://github.com/yourusername/armbian-a311d2-custom
cd armbian-a311d2-custom
./build.sh


###  刷写镜像

# 查看设备
lsblk

# 刷写镜像到 SD 卡或 eMMC
sudo dd if=Armbian_*.img of=/dev/sdX bs=1M status=progress

# 或者使用 balenaEtcher 图形工具
首次启动配置
插入刷写好的存储设备启动

默认用户名: armbian，密码: 1234

首次登录会提示修改密码

系统会自动扩展文件系统并配置网络

网络配置
无线网络
bash
# 扫描网络
nmcli dev wifi

# 连接网络
nmcli dev wifi connect "SSID" password "password"

# 图形界面：使用 NetworkManager applet
USB 网络设备
系统会自动识别大多数 USB 网卡，无需额外配置。

PVE 虚拟化
系统已预装 QEMU/KVM，可以运行 ARM 虚拟机：


# 查看虚拟化状态
virt-host-validate

# 创建虚拟机示例
sudo virt-install --name test-vm --memory 1024 --disk size=5 --cdrom /path/to/iso
故障排除
无线网络问题
bash
# 重新加载无线驱动
sudo modprobe -r brcmfmac && sudo modprobe brcmfmac

# 查看无线设备
iwconfig
显示问题
bash
# 检查 GPU 状态
glxinfo | grep renderer

# 重启显示管理器
sudo systemctl restart lightdm
贡献
欢迎提交 Issue 和 Pull Request 来改进这个项目。

text

## 7. 构建脚本

### build.sh
```bash
#!/bin/bash

set -e

echo "=== XF.A311D2 Armbian 构建脚本 ==="

# 克隆 Armbian 构建系统
if [ ! -d "build" ]; then
    echo "克隆 Armbian 构建系统..."
    git clone https://github.com/armbian/build.git
    cd build
    git checkout master
    cd ..
fi

# 复制配置文件
echo "复制配置文件..."
cp -r config/* build/config/
cp -r patches/* build/patches/
cp -r scripts/* build/userpatches/

# 进入构建目录
cd build

# 安装依赖
echo "安装构建依赖..."
./compile.sh prerequisites

# 开始构建
echo "开始构建系统..."
./compile.sh \
    BOARD=xf-a311d2 \
    BRANCH=edge \
    RELEASE=bookworm \
    BUILD_DESKTOP=yes \
    DESKTOP_ENVIRONMENT=xfce \
    DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base \
    KERNEL_CONFIGURE=yes \
    BUILD_MINIMAL=no \
    EXPERT=yes

echo "构建完成！镜像位于: build/output/images/"
