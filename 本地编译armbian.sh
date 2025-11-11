#适用于debian13系统
##我有一个arm的主板，型号是XF.A311D2 处理器是a311d2处理器，8g内存64g存储，其他硬件型号未知。
当前该主板安装了安卓13系统。我想给这个主板编译一个armbian （debian12）系统镜像，有如下问题和需求：
1、详细硬件参数还需要知道哪些？如何获取相关信息？
2、github中ophub编译的镜像在第一次配置成功wifi并连接后，再一次重启后经常丢失配置无线不能使用，而且桌面安装总是出问题（可能显卡安装不正确），
而armbian官方镜像总是不能启动，请以armbian官方的Khadas VIM4 （搭载的是 Amlogic A311D2 芯片）为基础进行操作，
结合armbian官方和ophub的优势，除了顺利驱动本机的有线无线网络和蓝牙、显卡外，我想实现插入任意usb方式的有线网卡、无线网卡、蓝牙设备能顺利驱动，
此外要安装xfce桌面和安装pve。3、以上全部在本地计算机（debian13系统）和中国网络环境下操作，请给出详尽的安装说明，谢谢！
#可以参考如下网络的内容：https://www.cnblogs.com/armsom/p/17835573.html 和 https://www.cnblogs.com/armsom/p/17838208.html
# 检查系统信息 内存: 8GB+ (推荐16GB);存储: 100GB+ 可用空间;网络: 稳定连接（需要下载大量源码）

# 在安卓系统中安装终端应用，执行以下命令：
# 获取CPU信息
cat /proc/cpuinfo
cat /proc/device-tree/compatible
# 获取内存信息
cat /proc/meminfo
cat /proc/iomem
# 获取存储信息
cat /proc/partitions
lsblk
# 获取网络设备
ip link show
dmesg | grep -i network
dmesg | grep -i ethernet
dmesg | grep -i wifi
dmesg | grep -i bluetooth
# 获取USB设备信息
lsusb
cat /proc/device-tree/usb*
# 获取GPU信息
dmesg | grep -i gpu
cat /proc/device-tree/gpu*
# 获取PCI设备
lspci
# 获取设备树信息
find /proc/device-tree -name "*.dtb" -exec fdtdump {} \; | less

#*********************************************************************************************************************************************#

#!/bin/bash
set -e

###############################################################################
#                                                                             #
#                 Khadas VIM4 Armbian 一键构建脚本                           #
#                                                                             #
# 功能说明:                                                                   #
#   此脚本用于自动化构建 Khadas VIM4 的 Armbian 系统                         #
#   支持构建基础系统和带 XFCE 桌面的完整系统                                 #
#                                                                             #
# 系统要求:                                                                   #
#   - Ubuntu 20.04/22.04 或 Debian 11/12                                     #
#   - 至少 8GB 内存 (推荐 16GB 或更多)                                       #
#   - 至少 100GB 可用磁盘空间                                                #
#   - 稳定的网络连接                                                         #
#                                                                             #
# 构建时间:                                                                   #
#   - 基础系统: 2-4 小时                                                     #
#   - 桌面系统: 3-6 小时                                                     #
#                                                                             #
# 输出文件:                                                                   #
#   - 构建完成的镜像在: ${WORK_DIR}/build/output/images/                     #
#                                                                             #
# 使用说明:                                                                   #
#   1. chmod +x build-vim4-armbian.sh                                        #
#   2. sudo ./build-vim4-armbian.sh [选项]                                   #
#                                                                             #
###############################################################################

# 默认工作目录
DEFAULT_WORK_DIR="/opt/armbian-build"

# 颜色定义用于输出美化
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
WORK_DIR="$DEFAULT_WORK_DIR"
BUILD_DIR="$WORK_DIR/build"

# 日志函数 - 提供不同级别的彩色输出
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }

###############################################################################
# 功能: 解析命令行参数
# 描述: 处理用户输入的命令行参数，包括工作目录设置
###############################################################################
parse_arguments() {
    local positional_args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--config)
                MODE="config"
                shift
                ;;
            -m|--minimal)
                MODE="minimal"
                shift
                ;;
            -d|--desktop)
                MODE="desktop"
                shift
                ;;
            -i|--info)
                MODE="info"
                shift
                ;;
            -w|--work-dir)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    WORK_DIR="$2"
                    BUILD_DIR="$WORK_DIR/build"
                    shift 2
                else
                    log_error "请为 --work-dir 参数指定有效的目录路径"
                    exit 1
                fi
                ;;
            --work-dir=*)
                WORK_DIR="${1#*=}"
                BUILD_DIR="$WORK_DIR/build"
                shift
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done
    
    # 设置默认模式（如果没有指定）
    MODE=${MODE:-"config"}
}

