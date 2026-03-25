#!/bin/bash

# =============================================================
# Xray + Reality + Xhttp 安装与流量统计脚本 (兼容优化版)
# =============================================================

if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31m错误：必须使用 root 用户运行此脚本！\033[0m"
    exit 1
fi

source <(timeout 5 curl -sL https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/base_fun.sh) && clear

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
# 工具函数
# -------------------------------------------------------------

check_cmd() { command -v "$1" &>/dev/null; }

# URL 编码
url_encode() {
    local str="$1"
    if check_cmd python3; then
        python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$str"
    elif check_cmd python; then
        python -c "import sys,urllib; print(urllib.quote(sys.stdin.read().strip()))" <<< "$str"
    else
        echo "$str" | sed 's/ /%20/g; s/#/%23/g; s/@/%40/g; s/&/%26/g; s/=/%3D/g'
    fi
}

# 生成 UUID
gen_uuid() {
    if [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    elif check_cmd uuidgen; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif check_cmd python3; then
        python3 -c "import uuid; print(uuid.uuid4())"
    elif check_cmd python; then
        python -c "import uuid; print(uuid.uuid4())"
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
    local bytes="$1"
    if check_cmd numfmt; then
        echo "$bytes" | numfmt --suffix=B --to=iec
    else
        awk -v b="$bytes" 'BEGIN {
            split("B KB MB GB TB", u)
            i=1; v=b
            while(v >= 1024 && i < 5) { v /= 1024; i++ }
            printf "%.1f%s\n", v, u[i]
        }'
    fi
}

# 获取包管理器
get_pkg_manager() {
    if check_cmd apt-get;  then echo "apt"
    elif check_cmd dnf;    then echo "dnf"
    elif check_cmd yum;    then echo "yum"
    elif check_cmd zypper; then echo "zypper"
    elif check_cmd pacman; then echo "pacman"
    elif check_cmd apk;    then echo "apk"
    else echo "unknown"
    fi
}

# 修复 CentOS 7 官方源下线问题
fix_centos7_repo() {
    [[ ! -f /etc/centos-release ]] && return 0
    grep -q "CentOS Linux release 7" /etc/centos-release 2>/dev/null || return 0

    # 测试源是否可用，可用则跳过
    if yum makecache -q &>/dev/null; then
        return 0
    fi

    echo -e "${YELLOW}检测到 CentOS 7 官方源已下线，正在自动切换到存档镜像...${NC}"

    local repo_dir=/etc/yum.repos.d
    mkdir -p "${repo_dir}/backup"
    mv "${repo_dir}"/CentOS-*.repo "${repo_dir}/backup/" 2>/dev/null

    # 国内优先阿里云，否则用官方 vault
    if timeout 5 curl -s https://mirrors.aliyun.com > /dev/null 2>&1; then
        curl -so "${repo_dir}/CentOS-Base.repo" \
            https://mirrors.aliyun.com/repo/Centos-vault-7.9.2009.repo
    else
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

    yum clean all -q
    yum makecache -q
    echo -e "${GREEN}CentOS 7 源修复完成。${NC}"
}

# 安装依赖包
install_pkg() {
    local pkgs=("$@")
    local mgr; mgr=$(get_pkg_manager)
    case "$mgr" in
        apt)
            apt-get update -qq 2>/dev/null || true
            apt-get install -y "${pkgs[@]}"
            ;;
        dnf)    dnf install -y "${pkgs[@]}" ;;
        yum)
            fix_centos7_repo
            yum install -y "${pkgs[@]}"
            ;;
        zypper) zypper install -y "${pkgs[@]}" ;;
        pacman) pacman -Sy --noconfirm "${pkgs[@]}" ;;
        apk)    apk add --no-cache "${pkgs[@]}" ;;
        *)
            echo -e "${C_ERROR}错误：未识别的包管理器，请手动安装: ${pkgs[*]}${NC}"
            return 1
            ;;
    esac
}

# 安装所有依赖
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

