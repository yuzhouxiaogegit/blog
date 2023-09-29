#!/usr/bin/env bash

#指定区间随机数
function random_num {
   shuf -i $1-$2 -n1
}
#指定区间随机字符串
function random_str {
   echo $(echo $(cat /proc/sys/kernel/random/uuid) | cut -c $1-$2) | sed 's/[1 -]//g'
}
# 打印文字颜色方法
echoTxtColor(){
	
	colorV="1"
	
	if [[ $2 = 'red' ]];
	then
		colorV="1"
	elif [[ $2 = 'green' ]];
	then
		colorV="2"
	elif [[ $2 = 'yellow' ]];
	then
		colorV="3"
	fi
	
	echo -e "\033[3${colorV}m ${1} \033[0m"
}

# 伪装域名
read -p "请输入伪装域名(例如 www.baidu.com):" xrayDomain
if 
	[[ $xrayDomain = "" ]];
then
	echoTxtColor "请输入伪装域名！" "red"
	exit
fi

# 伪装路径
read -p "请输入伪装路径，默认随机生成:" xrayPath

if 
	[[ $xrayPath = "" ]];
then
	xrayPath=$(random_str 1 15)
fi

# xray端口
read -p "请输入xray端口，默认随机生成:" xrayPort

if 
	[[ $xrayPort = "" ]];
then
	xrayPort=$(random_num 1500 20000)
fi

# 用户数量
read -p "请输入生成用户的数量，默认10:" userNum

if 
	[[ $userNum = "" ]];
then
	userNum=10
fi

xrayUserJson='';

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

for((i=1;i<=${userNum};i++));  
	do   
	xrayUserJson=${xrayUserJson}"
            {
                \"id\": \"`cat /proc/sys/kernel/random/uuid`\", 
                \"level\": `random_num 1 9`,
                \"alterId\": `random_num 1 30`
            },"
done 

echo "
{
  \"inbounds\": [
    {
      \"port\": ${xrayPort},
      \"listen\": \"127.0.0.1\",
      \"protocol\": \"vless\",
      \"settings\": {
        \"decryption\": \"none\",
        \"clients\": [${xrayUserJson%?}
        ]
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"wsSettings\": {
          \"path\": \"/${xrayPath}\",
          \"headers\": {
            \"Host\": \"${xrayDomain}\"
          }
        }
      }
    }
  ],
  \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {}
    }
  ]
}
" > /usr/local/etc/xray/config.json

systemctl restart xray
systemctl enable xray
systemctl status xray

crontabStr='0 23 * * 6  bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install && systemctl restart xray'
crontabConfigEnd=$(tail -n 1 /var/spool/cron/root)

if [[ $crontabStr != $crontabConfigEnd ]];then
    echo "$crontabStr" >> /var/spool/cron/root 
    systemctl reload crond.service
    systemctl restart crond.service
fi

echo -e "\n"
echoTxtColor "xray 用户uuid配置如下" "yellow";
echo -e "\n"
echo ${xrayUserJson}
echo -e "\n"
echoTxtColor "nginx 配置内容如下：" "yellow";

nginxConfig="
 location /${xrayPath} { 
      if (\$http_upgrade != "websocket") { 
           rewrite ^(.*)\$ https://\$host;
      }
      proxy_redirect off;
      proxy_pass http://127.0.0.1:${xrayPort};
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
"
echo "$nginxConfig"
echo -e "\n"