###############################################################################
# 功能: 验证工作目录
# 描述: 检查工作目录是否有效，并创建必要的目录结构
###############################################################################
validate_work_directory() {
    log_step "验证工作目录..."
    
    # 检查目录是否可访问
    if [[ ! -d "$(dirname "$WORK_DIR")" ]]; then
        log_error "父目录 $(dirname "$WORK_DIR") 不存在或不可访问"
        exit 1
    fi
    
    # 检查磁盘空间
    local available_space=$(df "$(dirname "$WORK_DIR")" | tail -1 | awk '{print $4}')
    local required_space=100000000  # 100GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "磁盘空间不足!"
        log_error "可用空间: $(($available_space/1024/1024))GB, 需要: $(($required_space/1024/1024))GB"
        log_info "请确保工作目录所在分区至少有 100GB 可用空间"
        exit 1
    fi
    
    # 创建目录
    mkdir -p "$WORK_DIR"
    if [[ $? -ne 0 ]]; then
        log_error "无法创建工作目录: $WORK_DIR"
        exit 1
    fi
    
    # 检查目录权限
    if [[ ! -w "$WORK_DIR" ]]; then
        log_error "工作目录没有写权限: $WORK_DIR"
        exit 1
    fi
    
    log_info "工作目录: $WORK_DIR"
    log_info "构建目录: $BUILD_DIR"
    log_success "工作目录验证通过"
}

###############################################################################
# 功能: 检查运行环境和依赖
# 描述: 验证脚本运行环境，包括用户权限、系统类型和基本依赖
###############################################################################
check_environment() {
    log_step "检查系统环境..."
    
    # 检查 root 权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测操作系统类型"
        exit 1
    fi
    
    # 显示系统信息
    local os_name=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    local kernel_version=$(uname -r)
    local architecture=$(uname -m)
    
    log_info "操作系统: $os_name"
    log_info "内核版本: $kernel_version"
    log_info "系统架构: $architecture"
    
    # 验证架构兼容性
    if [[ "$architecture" != "x86_64" ]]; then
        log_warning "此脚本主要针对 x86_64 架构优化"
        log_warning "在其他架构上运行可能会遇到问题"
    fi
    
    log_success "环境检查通过"
}

###############################################################################
# 功能: 安装系统依赖包
# 描述: 安装构建 Armbian 系统所需的所有编译工具和依赖包
###############################################################################
install_dependencies() {
    log_step "安装系统依赖包..."
    
    # 更新软件包列表
    log_info "更新软件包列表..."
    apt update
    
    # 升级系统软件包
    log_info "升级系统软件包..."
    apt upgrade -y
    
    # 安装基础编译工具链
    log_info "安装基础编译工具..."
    apt install -y \
        git bc build-essential devscripts debhelper-compat \
        wget cpio file kmod libelf-dev lsb-release python3 \
        flex bison libssl-dev rsync parted dosfstools \
        p7zip-full zip unzip curl jq tree
    
    # 安装交叉编译工具
    log_info "安装交叉编译工具..."
    apt install -y \
        gcc-aarch64-linux-gnu u-boot-tools \
        crossbuild-essential-arm64 device-tree-compiler \
        qemu-user-static binfmt-support
    
    # 安装额外的构建工具
    log_info "安装额外构建工具..."
    apt install -y \
        make gcc g++ patchutils \
        libncurses-dev libssl-dev \
        systemd-container debootstrap
    
    log_success "所有依赖包安装完成"
}

###############################################################################
# 功能: 准备构建环境
# 描述: 克隆 Armbian 构建系统并切换到稳定版本
###############################################################################
prepare_build_env() {
    log_step "准备 Armbian 构建环境..."
    
    # 进入工作目录
    cd "$WORK_DIR"
    
    # 克隆或更新 Armbian 构建系统
    if [[ ! -d "build" ]]; then
        log_info "克隆 Armbian 构建系统..."
        git clone https://github.com/armbian/build
        
        if [[ $? -ne 0 ]]; then
            log_error "克隆 Armbian 构建系统失败"
            exit 1
        fi
        
        cd build
    else
        log_info "Armbian 构建目录已存在，更新代码..."
        cd build
        
        # 检查是否在标签上（游离 HEAD 状态）
        if ! git symbolic-ref -q HEAD > /dev/null; then
            log_info "当前在标签上，切换到 main 分支进行更新..."
            git checkout -f main
        fi
        
        # 拉取最新更新
        git pull origin main
        
        if [[ $? -ne 0 ]]; then
            log_warning "Git 拉取失败，尝试强制更新..."
            git fetch --all
            git reset --hard origin/main
        fi
    fi
    
    # 切换到最新稳定版本
    log_info "获取最新稳定版本..."
    LATEST_TAG=$(git describe --tags --abbrev=0)
    
    if [[ -z "$LATEST_TAG" ]]; then
        log_error "无法获取最新版本标签"
        exit 1
    fi
    
    log_info "切换到最新稳定版本: $LATEST_TAG"
    git checkout -f $LATEST_TAG
    
    # 运行依赖检查脚本
    log_info "运行构建依赖检查..."
    ./compile.sh REQUIREMENTS
    
    if [[ $? -ne 0 ]]; then
        log_error "依赖检查失败，请检查错误信息"
        exit 1
    fi
    
    log_success "构建环境准备完成"
}

