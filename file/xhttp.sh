#!/bin/bash

# 脚本函数初始化
source <(timeout 5 curl -sL https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/base_fun.sh) && clear
# -------------------------------------------------------------
# 颜色和样式配置 (默认值)
# -------------------------------------------------------------
# 通用颜色代码
NC='\033[0m'    # No Color (重置)
C_MENU="${GREEN}" # 菜单文本颜色
C_TITLE="${GREEN}" # 标题颜色
C_EXIT="${RED}" # 退出选项颜色
C_ERROR="${RED}" # 错误信息颜色

# ANSI 颜色定义 (你可以在这里自定义颜色)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'


# -------------------------------------------------------------
# 核心函数: config_menu
# 描述: 可配置的交互式菜单函数。
# 参数:
#   $1 (String): 菜单标题
#   $2 (Array Name): 选项文本数组名 (e.g., OPTIONS_TEXT)
#   $3 (Array Name): 操作函数名数组名 (e.g., OPTIONS_FUNC)
# -------------------------------------------------------------
function config_menu {
    local menu_title="$1"
    local options_text_name="$2[@]"
    local options_func_name="$3[@]"

    # 通过间接引用获取数组内容
    local options_text=("${!options_text_name}")
    local options_func=("${!options_func_name}")
    
    local count=${#options_text[@]}
    local exit_index=$((count + 1)) 
    local choice 
    
    while true; do
        clear 

        # 1. 打印菜单标题和选项 (使用配置的颜色)
        echo -e "${C_TITLE}====================================${NC}"
        echo -e "${C_TITLE}       $menu_title ${NC}"
        echo -e "${C_TITLE}====================================${NC}"

        # 打印所有功能选项
        for i in "${!options_text[@]}"; do
            echo -e "${C_MENU}$((i+1)). ${options_text[$i]}${NC}"
        done
        
        # 打印退出选项
        echo -e "${C_EXIT}$exit_index. 退出脚本${NC}"
        echo -e "${C_TITLE}------------------------------------${NC}"

        # 2. 获取用户输入
        read -p "请输入选项 [1-$exit_index] 或 q 退出: " choice

        # 3. 处理用户输入
        case "$choice" in
            # 退出选项
            q|Q|"$exit_index")
                echo -e "\n${C_MENU}退出中...再见！${NC}\n"
                return 0
                ;;

            # 验证有效数字输入
            [1-9]|[1-9][0-9])
                if (( choice >= 1 && choice <= count )); then
                    local index=$((choice - 1))
                    
                    echo -e "\n--- 正在执行: ${options_text[$index]} ---"
                    # 关键步骤：执行对应的操作函数
                    ${options_func[$index]} 
                    echo -e "--- 执行完毕 ---\n"
                    
                    read -p "按任意键返回菜单..."
                else
                    echo -e "\n${C_ERROR}错误：选项编号 '$choice' 无效。${NC}"
                    sleep 1
                fi
                ;;

            # 无效输入
            *)
                echo -e "\n${C_ERROR}错误：无效输入 '$choice'，请重新输入。${NC}"
                sleep 1
                ;;
        esac
    done
}


# =============================================================
#                        使用示例
# =============================================================

# --- 1. 定义具体的操作函数 ---

