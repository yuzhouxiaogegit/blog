#!/bin/bash

# =============================================================
# Xray + Reality + Xhttp 安装与流量统计脚本 (兼容优化版)
# =============================================================

# -------------------------------------------------------------
# 颜色定义
# -------------------------------------------------------------
NC='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

C_TITLE="${GREEN}"
C_MENU="${YELLOW}"
C_EXIT="${RED}"
C_ERROR="${RED}"

# -------------------------------------------------------------
# 基础工具函数
# -------------------------------------------------------------

check_cmd() { command -v "$1" &>/dev/null; }

# 获取包管理器
get_pkg_manager() {
    if   check_cmd apt-get; then echo "apt"
    elif check_cmd dnf;     then echo "dnf"
    elif check_cmd yum;     then echo "yum"
    elif check_cmd zypper;  then echo "zypper"
    elif check_cmd pacman;  then echo "pacman"
    elif check_cmd apk;     then echo "apk"
    else echo "unknown"
    fi
}

# 检测服务管理器
get_service_manager() {
    if check_cmd systemctl && systemctl list-units &>/dev/null 2>&1; then echo "systemd"
    elif check_cmd rc-service; then echo "openrc"
    elif [[ -d /etc/init.d ]];  then echo "sysvinit"
    else echo "unknown"
    fi
}

# URL 编码（hostname 中常见字符）
url_encode() {
    echo "$1" | sed 's/ /%20/g; s/#/%23/g; s/@/%40/g; s/&/%26/g; s/=/%3D/g'
}

# 生成 UUID v4
gen_uuid() {
    if [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    elif check_cmd uuidgen; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        local b; b=$(openssl rand -hex 16)
        printf '%s-%s-%s-%s-%s\n' \
            "${b:0:8}" "${b:8:4}" "4${b:13:3}" \
            "$(printf '%x' $(( (16#${b:16:2} & 0x3f) | 0x80 )))${b:18:2}" \
            "${b:20:12}"
    fi
}

# 人性化字节显示
human_bytes() {
    awk -v b="${1:-0}" 'BEGIN {
        split("B KB MB GB TB", u); i=1; v=b
        while (v >= 1024 && i < 5) { v /= 1024; i++ }
        printf "%.1f%s\n", v, u[i]
    }'
}

# 生成随机字符串（fallback，基础库加载后会被覆盖）
yzxg_random_str() {
    local min=${1:-5} max=${2:-10}
    local len=$(( min + RANDOM % (max - min + 1) ))
    local chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result=''
    for (( i=0; i<len; i++ )); do
        result+="${chars:$(( RANDOM % ${#chars} )):1}"
    done
    echo "$result"
}

# 生成随机整数（fallback）
yzxg_random_num() {
    local min=${1:-1} max=${2:-10}
    echo $(( min + RANDOM % (max - min + 1) ))
}

# 彩色输出（fallback）
yzxg_echo_txt_color() {
    local text="$1" color="$2"
    case "$color" in
        green)  echo -e "${GREEN}${text}${NC}" ;;
        red)    echo -e "${RED}${text}${NC}" ;;
        yellow) echo -e "${YELLOW}${text}${NC}" ;;
        *)      echo -e "${text}" ;;
    esac
}

# 获取 xray 最新版本号
get_xray_version() {
    if declare -f yzxg_get_new_version_num > /dev/null 2>&1; then
        yzxg_get_new_version_num 'https://github.com/XTLS/Xray-core/releases'
    else
        timeout 10 curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" \
            | grep '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/' | head -n1
    fi
}

# 获取 CPU 架构
get_cpu_arch() {
    if declare -f yzxg_get_cpu_arch > /dev/null 2>&1; then
        yzxg_get_cpu_arch
    else
        case "$(uname -m)" in
            x86_64)  echo "64" ;;
            aarch64) echo "arm64-v8a" ;;
            armv7*)  echo "arm32-v7a" ;;
            *)       echo "64" ;;
        esac
    fi
}