###############################################################################
# 功能: 创建 VIM4 板级配置
# 描述: 为 Khadas VIM4 创建自定义板级配置文件
###############################################################################
create_vim4_config() {
    log_step "创建 VIM4 板级配置..."
    
    # 创建用户补丁目录
    mkdir -p userpatches/
    
    # 检查是否已存在 VIM4 配置
    if [[ ! -f "config/boards/vim4.conf" ]]; then
        log_info "创建 VIM4 自定义配置文件..."
        
        # 创建基于 amlogic-a311d 的自定义配置
        cat > config/boards/vim4-custom.conf << 'EOF'
# =============================================================================
# Khadas VIM4 (Amlogic A311D2) 自定义配置
# =============================================================================

# 板卡基本信息
BOARD_NAME="VIM4"                           # 板卡名称
BOARDFAMILY="meson-g12b"                    # 芯片系列
BOARD_MAINTAINER="Local Build"              # 维护者
BOARD_SUPPORT_TYPE="community"              # 支持类型

# 内核配置
KERNEL_TARGET="current,legacy"              # 支持的内核版本
KERNEL_TEST_TARGET="current"                # 测试内核版本

# U-Boot 配置
BOOTSOURCE='https://github.com/khadas/u-boot'  # U-Boot 源码地址
BOOTBRANCH='branch:khadas-vims-vim4'        # U-Boot 分支
BOOTDIR='u-boot-khadas'                     # U-Boot 目录
BOOTSCRIPT="boot-aml.cmd:boot.cmd"          # 启动脚本
BOOTENV_FILE='khadas-default.txt'           # 环境变量文件

# 设备树和架构
LINUXFAMILY="meson-g12b"                    # Linux 设备树系列
ARCH="arm64"                                # 目标架构
IMAGE_PARTITION_TABLE="gpt"                 # 分区表类型

# CPU 频率调节
CPUMIN="500000"                             # 最低 CPU 频率 (Hz)
CPUMAX="2208000"                            # 最高 CPU 频率 (Hz)
GOVERNOR="ondemand"                         # CPU 调频策略

# 硬件特性支持
HAVE_HDMI=yes                               # 支持 HDMI 输出
HAVE_HDMI_AUDIO=yes                         # 支持 HDMI 音频

# 构建选项
BUILD_DESKTOP="no"                          # 是否构建桌面版
DESKTOP_ENVIRONMENT="xfce"                  # 桌面环境类型
DESKTOP_ENVIRONMENT_CONFIG_NAME="config_base" # 桌面配置
DESKTOP_APPGROUPS_SELECTED="browsers office" # 预装应用组

# 额外软件包
PACKAGE_LIST_ADDITIONAL="linux-firmware firmware-realtek firmware-mediatek firmware-amlogic"

# 构建优化配置
EXTRA_BSP_NAME="vim4-local"                 # 额外 BSP 名称
ROOTFSTYPE="ext4"                           # 根文件系统类型
EOF

        export BOARD_NAME="vim4-custom"
        log_info "使用自定义配置: vim4-custom"
    else
        export BOARD_NAME="vim4"
        log_info "使用官方配置: vim4"
    fi
    
    log_success "VIM4 板级配置创建完成"
}

