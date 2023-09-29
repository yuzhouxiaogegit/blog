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
# 获取github 项目中的最新版本号
getVersion(){
	# 获取github项目中最新版本号
	echo $(wget -qO- -t1 -T2 "https://api.github.com/${1}/m3u8-downloader/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
}
# 调用示例
# 传入项目名称  "repos/llychao"
# getVersion "repos/llychao"