# 安装 xray + reality + xhttp 协议
function xhttp_install {
    
	# 伪装域名
	read -p "请输入境外域名,注意必须支持h2、h3协议(默认随机洛杉矶域名):" xrayDomain
	
	# 域名配置列表，洛杉矶域名
	xrayDomainList=("www.amazon.com" "www.tesla.com")
	# 取出数组的随机索引
	arrRandomIndex=$(( $RANDOM % ${#xrayDomainList[@]} ))
	
	# 判断是否有伪装域名
	if [[ $xrayDomain = "" ]]
	then
		xrayDomain=${xrayDomainList[$arrRandomIndex]}
	fi
	
	# 用户数量
	read -p "请输入生成用户的数量，默认10:" userNum
	
	if [[ $userNum = "" ]]
	then
		userNum=10
	fi
	
	# 伪装路径
	xrayPath=$(yzxg_random_str 1 11)
	
	# xray端口
	xrayPort=443
	
	isCommand=$(yzxg_get_package_manage)
	
	if [[ $isCommand = 'yum' ]]
	then
		# centos
		yum update -y
		yum install -y curl iproute2 wget unzip firewalld
		systemctl start firewalld.service
		if [[ ! $(firewall-cmd --list-ports | grep -Po $xrayPort) ]]; then
			firewall-cmd --zone=public --add-port=${xrayPort}/tcp --permanent
			firewall-cmd --zone=public --add-port=$(ss -tlpn | grep sshd | head -n1 | grep -Po ':[0-9]{2,}' | head -n1 | grep -Po '\d+')/tcp --permanent
		fi
		firewall-cmd --reload
		systemctl restart firewalld.service
	elif [[ $isCommand = 'apt' ]]
	then
	    # Debian/Ubuntu 相关命令
	    apt update
	    apt install -y curl iproute2 wget unzip ufw bsdmainutils # 在 Debian 上安装 ufw
	    systemctl start ufw.service
	    systemctl enable ufw.service
	    ufw allow "$(ss -tlpn | grep sshd | head -n1 | grep -Po ':[0-9]{2,}' | head -n1 | grep -Po '\d+')"/tcp
	    ufw allow "$xrayPort"/tcp comment "Allow Xray Port"
	    ufw reload
	    # 确保 ufw 已经启用
	    if [[ $(ufw status | grep "Status: active") ]]; then
	        echo "UFW is active."
	    else
	        ufw --force enable # 如果未启用，则启用防火墙
	        echo "UFW enabled."
	    fi
	fi
	
	#获取ipv4
	selfIpv4=$((timeout 5 curl -s https://ipv4.icanhazip.com) || (timeout 5 curl -s https://api.ipify.org))
	#获取ipv6
	selfIpv6=$((timeout 5 curl -s https://ipv6.icanhazip.com) || (timeout 5 curl -s -6 https://api.ipify.org))
	
	# 创建目录
	mkdir -p -m 755 /usr/local/bin
	mkdir -p /usr/local/etc/xray /usr/local/share/xray /var/log/xray
	# 获取最新版本号
	xrayVersion=$(yzxg_get_new_version_num 'https://github.com/XTLS/Xray-core/releases')
	# 下载 xray
	curl -s -L -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/$xrayVersion/Xray-linux-$(yzxg_get_cpu_arch).zip" && unzip -oq xray.zip -d /usr/local/bin
	rm -rf xray.zip
	
	# 获取xray 生成公钥和私钥
	/usr/local/bin/xray x25519 >> ./tempKey.txt
	# 私钥
	xrayPrivateKey=$(cat tempKey.txt | grep -oP 'PrivateKey: \K.*')
	# 公钥,密码
	xrayPassword=$(cat tempKey.txt | grep -oP 'Password: \K.*')
	rm -rf ./tempKey.txt
	
	# 创建系统服务
	read -r -d '' xrayService << EOF
	
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
	
	cat > /etc/systemd/system/xray.service << EOF
	$xrayService
EOF
	
	cat > /etc/systemd/system/xray@.service << EOF
	$xrayService
EOF
	
	systemctl daemon-reload
	
	levelId=1 # 等级id
	shortIds=''
	xrayUserJson=''
	shareLinks=''
	
	indexShort=0
	for((i=1;i<=${userNum};i++)) 
		do   
		indexShort=$((indexShort + 1))
		shortIds=${shortIds}"\"$(openssl rand -hex $(yzxg_random_num 1 8))\","
		userId=$(cat /proc/sys/kernel/random/uuid)
		xrayUserJson=${xrayUserJson}$(cat << EOF
		            {
		                "id": "$userId",
		                "level": $levelId,
		                "email": "$(yzxg_random_str 8 18)@xhttp.com"
		            },
EOF
	)
		shareLinks+="vless://$userId@$selfIpv4:$xrayPort?encryption=none&security=reality&sni=$xrayDomain&fp=chrome&pbk=$xrayPassword&sid=$(echo $shortIds | grep -Po '[^,\"]+' | sed -n $indexShort'p')&spx=%2F&type=xhttp&path=%2F$xrayPath&mode=auto#"$(hostname)"/reality+xhttp \n\n"
	done 
	
	cat > /usr/local/etc/xray/config.json << EOF
	
	{
	    "log": {
	        "loglevel": "debug"
	    },
	    "stats": {},
	    "api": {
	        "tag": "api",
	        "services": [
			"StatsService"
	 	]
	    },
	    "policy": {
	        "levels": {
	            "$levelId": {
	                "statsUserUplink": true,
	                "statsUserDownlink": true
	            }
	        },
	        "system": {
	            "statsInboundUplink": true,
	            "statsInboundDownlink": true,
	            "statsOutboundUplink": true,
	            "statsOutboundDownlink": true
	        }
	    },
	    "inbounds": [
	        {
	            "tag": "tcp",
	            "listen": "0.0.0.0",
	            "port": ${xrayPort},
	            "protocol": "vless",
	            "settings": {
	                "clients": [${xrayUserJson%?}
	        	],
	                "decryption": "none"
	            },
	            "streamSettings": {
	                "network": "xhttp",
	                "security": "reality",
	                "realitySettings": {
	                    "show": false,
	                    "target": "${xrayDomain}:${xrayPort}",
	                    "serverNames": ["${xrayDomain}"],
	                    "privateKey": "$xrayPrivateKey",
	                    "shortIds": [${shortIds%?}]
	                },
	                "xhttpSettings": {
	                    "host": "",
	                    "path": "/${xrayPath}",
	                    "mode": "auto"
	                }
	            },
	            "sniffing": {
	                "enabled": true,
	                "destOverride": [
	                    "http",
	                    "tls",
	                    "quic"
	                ],
	                "metadataOnly": false
	            }
	        },
	        {
	            "listen": "127.0.0.1",
	            "port": 10085,
	            "protocol": "dokodemo-door",
	            "settings": {
	                "address": "127.0.0.1"
	            },
	            "tag": "api"
	        }
	    ],
	    "outbounds": [
	       {
	           "tag": "direct",
	           "protocol": "freedom",
	           "settings": {}
	       },
	       {
	           "tag": "blocked",
		   "protocol": "blackhole",
		   "settings": {}
	       }
	    ],
	    "routing": {
	    	    "domainStrategy": "AsIs",
		    "rules": [
		      {
		        "type": "field",
		        "outboundTag": "blocked",
		        "domain": ["geosite:category-ads-all"]
		      },
	       	      {
		        "type": "field",
		        "inboundTag": ["api"],
		        "outboundTag": "api" 
		      },
	       	      {
		        "type": "field",
		        "protocol": ["bittorrent"],
		        "outboundTag": "direct"
		      },
		      {
		        "type": "field",
		        "ip": ["geoip:private", "geoip:cn"],
		        "outboundTag": "direct"
		      },
		      {
		        "type": "field",
		        "domain": ["geosite:cn"],
		        "outboundTag": "direct"
		      }
		    ]
	    }
	}
	
EOF
	
	systemctl enable xray.service
	
	systemctl restart xray.service
	
	systemctl status xray.service --no-pager #把日志直接输入到终端
	
	cat > /opt/update_xray.sh << EOF
	#!/usr/bin/env bash
	
	source <(timeout 5 curl -sL https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/base_fun.sh)
	xrayVersion=\$(yzxg_get_new_version_num 'https://github.com/XTLS/Xray-core/releases')
	curl -s -L -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/\$xrayVersion/Xray-linux-\$(yzxg_get_cpu_arch).zip" && unzip -oq xray.zip -d /usr/local/bin
	rm -rf xray.zip
	systemctl restart xray.service
EOF
	
	chmod +x /opt/update_xray.sh
	
	crontabStr='01 1 1 * *  /opt/update_xray.sh'
	(crontab -l | grep "update_xray.sh") || (crontab -l; echo "${crontabStr}") | crontab -
	
	echo -e "\n"
	yzxg_echo_txt_color "$shareLinks" "green"
}

# xray 流量使用情况统计
function xray_traffic {
     _APISERVER=127.0.0.1:10085
	_XRAY=/usr/local/bin/xray
	apidata () {
	    local ARGS=
	    if [[ $1 == "reset" ]]; then
	      ARGS="-reset=true"
	    fi
	    $_XRAY api statsquery --server=$_APISERVER "${ARGS}" \
	    | awk '{
	        if (match($1, /"name":/)) {
	            f=1; gsub(/^"|link"|,$/, "", $2);
	            split($2, p,  ">>>");
	            printf "%s:%s->%s\t", p[1],p[2],p[4];
	        }
	        else if (match($1, /"value":/) && f){
	          f = 0;
	          gsub(/"/, "", $2);
	          printf "%.0f\n", $2;
	        }
	        else if (match($0, /}/) && f) { f = 0; print 0; }
	    }'
	}
	
	print_sum() {
	    local DATA="$1"
	    local PREFIX="$2"
	    local SORTED=$(echo "$DATA" | grep "^${PREFIX}" | sort -r)
	    local SUM=$(echo "$SORTED" | awk '
	        /->up/{us+=$2}
	        /->down/{ds+=$2}
	        END{
	            printf "SUM->up:\t%.0f\nSUM->down:\t%.0f\nSUM->TOTAL:\t%.0f\n", us, ds, us+ds;
	        }')
	    echo -e "${SORTED}\n${SUM}" \
	    | numfmt --field=2 --suffix=B --to=iec \
	    | column -t
	}
	
	DATA=$(apidata $1)
	echo "------------Inbound----------"
	print_sum "$DATA" "inbound"
	echo "-----------------------------"
	echo "------------Outbound----------"
	print_sum "$DATA" "outbound"
	echo "-----------------------------"
	echo -e "${C_TITLE}-------------User------------${NC}"
	print_sum "$DATA" "user"
	echo -e "${C_TITLE}-----------------------------${NC}"
}

# --- 2. 配置菜单参数 ---
declare -a MY_TEXT=(
    "安装 xray + reality + xhttp"
    "统计 xray 每月流量使用情况"
)

declare -a MY_FUNC=(
    "xhttp_install"
    "xray_traffic"
)

# --- 3. 脚本入口：运行菜单并自定义配置 ---

# 示例 1: 使用默认颜色 (绿色)
echo "--- 运行菜单 1: 默认配置 ---"
# config_menu "基础管理工具" MY_TEXT MY_FUNC


# 示例 2: 自定义颜色 (蓝色标题，黄色菜单，红色退出)
C_TITLE="${GREEN}"
C_MENU="${YELLOW}"
C_EXIT="${RED}"
C_ERROR="${RED}"

echo "--- 运行菜单 2: 自定义颜色配置 ---"
config_menu "xray 安装面板" MY_TEXT MY_FUNC