###############################################################################
# 功能: 创建自定义镜像脚本
# 描述: 创建首次启动时的自定义配置脚本
###############################################################################
create_customize_script() {
    log_step "创建自定义镜像脚本..."
    
    cat > userpatches/customize-image.sh << 'EOF'
#!/bin/bash

# =============================================================================
# Armbian 镜像自定义脚本
# 此脚本在首次启动时自动执行，用于系统个性化配置
# =============================================================================

customize_image() {
    log_info "开始执行镜像自定义配置..."
    
    # -------------------------------------------------------------------------
    # 时区配置
    # -------------------------------------------------------------------------
    log_info "配置时区..."
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo "Asia/Shanghai" > /etc/timezone
    
    # -------------------------------------------------------------------------
    # 软件源配置 - 使用国内镜像加速
    # -------------------------------------------------------------------------
    log_info "配置软件源..."
    cat > /etc/apt/sources.list << 'SOURCES_EOF'
# 清华大学 Debian 镜像源
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free
SOURCES_EOF

    # -------------------------------------------------------------------------
    # 系统更新和基础软件安装
    # -------------------------------------------------------------------------
    log_info "更新系统并安装基础软件包..."
    apt-get update
    
    # 安装网络工具
    apt-get install -y \
        net-tools wireless-tools wpasupplicant \
        firmware-linux network-manager \
        curl wget vim htop tree
    
    # 安装无线网卡固件
    apt-get install -y \
        firmware-realtek firmware-atheros firmware-ralink \
        firmware-iwlwifi firmware-brcm80211
    
    # 安装蓝牙支持
    apt-get install -y \
        bluez bluez-tools pulseaudio-module-bluetooth
    
    # -------------------------------------------------------------------------
    # 桌面环境安装 (仅在构建桌面版时执行)
    # -------------------------------------------------------------------------
    if [[ "$BUILD_DESKTOP" == "yes" ]]; then
        log_info "安装桌面环境..."
        
        # 安装 XFCE 桌面环境
        apt-get install -y \
            xfce4 xfce4-goodies lightdm \
            firefox-esr file-roller mousepad \
            fonts-wqy-microhei fonts-wqy-zenhei
        
        # 配置显示管理器
        systemctl enable lightdm
        systemctl set-default graphical.target
    fi
    
    # -------------------------------------------------------------------------
    # 网络配置优化
    # -------------------------------------------------------------------------
    log_info "优化网络配置..."
    
    # 创建 NetworkManager 配置文件
    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/wifi-persistent.conf << 'NM_EOF'
[connection]
wifi.cloned-mac-address=preserve
wifi.mac-address-randomization=1

[device]
wifi.scan-rand-mac-address=no
NM_EOF

    # -------------------------------------------------------------------------
    # 系统服务配置
    # -------------------------------------------------------------------------
    log_info "配置系统服务..."
    
    # 启用网络管理器
    systemctl enable NetworkManager
    
    # 启用蓝牙服务
    systemctl enable bluetooth
    
    # -------------------------------------------------------------------------
    # 用户组配置
    # -------------------------------------------------------------------------
    log_info "配置用户组..."
    
    # 如果存在 libvirt 组，将用户添加到该组
    if getent group libvirt > /dev/null && [[ -n "$USERNAME" ]]; then
        usermod -a -G libvirt "$USERNAME" 2>/dev/null || true
    fi
    
    # -------------------------------------------------------------------------
    # 系统清理
    # -------------------------------------------------------------------------
    log_info "执行系统清理..."
    apt-get autoremove -y
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    
    log_info "镜像自定义配置完成"
}
EOF

    # 设置脚本执行权限
    chmod +x userpatches/customize-image.sh
    log_success "自定义镜像脚本创建完成"
}

