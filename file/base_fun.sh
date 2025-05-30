#!/usr/bin/env bash

#指定区间随机数
function random_num_fun {
   shuf -i $1-$2 -n1
}

#指定区间随机字符串
function random_str_fun {
   echo $($(cat /proc/sys/kernel/random/uuid || uuidgen) | cut -c $1-$2) | sed 's/-//g'
}

# 打印文字颜色方法
# 调用示例
# echo_txt_color_fun "您的文字颜色打印成功" "green"
echo_txt_color_fun(){
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
# 函数调用示例 get_new_version_num_fun 'https://www.ffmpeg.org/releases/' 'ffmpeg'
get_new_version_num_fun(){
	if [[ $1 =~ github.com ]]
		then
			wget --timeout=10 -qO- $1 | grep -Po '(?<=/tag/)[vV]?([0-9]+\.)+[0-9]+' | head -n 1
		else 
			wget --timeout=10 -qO- $1 | grep -Po '(?<='$2'.)[vV]?([0-9]+\.)+[0-9]+' | tail -n 1
	fi
}

# 获取系统判断包管理器
get_package_manage_fun(){

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