# 获取 SSH 端口
get_ssh_port() {
    local port
    port=$(grep -E '^Port ' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    if [[ -z "$port" ]]; then
        if check_cmd ss; then
            port=$(ss -tlpn 2>/dev/null | grep sshd \
                | awk -F'[: ]+' '{for(i=1;i<=NF;i++) if($i~/^[0-9]+$/ && $i+0>1 && $i+0<65536){print $i; exit}}' \
                | head -n1)
        elif check_cmd netstat; then
            port=$(netstat -tlpn 2>/dev/null | grep sshd \
                | awk -F'[: ]+' '{for(i=1;i<=NF;i++) if($i~/^[0-9]+$/ && $i+0>1 && $i+0<65536){print $i; exit}}' \
                | head -n1)
        fi
    fi
    echo "${port:-22}"
}

# -------------------------------------------------------------
# 包管理 & 依赖安装
# -------------------------------------------------------------

# 等待 apt 锁释放（兼容无 fuser/lsof 环境，直接用 apt-get 返回值判断）
wait_apt_lock() {
    local i=0
    while true; do
        # 优先用 fuser 检测
        if check_cmd fuser; then
            local locks="/var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock"
            # shellcheck disable=SC2086
            fuser $locks &>/dev/null 2>&1 || break
        elif check_cmd lsof; then
            local locked=0
            for f in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock; do
                lsof "$f" &>/dev/null 2>&1 && locked=1 && break
            done
            [[ $locked -eq 0 ]] && break
        else
            # 无检测工具：直接尝试 apt-get，失败则等待
            apt-get -qq -o DPkg::Lock::Timeout=1 check &>/dev/null 2>&1 && break
        fi
        (( i == 0 )) && echo -e "${YELLOW}检测到 apt 锁被占用，等待释放（最多 120 秒）...${NC}"
        (( ++i > 120 )) && { echo -e "${RED}错误：等待 apt 锁超时，请稍后重试！${NC}"; exit 1; }
        sleep 1
    done
}

# 安装一个或多个包（自动适配包管理器）
install_pkg() {
    local pkgs=("$@")
    local mgr; mgr=$(get_pkg_manager)
    case "$mgr" in
        apt)
            wait_apt_lock
            apt-get update -qq 2>/dev/null || true
            wait_apt_lock
            apt-get install -y "${pkgs[@]}"
            ;;
        dnf)    dnf install -y "${pkgs[@]}" ;;
        yum)    yum install -y "${pkgs[@]}" ;;
        zypper) zypper install -y "${pkgs[@]}" ;;
        pacman) pacman -Sy --noconfirm "${pkgs[@]}" ;;
        apk)    apk add --no-cache "${pkgs[@]}" ;;
        *)
            echo -e "${C_ERROR}错误：未识别的包管理器，请手动安装: ${pkgs[*]}${NC}"
            return 1
            ;;
    esac
}

# 安装所有运行依赖
install_deps() {
    local mgr; mgr=$(get_pkg_manager)
    case "$mgr" in
        apt)     install_pkg curl wget unzip openssl iproute2 ufw gawk ;;
        dnf|yum) install_pkg curl wget unzip openssl iproute firewalld gawk ;;
        zypper)  install_pkg curl wget unzip openssl iproute2 firewalld gawk ;;
        pacman)  install_pkg curl wget unzip openssl iproute2 ufw gawk ;;
        apk)     install_pkg curl wget unzip openssl iproute2 iptables ip6tables gawk ;;
        *)
            echo -e "${C_ERROR}错误：不支持的包管理器，请手动安装依赖。${NC}"
            return 1
            ;;
    esac
}

# 确保 curl 已安装（在加载基础库前调用）
ensure_curl() {
    check_cmd curl && return 0
    echo -e "${YELLOW}未检测到 curl，正在尝试安装...${NC}"
    install_pkg curl || { echo -e "${RED}错误：无法自动安装 curl，请手动安装后重试！${NC}"; exit 1; }
    check_cmd curl  || { echo -e "${RED}错误：curl 安装失败，请手动安装后重试！${NC}"; exit 1; }
    echo -e "${GREEN}curl 安装成功。${NC}"
}