# 获取 SSH 端口
get_ssh_port() {
    local port
    port=$(grep -E '^Port ' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    if [[ -z "$port" ]]; then
        if check_cmd ss; then
            port=$(ss -tlpn 2>/dev/null | grep sshd | grep -oP ':\K[0-9]{2,}' | head -n1)
        elif check_cmd netstat; then
            port=$(netstat -tlpn 2>/dev/null | grep sshd | grep -oP ':\K[0-9]{2,}' | head -n1)
        fi
    fi
    echo "${port:-22}"
}

# 检测服务管理器
get_service_manager() {
    if check_cmd systemctl && systemctl list-units &>/dev/null 2>&1; then
        echo "systemd"
    elif check_cmd rc-service; then
        echo "openrc"
    elif [[ -d /etc/init.d ]]; then
        echo "sysvinit"
    else
        echo "unknown"
    fi
}

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

# iptables 添加放行规则
_iptables_allow() {
    local port="$1"
    iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
    if check_cmd ip6tables; then
        ip6tables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
            ip6tables -I INPUT -p tcp --dport "$port" -j ACCEPT
    fi
}

# iptables 规则持久化
_iptables_save() {
    if check_cmd netfilter-persistent; then
        netfilter-persistent save
    elif check_cmd iptables-save; then
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
                if [[ -f "$rc_local" ]]; then
                    grep -q "iptables-restore" "$rc_local" || \
                        sed -i '/^exit 0/i iptables-restore < /etc/iptables/rules.v4' "$rc_local"
                fi
                ;;
        esac
    else
        echo -e "${YELLOW}警告：iptables 规则已生效但无法持久化，重启后需重新设置。${NC}"
    fi
}

# 开放防火墙端口
open_firewall_port() {
    local port="$1"
    local ssh_port; ssh_port=$(get_ssh_port)

    if check_cmd firewall-cmd && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --zone=public --add-port="${port}/tcp" --permanent 2>/dev/null
        [[ -n "$ssh_port" ]] && \
            firewall-cmd --zone=public --add-port="${ssh_port}/tcp" --permanent 2>/dev/null
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
# 服务文件创建
# -------------------------------------------------------------

create_openrc_service() {
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
}

create_systemd_service() {
    local svc_content
    read -r -d '' svc_content << 'EOF'
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
    echo "$svc_content" > /etc/systemd/system/xray.service
}

register_xray_service() {
    case "$(get_service_manager)" in
        systemd)
            create_systemd_service
            service_enable_start xray.service
            ;;
        openrc)
            create_openrc_service
            service_enable_start xray
            ;;
        *)
            echo -e "${C_ERROR}警告：不支持的服务管理器，请手动启动 xray。${NC}"
            echo "手动启动: /usr/local/bin/xray run -config /usr/local/etc/xray/config.json &"
            ;;
    esac
}

# -------------------------------------------------------------
# 核心函数: config_menu
# -------------------------------------------------------------
function config_menu {
    local menu_title="$1"
    local options_text_name="$2[@]"
    local options_func_name="$3[@]"
    local options_text=("${!options_text_name}")
    local options_func=("${!options_func_name}")
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

        read -p "请输入选项 [1-$exit_index] 或 q 退出: " choice

        case "$choice" in
            q|Q|"$exit_index")
                echo -e "\n${C_MENU}退出中...再见！${NC}\n"
                return 0
                ;;
            [1-9]|[1-9][0-9])
                if (( choice >= 1 && choice <= count )); then
                    local index=$((choice - 1))
                    echo -e "\n--- 正在执行: ${options_text[$index]} ---"
                    ${options_func[$index]}
                    echo -e "--- 执行完毕 ---\n"
                    read -p "按任意键返回菜单..."
                else
                    echo -e "\n${C_ERROR}错误：选项 '$choice' 无效。${NC}"
                    sleep 1
                fi
                ;;
            *)
                echo -e "\n${C_ERROR}错误：无效输入 '$choice'。${NC}"
                sleep 1
                ;;
        esac
    done
}

