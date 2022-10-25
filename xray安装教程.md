# vless + websocket + tls + nginx 安装教程

### 一键安装脚本（xray）官方脚本
```code
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```
### 修改配置文件 config.json
```code
cd /usr/local/etc/xray
```
### 配置文件内容为
```code
{
  "inbounds": [
    {
      "port": 10000, // 修改端口
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "76264082-4d96-4024-83d1-0aaa64d635e6", // uuid 自行修改
            "level": 9,
            "alterId": 19
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ray", // 代理服务器的路径，自行修改
          "headers": {
            "Host": "baidu.com" // 当前代理服务器的域名，自行修改
          }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
```
### 也可直接下载配置文件内容 config.json 到/usr/local/etc/xray目录下进行修改
```code
wget https://raw.githubusercontent.com/yuzhouxiaogegit/blog/main/file/config.json
```
### 设置开机启动
``` code
sudo systemctl enable xray
```
### 关闭开机启动
``` code
sudo systemctl disable xray
```
### 重启xray服务
``` code
sudo systemctl restart xray
```
### 查看是否开启状态
``` code
sudo systemctl status xray
```
### 启动
``` code
sudo systemctl start xray
```
### 停止
``` code
sudo systemctl stop xray
```

### 配置nginx 转发

```code
 location /ray { # 与 xray 配置中的 path 保持一致
      if ($http_upgrade != "websocket") { # WebSocket协商失败时返回首页
           rewrite ^(/.*)$ https://$host$1 permanent;
      }
      proxy_redirect off;
      proxy_pass http://127.0.0.1:10000; # 假设WebSocket监听在环回地址的10000端口上
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
```

### 配置定时任务，每周自动更新 xray

```code
 crontab -e
```
### 每周六，23点定时更新并且重启
```code
0 23 * * 6  bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install && systemctl restart xray
```
### 重载定时任务配置
```code
systemctl reload crond.service
```
### 重启定时任务
```code
systemctl restart crond.service
```