# -------------------------------------------------------------
# 修复各发行版已停止维护的官方源
# -------------------------------------------------------------

# 检测是否可访问阿里云镜像
_can_reach_aliyun() { timeout 5 curl -s https://mirrors.aliyun.com > /dev/null 2>&1; }

# 写入 apt sources.list 并禁用有效期检查（从 stdin 读取内容）
_write_apt_sources() {
    local sources=/etc/apt/sources.list
    cp "$sources" "${sources}.bak" 2>/dev/null
    cat > "$sources"
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until
    wait_apt_lock
    apt-get update -qq 2>/dev/null || true
}

# 修复 Debian / Ubuntu 旧版本源（统一处理）
fix_apt_repo() {
    [[ "$(get_pkg_manager)" != "apt" ]] && return 0

    wait_apt_lock
    apt-get update -qq &>/dev/null 2>&1 && return 0

    local distro="" codename=""
    if [[ -f /etc/lsb-release ]] && grep -q "Ubuntu" /etc/lsb-release 2>/dev/null; then
        distro="Ubuntu"
        codename=$(grep "DISTRIB_CODENAME" /etc/lsb-release | cut -d= -f2)
        case "$codename" in
            trusty|xenial|bionic|eoan|disco|cosmic|artful|zesty|yakkety|wily|vivid|utopic|saucy|raring|quantal|oneiric|natty|maverick|lucid) ;;
            *) return 0 ;;
        esac
    elif [[ -f /etc/debian_version ]]; then
        distro="Debian"
        codename=$(grep "^VERSION_CODENAME=" /etc/os-release 2>/dev/null | cut -d= -f2)
        [[ -z "$codename" ]] && codename=$(lsb_release -cs 2>/dev/null)
        case "$codename" in
            buster|stretch|jessie|wheezy) ;;
            *) return 0 ;;
        esac
    else
        return 0
    fi

    echo -e "${YELLOW}检测到 ${distro} ${codename} 官方源已下线，正在自动切换到存档镜像...${NC}"

    if [[ "$distro" == "Ubuntu" ]]; then
        if _can_reach_aliyun; then
            _write_apt_sources << EOF
deb https://mirrors.aliyun.com/ubuntu-old-releases/ubuntu/ ${codename} main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu-old-releases/ubuntu/ ${codename}-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu-old-releases/ubuntu/ ${codename}-security main restricted universe multiverse
EOF
        else
            _write_apt_sources << EOF
deb http://old-releases.ubuntu.com/ubuntu/ ${codename} main restricted universe multiverse
deb http://old-releases.ubuntu.com/ubuntu/ ${codename}-updates main restricted universe multiverse
deb http://old-releases.ubuntu.com/ubuntu/ ${codename}-security main restricted universe multiverse
EOF
        fi
    else
        if _can_reach_aliyun; then
            _write_apt_sources << EOF
deb https://mirrors.aliyun.com/debian-archive/debian/ ${codename} main contrib non-free
deb https://mirrors.aliyun.com/debian-archive/debian/ ${codename}-updates main contrib non-free
deb https://mirrors.aliyun.com/debian-archive/debian-security/ ${codename}/updates main contrib non-free
EOF
        else
            _write_apt_sources << EOF
deb http://archive.debian.org/debian/ ${codename} main contrib non-free
deb http://archive.debian.org/debian/ ${codename}-updates main contrib non-free
deb http://archive.debian.org/debian-security/ ${codename}/updates main contrib non-free
EOF
        fi
    fi

    echo -e "${GREEN}${distro} ${codename} 源修复完成。${NC}"
}

