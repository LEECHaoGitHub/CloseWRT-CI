#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " "

	cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#5e72e4'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样
if [ -d *"luci-app-aurora-config"* ]; then
	echo " "

	cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/ -type f -name "*aurora")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

# =========================================================
# 修复 eBPF 与 Daed 的内核依赖冲突 (终极性能版)
# =========================================================
echo ">>> [Kernel] 正在修复 eBPF/Daed 编译依赖..."

# 1. 解决 vmlinux-btf 依赖警告
find package feeds -name "Makefile" -path "*/daed/*" 2>/dev/null | xargs sed -i 's/+vmlinux-btf//g' 2>/dev/null || true
echo "✅ 移除了 Daed 中的 vmlinux-btf 虚拟依赖。"

# 2. 强行打通内核 BPF 与 TC (Traffic Control) 前置依赖
for conf in target/linux/mediatek/filogic/config-*; do
    # 【关键修正】：if 和 [ 之间必须有空格！
    if [ -f "$conf" ]; then
        echo ">>> 正在为 $conf 注入 eBPF/TC 核心与极致性能配置..."
        
        # --- 1. 流量控制 (TC) 前置大门 (缺失会导致 act_bpf 丢失) ---
        echo "CONFIG_NET_SCHED=y" >> "$conf"
        echo "CONFIG_NET_CLS=y" >> "$conf"
        echo "CONFIG_NET_CLS_ACT=y" >> "$conf"
        echo "CONFIG_NET_INGRESS=y" >> "$conf"
        echo "CONFIG_NET_EGRESS=y" >> "$conf"
        
        # --- 2. BPF 核心与模块 ---
        echo "CONFIG_NET_CLS_BPF=m" >> "$conf"
        echo "CONFIG_NET_ACT_BPF=m" >> "$conf"
        echo "CONFIG_BPF=y" >> "$conf"
        echo "CONFIG_BPF_SYSCALL=y" >> "$conf"
        echo "CONFIG_CGROUP_BPF=y" >> "$conf"
        echo "CONFIG_DEBUG_INFO_BTF=y" >> "$conf"
        
        # --- 3. BPF 极致性能优化 (榨干路由器算力) ---
        echo "CONFIG_BPF_JIT=y" >> "$conf"
        echo "CONFIG_BPF_JIT_ALWAYS_ON=y" >> "$conf"
        echo "CONFIG_BPF_STREAM_PARSER=y" >> "$conf"
        echo "CONFIG_NET_SOCK_MSG=y" >> "$conf"
        echo "CONFIG_XDP_SOCKETS=y" >> "$conf"
        
        echo "✅ eBPF 高性能与底层网络调度配置注入完成。"
    fi
done

#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "

	sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "diskman has been fixed!"
fi

#修复luci-app-netspeedtest相关问题
if [ -d *"luci-app-netspeedtest"* ]; then
	echo " "

	cd ./luci-app-netspeedtest/

	sed -i '$a\exit 0' ./netspeedtest/files/99_netspeedtest.defaults
	sed -i 's/ca-certificates/ca-bundle/g' ./speedtest-cli/Makefile

	cd $PKG_PATH && echo "netspeedtest has been fixed!"
fi
