#!/bin/bash

# XF.A311D2 硬件检测脚本

detect_network_hardware() {
    echo "检测网络硬件..."
    
    # 检测有线网络
    if dmesg | grep -q "r8169"; then
        echo "找到 Realtek R8169 有线网卡"
        MODULES_EXTRA+=" r8169"
    elif dmesg | grep -q "dwmac"; then
        echo "找到 Amlogic 内部以太网控制器"
    fi
    
    # 检测无线网络
    if lsusb | grep -q "Broadcom"; then
        echo "找到 Broadcom USB 无线网卡"
        MODULES_EXTRA+=" brcmfmac"
    elif lsusb | grep -q "Realtek"; then
        echo "找到 Realtek USB 无线网卡" 
        MODULES_EXTRA+=" rtl8xxxu rtl8192cu"
    fi
    
    # 检测蓝牙
    if dmesg | grep -q "Bluetooth"; then
        echo "找到蓝牙设备"
        MODULES_EXTRA+=" btusb btrtl"
    fi
}

detect_storage_hardware() {
    echo "检测存储硬件..."
    
    # 检测 eMMC
    if dmesg | grep -q "mmcblk"; then
        echo "找到 eMMC 存储"
    fi
    
    # 检测 SD 卡控制器
    if dmesg | grep -q "dwmmc"; then
        echo "找到 Synopsys DW MMC 控制器"
    fi
}

detect_usb_hardware() {
    echo "检测 USB 硬件..."
    
    # 检测 USB 控制器
    if dmesg | grep -q "dwc3"; then
        echo "找到 DesignWare USB3 控制器"
        MODULES_EXTRA+=" dwc3"
    fi
    
    if dmesg | grep -q "xhci"; then
        echo "找到 xHCI USB 控制器"
        MODULES_EXTRA+=" xhci_pci"
    fi
}

generate_custom_config() {
    echo "生成自定义配置..."
    
    cat > /tmp/xf-a311d2-custom.conf << EOF
# 自动生成的 XF.A311D2 配置
MODULES_EXTRA="$MODULES_EXTRA"

# 网络配置
$(if echo "$MODULES_EXTRA" | grep -q "brcmfmac"; then
echo "WIRELESS_DEVICE=\"broadcom:brcmfmac\""
fi)

# 存储配置
$(if dmesg | grep -q "mmcblk2"; then
echo "BOOT_ORDER=\"emmc\""
else
echo "BOOT_ORDER=\"sd\""
fi)
EOF
}

main() {
    detect_network_hardware
    detect_storage_hardware  
    detect_usb_hardware
    generate_custom_config
    
    echo "硬件检测完成!"
    echo "额外需要的模块: $MODULES_EXTRA"
}

main