# 修复 CentOS 7 / CentOS Stream 8 官方源下线问题
fix_centos_repo() {
    [[ ! -f /etc/centos-release ]] && return 0

    local centos_ver=""
    if grep -q "CentOS Linux release 7" /etc/centos-release 2>/dev/null; then
        centos_ver="7"
    elif grep -qE "CentOS Stream release 8|CentOS Linux release 8" /etc/centos-release 2>/dev/null; then
        centos_ver="8"
    else
        return 0
    fi

    { dnf makecache -q &>/dev/null 2>&1 || yum makecache -q &>/dev/null 2>&1; } && return 0

    echo -e "${YELLOW}检测到 CentOS ${centos_ver} 官方源已下线，正在自动切换到存档镜像...${NC}"

    local repo_dir=/etc/yum.repos.d
    mkdir -p "${repo_dir}/backup"
    mv "${repo_dir}"/CentOS-*.repo "${repo_dir}/backup/" 2>/dev/null

    if [[ "$centos_ver" == "7" ]]; then
        if _can_reach_aliyun; then
            curl -sL -o "${repo_dir}/CentOS-Base.repo" \
                https://mirrors.aliyun.com/repo/Centos-vault-7.9.2009.repo
        fi
        # 验证下载内容是否合法（必须包含 ini section 头）
        if ! grep -q '^\[' "${repo_dir}/CentOS-Base.repo" 2>/dev/null; then
            cat > "${repo_dir}/CentOS-Base.repo" << 'EOF'
[base]
name=CentOS-7 - Base
baseurl=http://vault.centos.org/7.9.2009/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-7 - Updates
baseurl=http://vault.centos.org/7.9.2009/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-7 - Extras
baseurl=http://vault.centos.org/7.9.2009/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
        fi
        yum clean all -q && yum makecache -q
    else
        if _can_reach_aliyun; then
            curl -sL -o "${repo_dir}/CentOS-Base.repo" \
                https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo
        fi
        # 验证下载内容是否合法
        if ! grep -q '^\[' "${repo_dir}/CentOS-Base.repo" 2>/dev/null; then
            cat > "${repo_dir}/CentOS-Base.repo" << 'EOF'
[baseos]
name=CentOS-8 - Base
baseurl=https://vault.centos.org/8.5.2111/BaseOS/$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[appstream]
name=CentOS-8 - AppStream
baseurl=https://vault.centos.org/8.5.2111/AppStream/$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[extras]
name=CentOS-8 - Extras
baseurl=https://vault.centos.org/8.5.2111/extras/$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF
        fi
        dnf clean all -q && dnf makecache -q
    fi

    echo -e "${GREEN}CentOS ${centos_ver} 源修复完成。${NC}"
}

# 修复旧版本系统源（统一入口）
fix_repo() {
    case "$(get_pkg_manager)" in
        apt)     fix_apt_repo ;;
        dnf|yum) fix_centos_repo ;;
    esac
}

# -------------------------------------------------------------
# 防火墙管理
# -------------------------------------------------------------

# iptables 放行单个端口（同时处理 ipv4 / ipv6）
_iptables_allow() {
    local port="$1"
    for ipt in iptables ip6tables; do
        check_cmd "$ipt" || continue
        $ipt -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
            $ipt -I INPUT -p tcp --dport "$port" -j ACCEPT
    done
}

# iptables 规则持久化
_iptables_save() {
    if check_cmd netfilter-persistent; then
        netfilter-persistent save
        return
    fi
    if ! check_cmd iptables-save; then
        echo -e "${YELLOW}警告：iptables 规则已生效但无法持久化，重启后需重新设置。${NC}"
        return
    fi

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    check_cmd ip6tables-save && ip6tables-save > /etc/iptables/rules.v6

    case "$(get_service_manager)" in
        systemd)
            cat > /etc/systemd/system/iptables-restore.service << 'EOF'
[Unit]
Description=Restore iptables rules
Before=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
ExecStart=/sbin/ip6tables-restore /etc/iptables/rules.v6
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable iptables-restore.service
            ;;
        openrc)
            cp /etc/iptables/rules.v4 /etc/iptables/rules 2>/dev/null
            rc-update add iptables default 2>/dev/null || true
            ;;
        sysvinit)
            local rc_local=/etc/rc.local
            if [[ -f "$rc_local" ]] && ! grep -q "iptables-restore" "$rc_local"; then
                sed -i '/^exit 0/i iptables-restore < /etc/iptables/rules.v4' "$rc_local"
            fi
            ;;
    esac
}

