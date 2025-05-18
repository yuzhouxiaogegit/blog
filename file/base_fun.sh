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
# 调用示例
# echoTxtColor "您的文字颜色打印成功" "green"
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

# 获取最新软件版本号码,非gitbub版本号也能获取,例如:ffmpeg等
# $1 = 软件releases地址
# $2 = 软件名称
# 函数调用示例 getNewVersionNum 'https://github.com/fatedier/frp/releases/' 'frp'
getNewVersionNum(){
	wget --timeout=10 $1 -O temp_$2.txt && echo "$(grep -Eo $2.[0-9.]+ temp_$2.txt | grep -Eo [0-9.]+[0-9] | tail -n 1)" && rm -rf temp_$2.txt
}
