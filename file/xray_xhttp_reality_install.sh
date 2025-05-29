#!/usr/bin/env bash

#获取ipv4
selfIpv4=$(timeout 10 curl -s http://ipv4.icanhazip.com);

#获取ipv6
selfIpv6=$(timeout 10 curl -s http://ipv6.icanhazip.com);

#指定区间随机数字
function random_num {
   shuf -i $1-$2 -n1;
}
#指定区间随机字符串
function random_str {
   echo $(echo $(cat /proc/sys/kernel/random/uuid) | cut -c $1-$2) | sed 's/[1 -]//g';
}
# 打印文字颜色方法
echoTxtColor(){
	
	colorV="1";
	
	if [[ $2 = 'red' ]];
	then
		colorV="1"
	elif [[ $2 = 'green' ]];
	then
		colorV="2"
	elif [[ $2 = 'yellow' ]];
	then
		colorV="3";
	fi
	
	echo -e "\033[3${colorV}m ${1} \033[0m";
}

# 伪装域名
read -p "请输入境外域名,注意必须支持h2、h3协议(默认为 www.amazon.com):" xrayDomain;
if 
	[[ $xrayDomain = "" ]];
then
	xrayDomain='www.amazon.com'
fi

# 伪装路径
read -p "请输入伪装路径，默认随机生成:" xrayPath;

if 
	[[ $xrayPath = "" ]];
then
	xrayPath=$(random_str 1 11);
fi

# xray端口
read -p "请输入xray端口，默认443:" xrayPort;

if 
	[[ $xrayPort = "" ]];
then
	xrayPort=443;
fi

# 用户数量
read -p "请输入生成用户的数量，默认10:" userNum;

if 
	[[ $userNum = "" ]];
then
	userNum=10;
fi

levelId=1 # 等级id

xrayUserJson='';

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install;

for((i=1;i<=${userNum};i++));  
	do   
	xrayUserJson=${xrayUserJson}$(cat << EOF
	            {
	                "id": "$(cat /proc/sys/kernel/random/uuid)",
	                "level": $levelId,
	                "email": "$(random_str 8 18)@qq.com"
	            },
EOF
)

done 


shortIds='';

for((i=1;i<=${userNum};i++));  
	do   
	shortIds=${shortIds}"\"$(openssl rand -hex $(random_num 1 8))\","
done 

tempKey=$(xray x25519);

rm -rf ./tempKey.txt;

echo "$(xray x25519 | cut -d " " -f3)" >> ./tempKey.txt;

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
                    "privateKey": "$(head -n 1 ./tempKey.txt)",
                    "shortIds": [${shortIds%?}]
                },
                "xhttpSettings": {
                    "host": "",
                    "path": "${xrayPath}",
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

systemctl restart xray
systemctl enable xray
systemctl status xray

crontabStr='0 23 * * 6  bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install && systemctl restart xray'
isXrayCron=$(cat /var/spool/cron/root | grep install-release)

if [[ $isXrayCron == '' ]];then
    echo "$crontabStr" >> /var/spool/cron/root;
    systemctl reload crond.service;
    systemctl restart crond.service;
fi

echo -e "\n";
echoTxtColor "xray 服务端配置如下" "yellow";
echo -e "\n";
echoTxtColor "${xrayUserJson%?}" "green";
echo -e "\n";
echoTxtColor "xray 客户端（ auto... ）中配置如下" "yellow";
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
            "publicKey": "$(tail -n 1 ./tempKey.txt)",
            "shortId": "$(echo "${shortIds}" | cut -d "," -f1)"
        },
        "xhttpSettings": {
                "path": "/${xrayPath}"
        }
    }
}
EOF

echoTxtColor "${userConfig}" "green";
echo -e "\n";

#如果获取到了 ipv6 则显示出来
if 
	[[ $selfIpv6 != "" ]];
then
	echoTxtColor "ipv6地址如下" "yellow";
	echo -e "\n";
	echoTxtColor "${selfIpv6}" "green";
fi

rm -rf ./tempKey.txt;