# 开放防火墙端口（自动适配 firewalld / ufw / iptables）
open_firewall_port() {
    local port="$1"
    local ssh_port; ssh_port=$(get_ssh_port)

    if check_cmd firewall-cmd && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --zone=public --add-port="${port}/tcp" --permanent 2>/dev/null
        [[ -n "$ssh_port" ]] && firewall-cmd --zone=public --add-port="${ssh_port}/tcp" --permanent 2>/dev/null
        firewall-cmd --reload
    elif check_cmd ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "${ssh_port}/tcp" 2>/dev/null
        ufw allow "${port}/tcp" comment "Allow Xray" 2>/dev/null
        ufw reload 2>/dev/null
    elif check_cmd iptables; then
        _iptables_allow "$port"
        [[ -n "$ssh_port" ]] && _iptables_allow "$ssh_port"
        _iptables_save
    else
        echo -e "${YELLOW}提示：未检测到激活的防火墙，请通过云服务商安全组放行端口 $port。${NC}"
    fi
}

# -------------------------------------------------------------
# 服务管理
# -------------------------------------------------------------

# 启用并启动服务
service_enable_start() {
    local svc="$1"
    case "$(get_service_manager)" in
        systemd)
            systemctl daemon-reload
            systemctl enable "$svc"
            systemctl restart "$svc"
            ;;
        openrc)
            rc-update add "$svc" default
            rc-service "$svc" restart
            ;;
        sysvinit)
            chmod +x "/etc/init.d/$svc" 2>/dev/null
            if check_cmd update-rc.d; then
                update-rc.d "$svc" defaults
            elif check_cmd chkconfig; then
                chkconfig --add "$svc"
                chkconfig "$svc" on
            else
                echo -e "${YELLOW}警告：无法注册开机启动，请手动配置 $svc。${NC}"
            fi
            "/etc/init.d/$svc" restart
            ;;
        *)
            echo -e "${C_ERROR}警告：无法自动管理服务 $svc，请手动启动。${NC}"
            ;;
    esac
}

# 查看服务状态
service_status() {
    local svc="$1"
    case "$(get_service_manager)" in
        systemd) systemctl status "$svc" --no-pager ;;
        openrc)  rc-service "$svc" status ;;
        *)       echo "无法获取服务状态" ;;
    esac
}

# 创建并注册 xray 服务（自动适配服务管理器）
register_xray_service() {
    case "$(get_service_manager)" in
        systemd)
            cat > /etc/systemd/system/xray.service << 'EOF'
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
            service_enable_start xray.service
            ;;
        openrc)
            cat > /etc/init.d/xray << 'EOF'
#!/sbin/openrc-run
name="xray"
description="Xray Service"
command="/usr/local/bin/xray"
command_args="run -config /usr/local/etc/xray/config.json"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/xray/access.log"
error_log="/var/log/xray/error.log"

depend() {
    need net
    after firewall
}
EOF
            chmod +x /etc/init.d/xray
            service_enable_start xray
            ;;
        *)
            echo -e "${C_ERROR}警告：不支持的服务管理器，请手动启动 xray。${NC}"
            echo "手动启动: /usr/local/bin/xray run -config /usr/local/etc/xray/config.json &"
            ;;
    esac
}

# -------------------------------------------------------------
# 菜单框架
# -------------------------------------------------------------
config_menu() {
    local menu_title="$1"
    local options_text=("${!2}") options_func=("${!3}")
    local count=${#options_text[@]}
    local exit_index=$((count + 1))
    local choice

    while true; do
        clear
        echo -e "${C_TITLE}====================================${NC}"
        echo -e "${C_TITLE}       $menu_title ${NC}"
        echo -e "${C_TITLE}====================================${NC}"
        for i in "${!options_text[@]}"; do
            echo -e "${C_MENU}$((i+1)). ${options_text[$i]}${NC}"
        done
        echo -e "${C_EXIT}$exit_index. 退出脚本${NC}"
        echo -e "${C_TITLE}------------------------------------${NC}"
        read -rp "请输入选项 [1-$exit_index] 或 q 退出: " choice

        case "$choice" in
            q|Q|"$exit_index")
                echo -e "\n${C_MENU}退出中...再见！${NC}\n"
                return 0
                ;;
            [1-9]|[1-9][0-9])
                if (( choice >= 1 && choice <= count )); then
                    echo -e "\n--- 正在执行: ${options_text[$((choice-1))]} ---"
                    ${options_func[$((choice-1))]}
                    echo -e "--- 执行完毕 ---\n"
                    read -rp "按任意键返回菜单..."
                else
                    echo -e "\n${C_ERROR}错误：选项 '$choice' 无效。${NC}"; sleep 1
                fi
                ;;
            *)
                echo -e "\n${C_ERROR}错误：无效输入 '$choice'。${NC}"; sleep 1
                ;;
        esac
    done
}

