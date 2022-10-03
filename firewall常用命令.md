# firewall常用命令
```sh
yum install -y firewalld # 安装防火墙
```
1、查看firewall状态
```code
firewall-cmd --state
```
2、关闭firewall
```code
systemctl stop firewalld.service
```
3、开启firewall
```code
systemctl start firewalld.service
```
4、重启firewall
```code
systemctl restart firewalld.service
```
5、重载firewall
```code
firewall-cmd --reload
```
6、禁止firewall开机启动
```code
systemctl disable firewalld.service
```
7、设置firewall开机启动
```code
systemctl enable firewalld.service
```
8、查看端口开放列表
```code
firewall-cmd --list-ports
```
9、永久开放80端口
```code
firewall-cmd --zone=public --add-port=80/tcp --permanent
```
10、允许192.168.1.1 访问80端口
```code
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.1" port protocol="tcp" port="80" accept'
```
11、移除192.168.1.1 访问80端口
```code
firewall-cmd --permanent --remove-rich-rule='rule family="ipv4" source address="192.168.1.1" port protocol="tcp" port="80" accept'
```
12、永久关闭80端口
```code
firewall-cmd --zone=public --remove-port=80/tcp --permanent
```
13、允许192.168.1.1所有访问所有端口
```code
firewall-cmd --zone=public --add-rich-rule 'rule family="ipv4" source address="192.168.1.1" accept' --permanent
```
14、移除192.168.1.1所有访问所有端口
```code
firewall-cmd --zone=public --remove-rich-rule 'rule family="ipv4" source address="192.168.1.1" accept' --permanent
```
15、允许192.168.1.0/24(0-255)所有访问所有端口
```code
firewall-cmd --zone=public --add-rich-rule 'rule family="ipv4" source address="192.168.1.0/24" accept' --permanent
```
16、屏蔽192.168.1.1 访问
```code
firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=192.168.1.1 reject"
```
17、查看屏蔽结果
```code
firewall-cmd --list-rich-rules
```
