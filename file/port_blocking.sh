#!/bin/bash

# 脚本函数初始化
source <(timeout 5 curl -sL https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/base_fun.sh) && clear

read -p "请输入允许的ip通过防火墙【多个ip用空格间隔】(默认不处理):" ipList

read -p "开放特定端口【多个端口用空格间隔】(默认不处理):" portList

read -p "是否同时开放udp协议(默认n/y):" udpStatus

# 支持 centos yum 命令 
if [[ $(yzxg_get_package_manage) = 'yum' ]]
then

	if ! command -v firewall-cmd &>/dev/null; then
	   yum install -y firewalld && systemctl restart firewalld.service
	fi
	
	# 允许特定ip通过防火墙 start -->
	ipList=$(echo $ipList | grep -Po '([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})+')
	if [[ $ipList && $ipList =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)+ ]]; then
		for reIp in $(firewall-cmd --list-rich-rules | grep -Po '([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})+'); do
			firewall-cmd --zone=public --remove-rich-rule 'rule family="ipv4" source address="'$reIp'" accept' --permanent
		done
		for acIp in $ipList; do
			firewall-cmd --zone=public --add-rich-rule 'rule family="ipv4" source address="'${acIp}'" accept' --permanent
		done
	fi
	# 允许特定ip通过防火墙 end <--

	# 开放特定端口 start -->
	if [[ $portList ]]; then
		for oldPort in $(firewall-cmd --list-ports | grep -Po '[^\s]+'); do
			firewall-cmd --zone=public --remove-port=$oldPort --permanent
		done
		for port in $(echo $portList | grep -Po '\d+'); do
			if (( port >= 1 && port <= 65535 )); then
				firewall-cmd --zone=public --add-port=$port/tcp --permanent
				if [[ $udpStatus == 'y' ]]; then
					firewall-cmd --zone=public --add-port=$port/udp --permanent
				fi
			fi
		done
	fi
	# 开放特定端口 end <--
	firewall-cmd --reload
	systemctl restart firewalld.service
	
	echo -e "\n"
	yzxg_echo_txt_color "防火墙开放端口列表" "green"
	firewall-cmd --list-ports
	
	echo -e "\n"
	yzxg_echo_txt_color "查看允许通过防火墙的ip列表" "green"
	firewall-cmd --list-rich-rules
else
	yzxg_echo_txt_color "暂不支持您的防火墙，等待更新" "green"
fi