# -------------------------------------------------------------
# 安装 xray + reality + xhttp
# -------------------------------------------------------------
xhttp_install() {
    local xrayDomainList=("www.amazon.com" "www.tesla.com" "www.apple.com")
    read -rp "请输入境外域名，需支持 h2/h3（默认随机热门域名）: " xrayDomain
    [[ -z "$xrayDomain" ]] && xrayDomain="${xrayDomainList[$(( RANDOM % ${#xrayDomainList[@]} ))]}"

    read -rp "请输入生成用户数量（默认 10）: " userNum
    [[ -z "$userNum" || ! "$userNum" =~ ^[0-9]+$ ]] && userNum=10

    local xrayPath; xrayPath=$(yzxg_random_str 5 11)
    local xrayPort=443

    echo -e "${C_TITLE}正在安装依赖...${NC}"
    fix_repo
    install_deps || return 1
    open_firewall_port "$xrayPort"

    # 获取公网 IP（优先 IPv4，fallback IPv6）
    local currentIp
    currentIp=$(timeout 5 curl -s https://ipv4.icanhazip.com 2>/dev/null)
    [[ -z "$currentIp" ]] && currentIp=$(timeout 5 curl -s https://api.ipify.org 2>/dev/null)
    [[ -z "$currentIp" ]] && currentIp=$(timeout 5 curl -s https://ipv6.icanhazip.com 2>/dev/null)
    [[ -z "$currentIp" ]] && currentIp=$(timeout 5 curl -s -6 https://api.ipify.org 2>/dev/null)
    if [[ -z "$currentIp" ]]; then
        echo -e "${C_ERROR}错误：无法获取本机公网 IP，请检查网络连接！${NC}"
        return 1
    fi

    mkdir -p /usr/local/bin /usr/local/etc/xray /usr/local/share/xray /var/log/xray

    # 下载 xray
    echo -e "${C_TITLE}正在下载 xray...${NC}"
    local xrayVersion; xrayVersion=$(get_xray_version)
    [[ -z "$xrayVersion" ]] && { echo -e "${C_ERROR}错误：无法获取 xray 最新版本号。${NC}"; return 1; }

    curl -s -L -o /tmp/xray.zip \
        "https://github.com/XTLS/Xray-core/releases/download/${xrayVersion}/Xray-linux-$(get_cpu_arch).zip" \
        && unzip -oq /tmp/xray.zip -d /usr/local/bin
    rm -f /tmp/xray.zip
    chmod +x /usr/local/bin/xray

    # 生成 x25519 密钥对
    local tempKey="/tmp/xray_key_$$.txt"
    /usr/local/bin/xray x25519 > "$tempKey"
    local xrayPrivateKey xrayPublicKey
    xrayPrivateKey=$(awk 'tolower($0) ~ /private/ {print $NF}' "$tempKey" | head -n1)
    xrayPublicKey=$(awk  'tolower($0) ~ /public/  {print $NF}' "$tempKey" | head -n1)
    rm -f "$tempKey"

    if [[ -z "$xrayPrivateKey" || -z "$xrayPublicKey" ]]; then
        echo -e "${C_ERROR}错误：密钥解析失败，请检查 xray 版本输出格式。${NC}"
        /usr/local/bin/xray x25519
        return 1
    fi

    # 生成用户列表与分享链接
    local fpList=("chrome" "firefox" "safari" "edge")
    local levelId=1
    local shortIds='' xrayUserJson='' shareLinks=''
    # IPv6 地址加方括号
    local shareIp="$currentIp"
    [[ "$shareIp" =~ : ]] && shareIp="[$shareIp]"

    for (( i=1; i<=userNum; i++ )); do
        local sid; sid=$(openssl rand -hex "$(yzxg_random_num 2 8)")
        local userId; userId=$(gen_uuid)
        local fp="${fpList[$(( RANDOM % ${#fpList[@]} ))]}"
        local remark; remark=$(url_encode "$(hostname)-User${i}")

        shortIds+="\"${sid}\","
        xrayUserJson+="{\"id\":\"${userId}\",\"level\":${levelId},\"email\":\"$(yzxg_random_str 8 12)@xhttp.com\"},"
        shareLinks+="vless://${userId}@${shareIp}:${xrayPort}?encryption=none&security=reality&sni=${xrayDomain}&fp=${fp}&pbk=${xrayPublicKey}&sid=${sid}&spx=%2F${xrayPath}&type=xhttp&path=%2F${xrayPath}&mode=auto#${remark}\n\n"
    done

    # 写入配置文件
    cat > /usr/local/etc/xray/config.json << EOF
{
  "log": { "loglevel": "warning" },
  "stats": {},
  "api": { "tag": "api", "services": ["StatsService"] },
  "policy": {
    "levels": { "${levelId}": { "statsUserUplink": true, "statsUserDownlink": true } },
    "system": {
      "statsInboundUplink": true, "statsInboundDownlink": true,
      "statsOutboundUplink": true, "statsOutboundDownlink": true
    }
  },
  "inbounds": [
    {
      "tag": "tcp", "listen": "0.0.0.0", "port": ${xrayPort},
      "protocol": "vless",
      "settings": { "clients": [${xrayUserJson%?}], "decryption": "none" },
      "streamSettings": {
        "network": "xhttp", "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "${xrayDomain}:${xrayPort}",
          "serverNames": ["${xrayDomain}"],
          "privateKey": "${xrayPrivateKey}",
          "shortIds": [${shortIds%?}]
        },
        "xhttpSettings": { "host": "", "path": "/${xrayPath}", "mode": "auto" }
      },
      "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"], "metadataOnly": false }
    },
    {
      "listen": "127.0.0.1", "port": 10085,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" },
      "tag": "api"
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom", "settings": {} },
    { "tag": "blocked", "protocol": "blackhole", "settings": {} }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "type": "field", "outboundTag": "blocked", "domain": ["geosite:category-ads-all"] },
      { "type": "field", "inboundTag": ["api"], "outboundTag": "api" },
      { "type": "field", "protocol": ["bittorrent"], "outboundTag": "direct" },
      { "type": "field", "ip": ["geoip:private","geoip:cn"], "outboundTag": "direct" },
      { "type": "field", "domain": ["geosite:cn"], "outboundTag": "direct" }
    ]
  }
}
EOF

    register_xray_service
    sleep 2
    service_status xray 2>/dev/null || service_status xray.service 2>/dev/null

    # 写入自动更新脚本
    cat > /opt/update_xray.sh << 'UPDEOF'
#!/usr/bin/env bash
source <(timeout 5 curl -sL https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/base_fun.sh) 2>/dev/null

get_xray_version() {
    if declare -f yzxg_get_new_version_num > /dev/null 2>&1; then
        yzxg_get_new_version_num 'https://github.com/XTLS/Xray-core/releases'
    else
        timeout 10 curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" \
            | grep '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/' | head -n1
    fi
}

get_cpu_arch() {
    if declare -f yzxg_get_cpu_arch > /dev/null 2>&1; then
        yzxg_get_cpu_arch
    else
        case "$(uname -m)" in
            x86_64)  echo "64" ;;
            aarch64) echo "arm64-v8a" ;;
            armv7*)  echo "arm32-v7a" ;;
            *)       echo "64" ;;
        esac
    fi
}