###############################################################################
# 功能: 创建内核配置文件
# 描述: 为 VIM4 创建自定义内核配置，启用额外的硬件支持
###############################################################################
create_kernel_config() {
    log_step "创建内核配置文件..."
    
    cat > userpatches/linux-khadas-vim4.config << 'EOF'
# =============================================================================
# Khadas VIM4 自定义内核配置
# 启用额外的硬件驱动和支持
# =============================================================================

# -----------------------------------------------------------------------------
# USB 网络设备支持
# -----------------------------------------------------------------------------
CONFIG_USB_NET_AX8817X=y                    # ASIX AX8817X 系列 USB 网卡
CONFIG_USB_NET_AX88179_178A=y               # ASIX AX88179/178A USB 3.0 网卡
CONFIG_USB_NET_CDCETHER=y                   # CDC Ethernet 支持
CONFIG_USB_NET_CDC_NCM=y                    # CDC NCM 支持
CONFIG_USB_NET_HUAWEI_CDC_NCM=y             # 华为 CDC NCM 设备
CONFIG_USB_NET_RNDIS_HOST=y                 # RNDIS 主机支持
CONFIG_USB_NET_CDC_SUBSET=y                 # CDC 子集支持
CONFIG_USB_USBNET=y                         # USB 网络设备框架

# -----------------------------------------------------------------------------
# 无线网卡支持
# -----------------------------------------------------------------------------
CONFIG_WLAN=y                               # 无线局域网支持
CONFIG_CFG80211=y                           # 无线配置 API
CONFIG_MAC80211=y                           # MAC 802.11 网络栈
CONFIG_RTL8XXXU=y                           # Realtek 8xxxU USB 无线驱动
CONFIG_RTL8192CU=y                          # Realtek 8192CU 无线驱动
CONFIG_RTL8192DU=y                          # Realtek 8192DU 无线驱动
CONFIG_RTL8192EU=y                          # Realtek 8192EU 无线驱动
CONFIG_RTL8812AU=y                          # Realtek 8812AU 无线驱动
CONFIG_RTL8821CU=y                          # Realtek 8821CU 无线驱动
CONFIG_ATH_COMMON=y                         # Atheros 通用支持
CONFIG_ATH9K_HTC=y                          # Atheros HTC 设备支持
CONFIG_ATH10K=y                             # Atheros 10K 无线驱动

# -----------------------------------------------------------------------------
# 蓝牙支持
# -----------------------------------------------------------------------------
CONFIG_BT=y                                 # 蓝牙支持
CONFIG_BT_RFCOMM=y                          # RFCOMM 协议支持
CONFIG_BT_HCIUART=y                         # HCI UART 驱动
CONFIG_BT_HCIUART_ATH3K=y                   # Atheros HCI UART 支持
CONFIG_BT_HCIBCM203X=y                      # Broadcom 203X 蓝牙支持

# -----------------------------------------------------------------------------
# 音视频和显示支持
# -----------------------------------------------------------------------------
CONFIG_SND_SOC=y                            # 音频编解码器支持
CONFIG_SND_ALOOP=y                          # 音频环回设备
CONFIG_DRM_MESON=y                          # Amlogic DRM 显示驱动
CONFIG_DRM_MESON_DW_HDMI=y                  # Amlogic HDMI 支持

# -----------------------------------------------------------------------------
# 文件系统支持
# -----------------------------------------------------------------------------
CONFIG_EXT4_FS=y                            # Ext4 文件系统
CONFIG_VFAT_FS=y                            # VFAT 文件系统
CONFIG_NTFS_FS=y                            # NTFS 文件系统
CONFIG_EXFAT_FS=y                           # ExFAT 文件系统

# -----------------------------------------------------------------------------
# 内核调试和性能监控
# -----------------------------------------------------------------------------
CONFIG_DEBUG_FS=y                           # 调试文件系统
CONFIG_PERF_EVENTS=y                        # 性能事件支持
CONFIG_FTRACE=y                             # 函数跟踪器
EOF

    log_success "内核配置文件创建完成"
}

