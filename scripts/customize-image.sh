
#!/bin/bash

# Armbian 镜像定制脚本

# 设置变量
IMAGE_MOUNT="/mnt/image"
ROOT_MOUNT="/mnt/image/root"

# 挂载镜像函数
mount_image() {
    local image_file=$1
    local mount_point=$2
    
    # 获取分区偏移量
    local offset=$(fdisk -l "$image_file" | grep -o '[0-9]*[[:space:]]*Linux' | head -1 | awk '{print $1}')
    local offset_bytes=$((offset * 512))
    
    # 挂载镜像
    mount -o loop,offset=$offset_bytes "$image_file" "$mount_point"
}

# 安装额外的驱动和软件包
install_additional_packages() {
    chroot $ROOT_MOUNT /bin/bash <<EOF
    # 更新系统
    apt-get update
    apt-get upgrade -y
    
    # 安装网络工具
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
        firmware-brcm80211
    
    # 安装桌面环境所需软件
    apt-get install -y \
        xfce4 \
        xfce4-goodies \
        lightdm \
        firefox-esr \
        file-manager \
        gparted \
        gnome-disk-utility \
        vim \
        htop
    
    # 安装开发工具
    apt-get install -y \
        build-essential \
        dkms \
        git \
        python3 \
        python3-pip
    
    # 安装 PVE 相关依赖
    apt-get install -y \
        qemu-system-arm \
        libvirt-daemon-system \
        libvirt-clients \
        virt-manager \
        bridge-utils
    
    # 清理缓存
    apt-get autoremove -y
    apt-get clean
EOF
}

# 配置网络和无线
configure_networking() {
    chroot $ROOT_MOUNT /bin/bash <<EOF
    # 启用 NetworkManager
    systemctl enable NetworkManager
    
    # 配置无线网络
    cat > /etc/NetworkManager/conf.d/wifi-backend.conf << 'WIFICONF'
[device]
wifi.backend=wpa_supplicant
WIFICONF

    # 创建无线配置持久化目录
    mkdir -p /etc/NetworkManager/conf.d/
    
    # 配置蓝牙
    systemctl enable bluetooth
EOF
}

# 配置 USB 设备自动识别
configure_usb_devices() {
    chroot $ROOT_MOUNT /bin/bash <<EOF
    # 创建 udev 规则用于 USB 网络设备
    cat > /etc/udev/rules.d/90-usb-networking.rules << 'UDEVRULES'
# USB 有线网卡
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth%n"
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="cdc_ether", NAME="usb%n"

# USB 无线网卡
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="wlan*", NAME="wlan%n"

# USB 蓝牙设备
SUBSYSTEM=="bluetooth", ACTION=="add", KERNEL=="hci*", NAME="hci%n"
UDEVRULES

    # 重新加载 udev 规则
    udevadm control --reload-rules
    udevadm trigger
EOF
}

# 配置 GPU 和显示
configure_gpu_display() {
    chroot $ROOT_MOUNT /bin/bash <<EOF
    # 安装 Mali GPU 驱动
    apt-get install -y \
        mesa-utils \
        mesa-vulkan-drivers \
        libegl1-mesa-dev \
        libgles2-mesa-dev
    
    # 创建 GPU 配置
    cat > /etc/X11/xorg.conf.d/20-meson.conf << 'XORGCONF'
Section "Device"
    Identifier "Meson"
    Driver "modesetting"
    Option "AccelMethod" "glamor"
    Option "DRI" "3"
EndSection

Section "OutputClass"
    Identifier "Meson"
    MatchDriver "meson"
    Driver "modesetting"
    Option "PrimaryGPU" "true"
EndSection
XORGCONF
EOF
}

# 安装 PVE 相关组件
install_pve_components() {
    chroot $ROOT_MOUNT /bin/bash <<EOF
    # 添加 Proxmox 仓库（如果需要）
    # echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve.list
    
    # 安装虚拟化组件
    apt-get install -y \
        qemu-system-arm \
        qemu-utils \
        libvirt-daemon-system \
        libvirt-clients \
        virtinst \
        bridge-utils
    
    # 配置 libvirt
    usermod -a -G libvirt armbian
    systemctl enable libvirtd
    
    # 创建虚拟机网络配置示例
    mkdir -p /home/armbian/vm-templates
    cat > /home/armbian/vm-templates/README.md << 'VMREADME'
# 虚拟机配置说明

## 创建 ARM 虚拟机示例：
sudo virt-install \
    --name arm-vm \
    --memory 1024 \
    --vcpus 2 \
    --disk size=8 \
    --os-variant debian12 \
    --network bridge=virbr0 \
    --graphics vnc

## 网络桥接配置：
编辑 /etc/network/interfaces 或使用 NetworkManager
VMREADME
    
    chown -R armbian:armbian /home/armbian/vm-templates
EOF
}

# 创建首次启动配置脚本
create_firstboot_script() {
    chroot $ROOT_MOUNT /bin/bash <<EOF
    cat > /etc/rc.local << 'RCLOCAL'
#!/bin/bash

# 首次启动配置
if [ ! -f /var/firstboot_done ]; then
    # 重新生成 SSH 主机密钥
    rm -f /etc/ssh/ssh_host_*
    dpkg-reconfigure openssh-server
    
    # 扩展文件系统
    /usr/lib/armbian/armbian-resize-filesystem
    
    # 标记首次启动完成
    touch /var/firstboot_done
fi

# 启动后自动连接已知 WiFi（可选）
if [ -f /boot/wifi-connect.sh ]; then
    /bin/bash /boot/wifi-connect.sh &
fi

exit 0
RCLOCAL

    chmod +x /etc/rc.local
EOF
}

# 主执行函数
main() {
    echo "开始定制 Armbian 镜像..."
    
    # 这里需要根据实际镜像文件路径进行调整
    local image_file="$1"
    
    if [ -z "$image_file" ]; then
        echo "错误: 未指定镜像文件"
        exit 1
    fi
    
    # 创建挂载点
    mkdir -p $IMAGE_MOUNT
    mkdir -p $ROOT_MOUNT
    
    # 挂载镜像
    echo "挂载镜像..."
    mount_image "$image_file" "$IMAGE_MOUNT"
    
    # 绑定挂载系统目录
    mount --bind /dev $ROOT_MOUNT/dev
    mount --bind /proc $ROOT_MOUNT/proc
    mount --bind /sys $ROOT_MOUNT/sys
    
    # 执行定制步骤
    install_additional_packages
    configure_networking
    configure_usb_devices
    configure_gpu_display
    install_pve_components
    create_firstboot_script
    
    # 清理和卸载
    umount $ROOT_MOUNT/dev
    umount $ROOT_MOUNT/proc
    umount $ROOT_MOUNT/sys
    umount $IMAGE_MOUNT
    
    echo "镜像定制完成!"
}

# 执行主函数
main "$@"
