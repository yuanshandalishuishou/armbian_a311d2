#!/bin/bash
# 本地构建脚本

set -e

echo "=== XF.A311D2 Armbian 本地构建脚本 ==="

# 检查依赖
check_dependencies() {
    echo "检查构建依赖..."
    
    local deps=("git" "make" "gcc" "bc" "device-tree-compiler" "flex" "bison")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "错误: 缺少依赖 $dep"
            echo "请安装: sudo apt-get install build-essential bc device-tree-compiler flex bison"
            exit 1
        fi
    done
}

# 克隆 Armbian 构建系统
setup_build_system() {
    if [ ! -d "build" ]; then
        echo "克隆 Armbian 构建系统..."
        git clone https://github.com/armbian/build.git
        cd build
        git checkout master
        cd ..
    else
        echo "更新 Armbian 构建系统..."
        cd build
        git pull
        cd ..
    fi
}

# 复制配置文件
copy_configs() {
    echo "复制配置文件..."
    
    # 复制板级配置
    cp config/boards/xf-a311d2.conf build/config/boards/
    
    # 复制内核配置
    cp config/kernel/arm64-edge.config build/config/kernel/
    
    # 复制自定义脚本
    mkdir -p build/userpatches
    cp scripts/*.sh build/userpatches/
    chmod +x build/userpatches/*.sh
    
    # 复制补丁（如果有）
    if [ -d "patches" ]; then
        cp -r patches/* build/patches/
    fi
}

# 执行构建
run_build() {
    cd build
    
    echo "开始构建 Armbian..."
    
    # 交互式构建
    if [ "$1" = "interactive" ]; then
        ./compile.sh
    else
        # 自动构建
        ./compile.sh \
            BOARD=xf-a311d2 \
            BRANCH=edge \
            RELEASE=bookworm \
            BUILD_DESKTOP=yes \
            DESKTOP_ENVIRONMENT=xfce \
            KERNEL_CONFIGURE=yes \
            BUILD_MINIMAL=no \
            EXPERT=yes
    fi
    
    cd ..
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  interactive    交互式构建"
    echo "  help          显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0             自动构建"
    echo "  $0 interactive 交互式构建"
}

# 主函数
main() {
    case "$1" in
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        "interactive")
            MODE="interactive"
            ;;
        *)
            MODE="auto"
            ;;
    esac
    
    check_dependencies
    setup_build_system
    copy_configs
    run_build "$MODE"
    
    echo "=== 构建完成 ==="
    echo "镜像位置: build/output/images/"
}

main "$@"
