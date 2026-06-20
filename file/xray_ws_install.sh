#!/usr/bin/env bash

# --- 1. 强制 Root 权限与错误终止 ---
if [[ $EUID -ne 0 ]]; then
   echo "错误：此脚本必须以 root 权限运行"
   exit 1
fi
set -e

# --- 颜色定义 ---
echoTxtColor(){
    local color_code="3${2:-1}"
    case $2 in
        "green") color_code="32" ;; "yellow") color_code="33" ;; "red") color_code="31" ;;
    esac
    echo -e "\033[${color_code}m${1}\033[0m"
}

# --- 2. 依赖全自动安装模块 ---
install_dependencies() {
    local deps=("curl" "jq" "sed")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "安装依赖: $dep..."
            if command -v apt-get &> /dev/null; then apt-get update && apt-get install -y "$dep" || true
            elif command -v yum &> /dev/null; then yum install -y epel-release && yum install -y "$dep" || true
            elif command -v dnf &> /dev/null; then dnf install -y "$dep" || true
            elif command -v apk &> /dev/null; then apk add --no-cache "$dep" || true
            fi
        fi
    done
}
install_dependencies

# --- 输入参数 ---
echo "请输入域名 (建议手动键盘输入):"
read -p "> " rawDomain
xrayDomain=$(echo "$rawDomain" | tr -cd '[:alnum:].-')
[[ -z "$xrayDomain" ]] && { echoTxtColor "域名格式错误" "red"; exit 1; }

read -p "请输入伪装路径 (如 /nc5COQMZ): " xrayPath
[[ -z "$xrayPath" ]] && xrayPath="/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
[[ "$xrayPath" != /* ]] && xrayPath="/$xrayPath"

# 端口逻辑：随机生成并保存到变量
xrayPort=$(shuf -i 10000-65535 -n1)
read -p "请输入用户数量: " userNum
userNum=${userNum:-1}

# --- 部署 Xray ---
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 生成用户数据
clients=$(for i in $(seq 1 $userNum); do cat /proc/sys/kernel/random/uuid; done | jq -R . | jq -s "map({
    id: ., 
    level: $((RANDOM % 9 + 1)), 
    alterId: $((RANDOM % 30 + 1))
})")

# 写入 Xray 配置文件
cat <<EOF > /usr/local/etc/xray/config.json
{
  "inbounds": [{
    "port": ${xrayPort},
    "listen": "127.0.0.1",
    "protocol": "vless",
    "settings": { "decryption": "none", "clients": $(echo $clients | jq -c .) },
    "streamSettings": {
      "network": "ws",
      "wsSettings": { "path": "${xrayPath}", "host": "${xrayDomain}" }
    }
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

systemctl restart xray
systemctl enable xray

# --- 输出结果 ---
echo -e "\n"
echoTxtColor "================ 节点列表 (直接复制即可) ================" "green"
echo "$clients" | jq -c '.[]' | while read -r client; do
    uuid=$(echo "$client" | jq -r '.id')
    echoTxtColor "vless://${uuid}@${xrayDomain}:443?type=ws&path=${xrayPath}&host=${xrayDomain}&security=tls&sni=${xrayDomain}#${xrayDomain}" "green"
    echo "" 
done

# --- 输出 Nginx 配置 ---
echoTxtColor "================ Nginx 反代配置 ================" "yellow"
# 使用 \ 转义 Nginx 变量，让 Shell 忽略它们，同时确保 ${xrayPort} 正确解析
cat <<EOF
    location ${xrayPath} {
        if (\$http_upgrade != "websocket") {
            rewrite ^(.*)\$ https://\$host permanent;
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
EOF
echo "================================================"
