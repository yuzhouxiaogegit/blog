#!/usr/bin/env bash

#base64加密方法
#echo $(yzxg_base64_en '12')
yzxg_base64_en(){
	local loopNum=${2:-1} # 加密次数
	local tempStr=${1:-} # 加密字符串
	for (( i=1; i<=$loopNum; i++ ))
	do
	    tempStr=$(printf '%s' "$tempStr" | base64)
	done
	echo $(echo $tempStr | grep -Eo '[A-Za-z0-9+/=]+')
}

#base64解密方法
#echo $(yzxg_base64_de "$(echo $(yzxg_base64_en '12'))")
yzxg_base64_de(){
	local loopNum=${2:-1} # 解密次数
	local tempStr=${1:-} # 解密字符串
	for (( i=1; i<=$loopNum; i++ ))
	do
	    tempStr=$(printf '%s' "$tempStr" | grep -Eo '[A-Za-z0-9+/=]+' | base64 -d)
	done
	echo $tempStr
}

#字符加密方法，支持键盘字符
#echo $(yzxg_char_en 'qqqqq' 5)
yzxg_char_en(){
	local tempStr=${1:-} #加密值
	local salt=${2:-0} #加密盐
	for (( i=0; i<${#tempStr}; i++ )); do
	    local char="${tempStr:$i:1}"
	    local originalAscii=$(printf "%d" "'$char")
         local newAscii=$((originalAscii + salt))
                  printf "%d " "$newAscii"    
	done
}

#字符串解密方法，支持键盘字符
#echo $(yzxg_char_de "$(yzxg_char_en 'qqqqq' 5)" 5)
yzxg_char_de(){
	local tempStr=${1:-} # 解密值
	local salt=${2:-0} # 解密盐
	local decodedString=''
     for code in $tempStr; do
         local originalAscii=$((code - salt))
         local charHex=$(printf "%x" "$originalAscii") 
               decodedString+=$(printf "\\x$charHex")
     done
     echo $decodedString
}

#指定区间随机数
#echo $(yzxg_random_num 8 16)
yzxg_random_num(){
   shuf -i $1-$2 -n1
}

#指定区间随机字符串
#echo $(yzxg_random_str 8 19)
yzxg_random_str(){
   echo $((cat /proc/sys/kernel/random/uuid || uuidgen) | cut -c $1-$2) | sed 's/-//g'
}

# 打印文字颜色方法
# yzxg_echo_txt_color "您的文字颜色打印成功" "green"
yzxg_echo_txt_color(){
	local colorV="1"
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
# 函数调用示例 yzxg_get_new_version_num 'https://www.ffmpeg.org/releases/' 'ffmpeg'
yzxg_get_new_version_num(){
	if [[ $1 =~ github.com ]]
		then
			wget --timeout=10 -qO- $1 | grep -Po '(?<=/tag/)[vV]?([0-9]+\.)+[0-9]+' | head -n 1
		else 
			wget --timeout=10 -qO- $1 | grep -Po '(?<='$2'.)[vV]?([0-9]+\.)+[0-9]+' | tail -n 1
	fi
}

# 获取系统判断包管理器
yzxg_get_package_manage(){
	if command -v yum &> /dev/null; then
	    # 系统使用 yum (可能是 CentOS/RHEL/Fedora)
	    echo "yum"
	elif command -v dnf &> /dev/null; then
	    # 系统使用 dnf (可能是 Fedora/较新的 RHEL)
	    echo "dnf"
	elif command -v apt-get &> /dev/null; then
	    # 系统使用 apt-get (可能是 Debian/Ubuntu)
	    echo "apt"
	elif command -v zypper &> /dev/null; then
	    # 系统使用 zypper (可能是 openSUSE/SUSE Linux Enterprise)
	    echo "zypper"
	elif command -v pacman &> /dev/null; then
	    # 系统使用 pacman (可能是 Arch Linux)
	    echo "pacman"
	else
	    # 无法确定包管理器类型
	    echo "unknown"
	fi
}