###############################################################################
# 功能: 创建构建脚本
# 描述: 创建基础系统和桌面系统的构建脚本
###############################################################################
create_build_scripts() {
    log_step "创建构建脚本..."
    
    # 基础系统构建脚本
    cat > build-vim4-minimal.sh << 'EOF'
#!/bin/bash
set -e

# =============================================================================
# Khadas VIM4 基础系统构建脚本
# 构建最小化的 Armbian 系统，包含基本功能
# =============================================================================

# 构建配置
export KERNEL_BTF=no                        # 禁用 BTF 以减少内存使用
export KERNEL_CONFIGURE=no                  # 不交互式配置内核
export BUILD_MINIMAL=no                     # 构建完整系统（非最小化）
export BUILD_DESKTOP=no                     # 不包含桌面环境
export RELEASE=bookworm                     # Debian 12 (Bookworm)
export BRANCH=legacy                        # 使用 legacy 内核分支
export BOARD=khadas-vim4                    # 目标板卡

# 性能优化配置
export MAKE_ALL_JOBS=$(nproc)               # 使用所有 CPU 核心
export EXTERNAL=yes                         # 使用外部工具链
export CREATE_PATCHES=no                    # 不创建补丁

# 显示构建信息
echo "=========================================="
echo "    Khadas VIM4 基础系统构建开始"
echo "=========================================="
echo "目标板卡: $BOARD"
echo "内核分支: $BRANCH"
echo "发行版本: $RELEASE"
echo "桌面环境: 无"
echo "CPU 核心数: $(nproc)"
echo "开始时间: $(date)"
echo "工作目录: $(pwd)"
echo "=========================================="

# 开始构建
./compile.sh \
    BOARD=$BOARD \
    BRANCH=$BRANCH \
    RELEASE=$RELEASE \
    BUILD_MINIMAL=$BUILD_MINIMAL \
    BUILD_DESKTOP=$BUILD_DESKTOP \
    KERNEL_ONLY=no \
    KERNEL_CONFIGURE=$KERNEL_CONFIGURE \
    COMPRESS_OUTPUTIMAGE=img

# 构建完成提示
echo "=========================================="
echo "   基础系统构建完成"
echo "   完成时间: $(date)"
echo "=========================================="
EOF

    # 桌面系统构建脚本
    cat > build-vim4-desktop.sh << 'EOF'
#!/bin/bash
set -e

# =============================================================================
# Khadas VIM4 桌面系统构建脚本
# 构建包含 XFCE 桌面环境的完整系统
# =============================================================================

# 构建配置
export KERNEL_BTF=no                        # 禁用 BTF 以减少内存使用
export KERNEL_CONFIGURE=no                  # 不交互式配置内核
export BUILD_MINIMAL=no                     # 构建完整系统
export BUILD_DESKTOP=yes                    # 包含桌面环境
export RELEASE=bookworm                     # Debian 12 (Bookworm)
export BRANCH=legacy                        # 使用 legacy 内核分支
export BOARD=khadas-vim4                    # 目标板卡

# 性能优化配置
export MAKE_ALL_JOBS=$(nproc)               # 使用所有 CPU 核心
export EXTERNAL=yes                         # 使用外部工具链
export CREATE_PATCHES=no                    # 不创建补丁

# 显示构建信息
echo "=========================================="
echo " Khadas VIM4 桌面系统构建开始"
echo "=========================================="
echo "目标板卡: $BOARD"
echo "内核分支: $BRANCH"
echo "发行版本: $RELEASE"
echo "桌面环境: XFCE"
echo "CPU 核心数: $(nproc)"
echo "开始时间: $(date)"
echo "工作目录: $(pwd)"
echo "=========================================="

# 开始构建
./compile.sh \
    BOARD=$BOARD \
    BRANCH=$BRANCH \
    RELEASE=$RELEASE \
    BUILD_MINIMAL=$BUILD_MINIMAL \
    BUILD_DESKTOP=$BUILD_DESKTOP \
    KERNEL_ONLY=no \
    KERNEL_CONFIGURE=$KERNEL_CONFIGURE \
    COMPRESS_OUTPUTIMAGE=img

# 构建完成提示
echo "=========================================="
echo "   桌面系统构建完成"
echo "   完成时间: $(date)"
echo "=========================================="
EOF

    # 设置脚本执行权限
    chmod +x build-vim4-minimal.sh
    chmod +x build-vim4-desktop.sh
    
    log_success "构建脚本创建完成"
    log_info "基础系统构建脚本: build-vim4-minimal.sh"
    log_info "桌面系统构建脚本: build-vim4-desktop.sh"
}

###############################################################################
# 功能: 创建首次启动优化脚本
# 描述: 创建在目标设备首次启动后运行的优化脚本
###############################################################################
create_first_boot_script() {
    log_step "创建首次启动优化脚本..."
    
    cat > "$WORK_DIR/first-boot-optimize.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# Khadas VIM4 首次启动优化脚本
# 在系统首次启动后运行，用于系统优化和硬件检测
# =============================================================================

echo "=========================================="
echo "   Khadas VIM4 首次启动优化"
echo "=========================================="

# -----------------------------------------------------------------------------
# 扩展文件系统到整个存储设备
# -----------------------------------------------------------------------------
echo "步骤 1: 扩展文件系统..."
if [[ -f /usr/lib/armbian/armbian-resize-filesystem ]]; then
    /usr/lib/armbian/armbian-resize-filesystem
    echo "文件系统扩展完成"
else
    echo "警告: 未找到文件系统扩展脚本，跳过此步骤"
fi

# -----------------------------------------------------------------------------
# 系统更新
# -----------------------------------------------------------------------------
echo "步骤 2: 系统更新..."
apt update
apt upgrade -y

# -----------------------------------------------------------------------------
# 安装实用工具
# -----------------------------------------------------------------------------
echo "步骤 3: 安装实用工具..."
apt install -y \
    htop iotop nethools iftop \
    lm-sensors stress stress-ng \
    usbutils pciutils lshw \
    neofetch screen tmux

# -----------------------------------------------------------------------------
# 硬件信息检测和显示
# -----------------------------------------------------------------------------
echo "步骤 4: 硬件信息检测..."

echo "=== 系统信息 ==="
if [[ -f /etc/armbian-release ]]; then
    cat /etc/armbian-release
else
    echo "未找到 Armbian 版本信息"
fi

echo "=== CPU 信息 ==="
lscpu | grep -E "Architecture|CPU\(s\)|Model name|MHz"

echo "=== 内存信息 ==="
free -h

echo "=== 存储信息 ==="
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE

echo "=== 网络设备 ==="
ip link show

echo "=== USB 设备 ==="
lsusb

echo "=== PCI 设备 ==="
lspci

echo "=== 温度传感器 ==="
sensors 2>/dev/null || echo "未找到传感器数据"

echo "=== 内核模块 ==="
lsmod | grep -E "meson|aml|drm|bluetooth|wlan"

# -----------------------------------------------------------------------------
# 性能优化建议
# -----------------------------------------------------------------------------
echo "步骤 5: 性能优化建议..."
echo "1. 建议启用 zram 交换压缩:"
echo "   sudo armbian-zram-config enable"
echo ""
echo "2. 建议配置 CPU 调频策略:"
echo "   echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
echo ""
echo "3. 建议定期更新系统:"
echo "   sudo apt update && sudo apt upgrade"
echo ""
echo "4. 监控系统温度:"
echo "   watch sensors"

# -----------------------------------------------------------------------------
# 完成提示
# -----------------------------------------------------------------------------
echo "=========================================="
echo "   首次启动优化完成!"
echo "=========================================="
echo "建议执行以下操作:"
echo "1. 重启系统: sudo reboot"
echo "2. 检查网络连接"
echo "3. 配置显示设置 (如需要)"
echo "4. 安装额外软件包"
echo ""
echo "享受您的 Khadas VIM4 系统!"
EOF

    # 设置脚本执行权限
    chmod +x "$WORK_DIR/first-boot-optimize.sh"
    
    log_success "首次启动优化脚本创建完成"
    log_info "脚本位置: $WORK_DIR/first-boot-optimize.sh"
}

