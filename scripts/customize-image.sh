#!/bin/bash
# Armbian 镜像定制脚本

set -e

echo "=== 开始定制 XF.A311D2 Armbian 镜像 ==="

# 参数检查
if [ $# -ne 1 ]; then
    echo "用法: $0 <镜像文件>"
    exit 1
fi

IMAGE_FILE="$1"
MOUNT_DIR="/mnt/image"

# 检查镜像文件
if [ ! -f "$IMAGE_FILE" ]; then
    echo "错误: 镜像文件不存在: $IMAGE_FILE"
    exit 1
fi

# 挂载镜像函数
mount_image() {
    echo "挂载镜像: $IMAGE_FILE"
    
    # 获取分区偏移
    OFFSET=$(fdisk -l "$IMAGE_FILE" | grep -A5 "Device" | grep "Linux" | head -1 | awk '{print $2}')
    OFFSET_BYTES=$((OFFSET * 512))
    
    # 创建挂载点
    sudo mkdir -p "$MOUNT_DIR"
    
    # 挂载根分区
    sudo mount -o loop,offset=$OFFSET_BYTES "$IMAGE_FILE" "$MOUNT_DIR"
    
    # 绑定系统目录
    sudo mount --bind /dev "$MOUNT_DIR/dev"
    sudo mount --bind /proc "$MOUNT_DIR/proc" 
    sudo mount --bind /sys "$MOUNT_DIR/sys"
}

# 卸载镜像函数
umount_image() {
    echo "卸载镜像..."
    sudo umount "$MOUNT_DIR/sys" 2>/dev/null || true
    sudo umount "$MOUNT_DIR/proc" 2>/dev/null || true
    sudo umount "$MOUNT_DIR/dev" 2>/dev/null || true
    sudo umount "$MOUNT_DIR" 2>/dev/null || true
    sudo rmdir "$MOUNT_DIR" 2>/dev/null || true
}

# 安装额外软件包
install_packages() {
    echo "安装额外软件包..."
    
    sudo chroot "$MOUNT_DIR" /bin/bash <<EOF
    # 更新系统
    apt-get update
    apt-get upgrade -y
    
    # 安装网络工具和驱动
    apt-get install -y \
        network-manager \
        wpasupplicant \
        wireless-tools \
        net-tools \
        usbutils \
        pciutils \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-realtek \
        firmware-atheros \
        firmware-iwlwifi \
        firmware-brcm80211 \
        firmware-misc-nonfree
    
    # 安装 XFCE 桌面（如果尚未安装）
    if ! dpkg -l | grep -q xfce4; then
        apt-get install -y \
            xfce4 \
            xfce4-goodies \
            lightdm \
            firefox-esr \
            thunar \
            gparted \
            gnome-disk-utility
    fi
    
    # 安装开发工具
    apt-get install -y \
        build-essential \
        dkms \
        git \
        python3 \
        python3-pip \
        vim \
        htop
    
    # 安装 PVE 相关组件
    apt-get install -y \
        qemu-system-arm \
        qemu-utils \
        libvirt-daemon-system \
        libvirt-clients \
        virt-manager \
        bridge-utils \
        virtinst
    
    # 清理
    apt-get autoremove -y
    apt-get clean
EOF
}

# 配置网络
configure_network() {
    echo "配置网络..."
    
    sudo chroot "$MOUNT_DIR" /bin/bash <<EOF
    # 启用 NetworkManager
    systemctl enable NetworkManager
    
    # 配置无线
    cat > /etc/NetworkManager/conf.d/wifi-backend.conf << 'WIFICONF'
[device]
wifi.backend=wpa_supplicant
WIFICONF

    # 配置蓝牙
    systemctl enable bluetooth
EOF
}

# 配置 USB 设备支持
configure_usb_devices() {
    echo "配置 USB 设备支持..."
    
    sudo chroot "$MOUNT_DIR" /bin/bash <<EOF
    # 创建 udev 规则
    cat > /etc/udev/rules.d/90-xf-a311d2-usb.rules << 'UDEVRULES'
# USB 有线网卡
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth%n"
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="cdc_ether", NAME="usb%n"

# USB 无线网卡
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="wlan*", NAME="wlan%n"

# USB 蓝牙设备
SUBSYSTEM=="bluetooth", ACTION=="add", KERNEL=="hci*", NAME="hci%n"
UDEVRULES
EOF
}

# 配置 GPU 和显示
configure_gpu() {
    echo "配置 GPU 和显示..."
    
    sudo chroot "$MOUNT_DIR" /bin/bash <<EOF
    # 安装 GPU 相关包
    apt-get install -y \
        mesa-utils \
        mesa-vulkan-drivers \
        libegl1-mesa-dev \
        libgles2-mesa-dev
    
    # 创建 Xorg 配置
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/20-xf-a311d2.conf << 'XORGCONF'
Section "Device"
    Identifier "A311D2"
    Driver "modesetting"
    Option "AccelMethod" "glamor"
    Option "DRI" "3"
EndSection

Section "OutputClass"
    Identifier "A311D2"
    MatchDriver "meson"
    Driver "modesetting"
    Option "PrimaryGPU" "true"
EndSection
XORGCONF
EOF
}

# 配置首次启动脚本
setup_firstboot() {
    echo "配置首次启动脚本..."
    
    sudo chroot "$MOUNT_DIR" /bin/bash <<EOF
    # 创建首次启动服务
    cat > /etc/systemd/system/xf-a311d2-firstboot.service << 'FIRSTBOOT'
[Unit]
Description=XF.A311D2 First Boot Setup
After=network.target
Before=rc-local.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xf-firstboot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
FIRSTBOOT

    # 创建首次启动脚本
    cat > /usr/local/bin/xf-firstboot.sh << 'SCRIPT'
#!/bin/bash

FIRSTBOOT_FILE="/var/lib/xf-a311d2-firstboot"

if [ ! -f "\$FIRSTBOOT_FILE" ]; then
    echo "执行首次启动配置..."
    
    # 重新生成 SSH 主机密钥
    rm -f /etc/ssh/ssh_host_*
    dpkg-reconfigure openssh-server
    
    # 扩展文件系统
    /usr/lib/armbian/armbian-resize-filesystem
    
    # 标记完成
    touch "\$FIRSTBOOT_FILE"
    echo "首次启动配置完成"
fi
SCRIPT

    chmod +x /usr/local/bin/xf-firstboot.sh
    systemctl enable xf-a311d2-firstboot.service
EOF
}

# 主函数
main() {
    echo "开始定制镜像: $IMAGE_FILE"
    
    # 挂载镜像
    mount_image
    
    # 执行定制步骤
    install_packages
    configure_network
    configure_usb_devices
    configure_gpu
    setup_firstboot
    
    # 卸载镜像
    umount_image
    
    echo "=== 镜像定制完成 ==="
    echo "镜像文件: $IMAGE_FILE"
}

# 捕获信号，确保卸载
trap umount_image EXIT INT TERM

# 执行主函数
main "$@"
