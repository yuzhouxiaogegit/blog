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
# $1 = 软件releases地址  参数示列值（https://www.ffmpeg.org/releases/）
# $2 = 软件名称：ffmpeg  参数示列值（ffmpeg-7.0.2.tar.xz）  
# 函数调用示例 getNewVersionNum 'https://www.ffmpeg.org/releases/' 'ffmpeg'
getNewVersionNum(){
	if [[ $1 =~ github.com ]]
		then
			wget --timeout=10 -qO- $1 | grep -Po '(?<=/tag/)[vV]?([0-9]+\.)+[0-9]+' | head -n 1
		else 
			wget --timeout=10 -qO- $1 | grep -Po '(?<='$2'.)[vV]?([0-9]+\.)+[0-9]+' | tail -n 1
	fi
}
