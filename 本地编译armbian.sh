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