###############################################################################
# 功能: 构建后检查
# 描述: 检查构建结果并显示生成的镜像文件信息
###############################################################################
post_build_check() {
    log_step "检查构建结果..."
    
    local image_dir="$BUILD_DIR/output/images"
    
    if [[ -d "$image_dir" ]]; then
        log_success "构建完成！生成的镜像文件在: $image_dir"
        echo "=========================================="
        
        # 列出所有镜像文件
        for img in $image_dir/*.img; do
            if [[ -f "$img" ]]; then
                echo "镜像文件: $(basename $img)"
                echo "文件大小: $(du -h $img | cut -f1)"
                echo "修改时间: $(date -r $img)"
                echo "文件类型: $(file $img | cut -d: -f2-)"
                echo "------------------------------------------"
            fi
        done
        
        echo "=========================================="
        
        # 显示构建总结
        local total_images=$(ls $image_dir/*.img 2>/dev/null | wc -l)
        if [[ $total_images -gt 0 ]]; then
            log_success "成功生成 $total_images 个镜像文件"
            log_info "镜像文件可用于刷写到 SD 卡或 eMMC"
        else
            log_warning "未找到 .img 镜像文件，但构建目录存在"
        fi
    else
        log_error "构建失败：未找到镜像输出目录"
        log_info "请检查构建日志获取详细错误信息"
        return 1
    fi
}

###############################################################################
# 功能: 显示使用说明
# 描述: 显示脚本的使用方法和选项
###############################################################################
show_usage() {
    cat << EOF

使用说明:

  sudo ./build-vim4-armbian.sh [选项]

选项:
  -h, --help          显示此帮助信息
  -c, --config        只进行环境配置，不开始构建
  -m, --minimal       配置环境并构建基础系统
  -d, --desktop       配置环境并构建桌面系统
  -i, --info          显示系统信息和构建状态
  -w, --work-dir DIR  设置工作目录 (默认: $DEFAULT_WORK_DIR)

示例:
  sudo ./build-vim4-armbian.sh --config                    # 只配置环境
  sudo ./build-vim4-armbian.sh --minimal                   # 构建基础系统
  sudo ./build-vim4-armbian.sh --desktop                   # 构建桌面系统
  sudo ./build-vim4-armbian.sh --info                      # 显示构建信息
  sudo ./build-vim4-armbian.sh --work-dir /home/user/build # 使用自定义工作目录
  sudo ./build-vim4-armbian.sh -w /mnt/ssd/armbian-build -m # 自定义目录并构建基础系统

构建步骤:
  1. 环境配置: 安装依赖，准备构建环境
  2. 系统构建: 编译内核，生成根文件系统
  3. 镜像打包: 创建可刷写的镜像文件
  4. 首次启动: 在目标设备上运行优化脚本

工作目录说明:
  - 默认工作目录: $DEFAULT_WORK_DIR
  - 构建目录: \${WORK_DIR}/build
  - 输出目录: \${WORK_DIR}/build/output/images/
  - 首次启动脚本: \${WORK_DIR}/first-boot-optimize.sh

注意事项:
  - 构建过程需要大量时间和磁盘空间
  - 确保网络连接稳定
  - 建议在性能较好的机器上运行
  - 工作目录所在分区应有至少 100GB 可用空间

EOF
}

###############################################################################
# 功能: 显示系统信息和构建状态
# 描述: 显示当前系统状态和构建环境信息
###############################################################################
show_system_info() {
    log_step "系统信息和构建状态"
    
    echo "=== 系统信息 ==="
    echo "主机名: $(hostname)"
    echo "操作系统: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    echo "内核版本: $(uname -r)"
    echo "系统架构: $(uname -m)"
    echo "CPU 核心: $(nproc)"
    echo "内存总量: $(free -h | grep Mem: | awk '{print $2}')"
    echo "磁盘空间:"
    df -h / | tail -1
    
    echo ""
    echo "=== 构建环境 ==="
    echo "工作目录: $WORK_DIR"
    if [[ -d "$BUILD_DIR" ]]; then
        echo "构建目录: $BUILD_DIR"
        cd "$BUILD_DIR"
        
        if [[ -d ".git" ]]; then
            local git_branch=$(git branch --show-current 2>/dev/null || echo "detached")
            local git_commit=$(git rev-parse --short HEAD 2>/dev/null)
            echo "Git 分支: $git_branch"
            echo "Git 提交: $git_commit"
        fi
        
        if [[ -d "output/images" ]]; then
            echo "已有镜像文件:"
            ls output/images/*.img 2>/dev/null | while read img; do
                echo "  - $(basename $img) ($(du -h $img | cut -f1))"
            done || echo "  无"
        else
            echo "输出目录: 无构建记录"
        fi
    else
        echo "构建环境: 未初始化"
    fi
    
    echo ""
    echo "=== 构建脚本 ==="
    ls "$BUILD_DIR/build-vim4-"*.sh 2>/dev/null | while read script; do
        echo "  - $(basename $script)"
    done || echo "  无"
    
    echo ""
    echo "=== 首次启动脚本 ==="
    if [[ -f "$WORK_DIR/first-boot-optimize.sh" ]]; then
        echo "  - $(basename $WORK_DIR/first-boot-optimize.sh)"
    else
        echo "  未创建"
    fi
}

###############################################################################
# 主函数 - 脚本执行入口
# 描述: 协调所有功能的执行流程
###############################################################################
main() {
    echo "=========================================="
    echo "  Khadas VIM4 Armbian 一键构建脚本"
    echo "=========================================="
    
    # 显示开始信息
    log_info "开始时间: $(date)"
    log_info "工作目录: $WORK_DIR"
    log_info "构建目录: $BUILD_DIR"
    
    # 验证工作目录
    validate_work_directory
    
    # 执行环境检查
    check_environment
    
    # 安装系统依赖
    install_dependencies
    
    # 准备构建环境
    prepare_build_env
    
    # 创建配置文件
    create_vim4_config
    create_customize_script
    create_kernel_config
    create_build_scripts
    create_first_boot_script
    
    # 显示完成信息
    log_success "所有配置已完成！"
    echo ""
    echo "下一步操作:"
    echo "1. 构建基础系统: cd $BUILD_DIR && ./build-vim4-minimal.sh"
    echo "2. 构建桌面系统: cd $BUILD_DIR && ./build-vim4-desktop.sh"
    echo ""
    echo "构建说明:"
    echo "- 基础系统构建时间: 2-4 小时"
    echo "- 桌面系统构建时间: 3-6 小时" 
    echo "- 输出目录: $BUILD_DIR/output/images/"
    echo "- 首次启动脚本: $WORK_DIR/first-boot-optimize.sh"
    echo ""
    log_info "配置完成时间: $(date)"
    echo "=========================================="
}

###############################################################################
# 脚本参数处理和主执行逻辑
###############################################################################

# 如果没有参数，显示使用说明
if [[ $# -eq 0 ]]; then
    show_usage
    exit 0
fi

# 解析命令行参数
parse_arguments "$@"

# 根据模式执行相应操作
case "$MODE" in
    "config")
        log_step "执行环境配置..."
        main
        ;;
    "minimal")
        log_step "配置环境并构建基础系统..."
        main
        cd "$BUILD_DIR"
        log_info "开始构建基础系统..."
        ./build-vim4-minimal.sh
        post_build_check
        ;;
    "desktop")
        log_step "配置环境并构建桌面系统..."
        main
        cd "$BUILD_DIR"
        log_info "开始构建桌面系统..."
        ./build-vim4-desktop.sh
        post_build_check
        ;;
    "info")
        show_system_info
        exit 0
        ;;
    *)
        log_error "未知模式: $MODE"
        show_usage
        exit 1
        ;;
esac