ver=$(get_xray_version)
[[ -z "$ver" ]] && exit 1
curl -s -L -o /tmp/xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${ver}/Xray-linux-$(get_cpu_arch).zip" \
    && unzip -oq /tmp/xray.zip -d /usr/local/bin
rm -f /tmp/xray.zip
chmod +x /usr/local/bin/xray
command -v systemctl &>/dev/null && systemctl restart xray.service && exit 0
command -v rc-service &>/dev/null && rc-service xray restart
UPDEOF
    chmod +x /opt/update_xray.sh

    # 注册每月自动更新 cron（幂等）
    (crontab -l 2>/dev/null | grep -q "update_xray.sh") || \
        { crontab -l 2>/dev/null; echo "01 3 1 * * /opt/update_xray.sh"; } | crontab -

    echo -e "\n"
    yzxg_echo_txt_color "========= 节点配置信息 =========" "green"
    echo -e "\n${GREEN}${shareLinks}${NC}"
}

# -------------------------------------------------------------
# xray 流量统计
# -------------------------------------------------------------
xray_traffic() {
    local _APISERVER=127.0.0.1:10085
    local _XRAY=/usr/local/bin/xray

    [[ ! -x "$_XRAY" ]] && { echo -e "${C_ERROR}错误：xray 未安装。${NC}"; return 1; }

    # 查询流量原始数据，输出格式: "类型:名称->方向\t字节数"
    _apidata() {
        local args=''
        [[ "$1" == "reset" ]] && args="-reset=true"
        $_XRAY api statsquery --server="$_APISERVER" $args \
        | awk '{
            if (match($1, /"name":/)) {
                f=1; gsub(/^"|",$/, "", $2); gsub(/,$/, "", $2);
                split($2, p, ">>>");
                printf "%s:%s->%s\t", p[1], p[2], p[4];
            } else if (match($1, /"value":/) && f) {
                f=0; gsub(/"/, "", $2); printf "%.0f\n", $2;
            } else if (match($0, /}/) && f) {
                f=0; print 0;
            }
        }'
    }

    # 打印指定前缀的流量汇总
    _print_sum() {
        local data="$1" prefix="$2"
        local sorted sum
        sorted=$(echo "$data" | grep "^${prefix}" | sort -r)
        sum=$(echo "$sorted" | awk '
            /->up/   { us += $2 }
            /->down/ { ds += $2 }
            END { printf "SUM->up\t%.0f\nSUM->down\t%.0f\nSUM->TOTAL\t%.0f\n", us, ds, us+ds }
        ')
        printf "%s\n%s\n" "$sorted" "$sum" | while IFS=$(printf '\t') read -r name bytes; do
            printf "%-40s %s\n" "$name" "$(human_bytes "${bytes:-0}")"
        done
    }

    local data; data=$(_apidata "$1")
    echo "------------ Inbound ------------"
    _print_sum "$data" "inbound"
    echo "------------ Outbound -----------"
    _print_sum "$data" "outbound"
    echo -e "${C_TITLE}------------- User --------------${NC}"
    _print_sum "$data" "user"
    echo -e "${C_TITLE}---------------------------------${NC}"
}

# -------------------------------------------------------------
# 初始化（root 检查 → 安装 curl → 加载基础库 → 进入菜单）
# -------------------------------------------------------------
[[ $EUID -ne 0 ]] && { echo -e "\033[0;31m错误：必须使用 root 用户运行此脚本！\033[0m"; exit 1; }

ensure_curl

if ! source <(timeout 5 curl -sL https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/base_fun.sh); then
    echo -e "${RED}错误：基础工具库加载失败，请检查网络连接！${NC}"; exit 1
fi
if ! declare -f yzxg_get_new_version_num > /dev/null 2>&1; then
    echo -e "${RED}错误：基础工具库函数未正确加载，请检查网络连接！${NC}"; exit 1
fi

clear

# -------------------------------------------------------------
# 菜单入口
# -------------------------------------------------------------
declare -a MY_TEXT=("安装 xray + reality + xhttp" "统计 xray 每月流量使用情况")
declare -a MY_FUNC=("xhttp_install" "xray_traffic")

config_menu "xray 安装面板" MY_TEXT[@] MY_FUNC[@]
