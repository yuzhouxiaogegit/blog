### 获取github 项目中的版本号
1、获取正式版本号 getVersion "XTLS/Xray-core"

2、获取开发版本号 getVersion "XTLS/Xray-core" "dev"
```sh
# 获取github 项目中的最新版本号
getVersion(){
	versionType=""
	if [[ $2 = 'dev' ]];
	then
		versionType="/latest"
	else
		versionType=""
	fi
	echo $(wget -qO- -t1 -T2 "https://api.github.com/repos/${1}/releases${versionType}" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/[^\.0-9A-Za-z]//g')
}
# 调用示例
# 传入项目名称（动态变化的路径部分）  "XTLS/Xray-core"
getVersion "XTLS/Xray-core"
```

### 打印文字颜色方法
1、打印红色 echoTxtColor "常用shell脚本方法封装" "red"

2、打印绿色 echoTxtColor "常用shell脚本方法封装" "green"

3、打印黄色 echoTxtColor "常用shell脚本方法封装" "yellow"
```sh
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
echoTxtColor "常用shell脚本方法封装" "green"
```