# -------------------------------------------------------------
# 安装 xray + reality + xhttp
# -------------------------------------------------------------
function xhttp_install {
    local xrayDomainList=("www.amazon.com" "www.tesla.com" "www.apple.com")
    local arrRandomIndex=$(( RANDOM % ${#xrayDomainList[@]} ))
    read -p "请输入境外域名，需支持 h2/h3（默认随机热门域名）: " xrayDomain
    [[ -z "$xrayDomain" ]] && xrayDomain="${xrayDomainList[$arrRandomIndex]}"

    read -p "请输入生成用户数量（默认 10）: " userNum
    [[ -z "$userNum" || ! "$userNum" =~ ^[0-9]+$ ]] && userNum=10

    local xrayPath; xrayPath=$(yzxg_random_str 5 11)
    local xrayPort=443

    echo -e "${C_TITLE}正在安装依赖...${NC}"
    install_deps || return 1

    open_firewall_port "$xrayPort"

    local selfIpv4 selfIpv6 currentIp
    selfIpv4=$(timeout 5 curl -s https://ipv4.icanhazip.com || timeout 5 curl -s https://api.ipify.org || echo "")
    selfIpv6=$(timeout 5 curl -s https://ipv6.icanhazip.com || timeout 5 curl -s -6 https://api.ipify.org || echo "")
    currentIp=${selfIpv4:-$selfIpv6}
    if [[ -z "$currentIp" ]]; then
        echo -e "${C_ERROR}错误：无法获取本机公网 IP，请检查网络连接！${NC}"
        return 1
    fi

    mkdir -p /usr/local/bin /usr/local/etc/xray /usr/local/share/xray /var/log/xray

    echo -e "${C_TITLE}正在下载 xray...${NC}"
    local xrayVersion; xrayVersion=$(yzxg_get_new_version_num 'https://github.com/XTLS/Xray-core/releases')
    if [[ -z "$xrayVersion" ]]; then
        echo -e "${C_ERROR}错误：无法获取 xray 最新版本号，请检查网络连接。${NC}"
        return 1
    fi

    local cpuArch; cpuArch=$(yzxg_get_cpu_arch)
    curl -s -L -o /tmp/xray.zip \
        "https://github.com/XTLS/Xray-core/releases/download/$xrayVersion/Xray-linux-${cpuArch}.zip" \
        && unzip -oq /tmp/xray.zip -d /usr/local/bin
    rm -f /tmp/xray.zip
    chmod +x /usr/local/bin/xray

    local tempKey="/tmp/xray_key_$$.txt"
    /usr/local/bin/xray x25519 > "$tempKey"

    local xrayPrivateKey xrayPublicKey
    xrayPrivateKey=$(awk 'tolower($0) ~ /private/ {print $NF}' "$tempKey" | head -n1)
    xrayPublicKey=$(awk  'tolower($0) ~ /public/  {print $NF}' "$tempKey" | head -n1)
    rm -f "$tempKey"

    if [[ -z "$xrayPrivateKey" || -z "$xrayPublicKey" ]]; then
        echo -e "${C_ERROR}错误：密钥解析失败，请检查 xray 版本输出格式。${NC}"
        echo -e "${YELLOW}原始输出：${NC}"
        /usr/local/bin/xray x25519
        return 1
    fi

    local fpList=("chrome" "firefox" "safari" "edge")
    local levelId=1
    local shortIds='' xrayUserJson='' shareLinks='' sid

    local shareIp="$currentIp"
    [[ "$shareIp" =~ ^[0-9a-fA-F:]+$ && "$shareIp" =~ ":" ]] && shareIp="[$shareIp]"

    for (( i=1; i<=userNum; i++ )); do
        sid=$(openssl rand -hex "$(yzxg_random_num 2 8)")
        shortIds="${shortIds}\"${sid}\","

        local userId; userId=$(gen_uuid)
        xrayUserJson="${xrayUserJson}{\"id\":\"$userId\",\"level\":$levelId,\"email\":\"$(yzxg_random_str 8 12)@xhttp.com\"},"

        local fp="${fpList[$(( RANDOM % ${#fpList[@]} ))]}"
        local remark; remark=$(url_encode "$(hostname)-User$i")

        shareLinks+="vless://$userId@$shareIp:$xrayPort?encryption=none&security=reality&sni=$xrayDomain&fp=$fp&pbk=$xrayPublicKey&sid=$sid&spx=%2F${xrayPath}&type=xhttp&path=%2F${xrayPath}&mode=auto#${remark}\n\n"
    done

    cat > /usr/local/etc/xray/config.json << EOF
{
  "log": { "loglevel": "warning" },
  "stats": {},
  "api": { "tag": "api", "services": ["StatsService"] },
  "policy": {
    "levels": { "$levelId": { "statsUserUplink": true, "statsUserDownlink": true } },
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
          "privateKey": "$xrayPrivateKey",
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

    cat > /opt/update_xray.sh << 'UPDEOF'
#!/usr/bin/env bash
source <(timeout 5 curl -sL https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/base_fun.sh)
xrayVersion=$(yzxg_get_new_version_num 'https://github.com/XTLS/Xray-core/releases')
[[ -z "$xrayVersion" ]] && exit 1
curl -s -L -o /tmp/xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/$xrayVersion/Xray-linux-$(yzxg_get_cpu_arch).zip" \
    && unzip -oq /tmp/xray.zip -d /usr/local/bin
rm -f /tmp/xray.zip
chmod +x /usr/local/bin/xray
command -v systemctl &>/dev/null && systemctl restart xray.service && exit 0
command -v rc-service &>/dev/null && rc-service xray restart
UPDEOF
    chmod +x /opt/update_xray.sh

    (crontab -l 2>/dev/null | grep -q "update_xray.sh") || \
        { crontab -l 2>/dev/null; echo "01 3 1 * * /opt/update_xray.sh"; } | crontab -

    echo -e "\n"
    yzxg_echo_txt_color "========= 节点配置信息 =========" "green"
    echo -e "\n"
    echo -e "${GREEN}${shareLinks}${NC}"
}

# -------------------------------------------------------------
# xray 流量统计
# -------------------------------------------------------------
function xray_traffic {
    local _APISERVER=127.0.0.1:10085
    local _XRAY=/usr/local/bin/xray

    if [[ ! -x "$_XRAY" ]]; then
        echo -e "${C_ERROR}错误：xray 未安装。${NC}"
        return 1
    fi

    apidata() {
        local ARGS=''
        [[ "$1" == "reset" ]] && ARGS="-reset=true"
        $_XRAY api statsquery --server=$_APISERVER $ARGS \
        | awk '{
            if (match($1, /"name":/)) {
                f=1; gsub(/^"|link"|,$/, "", $2);
                split($2, p, ">>>");
                printf "%s:%s->%s\t", p[1], p[2], p[4];
            } else if (match($1, /"value":/) && f) {
                f=0; gsub(/"/, "", $2); printf "%.0f\n", $2;
            } else if (match($0, /}/) && f) {
                f=0; print 0;
            }
        }'
    }

    print_sum() {
        local DATA="$1" PREFIX="$2"
        local SORTED; SORTED=$(echo "$DATA" | grep "^${PREFIX}" | sort -r)
        local SUM; SUM=$(echo "$SORTED" | awk '
            /->up/   { us += $2 }
            /->down/ { ds += $2 }
            END { printf "SUM->up:\t%.0f\nSUM->down:\t%.0f\nSUM->TOTAL:\t%.0f\n", us, ds, us+ds }
        ')
        if check_cmd numfmt; then
            echo -e "${SORTED}\n${SUM}" | numfmt --field=2 --suffix=B --to=iec | column -t
        else
            echo -e "${SORTED}\n${SUM}" | while IFS=$'\t' read -r name bytes; do
                printf "%-40s %s\n" "$name" "$(human_bytes "${bytes:-0}")"
            done
        fi
    }

    local DATA; DATA=$(apidata "$1")
    echo "------------ Inbound ------------"
    print_sum "$DATA" "inbound"
    echo "------------ Outbound -----------"
    print_sum "$DATA" "outbound"
    echo -e "${C_TITLE}------------- User --------------${NC}"
    print_sum "$DATA" "user"
    echo -e "${C_TITLE}---------------------------------${NC}"
}

# -------------------------------------------------------------
# 菜单入口
# -------------------------------------------------------------
declare -a MY_TEXT=("安装 xray + reality + xhttp" "统计 xray 每月流量使用情况")
declare -a MY_FUNC=("xhttp_install" "xray_traffic")

config_menu "xray 安装面板" MY_TEXT MY_FUNC
