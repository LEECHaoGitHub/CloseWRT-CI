#!/bin/bash

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
# sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_FILE="./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"
#修改WIFI名称
sed -i "s/ImmortalWrt/$WRT_SSID/g" $WIFI_FILE
#修改WIFI加密
sed -i "s/encryption=.*/encryption='psk2+ccmp'/g" $WIFI_FILE
#修改WIFI密码
sed -i "/set wireless.default_\${dev}.encryption='psk2+ccmp'/a \\\t\t\t\t\t\set wireless.default_\${dev}.key='$WRT_WORD'" $WIFI_FILE

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

# =========================================================
# 4. 内核配置追加
# =========================================================
for conf in target/linux/mediatek/filogic/config-*; do
cat >> $conf << 'EOF'

# =========================================================
# Cgroup v2（daed 必需，精简版）
# =========================================================
CONFIG_CGROUPS=y
CONFIG_CGROUP_BPF=y
CONFIG_SOCK_CGROUP_DATA=y

# =========================================================
# eBPF / Daed 核心
# =========================================================
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_UNPRIV_DEFAULT_OFF=y

# =========================================================
# eBPF 网络调度
# =========================================================
CONFIG_NET_SCHED=y
CONFIG_NET_CLS=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_ACT_BPF=m
CONFIG_NET_CLS_BPF=m

# =========================================================
# XDP / 高速数据路径
# =========================================================
CONFIG_XDP_SOCKETS=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_NET_SOCK_MSG=y

# =========================================================
# 网络命名空间 & 诊断
# =========================================================
CONFIG_NET_NS=y
CONFIG_INET_DIAG=y
CONFIG_INET_TCP_DIAG=y

# =========================================================
# TCP 优化（不改 choice 默认值）
# =========================================================
CONFIG_SYN_COOKIES=y
CONFIG_TCP_FASTOPEN=y

# =========================================================
# Conntrack 优化
# =========================================================
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_TIMESTAMP=y
CONFIG_NF_CONNTRACK_LABELS=y
CONFIG_NF_CT_NETLINK=y

# =========================================================
# 加密补充
# =========================================================
CONFIG_CRYPTO_CHACHA20POLY1305=y

EOF
done

# =========================================================
# 5. 网络参数优化（sysctl）
# =========================================================
mkdir -p files/etc/sysctl.d/

cat > files/etc/sysctl.d/99-proxy-optimize.conf << 'SYSCTL'
# ---------------------------------------------------------
# Conntrack（daed/代理高并发必需）
# ---------------------------------------------------------
# 默认 16384，代理场景适当放大
net.netfilter.nf_conntrack_max=32768
# 默认 432000(5天)，缩短回收空闲连接
net.netfilter.nf_conntrack_tcp_timeout_established=3600
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=120

# ---------------------------------------------------------
# TCP 优化
# ---------------------------------------------------------
net.core.netdev_max_backlog=2048
net.core.somaxconn=2048
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_max_tw_buckets=8192

# ---------------------------------------------------------
# 缓冲区（适配 256MB 路由器）
# ---------------------------------------------------------
# 单 socket 最大收/发缓冲 4MB（默认 208KB）
net.core.rmem_max=4194304
net.core.wmem_max=4194304
# TCP 自动调优：min=4KB, default=128KB, max=4MB
net.ipv4.tcp_rmem=4096 131072 4194304
net.ipv4.tcp_wmem=4096 65536 4194304
# UDP 内存限制（单位：页=4KB）：min=32MB pressure=48MB max=64MB
net.ipv4.udp_mem=8192 12288 16384

# ---------------------------------------------------------
# 本地端口范围
# ---------------------------------------------------------
net.ipv4.ip_local_port_range=1024 65535
SYSCTL

echo "✅ 网络优化参数已写入"
