#!/bin/bash

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
# 调用示例
# echoTxtColor "您的文字颜色打印成功" "green"

yum install -y firewalld # 安装防火墙

read -p "请输入允许的ip通过防火墙【多个ip用英文逗号间隔】,输入n取消:" ipList

resIpList=(${ipList//,/ })

for ip in ${resIpList[@]}; do
	if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		firewall-cmd --zone=public --add-rich-rule 'rule family="ipv4" source address="'${ip}'" accept' --permanent
	fi
done

read -p "是否屏蔽非80,443的端口:(默认y/n)" portClose

if [[ $portClose == 'y' || $portClose == '' ]]; then

	portList=$(firewall-cmd --list-ports)
	resPortList=(${portList// / })
 
	firewall-cmd --zone=public --add-port=80/tcp --permanent
	firewall-cmd --zone=public --add-port=80/udp --permanent
	firewall-cmd --zone=public --add-port=443/tcp --permanent
	firewall-cmd --zone=public --add-port=443/udp --permanent
 
	for v in ${resPortList[@]}; do
		if [[ $v == '80/tcp' || $v == '80/udp' || $v == '443/tcp' || $v == '443/udp' ]]; then
			continue
		fi
		firewall-cmd --zone=public --remove-port=$v --permanent
	done
fi

firewall-cmd --reload

echo -e "\n"
echoTxtColor "防火墙开放端口列表" "green"
firewall-cmd --list-ports

echo -e "\n"
echoTxtColor "允许通过防火墙的ip" "green"
firewall-cmd --list-rich-rules
