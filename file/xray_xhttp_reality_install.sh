#!/usr/bin/env bash

# 脚本函数初始化
source <(timeout 5 curl -sL https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/base_fun.sh)
 
# 伪装域名
read -p "请输入境外域名,注意必须支持h2、h3协议(默认为 www.amazon.com):" xrayDomain
if 
	[[ $xrayDomain = "" ]];
then
	xrayDomain='www.amazon.com'
fi

# 伪装路径
read -p "请输入伪装路径，默认随机生成:" xrayPath

if 
	[[ $xrayPath = "" ]];
then
	xrayPath=$(yzxg_random_str 1 11)
fi

# xray端口
read -p "请输入xray端口，默认443:" xrayPort

if 
	[[ $xrayPort = "" ]];
then
	xrayPort=443;
fi

# 用户数量
read -p "请输入生成用户的数量，默认10:" userNum

if 
	[[ $userNum = "" ]];
then
	userNum=10;
fi

if [[ $(yzxg_get_package_manage) = 'yum' ]];then
	yum install -y curl wget unzip firewalld
	systemctl start firewalld.service
	firewall-cmd --zone=public --add-port=$xrayPort/tcp --permanent
	firewall-cmd --reload
	systemctl restart firewalld.service
fi

#获取ipv4
selfIpv4=$((timeout 5 curl -s https://ipv4.icanhazip.com) || (timeout 5 curl -s https://api.ipify.org))
#获取ipv6
selfIpv6=$((timeout 5 curl -s https://ipv6.icanhazip.com) || (timeout 5 curl -s -6 https://api.ipify.org))

# 创建目录
[[ ! -d /usr/local/bin ]] && mkdir -p -m 755 /usr/local/bin
[[ ! -d /usr/local/etc/xray ]] && mkdir -p /usr/local/etc/xray
[[ ! -d /usr/local/share/xray ]] && mkdir -p /usr/local/share/xray
[[ ! -d /var/log/xray ]] && mkdir -p /var/log/xray
# 获取最新版本号
xrayVersion=$(yzxg_get_new_version_num 'https://github.com/XTLS/Xray-core/releases')
# 下载 xray
curl -s -L -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/$xrayVersion/Xray-linux-$(yzxg_get_cpu_arch).zip" && unzip -oq xray.zip -d /usr/local/bin
rm -rf xray.zip

# 获取xray 生成公钥和私钥
echo "$(/usr/local/bin/xray x25519 | cut -d " " -f3)" >> ./tempKey.txt;
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

xrayUserJson='';

for((i=1;i<=${userNum};i++));  
	do   
	xrayUserJson=${xrayUserJson}$(cat << EOF
	            {
	                "id": "$(cat /proc/sys/kernel/random/uuid)",
	                "level": $levelId,
	                "email": "$(yzxg_random_str 8 18)@qq.com"
	            },
EOF
)

done 

shortIds='';

for((i=1;i<=${userNum};i++));  
	do   
	shortIds=${shortIds}"\"$(openssl rand -hex $(yzxg_random_num 1 8))\","
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

chmod 755 /opt/update_xray.sh

crontabStr='0 23 * * 6  /opt/update_xray.sh && systemctl restart xray'
isXrayCron=$(cat /var/spool/cron/root | grep update_xray)

if [[ $isXrayCron == '' ]];then
    echo "$crontabStr" >> /var/spool/cron/root;
    systemctl reload crond.service;
    systemctl restart crond.service;
fi

echo -e "\n";
yzxg_echo_txt_color "xray 服务端配置如下" "yellow";
echo -e "\n";
yzxg_echo_txt_color "${xrayUserJson%?}" "green";
echo -e "\n";
yzxg_echo_txt_color "xray 客户端（ auto... ）中配置如下" "yellow";
echo -e "\n";

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

yzxg_echo_txt_color "${userConfig}" "green"

echo -e "\n";

#如果获取到了 ipv6 则显示出来
if 
	[[ $selfIpv6 != "" ]];
then
	yzxg_echo_txt_color "ipv6地址如下" "yellow"
	echo -e "\n";
	yzxg_echo_txt_color "${selfIpv6}" "green"
fi

rm -rf ./xray_xhttp_reality_install.sh
