#!/usr/bin/env bash

# 脚本函数初始化
source <(timeout 5 curl -sL https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/base_fun.sh) && clear

# 伪装域名
read -p "请输入境外域名,注意必须支持h2、h3协议(默认为 www.amazon.com):" xrayDomain
if [[ $xrayDomain = "" ]]
then
	xrayDomain='www.amazon.com'
fi

# 伪装路径
read -p "请输入伪装路径，默认随机生成:" xrayPath

if [[ $xrayPath = "" ]]
then
	xrayPath=$(yzxg_random_str 1 11)
fi

# xray端口
read -p "请输入xray端口，默认443:" xrayPort

if [[ $xrayPort = "" ]]
then
	xrayPort=443
fi

# 用户数量
read -p "请输入生成用户的数量，默认10:" userNum

if [[ $userNum = "" ]]
then
	userNum=10
fi

isCommand=$(yzxg_get_package_manage)

if [[ $isCommand = 'yum' ]]
then
	# centos
	yum install -y curl ss wget unzip firewalld
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
    apt install -y curl ss wget unzip ufw # 在 Debian 上安装 ufw
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
echo "$(/usr/local/bin/xray x25519 | cut -d " " -f3)" >> ./tempKey.txt
# 私钥
xrayPrivateKey=$(sed -n '1p' ./tempKey.txt)
# 公钥
xrayPublicKey=$(sed -n '2p' ./tempKey.txt)
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
read -r -d '' userConfig << EOF
{
    "downloadSettings": {
        "address": "${selfIpv4}",
        "port": ${xrayPort},
        "network": "xhttp",
        "security": "reality",
        "realitySettings": {
            "serverName": "${xrayDomain}",
            "fingerprint": "chrome",
            "publicKey": "$xrayPublicKey",
            "shortId": $(echo "${shortIds}" | cut -d "," -f1)
        },
        "xhttpSettings": {
                "path": "/${xrayPath}"
        }
    }
}
EOF

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
	                "email": "$(yzxg_random_str 8 18)@qq.com"
	            },
EOF
)
	shareLinks+="vless://$userId@$selfIpv4:$xrayPort?encryption=none&security=reality&sni=$xrayDomain&fp=chrome&pbk=$xrayPublicKey&sid=$(echo $shortIds | grep -Po '[^,\"]+' | sed -n $indexShort'p')&spx=%2F&type=xhttp&path=%2F$xrayPath&mode=auto#xhttp \n\n"
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
        }
    ],
    "routing": {
        "rules": [
            {
                "inboundTag": [
                    "api"
                ],
                "outboundTag": "api",
                "type": "field"
            }
        ],
        "domainStrategy": "AsIs"
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

crontabStr='0 23 * * 6  /opt/update_xray.sh'
(crontab -l | grep "update_xray.sh") || (crontab -l; echo "${crontabStr}") | crontab -

echo -e "\n"
yzxg_echo_txt_color "$shareLinks" "green"

rm -rf $(readlink -f "$0")
